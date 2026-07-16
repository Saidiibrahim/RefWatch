import { createHash, randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import pg from "pg";
import { livePrivilegeContract, liveSchemaContract, schemaContractDigest } from "./ledger-schema-contract.mjs";

const expectedBranchId = "ng9tgmy4pyi5";
const ledgerLockKey = "593105010451970337";
const databaseURL = required("REFWATCH_LEDGER_REHEARSAL_DATABASE_URL");
const baselineOutput = required("REFWATCH_LEDGER_BASELINE_OUTPUT");
const workerVersionId = required("REFWATCH_LEDGER_WORKER_VERSION_ID");
if (process.env.REFWATCH_ALLOW_LEDGER_REHEARSAL_PROBE !== "1") {
  throw new Error("Ledger rehearsal probe requires explicit opt-in");
}
const parsed = new URL(databaseURL);
const username = decodeURIComponent(parsed.username);
if (parsed.protocol !== "postgresql:" || !username.startsWith("pscale_api_") || !username.endsWith(`.${expectedBranchId}`)) {
  throw new Error("Ledger rehearsal probe refused a non-allowlisted PlanetScale branch");
}
if (parsed.searchParams.get("sslmode") !== "verify-full") throw new Error("Ledger rehearsal probe requires sslmode=verify-full");

const capturedTables = [
  "app_users", "clerk_user_deletion_tombstones", "user_devices", "teams", "team_members",
  "team_officials", "team_tags", "competitions", "venues", "scheduled_matches", "matches",
  "match_periods", "match_events", "match_metrics", "match_assessments", "pages",
  "workout_presets", "workout_sessions", "ai_threads", "ai_messages", "ai_attachments", "ai_usage_daily",
];
const client = new pg.Client({ connectionString: databaseURL });
await client.connect();
let epochId;
try {
  epochId = randomUUID();
  await client.query("begin isolation level repeatable read");
  await client.query("select pg_advisory_xact_lock($1::bigint)", [ledgerLockKey]);
  const baselineSchemaContract = await liveSchemaContract(client);
  const baselinePrivilegeContract = await livePrivilegeContract(client);
  const baselineSchemaHash = schemaContractDigest(baselineSchemaContract);

  const baselineTables = {};
  for (const table of capturedTables) {
    const result = await client.query(`select coalesce(jsonb_agg(to_jsonb(row_value) order by to_jsonb(row_value)::text), '[]'::jsonb) payload from ${quoteIdentifier(table)} row_value`);
    baselineTables[table] = result.rows[0].payload;
  }
  const baselineDataHash = digest(baselineTables);
  const capturedAt = new Date().toISOString();
  const baselineSnapshotId = `planetscale:${expectedBranchId}:${capturedAt}`;
  const mutationGroupId = randomUUID();
  const ownerId = randomUUID();
  const teamId = randomUUID();
  const requestId = `ledger-probe-${randomUUID()}`;

  await client.query(`
    insert into mutation_ledger_epochs (
      id, status, capture_enforced, baseline_snapshot_id, baseline_schema_hash,
      baseline_data_hash, opened_at
    ) values ($1, 'open', true, $2, $3, $4, now())
  `, [epochId, baselineSnapshotId, baselineSchemaHash, baselineDataHash]);
  await client.query("commit");
  await mkdir(dirname(baselineOutput), { recursive: true });
  await writeFile(baselineOutput, `${canonicalJSONString({
    schema_version: 1,
    branch_id: expectedBranchId,
    epoch_id: epochId,
    captured_at_utc: capturedAt,
    baseline_snapshot_id: baselineSnapshotId,
    baseline_schema_hash: baselineSchemaHash,
    baseline_schema_contract: baselineSchemaContract,
    baseline_privilege_contract: baselinePrivilegeContract,
    baseline_data_hash: baselineDataHash,
    tables: baselineTables,
  })}\n`, { mode: 0o600 });

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
    actor_id: "ledger-rehearsal-probe",
    worker_version_id: workerVersionId,
  };
  for (const [name, value] of Object.entries(settings)) {
    await client.query("select set_config($1, $2, true)", [`refwatch.${name}`, value]);
  }
  await client.query("insert into app_users (id, clerk_user_id, display_name) values ($1, $2, $3)", [ownerId, `ledger_probe_${ownerId}`, "Ledger Probe"]);
  await client.query("insert into teams (id, owner_id, name) values ($1, $2, $3)", [teamId, ownerId, "Ledger Probe Team"]);
  await client.query("update teams set name = $1, updated_at = now() where id = $2", ["Ledger Probe Team Final", teamId]);
  await client.query("commit");

  await client.query("begin isolation level repeatable read");
  await client.query("select pg_advisory_xact_lock($1::bigint)", [ledgerLockKey]);
  const watermark = await client.query("select coalesce(max(event_sequence), 0)::bigint value from mutation_outbox_events where epoch_id = $1", [epochId]);
  await client.query("update mutation_ledger_epochs set status = 'frozen', frozen_at = now(), frozen_event_sequence = $2, updated_at = now() where id = $1 and status = 'open'", [epochId, watermark.rows[0].value]);
  const events = await client.query("select event_id, event_sequence, table_name, operation from mutation_outbox_events where epoch_id = $1 order by event_sequence", [epochId]);
  await client.query("commit");

  process.stdout.write(`${JSON.stringify({
    branch_id: expectedBranchId,
    epoch_id: epochId,
    baseline_snapshot_id: baselineSnapshotId,
    baseline_schema_hash: baselineSchemaHash,
    baseline_data_hash: baselineDataHash,
    frozen_event_sequence: watermark.rows[0].value,
    probe_request_id: requestId,
    events: events.rows,
  })}\n`);
} catch (error) {
  await client.query("rollback").catch(() => undefined);
  if (epochId) {
    await client.query("begin").catch(() => undefined);
    await client.query("select pg_advisory_xact_lock($1::bigint)", [ledgerLockKey]).catch(() => undefined);
    await client.query("update mutation_ledger_epochs set status = 'frozen', frozen_at = now(), updated_at = now() where id = $1 and status = 'open'", [epochId]).catch(() => undefined);
    await client.query("update mutation_ledger_epochs set status = 'archived', capture_enforced = false, updated_at = now() where id = $1 and status = 'frozen'", [epochId]).catch(() => undefined);
    await client.query("commit").catch(() => undefined);
  }
  throw error;
} finally {
  await client.end();
}

function digest(value) {
  return createHash("sha256").update(canonicalJSONString(value)).digest("hex");
}

function canonicalJSONString(value) {
  if (value === null || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "string") return JSON.stringify(normalizeTimestamp(value));
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Cannot hash non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJSONString).join(",")}]`;
  if (typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJSONString(value[key])}`).join(",")}}`;
  throw new Error(`Cannot hash ${typeof value}`);
}

function normalizeTimestamp(value) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return value;
  const timestamp = new Date(value);
  return Number.isNaN(timestamp.getTime()) ? value : timestamp.toISOString();
}

function quoteIdentifier(value) {
  if (!/^[a-z][a-z0-9_]*$/.test(value)) throw new Error(`Unsafe SQL identifier: ${value}`);
  return `"${value}"`;
}

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}
