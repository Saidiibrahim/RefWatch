import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  canonicalSanitizedJSON,
  cleanTargetReadback,
  computeSanitizedReceiptSha256,
  greenfieldAuthorizationDigest,
  greenfieldAuthorizationProfile,
  greenfieldCleanTargetTables,
  greenfieldEmptyMappingHash,
  greenfieldIdentityProfile,
  greenfieldIdentityReceiptDigest,
  ledgerReadback,
  productionClerk,
  productionDatabase,
  reviewedDeterministicSeed,
  reviewedSchema0016,
} from "./greenfield-launch-packet.mjs";
import {
  loadProductionMigration0016Contract,
  productionMigration0016Contract,
  validateProductionMigration0016Sources,
} from "./apply-production-migration-0016.mjs";
import { productionRuntimeProvisioningTarget } from "./provision-production-runtime.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const migrationsDirectory = resolve(scriptDirectory, "../src/db/migrations");
const MAX_PROVIDER_OUTPUT_BYTES = 1024 * 1024;
const PROVIDER_TIMEOUT_MS = 120_000;
const PROVIDER_KILL_GRACE_MS = 2_000;
const RECEIPT_MARKER = "REFWATCH_GREENFIELD_IDENTITY_RECEIPT:";
const READY_MARKER = "REFWATCH_GREENFIELD_IDENTITY_READY";
const COMMITTED_MARKER = "REFWATCH_GREENFIELD_IDENTITY_COMMITTED";
const receiptType = "refwatch_production_greenfield_identity_activation";
const pendingStatus = "validated_pending_commit";

export const productionGreenfieldIdentityActivationGate =
  "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_IDENTITY_ACTIVATION";

export const productionGreenfieldIdentityActivationCommand = Object.freeze({
  command: "pscale",
  args: Object.freeze([
    "shell",
    productionDatabase.database,
    productionDatabase.branch,
    "--org",
    productionDatabase.organization,
    "--role",
    "admin",
    "--no-color",
  ]),
});

const sourcePaths = Object.freeze({
  schemaReadback: resolve(scriptDirectory, "greenfield-schema-readback.sql"),
  cleanTargetReadback: resolve(
    scriptDirectory,
    "greenfield-clean-target-readback.sql",
  ),
  ledgerReadback: resolve(scriptDirectory, "greenfield-ledger-readback.sql"),
  deterministicSeedMigration: resolve(
    migrationsDirectory,
    "0002_crazy_yellowjacket.sql",
  ),
  migrationSnapshot: resolve(
    migrationsDirectory,
    "meta/0016_snapshot.json",
  ),
  migrationJournal: resolve(migrationsDirectory, "meta/_journal.json"),
  previousMigration: resolve(
    migrationsDirectory,
    `${productionMigration0016Contract.previous.tag}.sql`,
  ),
  targetMigration: resolve(
    migrationsDirectory,
    `${productionMigration0016Contract.target.tag}.sql`,
  ),
});

export async function loadProductionGreenfieldIdentityActivationSources() {
  await loadProductionMigration0016Contract();
  const [
    schemaReadbackSQL,
    cleanTargetReadbackSQL,
    ledgerReadbackSQL,
    deterministicSeedMigrationSQL,
    migrationSnapshotJSON,
    migrationJournalJSON,
    previousMigrationSQL,
    targetMigrationSQL,
  ] = await Promise.all([
    readFile(sourcePaths.schemaReadback, "utf8"),
    readFile(sourcePaths.cleanTargetReadback, "utf8"),
    readFile(sourcePaths.ledgerReadback, "utf8"),
    readFile(sourcePaths.deterministicSeedMigration, "utf8"),
    readFile(sourcePaths.migrationSnapshot, "utf8"),
    readFile(sourcePaths.migrationJournal, "utf8"),
    readFile(sourcePaths.previousMigration, "utf8"),
    readFile(sourcePaths.targetMigration, "utf8"),
  ]);

  return validateProductionGreenfieldIdentityActivationSources({
    schemaReadbackSQL,
    cleanTargetReadbackSQL,
    ledgerReadbackSQL,
    deterministicSeedMigrationSQL,
    migrationSnapshotJSON,
    migrationJournalJSON,
    previousMigrationSQL,
    targetMigrationSQL,
  });
}

export function validateProductionGreenfieldIdentityActivationSources(source) {
  requireSourceDigest(
    source.schemaReadbackSQL,
    reviewedSchema0016.providerQuerySha256,
    "schema readback",
  );
  requireSourceDigest(
    source.cleanTargetReadbackSQL,
    cleanTargetReadback.querySha256,
    "clean-target readback",
  );
  requireSourceDigest(
    source.ledgerReadbackSQL,
    ledgerReadback.querySha256,
    "ledger readback",
  );
  requireSourceDigest(
    source.deterministicSeedMigrationSQL,
    reviewedDeterministicSeed.migrationSha256,
    "deterministic seed migration",
  );
  requireSourceDigest(
    source.migrationSnapshotJSON,
    reviewedSchema0016.repositorySnapshotSha256,
    "migration 0016 snapshot",
  );

  validateProductionMigration0016Sources({
    journalText: source.migrationJournalJSON,
    previousMigrationSql: source.previousMigrationSQL,
    targetMigrationSql: source.targetMigrationSQL,
  });
  validateCrossSourceContract();

  let snapshot;
  try {
    snapshot = JSON.parse(source.migrationSnapshotJSON);
  } catch {
    throw new Error("Production identity activation snapshot is invalid");
  }
  const tableNames = Object.keys(snapshot?.tables ?? {}).sort();
  if (
    tableNames.length !== reviewedSchema0016.publicTableCount
    || tableNames.some((name) => !/^public\.[a-z][a-z0-9_]*$/u.test(name))
    || md5Hex(tableNames.join(",")) !== reviewedSchema0016.publicTableNamesMd5
  ) {
    throw new Error("Production identity activation table lock contract does not match");
  }
  for (const tableName of greenfieldCleanTargetTables) {
    const physicalName = tableName === "user_owned_workout_presets"
      ? "workout_presets"
      : tableName;
    if (!tableNames.includes(`public.${physicalName}`)) {
      throw new Error("Production identity activation clean-target table is absent");
    }
  }

  return Object.freeze({
    ...source,
    tableNames: Object.freeze(tableNames),
    schemaReadbackQuery: embeddableReadback(
      source.schemaReadbackSQL,
      "schema readback",
    ),
    cleanTargetReadbackQuery: embeddableReadback(
      source.cleanTargetReadbackSQL,
      "clean-target readback",
    ),
    ledgerReadbackQuery: embeddableReadback(
      source.ledgerReadbackSQL,
      "ledger readback",
    ),
  });
}

