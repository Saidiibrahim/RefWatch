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
  reviewedSchema,
  reviewedSchema0016,
} from "./greenfield-launch-packet.mjs";
import { productionMigration0016Contract } from "./apply-production-migration-0016.mjs";
import { productionRuntimeProvisioningTarget } from "./provision-production-runtime.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const migrationsDirectory = resolve(scriptDirectory, "../src/db/migrations");
const MAX_PROVIDER_OUTPUT_BYTES = 1024 * 1024;
const PROVIDER_TIMEOUT_MS = 120_000;
const PROVIDER_KILL_GRACE_MS = 2_000;
const RECEIPT_MARKER = "REFWATCH_PRODUCTION_MIGRATION_0017_RECEIPT:";
const READY_MARKER = "REFWATCH_PRODUCTION_MIGRATION_0017_READY";
const COMMITTED_MARKER = "REFWATCH_PRODUCTION_MIGRATION_0017_COMMITTED";
const receiptType = "refwatch_production_migration_0017";
const pendingStatus = "validated_pending_commit";

export const productionMigration0017Gate =
  "REFWATCH_ALLOW_PRODUCTION_MIGRATION_0017";

export const productionMigration0017Command = Object.freeze({
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

export const productionMigration0017Contract = Object.freeze({
  organization: productionDatabase.organization,
  logicalDatabase: productionDatabase.database,
  postgresDatabase: productionRuntimeProvisioningTarget.databaseName,
  branch: productionDatabase.branch,
  branchId: productionDatabase.branchId,
  runtimeMarker: productionDatabase.runtimeMarker,
  stableOwner: productionMigration0016Contract.stableOwner,
  journalPath: productionMigration0016Contract.journalPath,
  journalSha256: productionMigration0016Contract.journalSha256,
  historySequence: Object.freeze({
    ...productionMigration0016Contract.historySequence,
    preflightNextValue: 18,
    targetRestartWith: 19,
    targetIsCalled: false,
  }),
  previous: Object.freeze({
    index: productionMigration0016Contract.target.index,
    tag: productionMigration0016Contract.target.tag,
    journalTimestamp: productionMigration0016Contract.target.journalTimestamp,
    historyId: productionMigration0016Contract.target.historyId,
    fileSha256: productionMigration0016Contract.target.fileSha256,
    migrationCount: productionMigration0016Contract.target.migrationCount,
    migrationHistoryMd5:
      productionMigration0016Contract.target.migrationHistoryMd5,
    fullHistorySha256:
      "2ea7870b3abe8b5bbddfee93eb70a1eee959df6bb4bbaf1e028ca5ddf0f13093",
  }),
  target: Object.freeze({
    index: productionMigration0016Contract.successor.index,
    tag: productionMigration0016Contract.successor.tag,
    journalTimestamp:
      productionMigration0016Contract.successor.journalTimestamp,
    historyId: reviewedSchema.migrationHeadId,
    fileSha256: reviewedSchema.migrationHeadHash,
    migrationCount: reviewedSchema.migrationCount,
    migrationHistoryMd5: reviewedSchema.migrationHistoryMd5,
    fullHistorySha256:
      "4df5affeb9a55d1dd00437eb952f13f00afbb1f730bb368e3b2310d16edfa695",
    publicTableCount: reviewedSchema.publicTableCount,
    publicColumnCount: reviewedSchema.publicColumnCount,
    publicColumnsMd5: reviewedSchema.publicColumnsMd5,
    catalogContractMd5: reviewedSchema.catalogContractMd5,
    tableName: "app_users",
    columnName: "clerk_profile_updated_at",
    columnType: "timestamp with time zone",
    udtName: "timestamptz",
  }),
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
  migrationJournal: resolve(migrationsDirectory, "meta/_journal.json"),
  previousMigration: resolve(
    migrationsDirectory,
    `${productionMigration0017Contract.previous.tag}.sql`,
  ),
  targetMigration: resolve(
    migrationsDirectory,
    `${productionMigration0017Contract.target.tag}.sql`,
  ),
  targetSnapshot: resolve(migrationsDirectory, "meta/0017_snapshot.json"),
});

export async function loadProductionMigration0017Sources() {
  const migrationJournalJSON = await readFile(
    sourcePaths.migrationJournal,
    "utf8",
  );
  requireSourceDigest(
    migrationJournalJSON,
    productionMigration0017Contract.journalSha256,
    "migration journal",
  );
  let journalEntries;
  try {
    journalEntries = JSON.parse(migrationJournalJSON)?.entries;
  } catch {
    throw new Error("Production migration 0017 journal contract is invalid");
  }
  if (
    !Array.isArray(journalEntries)
    || journalEntries.some(
      (entry) => !/^\d{4}_[a-z0-9_]+$/u.test(entry?.tag ?? ""),
    )
  ) {
    throw new Error("Production migration 0017 journal contract is invalid");
  }
  const migrationHistorySQL = await Promise.all(
    journalEntries.map((entry) => readFile(
      resolve(migrationsDirectory, `${entry.tag}.sql`),
      "utf8",
    )),
  );
  const migrationHistoryContractJSON = canonicalSanitizedJSON(
    journalEntries.map((entry, index) => ({
      id: index + 1,
      hash: sha256Hex(migrationHistorySQL[index]),
      created_at: entry.when,
    })),
  );
  const [
    schemaReadbackSQL,
    cleanTargetReadbackSQL,
    ledgerReadbackSQL,
    deterministicSeedMigrationSQL,
    previousMigrationSQL,
    targetMigrationSQL,
    targetSnapshotJSON,
  ] = await Promise.all([
    readFile(sourcePaths.schemaReadback, "utf8"),
    readFile(sourcePaths.cleanTargetReadback, "utf8"),
    readFile(sourcePaths.ledgerReadback, "utf8"),
    readFile(sourcePaths.deterministicSeedMigration, "utf8"),
    readFile(sourcePaths.previousMigration, "utf8"),
    readFile(sourcePaths.targetMigration, "utf8"),
    readFile(sourcePaths.targetSnapshot, "utf8"),
  ]);
  return validateProductionMigration0017Sources({
    schemaReadbackSQL,
    cleanTargetReadbackSQL,
    ledgerReadbackSQL,
    deterministicSeedMigrationSQL,
    migrationJournalJSON,
    migrationHistoryContractJSON,
    previousMigrationSQL,
    targetMigrationSQL,
    targetSnapshotJSON,
  });
}

export function validateProductionMigration0017Sources(source) {
  requireSourceDigest(
    source.schemaReadbackSQL,
    reviewedSchema.providerQuerySha256,
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
    source.migrationJournalJSON,
    productionMigration0017Contract.journalSha256,
    "migration journal",
  );
  requireSourceDigest(
    source.previousMigrationSQL,
    productionMigration0017Contract.previous.fileSha256,
    "migration 0016",
  );
  requireSourceDigest(
    source.targetMigrationSQL,
    productionMigration0017Contract.target.fileSha256,
    "migration 0017",
  );
  requireSourceDigest(
    source.targetSnapshotJSON,
    reviewedSchema.repositorySnapshotSha256,
    "migration 0017 snapshot",
  );

  let journal;
  let snapshot;
  let migrationHistoryRows;
  try {
    journal = JSON.parse(source.migrationJournalJSON);
    snapshot = JSON.parse(source.targetSnapshotJSON);
    migrationHistoryRows = JSON.parse(source.migrationHistoryContractJSON);
  } catch {
    throw new Error("Production migration 0017 repository contract is invalid");
  }
  if (
    journal?.version !== "7"
    || journal?.dialect !== "postgresql"
    || !Array.isArray(journal?.entries)
    || journal.entries.length !== productionMigration0017Contract.target.migrationCount
  ) {
    throw new Error("Production migration 0017 journal contract does not match");
  }
  requireExactJournalEntry(
    journal.entries[productionMigration0017Contract.previous.index],
    productionMigration0017Contract.previous,
  );
  requireExactJournalEntry(
    journal.entries[productionMigration0017Contract.target.index],
    productionMigration0017Contract.target,
  );
  if (
    !Array.isArray(migrationHistoryRows)
    || migrationHistoryRows.length
      !== productionMigration0017Contract.target.migrationCount
    || canonicalSanitizedJSON(migrationHistoryRows)
      !== source.migrationHistoryContractJSON
    || migrationHistoryRows.some((row, index) => (
      Object.keys(row ?? {}).sort().join(",") !== "created_at,hash,id"
      || row.id !== index + 1
      || !/^[0-9a-f]{64}$/u.test(row.hash ?? "")
      || !Number.isSafeInteger(row.created_at)
      || row.created_at !== journal.entries[index]?.when
    ))
    || fullHistorySha256(migrationHistoryRows.slice(
      0,
      productionMigration0017Contract.previous.migrationCount,
    )) !== productionMigration0017Contract.previous.fullHistorySha256
    || fullHistorySha256(migrationHistoryRows)
      !== productionMigration0017Contract.target.fullHistorySha256
  ) {
    throw new Error("Production migration 0017 full history source contract does not match");
  }
  if (
    /(^|\n)\s*(?:begin|commit|rollback)\s*;/iu.test(source.targetMigrationSQL)
    || /(^|\n)\s*\\/u.test(source.targetMigrationSQL)
  ) {
    throw new Error("Production migration 0017 cannot contain transaction or psql controls");
  }

  const tableNames = Object.keys(snapshot?.tables ?? {}).sort();
  const targetColumn = snapshot?.tables?.[
    `public.${productionMigration0017Contract.target.tableName}`
  ]?.columns?.[productionMigration0017Contract.target.columnName];
  if (
    snapshot?.version !== "7"
    || snapshot?.dialect !== "postgresql"
    || tableNames.length !== reviewedSchema.publicTableCount
    || md5Hex(tableNames.join(",")) !== reviewedSchema.publicTableNamesMd5
    || targetColumn?.name !== productionMigration0017Contract.target.columnName
    || targetColumn?.type !== productionMigration0017Contract.target.columnType
    || targetColumn?.notNull !== false
    || targetColumn?.primaryKey !== false
  ) {
    throw new Error("Production migration 0017 snapshot contract does not match");
  }
  validateCrossSourceContract();

  return Object.freeze({
    ...source,
    tableNames: Object.freeze(tableNames),
    migrationHistoryRows: Object.freeze(
      migrationHistoryRows.map((row) => Object.freeze({ ...row })),
    ),
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

export function renderProductionMigration0017SQL(source) {
  const validated = validateProductionMigration0017Sources(source);
  const expected = expectedReadbacks();
  const contract = productionMigration0017Contract;
  const lockRelations = [
    '"drizzle"."__drizzle_migrations"',
    ...validated.tableNames.map((name) => {
      const [schema, table] = name.split(".");
      return `${quoteSQLIdentifier(schema)}.${quoteSQLIdentifier(table)}`;
    }),
  ].join(",\n  ");
  const historySequence = '"drizzle"."__drizzle_migrations_id_seq"';
  const previousHistoryRows = validated.migrationHistoryRows.slice(
    0,
    contract.previous.migrationCount,
  );
  const targetHistoryRows = validated.migrationHistoryRows;
  const historyCatalogReadback = migrationHistoryCatalogReadbackSQL();

  return String.raw`\set QUIET 1
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN ISOLATION LEVEL SERIALIZABLE;
SET LOCAL ROLE ${quoteSQLIdentifier(contract.stableOwner)};
SET LOCAL search_path = pg_catalog, public;
DO $refwatch_migration_0017_session_state$
BEGIN
  IF current_setting('session_replication_role') <> 'origin' THEN
    RAISE EXCEPTION 'production migration 0017 replication role failed';
  END IF;
END;
$refwatch_migration_0017_session_state$;
LOCK TABLE
  ${lockRelations}
IN SHARE ROW EXCLUSIVE MODE;
SELECT pg_advisory_xact_lock(
  hashtextextended(
    ${quoteSQLLiteral(`reconciliation:${productionClerk.instanceId}`)},
    0
  )
);
CREATE TEMP TABLE refwatch_migration_0017_pre_schema
ON COMMIT DROP AS
SELECT greenfield_schema_readback AS payload
FROM (
${indentSQL(validated.schemaReadbackQuery, 2)}
) AS reviewed_schema_readback;
CREATE TEMP TABLE refwatch_migration_0017_pre_clean
ON COMMIT DROP AS
SELECT greenfield_readback AS payload
FROM (
${indentSQL(validated.cleanTargetReadbackQuery, 2)}
) AS reviewed_clean_readback;
CREATE TEMP TABLE refwatch_migration_0017_pre_ledger
ON COMMIT DROP AS
SELECT greenfield_ledger_readback AS payload
FROM (
${indentSQL(validated.ledgerReadbackQuery, 2)}
) AS reviewed_ledger_readback;
CREATE TEMP TABLE refwatch_migration_0017_pre_sequence
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
CREATE TEMP TABLE refwatch_migration_0017_pre_history
ON COMMIT DROP AS
SELECT
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'hash', hash,
        'created_at', created_at
      )
      ORDER BY id
    ),
    '[]'::jsonb
  ) AS rows,
  encode(
    sha256(
      convert_to(
        COALESCE(
          string_agg(
            id::text || ':' || hash || ':' || created_at::text,
            ','
            ORDER BY id
          ),
          ''
        ),
        'UTF8'
      )
    ),
    'hex'
  ) AS full_history_sha256
FROM drizzle.__drizzle_migrations;
CREATE TEMP TABLE refwatch_migration_0017_pre_history_catalog
ON COMMIT DROP AS
${historyCatalogReadback};
CREATE TEMP TABLE refwatch_migration_0017_identity_snapshot
ON COMMIT DROP AS
SELECT jsonb_build_object(
  'identity_receipt', jsonb_build_object(
    'id', receipts.id::text,
    'receipt_digest', receipts.receipt_digest,
    'clerk_instance_id', receipts.clerk_instance_id,
    'reconciliation_profile', receipts.reconciliation_profile,
    'authorization_profile', receipts.authorization_profile,
    'authorization_digest', receipts.authorization_digest,
    'clerk_issuer', receipts.clerk_issuer,
    'clerk_domain', receipts.clerk_domain,
    'snapshot_captured_at_utc', to_char(
      receipts.snapshot_captured_at AT TIME ZONE 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
    ),
    'legacy_mapping_count', receipts.legacy_mapping_count,
    'excluded_auth_count', receipts.excluded_auth_count,
    'mapping_hash', receipts.mapping_hash,
    'status', receipts.status,
    'reviewed_at_utc', to_char(
      receipts.reviewed_at AT TIME ZONE 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
    ),
    'activated_at_utc', to_char(
      receipts.activated_at AT TIME ZONE 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
    )
  ),
  'identity_activation', jsonb_build_object(
    'receipt_digest', activations.receipt_digest,
    'clerk_instance_id', activations.clerk_instance_id,
    'activated_at_utc', to_char(
      activations.activated_at AT TIME ZONE 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
    )
  )
) AS payload
FROM identity_reconciliation_receipts receipts
JOIN identity_reconciliation_activations activations
  ON activations.receipt_digest = receipts.receipt_digest
 AND activations.clerk_instance_id = receipts.clerk_instance_id
WHERE receipts.receipt_digest = ${quoteSQLLiteral(greenfieldIdentityReceiptDigest)}
  AND receipts.clerk_instance_id = ${quoteSQLLiteral(productionClerk.instanceId)}
  AND receipts.reconciliation_profile = ${quoteSQLLiteral(greenfieldIdentityProfile)}
  AND receipts.authorization_profile = ${quoteSQLLiteral(greenfieldAuthorizationProfile)}
  AND receipts.authorization_digest = ${quoteSQLLiteral(greenfieldAuthorizationDigest)}
  AND receipts.clerk_issuer = ${quoteSQLLiteral(productionClerk.issuer)}
  AND receipts.clerk_domain = ${quoteSQLLiteral(productionClerk.domain)}
  AND receipts.legacy_mapping_count = 0
  AND receipts.excluded_auth_count = 0
  AND receipts.mapping_hash = ${quoteSQLLiteral(greenfieldEmptyMappingHash)}
  AND receipts.status = 'verified'
  AND receipts.snapshot_captured_at = date_trunc('milliseconds', receipts.snapshot_captured_at)
  AND receipts.snapshot_captured_at = receipts.reviewed_at
  AND receipts.reviewed_at = receipts.activated_at
  AND receipts.activated_at = activations.activated_at;
CREATE TEMP TABLE refwatch_migration_0017_context (
  operation text NOT NULL
) ON COMMIT DROP;
DO $refwatch_migration_0017_preflight$
DECLARE
  schema_payload jsonb;
  clean_payload jsonb;
  ledger_payload jsonb;
  sequence_data_type text;
  sequence_start_value bigint;
  sequence_minimum_value bigint;
  sequence_maximum_value bigint;
  sequence_increment_by bigint;
  sequence_cache_size bigint;
  sequence_cycle boolean;
  sequence_last_value bigint;
  sequence_is_called boolean;
  history_rows jsonb;
  history_full_sha256 text;
  history_catalog jsonb;
  target_column_count bigint;
BEGIN
  SELECT payload INTO STRICT schema_payload
  FROM refwatch_migration_0017_pre_schema;
  SELECT payload INTO STRICT clean_payload
  FROM refwatch_migration_0017_pre_clean;
  SELECT payload INTO STRICT ledger_payload
  FROM refwatch_migration_0017_pre_ledger;
  SELECT rows, full_history_sha256
  INTO STRICT history_rows, history_full_sha256
  FROM refwatch_migration_0017_pre_history;
  SELECT payload INTO STRICT history_catalog
  FROM refwatch_migration_0017_pre_history_catalog;
  PERFORM payload FROM refwatch_migration_0017_identity_snapshot;
  IF NOT FOUND
    OR (SELECT count(*) FROM refwatch_migration_0017_identity_snapshot) <> 1
    OR (SELECT count(*) FROM identity_reconciliation_receipts) <> 1
    OR (SELECT count(*) FROM identity_reconciliation_activations) <> 1
  THEN
    RAISE EXCEPTION 'production migration 0017 activation receipt precondition failed';
  END IF;

  IF current_user <> ${quoteSQLLiteral(contract.stableOwner)}
    OR current_database() <> ${quoteSQLLiteral(contract.postgresDatabase)}
  THEN
    RAISE EXCEPTION 'production migration 0017 database role failed';
  END IF;
  IF clean_payload - 'deterministic_seed' - 'clean_target_inventory'
      IS DISTINCT FROM ${quoteSQLJSON(expected.cleanTarget)}
    OR clean_payload -> 'deterministic_seed'
      IS DISTINCT FROM ${quoteSQLJSON(expected.seed)}
    OR clean_payload -> 'clean_target_inventory'
      IS DISTINCT FROM ${quoteSQLJSON(expected.cleanActivated)}
  THEN
    RAISE EXCEPTION 'production migration 0017 clean or seed precondition failed';
  END IF;
  IF history_catalog IS DISTINCT FROM ${quoteSQLJSON(expected.historyCatalog)}
  THEN
    RAISE EXCEPTION 'production migration 0017 history catalog precondition failed';
  END IF;
  IF NOT ${inactiveLedgerSQL("ledger_payload")}
  THEN
    RAISE EXCEPTION 'production migration 0017 ledger precondition failed';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_class relation
    JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relkind IN ('r', 'p', 'S')
      AND pg_get_userbyid(relation.relowner) <> ${quoteSQLLiteral(contract.stableOwner)}
  ) OR EXISTS (
    SELECT 1
    FROM pg_proc procedure_definition
    JOIN pg_namespace namespace
      ON namespace.oid = procedure_definition.pronamespace
    WHERE namespace.nspname = 'public'
      AND pg_get_userbyid(procedure_definition.proowner)
        <> ${quoteSQLLiteral(contract.stableOwner)}
  ) OR EXISTS (
    SELECT 1
    FROM pg_class relation
    JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'drizzle'
      AND relation.relname IN (
        '__drizzle_migrations',
        '__drizzle_migrations_id_seq'
      )
      AND relation.relkind IN ('r', 'p', 'S')
      AND pg_get_userbyid(relation.relowner)
        <> ${quoteSQLLiteral(contract.stableOwner)}
  ) THEN
    RAISE EXCEPTION 'production migration 0017 stable ownership failed';
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
  FROM refwatch_migration_0017_pre_sequence;
  IF sequence_data_type IS DISTINCT FROM ${quoteSQLLiteral(contract.historySequence.dataType)}
    OR sequence_start_value <> ${contract.historySequence.startValue}
    OR sequence_minimum_value <> ${contract.historySequence.minimumValue}
    OR sequence_maximum_value <> ${contract.historySequence.maximumValue}
    OR sequence_increment_by <> ${contract.historySequence.incrementBy}
    OR sequence_cache_size <> ${contract.historySequence.cacheSize}
    OR sequence_cycle IS DISTINCT FROM ${contract.historySequence.cycle}
  THEN
    RAISE EXCEPTION 'production migration 0017 history sequence parameters failed';
  END IF;

  SELECT count(*) INTO target_column_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = ${quoteSQLLiteral(contract.target.tableName)}
    AND column_name = ${quoteSQLLiteral(contract.target.columnName)};
  IF schema_payload - 'observed_at_utc'
      IS NOT DISTINCT FROM ${quoteSQLJSON(expected.schema0016)}
  THEN
    IF target_column_count <> 0
      OR history_rows IS DISTINCT FROM ${quoteSQLJSON(previousHistoryRows)}
      OR history_full_sha256 IS DISTINCT FROM ${quoteSQLLiteral(contract.previous.fullHistorySha256)}
      OR NOT EXISTS (
        SELECT 1
        FROM drizzle.__drizzle_migrations
        WHERE id = ${contract.previous.historyId}
          AND hash = ${quoteSQLLiteral(contract.previous.fileSha256)}
          AND created_at = ${contract.previous.journalTimestamp}
      )
      OR NOT (
        (
          sequence_last_value = ${contract.historySequence.preflightNextValue}
          AND sequence_is_called IS FALSE
        )
        OR (
          sequence_last_value = ${contract.historySequence.preflightNextValue - 1}
          AND sequence_is_called IS TRUE
        )
      )
    THEN
      RAISE EXCEPTION 'production migration 0017 apply precondition failed';
    END IF;
    INSERT INTO refwatch_migration_0017_context (operation) VALUES ('applied');
  ELSIF schema_payload - 'observed_at_utc'
      IS NOT DISTINCT FROM ${quoteSQLJSON(expected.schema0017)}
  THEN
    IF target_column_count <> 1
      OR history_rows IS DISTINCT FROM ${quoteSQLJSON(targetHistoryRows)}
      OR history_full_sha256 IS DISTINCT FROM ${quoteSQLLiteral(contract.target.fullHistorySha256)}
      OR NOT EXISTS (
        SELECT 1
        FROM drizzle.__drizzle_migrations
        WHERE id = ${contract.target.historyId}
          AND hash = ${quoteSQLLiteral(contract.target.fileSha256)}
          AND created_at = ${contract.target.journalTimestamp}
      )
      OR sequence_last_value <> ${contract.historySequence.targetRestartWith}
      OR sequence_is_called IS DISTINCT FROM ${contract.historySequence.targetIsCalled}
    THEN
      RAISE EXCEPTION 'production migration 0017 retry precondition failed';
    END IF;
    INSERT INTO refwatch_migration_0017_context (operation)
    VALUES ('idempotent_retry');
  ELSE
    RAISE EXCEPTION 'production migration 0017 schema precondition failed';
  END IF;
END;
$refwatch_migration_0017_preflight$;
SELECT operation = 'applied' AS should_apply
FROM refwatch_migration_0017_context
\gset refwatch_migration_0017_
\if :refwatch_migration_0017_should_apply
${validated.targetMigrationSQL}
INSERT INTO drizzle.__drizzle_migrations ("id", "hash", "created_at")
VALUES (
  ${contract.target.historyId},
  ${quoteSQLLiteral(contract.target.fileSha256)},
  ${contract.target.journalTimestamp}
);
ALTER SEQUENCE ${historySequence}
  RESTART WITH ${contract.historySequence.targetRestartWith};
\endif
CREATE TEMP TABLE refwatch_migration_0017_post_schema
ON COMMIT DROP AS
SELECT greenfield_schema_readback AS payload
FROM (
${indentSQL(validated.schemaReadbackQuery, 2)}
) AS reviewed_schema_readback;
CREATE TEMP TABLE refwatch_migration_0017_post_clean
ON COMMIT DROP AS
SELECT greenfield_readback AS payload
FROM (
${indentSQL(validated.cleanTargetReadbackQuery, 2)}
) AS reviewed_clean_readback;
CREATE TEMP TABLE refwatch_migration_0017_post_ledger
ON COMMIT DROP AS
SELECT greenfield_ledger_readback AS payload
FROM (
${indentSQL(validated.ledgerReadbackQuery, 2)}
) AS reviewed_ledger_readback;
CREATE TEMP TABLE refwatch_migration_0017_post_sequence
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
CREATE TEMP TABLE refwatch_migration_0017_post_history
ON COMMIT DROP AS
SELECT
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'hash', hash,
        'created_at', created_at
      )
      ORDER BY id
    ),
    '[]'::jsonb
  ) AS rows,
  encode(
    sha256(
      convert_to(
        COALESCE(
          string_agg(
            id::text || ':' || hash || ':' || created_at::text,
            ','
            ORDER BY id
          ),
          ''
        ),
        'UTF8'
      )
    ),
    'hex'
  ) AS full_history_sha256
FROM drizzle.__drizzle_migrations;
CREATE TEMP TABLE refwatch_migration_0017_post_history_catalog
ON COMMIT DROP AS
${historyCatalogReadback};
DO $refwatch_migration_0017_postflight$
DECLARE
  schema_payload jsonb;
  clean_payload jsonb;
  ledger_payload jsonb;
  pre_identity jsonb;
  post_identity jsonb;
  sequence_payload jsonb;
  history_rows jsonb;
  history_full_sha256 text;
  history_catalog jsonb;
  target_column_count bigint;
BEGIN
  SELECT payload INTO STRICT schema_payload
  FROM refwatch_migration_0017_post_schema;
  SELECT payload INTO STRICT clean_payload
  FROM refwatch_migration_0017_post_clean;
  SELECT payload INTO STRICT ledger_payload
  FROM refwatch_migration_0017_post_ledger;
  SELECT rows, full_history_sha256
  INTO STRICT history_rows, history_full_sha256
  FROM refwatch_migration_0017_post_history;
  SELECT payload INTO STRICT history_catalog
  FROM refwatch_migration_0017_post_history_catalog;
  SELECT payload INTO STRICT pre_identity
  FROM refwatch_migration_0017_identity_snapshot;

  SELECT jsonb_build_object(
    'identity_receipt', jsonb_build_object(
      'id', receipts.id::text,
      'receipt_digest', receipts.receipt_digest,
      'clerk_instance_id', receipts.clerk_instance_id,
      'reconciliation_profile', receipts.reconciliation_profile,
      'authorization_profile', receipts.authorization_profile,
      'authorization_digest', receipts.authorization_digest,
      'clerk_issuer', receipts.clerk_issuer,
      'clerk_domain', receipts.clerk_domain,
      'snapshot_captured_at_utc', to_char(receipts.snapshot_captured_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'legacy_mapping_count', receipts.legacy_mapping_count,
      'excluded_auth_count', receipts.excluded_auth_count,
      'mapping_hash', receipts.mapping_hash,
      'status', receipts.status,
      'reviewed_at_utc', to_char(receipts.reviewed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'activated_at_utc', to_char(receipts.activated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
    ),
    'identity_activation', jsonb_build_object(
      'receipt_digest', activations.receipt_digest,
      'clerk_instance_id', activations.clerk_instance_id,
      'activated_at_utc', to_char(activations.activated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
    )
  ) INTO STRICT post_identity
  FROM identity_reconciliation_receipts receipts
  JOIN identity_reconciliation_activations activations
    ON activations.receipt_digest = receipts.receipt_digest
   AND activations.clerk_instance_id = receipts.clerk_instance_id;

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
  ) INTO STRICT sequence_payload
  FROM refwatch_migration_0017_post_sequence;

  SELECT count(*) INTO target_column_count
  FROM information_schema.columns columns
  JOIN pg_class relation ON relation.relname = columns.table_name
  JOIN pg_namespace namespace
    ON namespace.oid = relation.relnamespace
   AND namespace.nspname = columns.table_schema
  WHERE columns.table_schema = 'public'
    AND columns.table_name = ${quoteSQLLiteral(contract.target.tableName)}
    AND columns.column_name = ${quoteSQLLiteral(contract.target.columnName)}
    AND columns.data_type = ${quoteSQLLiteral(contract.target.columnType)}
    AND columns.udt_schema = 'pg_catalog'
    AND columns.udt_name = ${quoteSQLLiteral(contract.target.udtName)}
    AND columns.is_nullable = 'YES'
    AND columns.column_default IS NULL
    AND pg_get_userbyid(relation.relowner) = ${quoteSQLLiteral(contract.stableOwner)};

  IF schema_payload - 'observed_at_utc'
      IS DISTINCT FROM ${quoteSQLJSON(expected.schema0017)}
    OR clean_payload - 'deterministic_seed' - 'clean_target_inventory'
      IS DISTINCT FROM ${quoteSQLJSON(expected.cleanTarget)}
    OR clean_payload -> 'deterministic_seed'
      IS DISTINCT FROM ${quoteSQLJSON(expected.seed)}
    OR clean_payload -> 'clean_target_inventory'
      IS DISTINCT FROM ${quoteSQLJSON(expected.cleanActivated)}
    OR clean_payload IS DISTINCT FROM (
      SELECT payload FROM refwatch_migration_0017_pre_clean
    )
    OR ledger_payload - 'observed_at_utc' IS DISTINCT FROM (
      SELECT payload - 'observed_at_utc'
      FROM refwatch_migration_0017_pre_ledger
    )
    OR NOT ${inactiveLedgerSQL("ledger_payload")}
    OR pre_identity IS DISTINCT FROM post_identity
    OR sequence_payload IS DISTINCT FROM ${quoteSQLJSON(expected.historySequence0017)}
    OR history_rows IS DISTINCT FROM ${quoteSQLJSON(targetHistoryRows)}
    OR history_full_sha256 IS DISTINCT FROM ${quoteSQLLiteral(contract.target.fullHistorySha256)}
    OR history_catalog IS DISTINCT FROM ${quoteSQLJSON(expected.historyCatalog)}
    OR history_catalog IS DISTINCT FROM (
      SELECT payload FROM refwatch_migration_0017_pre_history_catalog
    )
    OR target_column_count <> 1
    OR NOT EXISTS (
      SELECT 1
      FROM drizzle.__drizzle_migrations
      WHERE id = ${contract.target.historyId}
        AND hash = ${quoteSQLLiteral(contract.target.fileSha256)}
        AND created_at = ${contract.target.journalTimestamp}
    )
  THEN
    RAISE EXCEPTION 'production migration 0017 postcondition failed';
  END IF;
END;
$refwatch_migration_0017_postflight$;
SELECT ${quoteSQLLiteral(RECEIPT_MARKER)} || jsonb_build_object(
  'schema_version', 1,
  'receipt_type', ${quoteSQLLiteral(receiptType)},
  'status', ${quoteSQLLiteral(pendingStatus)},
  'operation', (SELECT operation FROM refwatch_migration_0017_context),
  'provider_command', jsonb_build_object(
    'command', ${quoteSQLLiteral(productionMigration0017Command.command)},
    'arguments', ${quoteSQLJSON(productionMigration0017Command.args)},
    'sql_transport', 'stdin'
  ),
  'production_target', jsonb_build_object(
    'organization', ${quoteSQLLiteral(contract.organization)},
    'logical_database', ${quoteSQLLiteral(contract.logicalDatabase)},
    'postgres_database', current_database(),
    'branch', ${quoteSQLLiteral(contract.branch)},
    'branch_id', ${quoteSQLLiteral(contract.branchId)},
    'runtime_marker', ${quoteSQLLiteral(contract.runtimeMarker)},
    'stable_role', current_user
  ),
  'source_contract', ${quoteSQLJSON(expected.sourceContract)},
  'verified_state', jsonb_build_object(
    'schema', (
      SELECT payload - 'observed_at_utc'
      FROM refwatch_migration_0017_post_schema
    ),
    'migration_history', jsonb_build_object(
      'migration_count', (
        SELECT count(*) FROM drizzle.__drizzle_migrations
      ),
      'head_id', (
        SELECT id FROM drizzle.__drizzle_migrations ORDER BY id DESC LIMIT 1
      ),
      'head_hash', (
        SELECT hash FROM drizzle.__drizzle_migrations ORDER BY id DESC LIMIT 1
      ),
      'head_created_at', (
        SELECT created_at
        FROM drizzle.__drizzle_migrations
        ORDER BY id DESC
        LIMIT 1
      ),
      'history_md5', (
        SELECT md5(string_agg(id::text || ':' || hash, ',' ORDER BY id))
        FROM drizzle.__drizzle_migrations
      ),
      'full_history_sha256', (
        SELECT full_history_sha256
        FROM refwatch_migration_0017_post_history
      )
    ),
    'migration_history_catalog', (
      SELECT payload
      FROM refwatch_migration_0017_post_history_catalog
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
      FROM refwatch_migration_0017_post_sequence
    ),
    'target_column', (
      SELECT jsonb_build_object(
        'table_schema', columns.table_schema,
        'table_name', columns.table_name,
        'column_name', columns.column_name,
        'data_type', columns.data_type,
        'udt_schema', columns.udt_schema,
        'udt_name', columns.udt_name,
        'nullable', columns.is_nullable = 'YES',
        'column_default', columns.column_default,
        'table_owner', pg_get_userbyid(relation.relowner)
      )
      FROM information_schema.columns columns
      JOIN pg_class relation ON relation.relname = columns.table_name
      JOIN pg_namespace namespace
        ON namespace.oid = relation.relnamespace
       AND namespace.nspname = columns.table_schema
      WHERE columns.table_schema = 'public'
        AND columns.table_name = ${quoteSQLLiteral(contract.target.tableName)}
        AND columns.column_name = ${quoteSQLLiteral(contract.target.columnName)}
    ),
    'deterministic_seed', (
      SELECT payload -> 'deterministic_seed'
      FROM refwatch_migration_0017_post_clean
    ),
    'clean_target_inventory', (
      SELECT payload -> 'clean_target_inventory'
      FROM refwatch_migration_0017_post_clean
    ),
    'ledger', (
      SELECT payload - 'observed_at_utc'
      FROM refwatch_migration_0017_post_ledger
    )
  ),
  'identity_receipt', (
    SELECT payload -> 'identity_receipt'
    FROM refwatch_migration_0017_identity_snapshot
  ),
  'identity_activation', (
    SELECT payload -> 'identity_activation'
    FROM refwatch_migration_0017_identity_snapshot
  )
)::text;
\echo ${READY_MARKER}
`;
}

export function validateProductionMigration0017Readback(value) {
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
  if (!new Set(["applied", "idempotent_retry"]).has(value.operation)) {
    throw invalidReadback();
  }
  requireExactObject(value.provider_command, {
    command: productionMigration0017Command.command,
    arguments: [...productionMigration0017Command.args],
    sql_transport: "stdin",
  });
  requireExactObject(value.production_target, expected.productionTarget);
  requireExactObject(value.source_contract, expected.sourceContract);
  requireExactKeys(value.verified_state, [
    "schema",
    "migration_history",
    "migration_history_catalog",
    "history_sequence",
    "target_column",
    "deterministic_seed",
    "clean_target_inventory",
    "ledger",
  ]);
  requireExactObject(value.verified_state.schema, expected.schema0017);
  requireExactObject(
    value.verified_state.migration_history,
    expected.migrationHistory0017,
  );
  requireExactObject(
    value.verified_state.migration_history_catalog,
    expected.historyCatalog,
  );
  requireExactObject(
    value.verified_state.history_sequence,
    expected.historySequence0017,
  );
  requireExactObject(value.verified_state.target_column, expected.targetColumn);
  requireExactObject(value.verified_state.deterministic_seed, expected.seed);
  requireExactObject(
    value.verified_state.clean_target_inventory,
    expected.cleanActivated,
  );
  validateLedgerReadback(value.verified_state.ledger);
  validateIdentityReceipt(value.identity_receipt);
  validateIdentityActivation(value.identity_activation);
  if (
    value.identity_receipt.activated_at_utc
      !== value.identity_activation.activated_at_utc
  ) {
    throw invalidReadback();
  }
  return Object.freeze(value);
}

export function createProductionMigration0017Receipt(readback) {
  const validated = validateProductionMigration0017Readback(readback);
  const committed = { ...validated, status: "committed" };
  return Object.freeze({
    ...committed,
    receipt_sha256: computeSanitizedReceiptSha256(committed),
  });
}

export async function executeProductionMigration0017(options = {}) {
  const executionEnvironment = options.environment ?? process.env;
  if (executionEnvironment[productionMigration0017Gate] !== "1") {
    throw new Error("Production migration 0017 gate is closed");
  }
  const source = await loadProductionMigration0017Sources();
  const providerEnvironment = {
    ...executionEnvironment,
    PSCALE_ALLOW_NONINTERACTIVE_SHELL: "1",
    PSQLRC: "/dev/null",
    PSQL_HISTORY: "/dev/null",
  };
  delete providerEnvironment.PGOPTIONS;
  const specification = {
    command: productionMigration0017Command.command,
    args: productionMigration0017Command.args,
    sql: renderProductionMigration0017SQL(source),
    environment: providerEnvironment,
  };
  const runSession = options.runSession ?? runProductionMigration0017Session;
  const readback = await runSession(
    specification,
    validateProductionMigration0017Readback,
  );
  return createProductionMigration0017Receipt(readback);
}

export function runProductionMigration0017Session(
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
          readback = validateBeforeCommit(
            JSON.parse(line.slice(RECEIPT_MARKER.length)),
          );
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
      const output = Buffer.isBuffer(chunk) ? chunk.toString("utf8") : String(chunk);
      outputBytes += Buffer.byteLength(output);
      if (outputBytes > maxOutputBytes) {
        failAndTerminate();
        return;
      }
      lineBuffer += output;
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

export async function runProductionMigration0017CLI(options = {}) {
  const args = options.args ?? process.argv.slice(2);
  const environment = options.environment ?? process.env;
  const writeStdout = options.writeStdout
    ?? ((value) => process.stdout.write(value));
  const writeStderr = options.writeStderr
    ?? ((value) => process.stderr.write(value));
  const checkSources = options.checkSources ?? loadProductionMigration0017Sources;
  const execute = options.execute
    ?? (() => executeProductionMigration0017({ environment }));

  if (args.length === 1 && args[0] === "--check") {
    try {
      await checkSources();
      writeStdout("Production migration 0017 source contract verified.\n");
      return 0;
    } catch {
      writeStderr("Production migration 0017 source contract check failed.\n");
      return 1;
    }
  }
  if (args.length !== 1 || args[0] !== "--execute") {
    writeStderr(
      "Usage: node scripts/apply-production-migration-0017.mjs --check|--execute\n",
    );
    return 2;
  }
  if (environment[productionMigration0017Gate] !== "1") {
    writeStderr("Production migration 0017 technical gate is closed.\n");
    return 2;
  }
  try {
    const receipt = await execute();
    writeStdout(`${canonicalSanitizedJSON(receipt)}\n`);
    return 0;
  } catch {
    writeStderr(
      "Production migration 0017 failed without disclosing provider output.\n",
    );
    return 1;
  }
}

function expectedReadbacks() {
  const cleanActivated = Object.fromEntries(
    greenfieldCleanTargetTables.map((name) => [name, 0]),
  );
  cleanActivated.identity_reconciliation_receipts = 1;
  cleanActivated.identity_reconciliation_activations = 1;
  const schema0016 = expectedSchema(reviewedSchema0016);
  const schema0017 = expectedSchema(reviewedSchema);
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
  return {
    schema0016,
    schema0017,
    seed,
    cleanActivated,
    cleanTarget: {
      database_name: productionMigration0017Contract.postgresDatabase,
      database_role: productionMigration0017Contract.stableOwner,
      runtime_markers: [{
        marker: productionMigration0017Contract.runtimeMarker,
        branch_id: productionMigration0017Contract.branchId,
        environment: "production",
      }],
    },
    historySequence0017: {
      data_type: productionMigration0017Contract.historySequence.dataType,
      start_value: productionMigration0017Contract.historySequence.startValue,
      minimum_value:
        productionMigration0017Contract.historySequence.minimumValue,
      maximum_value:
        productionMigration0017Contract.historySequence.maximumValue,
      increment_by:
        productionMigration0017Contract.historySequence.incrementBy,
      cache_size: productionMigration0017Contract.historySequence.cacheSize,
      cycle: productionMigration0017Contract.historySequence.cycle,
      last_value: productionMigration0017Contract.historySequence.targetRestartWith,
      is_called: productionMigration0017Contract.historySequence.targetIsCalled,
      next_value: productionMigration0017Contract.historySequence.targetRestartWith,
    },
    migrationHistory0017: {
      migration_count: productionMigration0017Contract.target.migrationCount,
      head_id: productionMigration0017Contract.target.historyId,
      head_hash: productionMigration0017Contract.target.fileSha256,
      head_created_at: productionMigration0017Contract.target.journalTimestamp,
      history_md5: productionMigration0017Contract.target.migrationHistoryMd5,
      full_history_sha256:
        productionMigration0017Contract.target.fullHistorySha256,
    },
    historyCatalog: {
      table_owner: productionMigration0017Contract.stableOwner,
      sequence_owner: productionMigration0017Contract.stableOwner,
      columns: [
        {
          column_name: "id",
          ordinal_position: 1,
          data_type: "integer",
          not_null: true,
          default_expression:
            "nextval('drizzle.__drizzle_migrations_id_seq'::regclass)",
        },
        {
          column_name: "hash",
          ordinal_position: 2,
          data_type: "text",
          not_null: true,
          default_expression: null,
        },
        {
          column_name: "created_at",
          ordinal_position: 3,
          data_type: "bigint",
          not_null: false,
          default_expression: null,
        },
      ],
      primary_key: {
        constraint_name: "__drizzle_migrations_pkey",
        definition: "PRIMARY KEY (id)",
        key_attnums: [1],
      },
      serial_sequence: "drizzle.__drizzle_migrations_id_seq",
      owned_by_dependency: {
        dependency_type: "a",
        sequence_schema: "drizzle",
        sequence_name: "__drizzle_migrations_id_seq",
        table_schema: "drizzle",
        table_name: "__drizzle_migrations",
        column_name: "id",
      },
    },
    targetColumn: {
      table_schema: "public",
      table_name: productionMigration0017Contract.target.tableName,
      column_name: productionMigration0017Contract.target.columnName,
      data_type: productionMigration0017Contract.target.columnType,
      udt_schema: "pg_catalog",
      udt_name: productionMigration0017Contract.target.udtName,
      nullable: true,
      column_default: null,
      table_owner: productionMigration0017Contract.stableOwner,
    },
    productionTarget: {
      organization: productionMigration0017Contract.organization,
      logical_database: productionMigration0017Contract.logicalDatabase,
      postgres_database: productionMigration0017Contract.postgresDatabase,
      branch: productionMigration0017Contract.branch,
      branch_id: productionMigration0017Contract.branchId,
      runtime_marker: productionMigration0017Contract.runtimeMarker,
      stable_role: productionMigration0017Contract.stableOwner,
    },
    sourceContract: {
      schema_readback_path: reviewedSchema.providerQueryPath,
      schema_readback_sha256: reviewedSchema.providerQuerySha256,
      clean_target_readback_path: cleanTargetReadback.queryPath,
      clean_target_readback_sha256: cleanTargetReadback.querySha256,
      ledger_readback_path: ledgerReadback.queryPath,
      ledger_readback_sha256: ledgerReadback.querySha256,
      seed_migration_path: reviewedDeterministicSeed.migrationPath,
      seed_migration_sha256: reviewedDeterministicSeed.migrationSha256,
      migration_journal_path: productionMigration0017Contract.journalPath,
      migration_journal_sha256: productionMigration0017Contract.journalSha256,
      previous_migration: productionMigration0017Contract.previous.tag,
      previous_migration_sha256:
        productionMigration0017Contract.previous.fileSha256,
      previous_full_history_sha256:
        productionMigration0017Contract.previous.fullHistorySha256,
      target_migration: productionMigration0017Contract.target.tag,
      target_migration_sha256: productionMigration0017Contract.target.fileSha256,
      target_full_history_sha256:
        productionMigration0017Contract.target.fullHistorySha256,
      target_snapshot_path: reviewedSchema.repositorySnapshotPath,
      target_snapshot_sha256: reviewedSchema.repositorySnapshotSha256,
    },
  };
}

function expectedSchema(schema) {
  return {
    database_name: productionMigration0017Contract.postgresDatabase,
    runtime_marker: productionMigration0017Contract.runtimeMarker,
    database_branch_id: productionMigration0017Contract.branchId,
    migration_count: schema.migrationCount,
    migration_head_id: schema.migrationHeadId,
    migration_head_hash: schema.migrationHeadHash,
    migration_history_md5: schema.migrationHistoryMd5,
    public_table_count: schema.publicTableCount,
    public_table_names_md5: schema.publicTableNamesMd5,
    public_table_properties_count: schema.publicTablePropertiesCount,
    public_table_properties_md5: schema.publicTablePropertiesMd5,
    public_column_count: schema.publicColumnCount,
    public_columns_md5: schema.publicColumnsMd5,
    public_constraint_count: schema.publicConstraintCount,
    public_constraints_md5: schema.publicConstraintsMd5,
    public_index_count: schema.publicIndexCount,
    public_indexes_md5: schema.publicIndexesMd5,
    public_trigger_count: schema.publicTriggerCount,
    public_triggers_md5: schema.publicTriggersMd5,
    public_function_count: schema.publicFunctionCount,
    public_functions_md5: schema.publicFunctionsMd5,
    public_enum_label_count: schema.publicEnumLabelCount,
    public_enum_labels_md5: schema.publicEnumLabelsMd5,
    catalog_contract_md5: schema.catalogContractMd5,
  };
}

function validateCrossSourceContract() {
  const contract = productionMigration0017Contract;
  if (
    contract.organization !== productionDatabase.organization
    || contract.logicalDatabase !== productionDatabase.database
    || contract.postgresDatabase !== productionRuntimeProvisioningTarget.databaseName
    || contract.branch !== productionDatabase.branch
    || contract.branchId !== productionDatabase.branchId
    || contract.runtimeMarker !== productionDatabase.runtimeMarker
    || contract.stableOwner !== productionMigration0016Contract.stableOwner
    || reviewedSchema.migrationCount !== 18
    || reviewedSchema.migrationHeadId !== 18
    || reviewedSchema.migrationHistoryMd5 !== "f2f3ddf416d58b2d9a60749e41af11f7"
    || reviewedSchema.publicTableCount !== 36
    || reviewedSchema.publicColumnCount !== 383
    || reviewedSchema.publicColumnsMd5 !== "5fa4e25bcf19d7caf1f9adcfb4879344"
    || reviewedSchema.catalogContractMd5 !== "99dca5e8c11b8ec23debfb7c698a74d7"
  ) {
    throw new Error("Production migration 0017 cross-source contract does not match");
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
  requireEqual(value.database_name, productionMigration0017Contract.postgresDatabase);
  requireEqual(value.database_branch_id, productionMigration0017Contract.branchId);
  requireEqual(value.runtime_marker, productionMigration0017Contract.runtimeMarker);
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
      throw invalidReadback();
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
    throw invalidReadback();
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
    throw invalidReadback();
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
    throw invalidReadback();
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
  if (!validUTCInstant(value.activated_at_utc)) throw invalidReadback();
}

function migrationHistoryCatalogReadbackSQL() {
  return String.raw`SELECT jsonb_build_object(
  'table_owner', (
    SELECT pg_get_userbyid(relation.relowner)
    FROM pg_class relation
    WHERE relation.oid = 'drizzle.__drizzle_migrations'::regclass
  ),
  'sequence_owner', (
    SELECT pg_get_userbyid(relation.relowner)
    FROM pg_class relation
    WHERE relation.oid = 'drizzle.__drizzle_migrations_id_seq'::regclass
  ),
  'columns', (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'column_name', attribute.attname,
          'ordinal_position', attribute.attnum,
          'data_type', format_type(attribute.atttypid, attribute.atttypmod),
          'not_null', attribute.attnotnull,
          'default_expression', pg_get_expr(
            column_default.adbin,
            column_default.adrelid
          )
        )
        ORDER BY attribute.attnum
      ),
      '[]'::jsonb
    )
    FROM pg_attribute attribute
    LEFT JOIN pg_attrdef column_default
      ON column_default.adrelid = attribute.attrelid
     AND column_default.adnum = attribute.attnum
    WHERE attribute.attrelid = 'drizzle.__drizzle_migrations'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  ),
  'primary_key', (
    SELECT jsonb_build_object(
      'constraint_name', constraint_definition.conname,
      'definition', pg_get_constraintdef(constraint_definition.oid, true),
      'key_attnums', to_jsonb(constraint_definition.conkey)
    )
    FROM pg_constraint constraint_definition
    WHERE constraint_definition.conrelid
      = 'drizzle.__drizzle_migrations'::regclass
      AND constraint_definition.contype = 'p'
  ),
  'serial_sequence', pg_get_serial_sequence(
    'drizzle.__drizzle_migrations',
    'id'
  ),
  'owned_by_dependency', (
    SELECT jsonb_build_object(
      'dependency_type', dependency.deptype::text,
      'sequence_schema', sequence_namespace.nspname,
      'sequence_name', sequence_relation.relname,
      'table_schema', table_namespace.nspname,
      'table_name', table_relation.relname,
      'column_name', table_attribute.attname
    )
    FROM pg_depend dependency
    JOIN pg_class sequence_relation
      ON dependency.classid = 'pg_class'::regclass
     AND dependency.objid = sequence_relation.oid
     AND sequence_relation.relkind = 'S'
    JOIN pg_namespace sequence_namespace
      ON sequence_namespace.oid = sequence_relation.relnamespace
    JOIN pg_class table_relation
      ON dependency.refclassid = 'pg_class'::regclass
     AND dependency.refobjid = table_relation.oid
    JOIN pg_namespace table_namespace
      ON table_namespace.oid = table_relation.relnamespace
    JOIN pg_attribute table_attribute
      ON table_attribute.attrelid = table_relation.oid
     AND table_attribute.attnum = dependency.refobjsubid
    WHERE sequence_relation.oid
      = 'drizzle.__drizzle_migrations_id_seq'::regclass
      AND dependency.deptype = 'a'
  )
) AS payload`;
}

function fullHistorySha256(rows) {
  return sha256Hex(rows.map((row) => (
    `${row.id}:${row.hash}:${row.created_at}`
  )).join(","));
}

function inactiveLedgerSQL(variableName) {
  return `(
    ${variableName} ->> 'database_name' = ${quoteSQLLiteral(productionMigration0017Contract.postgresDatabase)}
    AND ${variableName} ->> 'database_branch_id' = ${quoteSQLLiteral(productionMigration0017Contract.branchId)}
    AND ${variableName} ->> 'runtime_marker' = ${quoteSQLLiteral(productionMigration0017Contract.runtimeMarker)}
    AND (${variableName} ->> 'preparing_epoch_count')::bigint = 0
    AND (${variableName} ->> 'open_epoch_count')::bigint = 0
    AND (${variableName} ->> 'capture_enforced_epoch_count')::bigint = 0
    AND (${variableName} ->> 'outbox_event_count')::bigint = 0
    AND (${variableName} ->> 'outbox_delivery_count')::bigint = 0
    AND (${variableName} ->> 'total_epoch_count')::bigint
      = (${variableName} ->> 'frozen_epoch_count')::bigint
        + (${variableName} ->> 'archived_epoch_count')::bigint
  )`;
}

function requireExactJournalEntry(entry, expected) {
  if (
    entry?.idx !== expected.index
    || entry?.version !== "7"
    || entry?.when !== expected.journalTimestamp
    || entry?.tag !== expected.tag
    || entry?.breakpoints !== true
  ) {
    throw new Error("Production migration 0017 journal entry does not match");
  }
}

function requireSourceDigest(value, expectedDigest, label) {
  if (typeof value !== "string" || sha256Hex(value) !== expectedDigest) {
    throw new Error(`Production migration 0017 ${label} digest does not match`);
  }
}

function embeddableReadback(value, label) {
  const trimmed = value.trim();
  if (
    !trimmed.endsWith(";")
    || /(^|\n)\s*\\/u.test(trimmed)
    || /(^|\n)\s*(?:begin|commit|rollback)\b/iu.test(trimmed)
  ) {
    throw new Error(`Production migration 0017 ${label} is not embeddable`);
  }
  return trimmed.slice(0, -1);
}

function requireExactObject(actual, expected) {
  if (canonicalSanitizedJSON(actual) !== canonicalSanitizedJSON(expected)) {
    throw invalidReadback();
  }
}

function requireExactKeys(value, expected) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw invalidReadback();
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (
    actual.length !== wanted.length
    || actual.some((key, index) => key !== wanted[index])
  ) {
    throw invalidReadback();
  }
}

function requireEqual(actual, expected) {
  if (actual !== expected) throw invalidReadback();
}

function validUTCInstant(value) {
  return typeof value === "string"
    && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u.test(value)
    && Number.isFinite(Date.parse(value));
}

function invalidReadback() {
  return new Error("Production migration 0017 readback is invalid");
}

function genericExecutionError() {
  return new Error("Production migration 0017 execution failed");
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

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await runProductionMigration0017CLI();
}
