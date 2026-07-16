import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import pg from "pg";
import { livePrivilegeContract, liveSchemaContract, schemaContractDigest } from "./ledger-schema-contract.mjs";
import { foreignKeyRelationships, orderMutationGroups } from "./mutation-group-order.mjs";

const expectedBranchId = "ng9tgmy4pyi5";
const expectedReadonlyRoleId = "psf6epuvymjt";
const capturedTables = [
  "app_users", "clerk_user_deletion_tombstones", "user_devices", "teams", "team_members",
  "team_officials", "team_tags", "competitions", "venues", "scheduled_matches", "matches",
  "match_periods", "match_events", "match_metrics", "match_assessments", "pages",
  "workout_presets", "workout_sessions", "ai_threads", "ai_messages", "ai_attachments", "ai_usage_daily",
];
const secondSameContractTableMap = Object.freeze(Object.fromEntries(capturedTables.map((table) => [table, table])));

if (process.env.REFWATCH_ALLOW_DESTRUCTIVE_LEDGER_REPLAY !== "1") {
  throw new Error("Ledger replay requires explicit destructive opt-in");
}
const baselinePath = required("REFWATCH_LEDGER_BASELINE_PATH");
const ledgerPath = required("REFWATCH_LEDGER_D1_EXPORT_PATH");
const targetURL = required("REFWATCH_LEDGER_REPLAY_TARGET_URL");
const sourceURL = required("REFWATCH_LEDGER_REHEARSAL_SOURCE_URL");
const targetMarker = required("REFWATCH_LEDGER_REPLAY_TARGET_MARKER");
const keyring = replayKeyring();
const targetKind = required("REFWATCH_LEDGER_REPLAY_TARGET_KIND");
if (!new Set(["same_schema", "second_same_contract"]).has(targetKind)) {
  throw new Error("Replay target kind must be same_schema or second_same_contract");
}
validateSourceURL(sourceURL);
validateTargetURL(targetURL, targetKind);
if (normalizedURL(sourceURL) === normalizedURL(targetURL)) throw new Error("Replay source and target must differ");

const baseline = JSON.parse(await readFile(baselinePath, "utf8"));
if (baseline.branch_id !== expectedBranchId || !uuidPattern().test(baseline.epoch_id ?? "")) {
  throw new Error("Baseline is not bound to the allowlisted rehearsal epoch");
}
const exportDocument = JSON.parse(ledgerPath === "-" ? await readStdin() : await readFile(ledgerPath, "utf8"));
const ledgerRows = exportDocument.flatMap((result) => result.results ?? []);
if (!ledgerRows.length) throw new Error("D1 replay export is empty");
assertUnique(ledgerRows.map((row) => row.event_id), "D1 event ID");
assertUnique(ledgerRows.map((row) => `${row.epoch_id}:${row.event_sequence}`), "D1 epoch sequence");
assertUnique(ledgerRows.map((row) => `${row.mutation_group_id}:${row.group_ordinal}`), "D1 group ordinal");