export function renderProductionGreenfieldIdentityActivationSQL(source) {
  const validated = validateProductionGreenfieldIdentityActivationSources(source);
  const expected = expectedReadbacks();
  const lockRelations = [
    '"drizzle"."__drizzle_migrations"',
    ...validated.tableNames.map((name) => {
      const [schema, table] = name.split(".");
      return `${quoteSQLIdentifier(schema)}.${quoteSQLIdentifier(table)}`;
    }),
  ].join(",\n  ");
  const contract = productionMigration0016Contract;

  return String.raw`\set QUIET 1
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN ISOLATION LEVEL SERIALIZABLE;
SET LOCAL ROLE ${quoteSQLIdentifier(contract.stableOwner)};
SET LOCAL search_path = pg_catalog, public;
DO $refwatch_activation_session_state$
BEGIN
  IF current_setting('session_replication_role') <> 'origin' THEN
    RAISE EXCEPTION 'production identity activation replication role failed';
  END IF;
END;
$refwatch_activation_session_state$;
LOCK TABLE
  ${lockRelations}
IN SHARE ROW EXCLUSIVE MODE;
SELECT pg_advisory_xact_lock(
  hashtextextended(
    ${quoteSQLLiteral(`reconciliation:${productionClerk.instanceId}`)},
    0
  )
);
CREATE TEMP TABLE refwatch_activation_history_sequence_readback
ON COMMIT DROP AS
SELECT
  format_type(sequence_definition.seqtypid, NULL) AS data_type,
  sequence_definition.seqstart AS start_value,
  sequence_definition.seqmin AS minimum_value,
  sequence_definition.seqmax AS maximum_value,
  sequence_definition.seqincrement AS increment_by,
  sequence_definition.seqcache AS cache_size,
  sequence_definition.seqcycle AS cycle,
  sequence_state.last_value,
  sequence_state.is_called
FROM pg_sequence sequence_definition
CROSS JOIN drizzle.__drizzle_migrations_id_seq sequence_state
WHERE sequence_definition.seqrelid
  = 'drizzle.__drizzle_migrations_id_seq'::regclass;
CREATE TEMP TABLE refwatch_activation_schema_readback
ON COMMIT DROP AS
SELECT greenfield_schema_readback AS payload
FROM (
${indentSQL(validated.schemaReadbackQuery, 2)}
) AS reviewed_schema_readback;
CREATE TEMP TABLE refwatch_activation_clean_readback
ON COMMIT DROP AS
SELECT greenfield_readback AS payload
FROM (
${indentSQL(validated.cleanTargetReadbackQuery, 2)}
) AS reviewed_clean_readback;
CREATE TEMP TABLE refwatch_activation_ledger_readback
ON COMMIT DROP AS
SELECT greenfield_ledger_readback AS payload
FROM (
${indentSQL(validated.ledgerReadbackQuery, 2)}
) AS reviewed_ledger_readback;
CREATE TEMP TABLE refwatch_activation_context (
  operation text NOT NULL
) ON COMMIT DROP;
DO $refwatch_activation_preflight$
DECLARE
  schema_payload jsonb;
  clean_payload jsonb;
  clean_inventory jsonb;
  ledger_payload jsonb;
  receipt_count bigint;
  activation_count bigint;
  migration_created_at bigint;
  sequence_data_type text;
  sequence_start_value bigint;
  sequence_minimum_value bigint;
  sequence_maximum_value bigint;
  sequence_increment_by bigint;
  sequence_cache_size bigint;
  sequence_cycle boolean;
  sequence_last_value bigint;
  sequence_is_called boolean;
BEGIN
  SELECT payload INTO STRICT schema_payload
  FROM refwatch_activation_schema_readback;
  SELECT payload INTO STRICT clean_payload
  FROM refwatch_activation_clean_readback;
  SELECT payload INTO STRICT ledger_payload
  FROM refwatch_activation_ledger_readback;
  clean_inventory := clean_payload -> 'clean_target_inventory';

  IF schema_payload - 'observed_at_utc'
    IS DISTINCT FROM ${quoteSQLJSON(expected.schema)}
  THEN
    RAISE EXCEPTION 'production identity activation schema contract failed';
  END IF;
  IF clean_payload - 'deterministic_seed' - 'clean_target_inventory'
    IS DISTINCT FROM ${quoteSQLJSON(expected.cleanTarget)}
    OR clean_payload -> 'deterministic_seed'
      IS DISTINCT FROM ${quoteSQLJSON(expected.seed)}
  THEN
    RAISE EXCEPTION 'production identity activation seed or target contract failed';
  END IF;
  IF clean_inventory IS DISTINCT FROM ${quoteSQLJSON(expected.cleanFresh)}
    AND clean_inventory IS DISTINCT FROM ${quoteSQLJSON(expected.cleanActivated)}
  THEN
    RAISE EXCEPTION 'production identity activation clean-state contract failed';
  END IF;

  IF ledger_payload ->> 'database_name'
      IS DISTINCT FROM ${quoteSQLLiteral(productionRuntimeProvisioningTarget.databaseName)}
    OR ledger_payload ->> 'database_branch_id'
      IS DISTINCT FROM ${quoteSQLLiteral(productionDatabase.branchId)}
    OR ledger_payload ->> 'runtime_marker'
      IS DISTINCT FROM ${quoteSQLLiteral(productionDatabase.runtimeMarker)}
    OR (ledger_payload ->> 'preparing_epoch_count')::bigint <> 0
    OR (ledger_payload ->> 'open_epoch_count')::bigint <> 0
    OR (ledger_payload ->> 'capture_enforced_epoch_count')::bigint <> 0
    OR (ledger_payload ->> 'outbox_event_count')::bigint <> 0
    OR (ledger_payload ->> 'outbox_delivery_count')::bigint <> 0
  THEN
    RAISE EXCEPTION 'production identity activation ledger contract failed';
  END IF;

  IF current_user <> ${quoteSQLLiteral(contract.stableOwner)}
    OR current_database()
      <> ${quoteSQLLiteral(productionRuntimeProvisioningTarget.databaseName)}
  THEN
    RAISE EXCEPTION 'production identity activation database role failed';
  END IF;
  SELECT created_at INTO migration_created_at
  FROM drizzle.__drizzle_migrations
  WHERE id = ${contract.target.historyId}
    AND hash = ${quoteSQLLiteral(contract.target.fileSha256)};
  IF migration_created_at IS DISTINCT FROM ${contract.target.journalTimestamp}
  THEN
    RAISE EXCEPTION 'production identity activation migration history failed';
  END IF;
  SELECT
    data_type,
    start_value,
    minimum_value,
    maximum_value,
    increment_by,
    cache_size,
    cycle,
    last_value,
    is_called
  INTO STRICT
    sequence_data_type,
    sequence_start_value,
    sequence_minimum_value,
    sequence_maximum_value,
    sequence_increment_by,
    sequence_cache_size,
    sequence_cycle,
    sequence_last_value,
    sequence_is_called
  FROM refwatch_activation_history_sequence_readback;
  IF sequence_data_type
      IS DISTINCT FROM ${quoteSQLLiteral(contract.historySequence.dataType)}
    OR sequence_start_value <> ${contract.historySequence.startValue}
    OR sequence_minimum_value <> ${contract.historySequence.minimumValue}
    OR sequence_maximum_value <> ${contract.historySequence.maximumValue}
    OR sequence_increment_by <> ${contract.historySequence.incrementBy}
    OR sequence_cache_size <> ${contract.historySequence.cacheSize}
    OR sequence_cycle IS DISTINCT FROM ${contract.historySequence.cycle}
  THEN
    RAISE EXCEPTION 'production identity activation history sequence parameters failed';
  END IF;
  IF NOT (
    (
      sequence_last_value = ${contract.historySequence.targetRestartWith}
      AND sequence_is_called
        IS NOT DISTINCT FROM ${contract.historySequence.targetIsCalled}
    )
    OR (
      sequence_last_value = ${contract.historySequence.targetRestartWith - 1}
      AND sequence_is_called IS TRUE
    )
  )
  THEN
    RAISE EXCEPTION 'production identity activation history sequence failed';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_class relation
    JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relkind IN ('r', 'p', 'S')
      AND pg_get_userbyid(relation.relowner)
        <> ${quoteSQLLiteral(contract.stableOwner)}
  ) OR EXISTS (
    SELECT 1
    FROM pg_proc procedure_definition
    JOIN pg_namespace namespace
      ON namespace.oid = procedure_definition.pronamespace
    WHERE namespace.nspname = 'public'
      AND pg_get_userbyid(procedure_definition.proowner)
        <> ${quoteSQLLiteral(contract.stableOwner)}
  ) THEN
    RAISE EXCEPTION 'production identity activation stable ownership failed';
  END IF;

  SELECT count(*) INTO receipt_count
  FROM identity_reconciliation_receipts;
  SELECT count(*) INTO activation_count
  FROM identity_reconciliation_activations;
  IF receipt_count = 0 AND activation_count = 0 THEN
    INSERT INTO refwatch_activation_context (operation) VALUES ('activated');
  ELSIF receipt_count = 1 AND activation_count = 1
    AND EXISTS (
      SELECT 1
      FROM identity_reconciliation_receipts receipts
      JOIN identity_reconciliation_activations activations
        ON activations.receipt_digest = receipts.receipt_digest
       AND activations.clerk_instance_id = receipts.clerk_instance_id
      WHERE receipts.receipt_digest
          = ${quoteSQLLiteral(greenfieldIdentityReceiptDigest)}
        AND receipts.clerk_instance_id
          = ${quoteSQLLiteral(productionClerk.instanceId)}
        AND receipts.reconciliation_profile
          = ${quoteSQLLiteral(greenfieldIdentityProfile)}
        AND receipts.authorization_profile
          = ${quoteSQLLiteral(greenfieldAuthorizationProfile)}
        AND receipts.authorization_digest
          = ${quoteSQLLiteral(greenfieldAuthorizationDigest)}
        AND receipts.clerk_issuer
          = ${quoteSQLLiteral(productionClerk.issuer)}
        AND receipts.clerk_domain
          = ${quoteSQLLiteral(productionClerk.domain)}
        AND receipts.legacy_mapping_count = 0
        AND receipts.excluded_auth_count = 0
        AND receipts.mapping_hash
          = ${quoteSQLLiteral(greenfieldEmptyMappingHash)}
        AND receipts.status = 'verified'
        AND receipts.snapshot_captured_at
          = date_trunc('milliseconds', receipts.snapshot_captured_at)
        AND receipts.snapshot_captured_at = receipts.reviewed_at
        AND receipts.reviewed_at = receipts.activated_at
        AND receipts.activated_at = activations.activated_at
    )
  THEN
    INSERT INTO refwatch_activation_context (operation)
    VALUES ('idempotent_retry');
  ELSE
    RAISE EXCEPTION 'production identity activation receipt state conflicts';
  END IF;
END;
$refwatch_activation_preflight$;
INSERT INTO identity_reconciliation_receipts (
  receipt_digest,
  clerk_instance_id,
  snapshot_captured_at,
  legacy_mapping_count,
  excluded_auth_count,
  mapping_hash,
  status,
  reviewed_at,
  activated_at,
  reconciliation_profile,
  authorization_profile,
  authorization_digest,
  clerk_issuer,
  clerk_domain
)
SELECT
  ${quoteSQLLiteral(greenfieldIdentityReceiptDigest)},
  ${quoteSQLLiteral(productionClerk.instanceId)},
  date_trunc('milliseconds', transaction_timestamp()),
  0,
  0,
  ${quoteSQLLiteral(greenfieldEmptyMappingHash)},
  'verified',
  date_trunc('milliseconds', transaction_timestamp()),
  date_trunc('milliseconds', transaction_timestamp()),
  ${quoteSQLLiteral(greenfieldIdentityProfile)},
  ${quoteSQLLiteral(greenfieldAuthorizationProfile)},
  ${quoteSQLLiteral(greenfieldAuthorizationDigest)},
  ${quoteSQLLiteral(productionClerk.issuer)},
  ${quoteSQLLiteral(productionClerk.domain)}
FROM refwatch_activation_context
WHERE operation = 'activated';
INSERT INTO identity_reconciliation_activations (
  receipt_digest,
  clerk_instance_id,
  activated_at
)
SELECT
  ${quoteSQLLiteral(greenfieldIdentityReceiptDigest)},
  ${quoteSQLLiteral(productionClerk.instanceId)},
  date_trunc('milliseconds', transaction_timestamp())
FROM refwatch_activation_context
WHERE operation = 'activated';
CREATE TEMP TABLE refwatch_activation_post_clean_readback
ON COMMIT DROP AS
SELECT greenfield_readback AS payload
FROM (
${indentSQL(validated.cleanTargetReadbackQuery, 2)}
) AS reviewed_post_clean_readback;
CREATE TEMP TABLE refwatch_activation_post_ledger_readback
ON COMMIT DROP AS
SELECT greenfield_ledger_readback AS payload
FROM (
${indentSQL(validated.ledgerReadbackQuery, 2)}
) AS reviewed_post_ledger_readback;
DO $refwatch_activation_postflight$
DECLARE
  clean_payload jsonb;
  ledger_payload jsonb;
BEGIN
  SELECT payload INTO STRICT clean_payload
  FROM refwatch_activation_post_clean_readback;
  SELECT payload INTO STRICT ledger_payload
  FROM refwatch_activation_post_ledger_readback;
  IF clean_payload -> 'clean_target_inventory'
    IS DISTINCT FROM ${quoteSQLJSON(expected.cleanActivated)}
  THEN
    RAISE EXCEPTION 'production identity activation post-state failed';
  END IF;
  IF (ledger_payload ->> 'preparing_epoch_count')::bigint <> 0
    OR (ledger_payload ->> 'open_epoch_count')::bigint <> 0
    OR (ledger_payload ->> 'capture_enforced_epoch_count')::bigint <> 0
    OR (ledger_payload ->> 'outbox_event_count')::bigint <> 0
    OR (ledger_payload ->> 'outbox_delivery_count')::bigint <> 0
  THEN
    RAISE EXCEPTION 'production identity activation post-ledger state failed';
  END IF;
  IF (SELECT count(*) FROM identity_reconciliation_receipts) <> 1
    OR (SELECT count(*) FROM identity_reconciliation_activations) <> 1
    OR NOT EXISTS (
      SELECT 1
      FROM identity_reconciliation_receipts receipts
      JOIN identity_reconciliation_activations activations
        ON activations.receipt_digest = receipts.receipt_digest
       AND activations.clerk_instance_id = receipts.clerk_instance_id
      WHERE receipts.receipt_digest
          = ${quoteSQLLiteral(greenfieldIdentityReceiptDigest)}
        AND receipts.clerk_instance_id
          = ${quoteSQLLiteral(productionClerk.instanceId)}
        AND receipts.reconciliation_profile
          = ${quoteSQLLiteral(greenfieldIdentityProfile)}
        AND receipts.authorization_profile
          = ${quoteSQLLiteral(greenfieldAuthorizationProfile)}
        AND receipts.authorization_digest
          = ${quoteSQLLiteral(greenfieldAuthorizationDigest)}
        AND receipts.clerk_issuer
          = ${quoteSQLLiteral(productionClerk.issuer)}
        AND receipts.clerk_domain
          = ${quoteSQLLiteral(productionClerk.domain)}
        AND receipts.legacy_mapping_count = 0
        AND receipts.excluded_auth_count = 0
        AND receipts.mapping_hash
          = ${quoteSQLLiteral(greenfieldEmptyMappingHash)}
        AND receipts.status = 'verified'
        AND receipts.snapshot_captured_at
          = date_trunc('milliseconds', receipts.snapshot_captured_at)
        AND receipts.snapshot_captured_at = receipts.reviewed_at
        AND receipts.reviewed_at = receipts.activated_at
        AND receipts.activated_at = activations.activated_at
    )
  THEN
    RAISE EXCEPTION 'production identity activation immutable readback failed';
  END IF;
END;
$refwatch_activation_postflight$;
SELECT ${quoteSQLLiteral(RECEIPT_MARKER)} || jsonb_build_object(
  'schema_version', 1,
  'receipt_type', ${quoteSQLLiteral(receiptType)},
  'status', ${quoteSQLLiteral(pendingStatus)},
  'operation', (SELECT operation FROM refwatch_activation_context),
  'provider_command', jsonb_build_object(
    'command', ${quoteSQLLiteral(productionGreenfieldIdentityActivationCommand.command)},
    'arguments', ${quoteSQLJSON(productionGreenfieldIdentityActivationCommand.args)},
    'sql_transport', 'stdin'
  ),
  'production_target', jsonb_build_object(
    'organization', ${quoteSQLLiteral(productionDatabase.organization)},
    'logical_database', ${quoteSQLLiteral(productionDatabase.database)},
    'postgres_database', current_database(),
    'branch', ${quoteSQLLiteral(productionDatabase.branch)},
    'branch_id', ${quoteSQLLiteral(productionDatabase.branchId)},
    'runtime_marker', ${quoteSQLLiteral(productionDatabase.runtimeMarker)},
    'stable_role', current_user
  ),
  'source_contract', ${quoteSQLJSON(expected.sourceContract)},
  'verified_state', jsonb_build_object(
    'schema', (
      SELECT payload - 'observed_at_utc'
      FROM refwatch_activation_schema_readback
    ),
    'history_sequence', (
      SELECT jsonb_build_object(
        'data_type', data_type,
        'start_value', start_value,
        'minimum_value', minimum_value,
        'maximum_value', maximum_value,
        'increment_by', increment_by,
        'cache_size', cache_size,
        'cycle', cycle,
        'last_value', last_value,
        'is_called', is_called,
        'next_value', ${contract.historySequence.targetRestartWith}
      )
      FROM refwatch_activation_history_sequence_readback
    ),
    'deterministic_seed', (
      SELECT payload -> 'deterministic_seed'
      FROM refwatch_activation_post_clean_readback
    ),
    'clean_target_inventory', (
      SELECT payload -> 'clean_target_inventory'
      FROM refwatch_activation_post_clean_readback
    ),
    'ledger', (
      SELECT payload - 'observed_at_utc'
      FROM refwatch_activation_post_ledger_readback
    )
  ),
  'identity_receipt', (
    SELECT jsonb_build_object(
      'id', id::text,
      'receipt_digest', receipt_digest,
      'clerk_instance_id', clerk_instance_id,
      'reconciliation_profile', reconciliation_profile,
      'authorization_profile', authorization_profile,
      'authorization_digest', authorization_digest,
      'clerk_issuer', clerk_issuer,
      'clerk_domain', clerk_domain,
      'snapshot_captured_at_utc', to_char(
        snapshot_captured_at AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
      ),
      'legacy_mapping_count', legacy_mapping_count,
      'excluded_auth_count', excluded_auth_count,
      'mapping_hash', mapping_hash,
      'status', status,
      'reviewed_at_utc', to_char(
        reviewed_at AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
      ),
      'activated_at_utc', to_char(
        activated_at AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
      )
    )
    FROM identity_reconciliation_receipts
  ),
  'identity_activation', (
    SELECT jsonb_build_object(
      'receipt_digest', receipt_digest,
      'clerk_instance_id', clerk_instance_id,
      'activated_at_utc', to_char(
        activated_at AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
      )
    )
    FROM identity_reconciliation_activations
  )
)::text;
\echo ${READY_MARKER}
`;
}

