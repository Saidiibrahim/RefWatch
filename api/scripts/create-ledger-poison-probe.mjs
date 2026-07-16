import { execFile } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import pg from "pg";

const execute = promisify(execFile);
const expectedBranchId = "ng9tgmy4pyi5";
const expectedD1Database = "refwatch-mutation-ledger-rehearsal-20260715";
const expectedD1DatabaseId = "d6fd2757-0cfa-4468-97bc-c543de824917";
const ledgerLockKey = "593105010451970337";
const databaseURL = required("REFWATCH_LEDGER_REHEARSAL_DATABASE_URL");
const workerVersionId = required("REFWATCH_LEDGER_WORKER_VERSION_ID");
if (process.env.REFWATCH_ALLOW_LEDGER_POISON_PROBE !== "1") {
  throw new Error("Ledger poison probe requires explicit opt-in");
}
if (process.env.REFWATCH_LEDGER_D1_DATABASE !== expectedD1Database
  || process.env.REFWATCH_LEDGER_D1_DATABASE_ID !== expectedD1DatabaseId) {
  throw new Error("Ledger poison probe refused a non-allowlisted D1 database");
}
validateSourceURL(databaseURL);
if (!uuidPattern().test(workerVersionId)) throw new Error("Ledger poison probe requires a deployed Worker version UUID");

