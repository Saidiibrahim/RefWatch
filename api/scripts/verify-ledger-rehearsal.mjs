import { createHash } from "node:crypto";
import pg from "pg";
import { canonicalJSONString, livePrivilegeContract, liveSchemaContract, schemaContractDigest } from "./ledger-schema-contract.mjs";

const expectedBranchId = "ng9tgmy4pyi5";
const expectedReadonlyRoleId = "psf6epuvymjt";
const capturedTables = [
  "app_users", "clerk_user_deletion_tombstones", "user_devices", "teams", "team_members",
  "team_officials", "team_tags", "competitions", "venues", "scheduled_matches", "matches",
  "match_periods", "match_events", "match_metrics", "match_assessments", "pages",
  "workout_presets", "workout_sessions", "ai_threads", "ai_messages", "ai_attachments", "ai_usage_daily",
];
const databaseURL = required("REFWATCH_LEDGER_REHEARSAL_READONLY_URL");
const epochId = required("REFWATCH_LEDGER_VERIFY_EPOCH_ID");
const poisonEventId = required("REFWATCH_LEDGER_VERIFY_POISON_EVENT_ID");
const firstD1 = parseD1(required("REFWATCH_LEDGER_D1_READ_ONE"));
const secondD1 = parseD1(required("REFWATCH_LEDGER_D1_READ_TWO"));
const deadLetters = parseD1(required("REFWATCH_LEDGER_D1_DEAD_LETTER_READ"));
validateSourceURL(databaseURL);

const firstRows = firstD1.results;
const secondRows = secondD1.results;
if (!firstD1.primary || !secondD1.primary) throw new Error("Both D1 reconciliation reads must be served by primary");
const firstCanonical = canonicalJSONString(firstRows);
const secondCanonical = canonicalJSONString(secondRows);
if (firstCanonical !== secondCanonical) throw new Error("Repeated D1 reads are not stable");