export function validateProductionGreenfieldIdentityActivationReadback(value) {
  const expected = expectedReadbacks();
  requireExactKeys(value, [
    "schema_version",
    "receipt_type",
    "status",
    "operation",
    "provider_command",
    "production_target",
    "source_contract",
    "verified_state",
    "identity_receipt",
    "identity_activation",
  ]);
  requireEqual(value.schema_version, 1);
  requireEqual(value.receipt_type, receiptType);
  requireEqual(value.status, pendingStatus);
  if (!new Set(["activated", "idempotent_retry"]).has(value.operation)) {
    throw new Error("Production identity activation readback is invalid");
  }
  requireExactObject(value.provider_command, {
    command: productionGreenfieldIdentityActivationCommand.command,
    arguments: [...productionGreenfieldIdentityActivationCommand.args],
    sql_transport: "stdin",
  });
  requireExactObject(value.production_target, expected.productionTarget);
  requireExactObject(value.source_contract, expected.sourceContract);
  requireExactObject(value.verified_state?.schema, expected.schema);
  requireExactObject(
    value.verified_state?.deterministic_seed,
    expected.seed,
  );
  requireExactObject(
    value.verified_state?.clean_target_inventory,
    expected.cleanActivated,
  );
  requireExactKeys(value.verified_state, [
    "schema",
    "history_sequence",
    "deterministic_seed",
    "clean_target_inventory",
    "ledger",
  ]);
  validateHistorySequenceReadback(
    value.verified_state.history_sequence,
    expected.historySequence,
  );
  validateLedgerReadback(value.verified_state.ledger);
  validateIdentityReceipt(value.identity_receipt);
  validateIdentityActivation(value.identity_activation);
  if (
    value.identity_receipt.activated_at_utc
      !== value.identity_activation.activated_at_utc
  ) {
    throw new Error("Production identity activation readback is invalid");
  }
  return Object.freeze(value);
}