const wrangler = fileURLToPath(new URL("../node_modules/.bin/wrangler", import.meta.url));
const epochId = randomUUID();
const mutationGroupId = randomUUID();
const ownerId = randomUUID();
const requestId = `ledger-poison-${randomUUID()}`;
const client = new pg.Client({ connectionString: databaseURL });
await client.connect();
let event;
try {
  await client.query("begin isolation level repeatable read");
  await client.query("select pg_advisory_xact_lock($1::bigint)", [ledgerLockKey]);
  await client.query(`
    insert into mutation_ledger_epochs (
      id, status, capture_enforced, baseline_snapshot_id,
      baseline_schema_hash, baseline_data_hash, opened_at
    ) values ($1, 'open', true, $2, $3, $4, now())
  `, [
    epochId,
    `poison:${expectedBranchId}:${new Date().toISOString()}`,
    sha256("poison-schema-not-replayable"),
    sha256("poison-data-not-replayable"),
  ]);
  await client.query("commit");

  await client.query("begin");
  await client.query("select pg_advisory_xact_lock_shared($1::bigint)", [ledgerLockKey]);
  const settings = {
    mutation_group_id: mutationGroupId,
    group_ordinal: "0",
    source_kind: "admin",
    source_event_id: requestId,
    request_id: requestId,
    idempotency_key: "",
    app_user_id: ownerId,
    method: "",
    path: "",
    actor_id: "ledger-poison-probe",
    worker_version_id: workerVersionId,
  };
  for (const [name, value] of Object.entries(settings)) {
    await client.query("select set_config($1, $2, true)", [`refwatch.${name}`, value]);
  }
  await client.query(
    "insert into app_users (id, clerk_user_id, display_name) values ($1, $2, $3)",
    [ownerId, `ledger_poison_${ownerId}`, "Ledger Poison Probe"],
  );
  const eventResult = await client.query(`
    select event_id, event_sequence::int, epoch_id, mutation_group_id,
           group_ordinal, schema_version, source_kind, worker_version_id
    from mutation_outbox_events
    where request_id = $1
  `, [requestId]);
  if (eventResult.rowCount !== 1) throw new Error("Poison probe did not create exactly one event");
  event = eventResult.rows[0];
  await client.query(`
    update mutation_outbox_deliveries
    set next_attempt_at = now() + interval '15 minutes', updated_at = now()
    where event_id = $1
  `, [event.event_id]);
  await client.query("commit");

  await client.query("begin isolation level repeatable read");
  await client.query("select pg_advisory_xact_lock($1::bigint)", [ledgerLockKey]);
  await client.query(`
    update mutation_ledger_epochs
    set status = 'frozen', frozen_at = now(), frozen_event_sequence = $2, updated_at = now()
    where id = $1 and status = 'open' and capture_enforced
  `, [epochId, event.event_sequence]);
  await client.query("commit");

  const conflictingWorkerVersion = "intentional-poison-conflict";
  const insertSQL = `INSERT INTO mutation_ledger_events (
    event_id, event_sequence, epoch_id, mutation_group_id, group_ordinal,
    schema_version, source_kind, worker_version_id, content_digest,
    encryption_key_id, encryption_nonce, encrypted_envelope, materialized_at_utc
  ) VALUES (
    ${sqlString(event.event_id)}, ${Number(event.event_sequence)}, ${sqlString(event.epoch_id)},
    ${sqlString(event.mutation_group_id)}, ${Number(event.group_ordinal)}, ${Number(event.schema_version)},
    ${sqlString(event.source_kind)}, ${sqlString(conflictingWorkerVersion)}, ${sqlString("0".repeat(64))},
    'intentional-poison', 'AA==', 'AA==', ${sqlString(new Date().toISOString())}
  )`;
  const insertReceipt = await wranglerD1(insertSQL);
  const readReceipt = await wranglerD1(`
    SELECT event_id, event_sequence, epoch_id, mutation_group_id, group_ordinal,
           schema_version, source_kind, worker_version_id, content_digest,
           encryption_key_id, encryption_nonce, encrypted_envelope
    FROM mutation_ledger_events WHERE event_id = ${sqlString(event.event_id)}
  `);
  const readRows = parseD1(readReceipt.stdout);
  if (readRows.length !== 1 || readRows[0].worker_version_id !== conflictingWorkerVersion) {
    throw new Error("Poison D1 conflict readback did not match the guarded fixture");
  }

  await client.query(`
    update mutation_outbox_deliveries
    set next_attempt_at = now(), updated_at = now()
    where event_id = $1 and state = 'pending'
  `, [event.event_id]);
  process.stdout.write(`${JSON.stringify({
    ok: true,
    scope: "isolated-ledger-poison",
    branch_id: expectedBranchId,
    d1_database_id: expectedD1DatabaseId,
    epoch_id: epochId,
    event_id: event.event_id,
    event_sequence: event.event_sequence,
    mutation_group_id: event.mutation_group_id,
    request_id: requestId,
    worker_version_id: workerVersionId,
    conflict_field: "worker_version_id",
    conflicting_value: conflictingWorkerVersion,
    d1_insert_stdout_sha256: sha256(insertReceipt.stdout),
    d1_read_stdout_sha256: sha256(readReceipt.stdout),
    d1_read_served_by_primary: readRows.servedByPrimary,
    delivery_released_at_utc: new Date().toISOString(),
  })}\n`);
} catch (error) {
  await client.query("rollback").catch(() => undefined);
  await client.query("begin").catch(() => undefined);
  await client.query("select pg_advisory_xact_lock($1::bigint)", [ledgerLockKey]).catch(() => undefined);
  await client.query(`
    update mutation_ledger_epochs
    set status = case when status = 'open' then 'frozen' else status end,
        frozen_at = coalesce(frozen_at, now()),
        updated_at = now()
    where id = $1 and status = 'open'
  `, [epochId]).catch(() => undefined);
  await client.query(`
    update mutation_ledger_epochs
    set status = 'archived', capture_enforced = false, updated_at = now()
    where id = $1 and status = 'frozen'
  `, [epochId]).catch(() => undefined);
  await client.query("commit").catch(() => undefined);
  throw error;
} finally {
  await client.end();
}

async function wranglerD1(command) {
  const result = await execute(wrangler, [
    "d1", "execute", expectedD1Database,
    "--env", "rehearsal",
    "--remote",
    "--json",
    "--command", command,
  ], { cwd: fileURLToPath(new URL("..", import.meta.url)), maxBuffer: 10 * 1_024 * 1_024 });
  return { stdout: result.stdout, stderr: result.stderr };
}

function parseD1(value) {
  const documents = JSON.parse(value);
  const rows = documents.flatMap((document) => document.results ?? []);
  rows.servedByPrimary = documents.every((document) => document.success === true && document.meta?.served_by_primary === true);
  if (!rows.servedByPrimary) throw new Error("Poison D1 read was not served by primary");
  return rows;
}

function validateSourceURL(value) {
  const parsed = new URL(value);
  const username = decodeURIComponent(parsed.username);
  if (parsed.protocol !== "postgresql:" || !username.startsWith("pscale_api_") || !username.endsWith(`.${expectedBranchId}`)) {
    throw new Error("Poison probe refused a non-allowlisted PlanetScale branch");
  }
  if (parsed.searchParams.get("sslmode") !== "verify-full") throw new Error("Poison probe requires sslmode=verify-full");
}

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function uuidPattern() {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
}

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}