const target = new pg.Client({ connectionString: targetURL });
const source = new pg.Client({ connectionString: sourceURL });
const procedureStartedAt = new Date();
await Promise.all([target.connect(), source.connect()]);
let targetTransactionOpen = false;
try {
  await source.query("begin isolation level repeatable read read only");
  await assertReadOnlyRehearsalSource(source);
  await assertDisposableTarget(target, targetMarker);
  const sourceContract = await sourceEpochContract(source, baseline.epoch_id);
  const comparison = compareD1ToSource(ledgerRows, sourceContract.events);
  if (comparison.missing_event_ids.length || comparison.unexpected_event_ids.length || comparison.metadata_mismatches.length) {
    throw new Error(`D1/source reconciliation mismatch: ${JSON.stringify(comparison)}`);
  }

  const envelopes = [];
  for (const row of ledgerRows) {
    const plaintext = await decrypt(row, keyring);
    if (sha256(plaintext) !== row.content_digest) throw new Error(`Digest mismatch for ${row.event_id}`);
    const envelope = JSON.parse(plaintext);
    assertEnvelopeMatchesRow(envelope, row);
    envelopes.push(envelope);
  }
  const orderedGroups = orderMutationGroups(
    envelopes,
    canonicalJSONString,
    foreignKeyRelationships(baseline.baseline_schema_contract),
  );

  await target.query("begin");
  targetTransactionOpen = true;
  const targetSchemaHash = await schemaHash(target);
  if (targetSchemaHash !== baseline.baseline_schema_hash) {
    throw new Error(`Replay target schema hash mismatch: ${targetSchemaHash} != ${baseline.baseline_schema_hash}`);
  }
  await clearReplayTarget(target);
  await restoreBaseline(target, baseline.tables);
  const restoredTables = await tableSnapshot(target, true);
  const restoredBaselineHash = sha256(canonicalJSONString(restoredTables));
  if (restoredBaselineHash !== baseline.baseline_data_hash) {
    const mismatches = capturedTables.filter((table) =>
      sha256(canonicalJSONString(restoredTables[table])) !== sha256(canonicalJSONString(baseline.tables[table] ?? []))
    ).map((table) => ({
      table,
      expected: sha256(canonicalJSONString(baseline.tables[table] ?? [])),
      actual: sha256(canonicalJSONString(restoredTables[table])),
    }));
    throw new Error(`Restored baseline hash mismatch: ${restoredBaselineHash}; tables=${JSON.stringify(mismatches)}`);
  }
  for (const group of orderedGroups) {
    for (const envelope of group) await applyEnvelope(target, envelope);
  }
  const [targetHash, sourceHash] = await Promise.all([dataHash(target, true), dataHash(source)]);
  if (targetHash !== sourceHash) throw new Error(`Replay target/source hash mismatch: ${targetHash} != ${sourceHash}`);
  await target.query("commit");
  targetTransactionOpen = false;

  const completedAt = new Date();
  process.stdout.write(`${JSON.stringify({
    ok: true,
    target_kind: targetKind,
    baseline_snapshot_id: baseline.baseline_snapshot_id,
    epoch_id: baseline.epoch_id,
    frozen_event_sequence: sourceContract.frozen_event_sequence,
    expected_event_count: sourceContract.events.length,
    replay_event_count: envelopes.length,
    missing_event_ids: comparison.missing_event_ids,
    unexpected_event_ids: comparison.unexpected_event_ids,
    metadata_mismatches: comparison.metadata_mismatches,
    measured_rpo_events: comparison.missing_event_ids.length,
    baseline_schema_hash: baseline.baseline_schema_hash,
    target_schema_hash: targetSchemaHash,
    target_privilege_digest: sha256(canonicalJSONString(await livePrivilegeContract(target))),
    target_adapter_digest: sha256(canonicalJSONString(targetAdapter())),
    baseline_data_hash: baseline.baseline_data_hash,
    final_source_data_hash: sourceHash,
    final_target_data_hash: targetHash,
    first_event_sequence: Math.min(...envelopes.map((event) => Number(event.event_sequence))),
    last_event_sequence: Math.max(...envelopes.map((event) => Number(event.event_sequence))),
    mutation_group_count: orderedGroups.length,
    procedure_started_at_utc: procedureStartedAt.toISOString(),
    completed_at_utc: completedAt.toISOString(),
    observed_replay_procedure_seconds: (completedAt.getTime() - procedureStartedAt.getTime()) / 1_000,
  })}\n`);
} catch (error) {
  if (targetTransactionOpen) await target.query("rollback").catch(() => undefined);
  throw error;
} finally {
  await source.query("rollback").catch(() => undefined);
  await Promise.all([target.end(), source.end()]);
}