export function createProductionGreenfieldIdentityActivationReceipt(readback) {
  const validated = validateProductionGreenfieldIdentityActivationReadback(readback);
  const committed = {
    ...validated,
    status: "committed",
  };
  return Object.freeze({
    ...committed,
    receipt_sha256: computeSanitizedReceiptSha256(committed),
  });
}

export async function executeProductionGreenfieldIdentityActivation(options = {}) {
  const executionEnvironment = options.environment ?? process.env;
  if (executionEnvironment[productionGreenfieldIdentityActivationGate] !== "1") {
    throw new Error("Production greenfield identity activation gate is closed");
  }
  const source = await loadProductionGreenfieldIdentityActivationSources();
  const providerEnvironment = {
    ...executionEnvironment,
    PSCALE_ALLOW_NONINTERACTIVE_SHELL: "1",
    PSQLRC: "/dev/null",
    PSQL_HISTORY: "/dev/null",
  };
  delete providerEnvironment.PGOPTIONS;
  const specification = {
    command: productionGreenfieldIdentityActivationCommand.command,
    args: productionGreenfieldIdentityActivationCommand.args,
    sql: renderProductionGreenfieldIdentityActivationSQL(source),
    environment: providerEnvironment,
  };
  const runSession = options.runSession
    ?? runProductionGreenfieldIdentityActivationSession;
  const readback = await runSession(
    specification,
    validateProductionGreenfieldIdentityActivationReadback,
  );
  return createProductionGreenfieldIdentityActivationReceipt(readback);
}