const client = new pg.Client({ connectionString: databaseURL });
await client.connect();
try {
  await client.query("begin isolation level repeatable read read only");
  const identity = await client.query(`
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
  const verifier = identity.rows[0];
  if (verifier.current_user !== `pscale_api_${expectedReadonlyRoleId}` || verifier.rolsuper || verifier.can_write_all
    || verifier.transaction_read_only !== "on" || verifier.has_domain_dml) {
    throw new Error("Verifier database role is not the exact read-only rehearsal role");
  }

  const epoch = await client.query(`
    select id, status, capture_enforced, baseline_snapshot_id, baseline_schema_hash,
           baseline_data_hash, frozen_event_sequence
    from mutation_ledger_epochs where id = $1
  `, [epochId]);
  if (epoch.rowCount !== 1 || epoch.rows[0].status !== "frozen" || !epoch.rows[0].capture_enforced) {
    throw new Error("Verified epoch must remain frozen during reconciliation");
  }
  const events = await client.query(`
    select event.event_id, event.event_sequence::int, event.epoch_id,
           event.mutation_group_id, event.group_ordinal, event.schema_version,
           event.source_kind, event.worker_version_id, delivery.content_digest,
           delivery.encryption_key_id, delivery.encryption_nonce,
           delivery.encrypted_envelope, delivery.state delivery_state,
           delivery.leased_until
    from mutation_outbox_events event
    join mutation_outbox_deliveries delivery on delivery.event_id = event.event_id
    where event.epoch_id = $1 and event.event_sequence <= $2
    order by event.event_sequence
  `, [epochId, epoch.rows[0].frozen_event_sequence]);
  const comparablePG = events.rows.map(({ delivery_state: _state, leased_until: _lease, ...row }) => row);
  const fields = [
    "event_sequence", "epoch_id", "mutation_group_id", "group_ordinal", "schema_version",
    "source_kind", "worker_version_id", "content_digest", "encryption_key_id",
    "encryption_nonce", "encrypted_envelope",
  ];
  const pgById = new Map(comparablePG.map((row) => [row.event_id, row]));
  const d1ById = new Map(firstRows.map((row) => [row.event_id, row]));
  const missing = [...pgById.keys()].filter((id) => !d1ById.has(id)).sort();
  const unexpected = [...d1ById.keys()].filter((id) => !pgById.has(id)).sort();
  const mismatches = [];
  for (const [eventId, pgRow] of pgById) {
    const d1Row = d1ById.get(eventId);
    if (!d1Row) continue;
    const mismatchedFields = fields.filter((field) => String(pgRow[field]) !== String(d1Row[field]));
    if (mismatchedFields.length) mismatches.push({ event_id: eventId, fields: mismatchedFields });
  }
  if (missing.length || unexpected.length || mismatches.length) throw new Error("Independent PG/D1 reconciliation failed");
  if (events.rows.some((row) => row.delivery_state !== "delivered" || row.leased_until !== null)) {
    throw new Error("Verified epoch is not fully delivered and lease-free");
  }

  const poison = await client.query(`
    select event.event_id, event.epoch_id, delivery.state, delivery.lease_generation,
           delivery.leased_until, delivery.last_error
    from mutation_outbox_events event
    join mutation_outbox_deliveries delivery on delivery.event_id = event.event_id
    where event.event_id = $1
  `, [poisonEventId]);
  const poisonRow = poison.rows[0];
  if (poison.rowCount !== 1 || poisonRow.state !== "quarantined" || poisonRow.leased_until !== null) {
    throw new Error("Poison delivery is not quarantined and lease-free");
  }
  const deadLetter = deadLetters.results.find((row) => row.event_id === poisonEventId);
  if (!deadLetter || Number(deadLetter.lease_generation) !== Number(poisonRow.lease_generation) || deadLetter.disposition !== "quarantined") {
    throw new Error("DLQ receipt does not match the quarantined PostgreSQL generation");
  }

  const schemaContract = await liveSchemaContract(client);
  const privilegeContract = await livePrivilegeContract(client);
  if (schemaContractDigest(schemaContract) !== epoch.rows[0].baseline_schema_hash) {
    throw new Error("Live source schema contract changed after baseline binding");
  }
  const openEpochs = await client.query("select count(*)::int count from mutation_ledger_epochs where status = 'open'");
  process.stdout.write(`${JSON.stringify({
    ok: true,
    branch_id: expectedBranchId,
    verifier_role: identity.rows[0].current_user,
    epoch_id: epochId,
    epoch_status: epoch.rows[0].status,
    capture_enforced: epoch.rows[0].capture_enforced,
    frozen_event_sequence: Number(epoch.rows[0].frozen_event_sequence),
    expected_event_count: comparablePG.length,
    delivered_event_count: events.rows.filter((row) => row.delivery_state === "delivered").length,
    active_lease_count: events.rows.filter((row) => row.leased_until !== null).length,
    missing_event_ids: missing,
    unexpected_event_ids: unexpected,
    metadata_mismatches: mismatches,
    measured_rpo_events: missing.length,
    stable_primary_d1_read_sha256: sha256(firstCanonical),
    repeated_primary_reads_match: true,
    live_schema_contract_sha256: schemaContractDigest(schemaContract),
    live_privilege_contract_sha256: sha256(canonicalJSONString(privilegeContract)),
    poison_event_id: poisonEventId,
    poison_delivery_state: poisonRow.state,
    poison_queue_attempt_code: poisonRow.last_error,
    poison_lease_generation: Number(poisonRow.lease_generation),
    dead_letter_id: deadLetter.dead_letter_id,
    dead_letter_disposition: deadLetter.disposition,
    open_epoch_count: openEpochs.rows[0].count,
    verified_at_utc: new Date().toISOString(),
  })}\n`);
} finally {
  await client.query("rollback").catch(() => undefined);
  await client.end();
}

function parseD1(value) {
  const documents = JSON.parse(value);
  return {
    results: documents.flatMap((result) => result.results ?? []),
    primary: documents.every((result) => result.success === true && result.meta?.served_by_primary === true),
  };
}

function validateSourceURL(value) {
  const parsed = new URL(value);
  const username = decodeURIComponent(parsed.username);
  if (parsed.protocol !== "postgresql:" || !username.startsWith("pscale_api_") || !username.endsWith(`.${expectedBranchId}`)) {
    throw new Error("Verifier source is not the allowlisted rehearsal branch");
  }
  if (parsed.searchParams.get("sslmode") !== "verify-full") throw new Error("Verifier requires sslmode=verify-full");
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}