async function sourceEpochContract(client, epochId) {
  const epoch = await client.query(`
    select id, status, capture_enforced, frozen_event_sequence
    from mutation_ledger_epochs where id = $1
  `, [epochId]);
  const row = epoch.rows[0];
  if (epoch.rowCount !== 1 || !["frozen", "archived"].includes(row.status) || row.frozen_event_sequence === null) {
    throw new Error("Replay source epoch is not frozen at an exact watermark");
  }
  const events = await client.query(`
    select event.event_id, event.event_sequence::bigint, event.epoch_id,
           event.mutation_group_id, event.group_ordinal, event.schema_version,
           event.source_kind, event.worker_version_id, delivery.content_digest,
           delivery.encryption_key_id, delivery.encryption_nonce,
           delivery.encrypted_envelope, delivery.state delivery_state
    from mutation_outbox_events event
    join mutation_outbox_deliveries delivery on delivery.event_id = event.event_id
    where event.epoch_id = $1 and event.event_sequence <= $2
    order by event.event_sequence
  `, [epochId, row.frozen_event_sequence]);
  if (events.rows.some((event) => event.delivery_state !== "delivered")) {
    throw new Error("Replay source epoch contains an undelivered event");
  }
  return { frozen_event_sequence: Number(row.frozen_event_sequence), events: events.rows };
}

function compareD1ToSource(d1Rows, sourceRows) {
  const d1ById = new Map(d1Rows.map((row) => [row.event_id, row]));
  const sourceById = new Map(sourceRows.map((row) => [row.event_id, row]));
  const missing = [...sourceById.keys()].filter((id) => !d1ById.has(id)).sort();
  const unexpected = [...d1ById.keys()].filter((id) => !sourceById.has(id)).sort();
  const fields = [
    "event_sequence", "epoch_id", "mutation_group_id", "group_ordinal", "schema_version",
    "source_kind", "worker_version_id", "content_digest", "encryption_key_id",
    "encryption_nonce", "encrypted_envelope",
  ];
  const metadataMismatches = [];
  for (const [id, source] of sourceById) {
    const d1 = d1ById.get(id);
    if (!d1) continue;
    const mismatchedFields = fields.filter((field) => String(d1[field]) !== String(source[field]));
    if (mismatchedFields.length) metadataMismatches.push({ event_id: id, fields: mismatchedFields });
  }
  return { missing_event_ids: missing, unexpected_event_ids: unexpected, metadata_mismatches: metadataMismatches };
}

function assertEnvelopeMatchesRow(envelope, row) {
  const pairs = [
    ["event_id", envelope.event_id, row.event_id],
    ["event_sequence", envelope.event_sequence, row.event_sequence],
    ["epoch_id", envelope.epoch_id, row.epoch_id],
    ["mutation_group_id", envelope.mutation_group_id, row.mutation_group_id],
    ["group_ordinal", envelope.group_ordinal, row.group_ordinal],
    ["schema_version", envelope.schema_version, row.schema_version],
    ["source_kind", envelope.source_kind, row.source_kind],
    ["worker_version_id", envelope.worker_version_id, row.worker_version_id],
  ];
  const mismatch = pairs.find(([, left, right]) => String(left) !== String(right));
  if (mismatch) throw new Error(`D1 metadata/envelope mismatch for ${row.event_id}: ${mismatch[0]}`);
  if (!Number.isInteger(Number(envelope.entity_revision)) || Number(envelope.entity_revision) < 1) {
    throw new Error(`Invalid entity revision for ${row.event_id}`);
  }
}

async function clearReplayTarget(client) {
  await client.query(`truncate table ${capturedTables.map((table) => quoteIdentifier(targetTable(table))).join(", ")} restart identity cascade`);
}

async function restoreBaseline(client, tables) {
  for (const table of capturedTables) {
    const rows = tables[table] ?? [];
    for (const row of rows) await upsertRow(client, targetTable(table), row);
  }
}