export function runProductionGreenfieldIdentityActivationSession(
  specification,
  validateBeforeCommit,
  options = {},
) {
  const spawnImpl = options.spawnImpl ?? spawn;
  const timeoutMs = options.timeoutMs ?? PROVIDER_TIMEOUT_MS;
  const maxOutputBytes = options.maxOutputBytes ?? MAX_PROVIDER_OUTPUT_BYTES;
  const killGraceMs = options.killGraceMs ?? PROVIDER_KILL_GRACE_MS;

  return new Promise((resolvePromise, rejectPromise) => {
    let child;
    try {
      child = spawnImpl(specification.command, specification.args, {
        env: specification.environment,
        stdio: ["pipe", "pipe", "pipe"],
      });
    } catch {
      rejectPromise(genericExecutionError());
      return;
    }

    let outputBytes = 0;
    let lineBuffer = "";
    let readback;
    let readySeen = false;
    let commitSent = false;
    let committedSeen = false;
    let failed = false;
    let settled = false;
    let forceKillTimer;

    const timeout = setTimeout(() => failAndTerminate(false), timeoutMs);

    const finish = (error, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (forceKillTimer) clearTimeout(forceKillTimer);
      if (error) rejectPromise(genericExecutionError());
      else resolvePromise(value);
    };

    const failAndTerminate = (canRollback = true) => {
      if (failed) return;
      failed = true;
      if (canRollback && !commitSent && child.stdin?.writable) {
        try {
          child.stdin.end("ROLLBACK;\n\\quit\n");
        } catch {
          child.kill?.("SIGTERM");
        }
      } else {
        child.kill?.("SIGTERM");
      }
      forceKillTimer = setTimeout(() => child.kill?.("SIGKILL"), killGraceMs);
    };

    const processLine = (rawLine) => {
      const line = rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine;
      if (line.startsWith(RECEIPT_MARKER)) {
        if (readback !== undefined || readySeen) {
          failAndTerminate();
          return;
        }
        try {
          const parsed = JSON.parse(line.slice(RECEIPT_MARKER.length));
          readback = validateBeforeCommit(parsed);
        } catch {
          failAndTerminate();
        }
        return;
      }
      if (line === READY_MARKER) {
        if (readySeen || readback === undefined || failed) {
          failAndTerminate();
          return;
        }
        readySeen = true;
        commitSent = true;
        try {
          child.stdin.end(`COMMIT;\n\\echo ${COMMITTED_MARKER}\n\\quit\n`);
        } catch {
          failAndTerminate(false);
        }
        return;
      }
      if (line === COMMITTED_MARKER) {
        if (!commitSent || committedSeen || failed) {
          failAndTerminate(false);
          return;
        }
        committedSeen = true;
      }
    };

    child.stdout?.on("data", (chunk) => {
      if (failed) return;
      const text = Buffer.isBuffer(chunk) ? chunk.toString("utf8") : String(chunk);
      outputBytes += Buffer.byteLength(text);
      if (outputBytes > maxOutputBytes) {
        failAndTerminate();
        return;
      }
      lineBuffer += text;
      let newlineIndex = lineBuffer.indexOf("\n");
      while (newlineIndex >= 0 && !failed) {
        processLine(lineBuffer.slice(0, newlineIndex));
        lineBuffer = lineBuffer.slice(newlineIndex + 1);
        newlineIndex = lineBuffer.indexOf("\n");
      }
    });
    child.stderr?.on("data", (chunk) => {
      outputBytes += Buffer.byteLength(chunk);
      if (outputBytes > maxOutputBytes) failAndTerminate();
    });
    child.on("error", () => failAndTerminate(false));
    child.on("close", (code) => {
      if (lineBuffer && !failed) processLine(lineBuffer);
      if (
        !failed
        && code === 0
        && readySeen
        && commitSent
        && committedSeen
        && readback !== undefined
      ) {
        finish(undefined, readback);
      } else {
        finish(genericExecutionError());
      }
    });
    child.stdin?.on("error", () => failAndTerminate(false));
    try {
      if (!child.stdin?.writable) throw new Error("Provider stdin is unavailable");
      child.stdin.write(`${specification.sql}\n`);
    } catch {
      failAndTerminate(false);
    }
  });
}

export async function runProductionGreenfieldIdentityActivationCLI(options = {}) {
  const args = options.args ?? process.argv.slice(2);
  const environment = options.environment ?? process.env;
  const writeStdout = options.writeStdout
    ?? ((value) => process.stdout.write(value));
  const writeStderr = options.writeStderr
    ?? ((value) => process.stderr.write(value));
  const checkSources = options.checkSources
    ?? loadProductionGreenfieldIdentityActivationSources;
  const execute = options.execute
    ?? (() => executeProductionGreenfieldIdentityActivation({ environment }));

  if (args.length === 1 && args[0] === "--check") {
    try {
      await checkSources();
      writeStdout("Production greenfield identity activation sources verified.\n");
      return 0;
    } catch {
      writeStderr("Production greenfield identity activation source check failed.\n");
      return 1;
    }
  }
  if (args.length !== 1 || args[0] !== "--execute") {
    writeStderr(
      "Usage: node scripts/activate-production-greenfield-identity.mjs --check|--execute\n",
    );
    return 2;
  }
  if (environment[productionGreenfieldIdentityActivationGate] !== "1") {
    writeStderr("Production greenfield identity activation technical gate is closed.\n");
    return 2;
  }
  try {
    const receipt = await execute();
    writeStdout(`${canonicalSanitizedJSON(receipt)}\n`);
    return 0;
  } catch {
    writeStderr(
      "Production greenfield identity activation failed without disclosing provider output.\n",
    );
    return 1;
  }
}