async function applyEnvelope(client, envelope) {
  if (!capturedTables.includes(envelope.entity_type)) throw new Error(`Unapproved replay table ${envelope.entity_type}`);
  const table = targetTable(envelope.entity_type);
  const entityKey = typeof envelope.entity_id === "string" ? JSON.parse(envelope.entity_id) : envelope.entity_id;
  if (!entityKey || typeof entityKey !== "object" || Array.isArray(entityKey)) throw new Error(`Invalid entity key for ${envelope.event_id}`);
  if (envelope.operation === "delete") {
    const keys = Object.keys(entityKey).sort();
    const clauses = keys.map((key, index) => `${quoteIdentifier(key)} = $${index + 1}`);
    await client.query(`delete from ${quoteIdentifier(table)} where ${clauses.join(" and ")}`, keys.map((key) => entityKey[key]));
    return;
  }
  if (!envelope.after || typeof envelope.after !== "object") throw new Error(`Missing after image for ${envelope.event_id}`);
  await upsertRow(client, table, envelope.after, Object.keys(entityKey));
}

async function upsertRow(client, table, row, knownPrimaryKeys) {
  const columns = Object.keys(row).sort();
  const primaryKeys = knownPrimaryKeys?.length ? [...knownPrimaryKeys].sort() : await primaryKeyColumns(client, table);
  if (!primaryKeys.length) throw new Error(`No primary key for replay table ${table}`);
  if (primaryKeys.some((key) => !columns.includes(key))) throw new Error(`Replay row for ${table} lacks its primary key`);
  const values = columns.map((column) => row[column]);
  const updateColumns = columns.filter((column) => !primaryKeys.includes(column));
  const conflict = updateColumns.length
    ? `do update set ${updateColumns.map((column) => `${quoteIdentifier(column)} = excluded.${quoteIdentifier(column)}`).join(", ")}`
    : "do nothing";
  await client.query(`
    insert into ${quoteIdentifier(table)} (${columns.map(quoteIdentifier).join(", ")})
    values (${columns.map((_, index) => `$${index + 1}`).join(", ")})
    on conflict (${primaryKeys.map(quoteIdentifier).join(", ")}) ${conflict}
  `, values);
}

async function primaryKeyColumns(client, table) {
  const result = await client.query(`
    select attribute.attname column_name
    from pg_index index_definition
    join pg_class relation on relation.oid = index_definition.indrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    join unnest(index_definition.indkey) with ordinality key(attnum, ordinal) on true
    join pg_attribute attribute on attribute.attrelid = relation.oid and attribute.attnum = key.attnum
    where namespace.nspname = 'public' and relation.relname = $1 and index_definition.indisprimary
    order by key.ordinal
  `, [table]);
  return result.rows.map((row) => row.column_name);
}

async function dataHash(client, useTargetAdapter = false) {
  return sha256(canonicalJSONString(await tableSnapshot(client, useTargetAdapter)));
}

async function tableSnapshot(client, useTargetAdapter = false) {
  const tables = {};
  for (const table of capturedTables) {
    const physicalTable = useTargetAdapter ? targetTable(table) : table;
    const result = await client.query(`select coalesce(jsonb_agg(to_jsonb(row_value) order by to_jsonb(row_value)::text), '[]'::jsonb) payload from ${quoteIdentifier(physicalTable)} row_value`);
    tables[table] = result.rows[0].payload;
  }
  return tables;
}

async function schemaHash(client) {
  return schemaContractDigest(await liveSchemaContract(client));
}

async function assertReadOnlyRehearsalSource(client) {
  const result = await client.query(`
    select current_user,
           coalesce((select rolsuper from pg_roles where rolname = current_user), false) rolsuper,
           pg_has_role(current_user, 'pg_write_all_data', 'member') can_write_all,
           current_setting('transaction_read_only') transaction_read_only,
           exists (
             select 1
             from unnest($1::text[]) table_name
             where has_table_privilege(
               current_user,
               format('%I.%I', 'public', table_name),
               'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'
             )
           ) has_domain_dml
  `, [capturedTables]);
  const row = result.rows[0];
  if (row.current_user !== `pscale_api_${expectedReadonlyRoleId}` || row.rolsuper || row.can_write_all
    || row.transaction_read_only !== "on" || row.has_domain_dml) {
    throw new Error("Replay source must be an allowlisted read-only rehearsal role");
  }
}