function expectedReadbacks() {
  const cleanFresh = Object.fromEntries(
    greenfieldCleanTargetTables.map((name) => [name, 0]),
  );
  const cleanActivated = {
    ...cleanFresh,
    identity_reconciliation_receipts: 1,
    identity_reconciliation_activations: 1,
  };
  const schema = {
    database_name: productionRuntimeProvisioningTarget.databaseName,
    runtime_marker: productionDatabase.runtimeMarker,
    database_branch_id: productionDatabase.branchId,
    migration_count: reviewedSchema0016.migrationCount,
    migration_head_id: reviewedSchema0016.migrationHeadId,
    migration_head_hash: reviewedSchema0016.migrationHeadHash,
    migration_history_md5: reviewedSchema0016.migrationHistoryMd5,
    public_table_count: reviewedSchema0016.publicTableCount,
    public_table_names_md5: reviewedSchema0016.publicTableNamesMd5,
    public_table_properties_count:
      reviewedSchema0016.publicTablePropertiesCount,
    public_table_properties_md5:
      reviewedSchema0016.publicTablePropertiesMd5,
    public_column_count: reviewedSchema0016.publicColumnCount,
    public_columns_md5: reviewedSchema0016.publicColumnsMd5,
    public_constraint_count: reviewedSchema0016.publicConstraintCount,
    public_constraints_md5: reviewedSchema0016.publicConstraintsMd5,
    public_index_count: reviewedSchema0016.publicIndexCount,
    public_indexes_md5: reviewedSchema0016.publicIndexesMd5,
    public_trigger_count: reviewedSchema0016.publicTriggerCount,
    public_triggers_md5: reviewedSchema0016.publicTriggersMd5,
    public_function_count: reviewedSchema0016.publicFunctionCount,
    public_functions_md5: reviewedSchema0016.publicFunctionsMd5,
    public_enum_label_count: reviewedSchema0016.publicEnumLabelCount,
    public_enum_labels_md5: reviewedSchema0016.publicEnumLabelsMd5,
    catalog_contract_md5: reviewedSchema0016.catalogContractMd5,
  };
  const seed = {
    reference_competitions_count:
      reviewedDeterministicSeed.referenceCompetitionsCount,
    reference_competitions_business_md5:
      reviewedDeterministicSeed.referenceCompetitionsBusinessMd5,
    reference_teams_count: reviewedDeterministicSeed.referenceTeamsCount,
    reference_teams_business_md5:
      reviewedDeterministicSeed.referenceTeamsBusinessMd5,
    reference_disciplinary_codes_count:
      reviewedDeterministicSeed.referenceDisciplinaryCodesCount,
    reference_disciplinary_rules_count:
      reviewedDeterministicSeed.referenceDisciplinaryRulesCount,
    global_workout_presets_count:
      reviewedDeterministicSeed.globalWorkoutPresetsCount,
  };
  const sourceContract = {
    schema_readback_path: reviewedSchema0016.providerQueryPath,
    schema_readback_sha256: reviewedSchema0016.providerQuerySha256,
    clean_target_readback_path: cleanTargetReadback.queryPath,
    clean_target_readback_sha256: cleanTargetReadback.querySha256,
    ledger_readback_path: ledgerReadback.queryPath,
    ledger_readback_sha256: ledgerReadback.querySha256,
    seed_migration_path: reviewedDeterministicSeed.migrationPath,
    seed_migration_sha256: reviewedDeterministicSeed.migrationSha256,
    migration_snapshot_path: reviewedSchema0016.repositorySnapshotPath,
    migration_snapshot_sha256: reviewedSchema0016.repositorySnapshotSha256,
    migration_journal_path: productionMigration0016Contract.journalPath,
    migration_journal_sha256: productionMigration0016Contract.journalSha256,
    migration_head: reviewedSchema0016.migrationHead,
    migration_count: reviewedSchema0016.migrationCount,
    migration_head_hash: reviewedSchema0016.migrationHeadHash,
  };
  const historySequence = {
    data_type: productionMigration0016Contract.historySequence.dataType,
    start_value: productionMigration0016Contract.historySequence.startValue,
    minimum_value:
      productionMigration0016Contract.historySequence.minimumValue,
    maximum_value:
      productionMigration0016Contract.historySequence.maximumValue,
    increment_by: productionMigration0016Contract.historySequence.incrementBy,
    cache_size: productionMigration0016Contract.historySequence.cacheSize,
    cycle: productionMigration0016Contract.historySequence.cycle,
    next_value:
      productionMigration0016Contract.historySequence.targetRestartWith,
  };
  return {
    schema,
    historySequence,
    seed,
    cleanFresh,
    cleanActivated,
    cleanTarget: {
      database_name: productionRuntimeProvisioningTarget.databaseName,
      database_role: productionMigration0016Contract.stableOwner,
      runtime_markers: [{
        marker: productionDatabase.runtimeMarker,
        branch_id: productionDatabase.branchId,
        environment: "production",
      }],
    },
    sourceContract,
    productionTarget: {
      organization: productionDatabase.organization,
      logical_database: productionDatabase.database,
      postgres_database: productionRuntimeProvisioningTarget.databaseName,
      branch: productionDatabase.branch,
      branch_id: productionDatabase.branchId,
      runtime_marker: productionDatabase.runtimeMarker,
      stable_role: productionMigration0016Contract.stableOwner,
    },
  };
}

function validateCrossSourceContract() {
  const migration = productionMigration0016Contract;
  const runtime = productionRuntimeProvisioningTarget;
  if (
    migration.organization !== productionDatabase.organization
    || migration.database !== productionDatabase.database
    || migration.branch !== productionDatabase.branch
    || migration.branchId !== productionDatabase.branchId
    || migration.runtimeMarker !== productionDatabase.runtimeMarker
    || runtime.organization !== productionDatabase.organization
    || runtime.database !== productionDatabase.database
    || runtime.branch !== productionDatabase.branch
    || runtime.branchId !== productionDatabase.branchId
    || runtime.runtimeMarker !== productionDatabase.runtimeMarker
    || runtime.databaseName !== migration.stableOwner
    || reviewedSchema0016.migrationCount !== migration.target.migrationCount
    || reviewedSchema0016.migrationHeadId !== migration.target.historyId
    || reviewedSchema0016.migrationHeadHash !== migration.target.fileSha256
    || reviewedSchema0016.migrationHistoryMd5
      !== migration.target.migrationHistoryMd5
    || reviewedSchema0016.publicTableCount !== migration.target.publicTableCount
  ) {
    throw new Error("Production identity activation cross-source contract does not match");
  }
}

function validateLedgerReadback(value) {
  requireExactKeys(value, [
    "database_name",
    "database_branch_id",
    "runtime_marker",
    "total_epoch_count",
    "preparing_epoch_count",
    "open_epoch_count",
    "frozen_epoch_count",
    "archived_epoch_count",
    "capture_enforced_epoch_count",
    "entity_revision_count",
    "outbox_event_count",
    "outbox_delivery_count",
  ]);
  requireEqual(value.database_name, productionRuntimeProvisioningTarget.databaseName);
  requireEqual(value.database_branch_id, productionDatabase.branchId);
  requireEqual(value.runtime_marker, productionDatabase.runtimeMarker);
  for (const name of [
    "total_epoch_count",
    "preparing_epoch_count",
    "open_epoch_count",
    "frozen_epoch_count",
    "archived_epoch_count",
    "capture_enforced_epoch_count",
    "entity_revision_count",
    "outbox_event_count",
    "outbox_delivery_count",
  ]) {
    if (!Number.isSafeInteger(value[name]) || value[name] < 0) {
      throw new Error("Production identity activation readback is invalid");
    }
  }
  if (
    value.preparing_epoch_count !== 0
    || value.open_epoch_count !== 0
    || value.capture_enforced_epoch_count !== 0
    || value.outbox_event_count !== 0
    || value.outbox_delivery_count !== 0
    || value.total_epoch_count
      !== value.frozen_epoch_count + value.archived_epoch_count
  ) {
    throw new Error("Production identity activation readback is invalid");
  }
}

function validateHistorySequenceReadback(value, expected) {
  requireExactKeys(value, [
    "data_type",
    "start_value",
    "minimum_value",
    "maximum_value",
    "increment_by",
    "cache_size",
    "cycle",
    "last_value",
    "is_called",
    "next_value",
  ]);
  for (const name of [
    "data_type",
    "start_value",
    "minimum_value",
    "maximum_value",
    "increment_by",
    "cache_size",
    "cycle",
    "next_value",
  ]) {
    requireEqual(value[name], expected[name]);
  }
  const applyTime = value.last_value === expected.next_value
    && value.is_called === false;
  const productionEquivalent = value.last_value === expected.next_value - 1
    && value.is_called === true;
  if (!applyTime && !productionEquivalent) {
    throw new Error("Production identity activation readback is invalid");
  }
}

function validateIdentityReceipt(value) {
  requireExactKeys(value, [
    "id",
    "receipt_digest",
    "clerk_instance_id",
    "reconciliation_profile",
    "authorization_profile",
    "authorization_digest",
    "clerk_issuer",
    "clerk_domain",
    "snapshot_captured_at_utc",
    "legacy_mapping_count",
    "excluded_auth_count",
    "mapping_hash",
    "status",
    "reviewed_at_utc",
    "activated_at_utc",
  ]);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value.id)) {
    throw new Error("Production identity activation readback is invalid");
  }
  requireExactObject({
    receipt_digest: value.receipt_digest,
    clerk_instance_id: value.clerk_instance_id,
    reconciliation_profile: value.reconciliation_profile,
    authorization_profile: value.authorization_profile,
    authorization_digest: value.authorization_digest,
    clerk_issuer: value.clerk_issuer,
    clerk_domain: value.clerk_domain,
    legacy_mapping_count: value.legacy_mapping_count,
    excluded_auth_count: value.excluded_auth_count,
    mapping_hash: value.mapping_hash,
    status: value.status,
  }, {
    receipt_digest: greenfieldIdentityReceiptDigest,
    clerk_instance_id: productionClerk.instanceId,
    reconciliation_profile: greenfieldIdentityProfile,
    authorization_profile: greenfieldAuthorizationProfile,
    authorization_digest: greenfieldAuthorizationDigest,
    clerk_issuer: productionClerk.issuer,
    clerk_domain: productionClerk.domain,
    legacy_mapping_count: 0,
    excluded_auth_count: 0,
    mapping_hash: greenfieldEmptyMappingHash,
    status: "verified",
  });
  const timestamps = [
    value.snapshot_captured_at_utc,
    value.reviewed_at_utc,
    value.activated_at_utc,
  ];
  if (
    timestamps.some((timestamp) => !validUTCInstant(timestamp))
    || new Set(timestamps).size !== 1
  ) {
    throw new Error("Production identity activation readback is invalid");
  }
}

function validateIdentityActivation(value) {
  requireExactKeys(value, [
    "receipt_digest",
    "clerk_instance_id",
    "activated_at_utc",
  ]);
  requireEqual(value.receipt_digest, greenfieldIdentityReceiptDigest);
  requireEqual(value.clerk_instance_id, productionClerk.instanceId);
  if (!validUTCInstant(value.activated_at_utc)) {
    throw new Error("Production identity activation readback is invalid");
  }
}

function requireSourceDigest(value, expectedDigest, label) {
  if (typeof value !== "string" || sha256Hex(value) !== expectedDigest) {
    throw new Error(`Production identity activation ${label} digest does not match`);
  }
}

function embeddableReadback(value, label) {
  const trimmed = value.trim();
  if (
    !trimmed.endsWith(";")
    || /(^|\n)\s*\\/u.test(trimmed)
    || /(^|\n)\s*(?:begin|commit|rollback)\b/iu.test(trimmed)
  ) {
    throw new Error(`Production identity activation ${label} is not embeddable`);
  }
  return trimmed.slice(0, -1);
}

function requireExactObject(actual, expected) {
  if (canonicalSanitizedJSON(actual) !== canonicalSanitizedJSON(expected)) {
    throw new Error("Production identity activation readback is invalid");
  }
}

function requireExactKeys(value, expected) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Production identity activation readback is invalid");
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (
    actual.length !== wanted.length
    || actual.some((key, index) => key !== wanted[index])
  ) {
    throw new Error("Production identity activation readback is invalid");
  }
}

function requireEqual(actual, expected) {
  if (actual !== expected) {
    throw new Error("Production identity activation readback is invalid");
  }
}

function validUTCInstant(value) {
  return typeof value === "string"
    && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u.test(value)
    && Number.isFinite(Date.parse(value));
}

function indentSQL(value, spaces) {
  const prefix = " ".repeat(spaces);
  return value.split("\n").map((line) => `${prefix}${line}`).join("\n");
}

function quoteSQLIdentifier(value) {
  return `"${String(value).replaceAll('"', '""')}"`;
}

function quoteSQLLiteral(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function quoteSQLJSON(value) {
  return `${quoteSQLLiteral(canonicalSanitizedJSON(value))}::jsonb`;
}

function sha256Hex(value) {
  return createHash("sha256").update(value).digest("hex");
}

function md5Hex(value) {
  return createHash("md5").update(value).digest("hex");
}

function genericExecutionError() {
  return new Error("Production greenfield identity activation execution failed");
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await runProductionGreenfieldIdentityActivationCLI();
}