async function assertDisposableTarget(client, expectedMarker) {
  const result = await client.query("select marker from runtime_database_markers where marker = $1", [expectedMarker]);
  if (result.rowCount !== 1 || !expectedMarker.startsWith("refwatch:local-ledger-replay:")) {
    throw new Error("Replay target lacks the exact disposable marker");
  }
}

function targetAdapter() {
  return targetKind === "same_schema"
    ? Object.fromEntries(capturedTables.map((table) => [table, table]))
    : secondSameContractTableMap;
}

function targetTable(table) {
  const physicalTable = targetAdapter()[table];
  if (!physicalTable) throw new Error(`Replay adapter has no target for ${table}`);
  return physicalTable;
}

async function decrypt(row, keys) {
  const keyBase64 = keys[row.encryption_key_id];
  if (!keyBase64) throw new Error(`Replay keyring has no key ${row.encryption_key_id}`);
  const keyBytes = fromBase64(keyBase64);
  if (keyBytes.byteLength !== 32) throw new Error("Replay key must be 32 bytes");
  const key = await crypto.subtle.importKey("raw", toArrayBuffer(keyBytes), "AES-GCM", false, ["decrypt"]);
  const additionalData = new TextEncoder().encode(`refwatch-ledger:${row.event_id}:${row.schema_version}:${row.content_digest}`);
  const plaintext = await crypto.subtle.decrypt({
    name: "AES-GCM",
    iv: toArrayBuffer(fromBase64(row.encryption_nonce)),
    additionalData: toArrayBuffer(additionalData),
  }, key, toArrayBuffer(fromBase64(row.encrypted_envelope)));
  return new TextDecoder().decode(plaintext);
}

function replayKeyring() {
  const value = JSON.parse(required("REFWATCH_LEDGER_DECRYPTION_KEYRING"));
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Replay keyring must be an object");
  return value;
}

function validateSourceURL(value) {
  const parsed = new URL(value);
  const username = decodeURIComponent(parsed.username);
  if (parsed.protocol !== "postgresql:" || !username.startsWith("pscale_api_") || !username.endsWith(`.${expectedBranchId}`)) {
    throw new Error("Replay source is not the allowlisted PlanetScale branch");
  }
  if (parsed.searchParams.get("sslmode") !== "verify-full") throw new Error("Replay source requires sslmode=verify-full");
}

function validateTargetURL(value, kind) {
  const parsed = new URL(value);
  const expectedDatabase = kind === "same_schema" ? "same_schema" : "second_same_contract";
  if (parsed.protocol !== "postgresql:" || !new Set(["localhost", "127.0.0.1", "::1"]).has(parsed.hostname)) {
    throw new Error("Rehearsal replay target must be local PostgreSQL");
  }
  if (parsed.pathname.replace(/^\//, "") !== expectedDatabase) throw new Error("Replay target database does not match target kind");
}

function normalizedURL(value) {
  const parsed = new URL(value);
  parsed.password = "";
  return parsed.toString();
}

function assertUnique(values, label) {
  if (new Set(values).size !== values.length) throw new Error(`Duplicate ${label} in replay export`);
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function canonicalJSONString(value) {
  if (value === null || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "string") return JSON.stringify(normalizeTimestamp(value));
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Cannot hash non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJSONString).join(",")}]`;
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJSONString(value[key])}`).join(",")}}`;
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

function fromBase64(value) {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function toArrayBuffer(value) {
  return value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength);
}

function uuidPattern() {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
}

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}
