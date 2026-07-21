import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const productionMigration0016Contract = Object.freeze({
  organization: "ibrahim-aka-ajax",
  database: "refwatch",
  branch: "main",
  branchId: "w3g1f8vcbg34",
  runtimeMarker: "refwatch:production:w3g1f8vcbg34",
  stableOwner: "postgres",
  journalPath: "api/src/db/migrations/meta/_journal.json",
  journalSha256:
    "6bee16ebf32328698e91690932ca6a159fdc26c67422897032d96bc8ac80304a",
  historySequence: Object.freeze({
    schema: "drizzle",
    name: "__drizzle_migrations_id_seq",
    dataType: "integer",
    startValue: 1,
    minimumValue: 1,
    maximumValue: 2_147_483_647,
    incrementBy: 1,
    cacheSize: 1,
    cycle: false,
    previousLastValue: 16,
    previousIsCalled: true,
    targetRestartWith: 18,
    targetIsCalled: false,
  }),
  previous: Object.freeze({
    index: 15,
    tag: "0015_bound_ledger_capture_envelope",
    journalTimestamp: 1_784_091_083_000,
    historyId: 16,
    fileSha256:
      "6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a",
    migrationCount: 16,
    publicTableCount: 35,
  }),
  target: Object.freeze({
    index: 16,
    tag: "0016_careless_steel_serpent",
    journalTimestamp: 1_784_513_382_441,
    historyId: 17,
    fileSha256:
      "0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac",
    migrationCount: 17,
    migrationHistoryMd5: "73ad9d2a055b09e83324a50f74ed94dd",
    publicTableCount: 36,
    tableName: "clerk_webhook_delivery_receipts",
    functionNames: Object.freeze([
      "guard_greenfield_app_user_bootstrap",
      "protect_activated_identity_reconciliation_receipt",
      "protect_activated_identity_registry",
      "protect_clerk_webhook_delivery_receipt",
      "validate_and_protect_identity_activation",
    ]),
  }),
  successor: Object.freeze({
    index: 17,
    tag: "0017_ambiguous_hedge_knight",
    journalTimestamp: 1_784_597_422_601,
    migrationCount: 18,
  }),
});

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const migrationsDirectory = resolve(scriptDirectory, "../src/db/migrations");
const journalPath = resolve(migrationsDirectory, "meta/_journal.json");
const previousMigrationPath = resolve(
  migrationsDirectory,
  `${productionMigration0016Contract.previous.tag}.sql`,
);
const targetMigrationPath = resolve(
  migrationsDirectory,
  `${productionMigration0016Contract.target.tag}.sql`,
);

export async function loadProductionMigration0016Contract() {
  const [journalText, previousMigrationSql, targetMigrationSql] =
    await Promise.all([
      readFile(journalPath, "utf8"),
      readFile(previousMigrationPath, "utf8"),
      readFile(targetMigrationPath, "utf8"),
    ]);
  return validateProductionMigration0016Sources({
    journalText,
    previousMigrationSql,
    targetMigrationSql,
  });
}

export function validateProductionMigration0016Sources({
  journalText,
  previousMigrationSql,
  targetMigrationSql,
}) {
  if (
    typeof journalText !== "string"
    || typeof previousMigrationSql !== "string"
    || typeof targetMigrationSql !== "string"
  ) {
    throw new Error("Production migration 0016 source contract is unreadable");
  }
  const journalSha256 = sha256Hex(journalText);
  if (journalSha256 !== productionMigration0016Contract.journalSha256) {
    throw new Error("Production migration journal source digest does not match");
  }

  let journal;
  try {
    journal = JSON.parse(journalText);
  } catch {
    throw new Error("Production migration 0016 journal contract is invalid");
  }

  const entries = journal?.entries;
  if (
    journal?.version !== "7"
    || journal?.dialect !== "postgresql"
    || !Array.isArray(entries)
    || entries.length !== productionMigration0016Contract.successor.migrationCount
  ) {
    throw new Error("Production migration 0016 journal contract does not match");
  }

  requireExactJournalEntry(
    entries[productionMigration0016Contract.previous.index],
    productionMigration0016Contract.previous,
  );
  requireExactJournalEntry(
    entries[productionMigration0016Contract.target.index],
    productionMigration0016Contract.target,
  );
  requireExactJournalEntry(
    entries[productionMigration0016Contract.successor.index],
    productionMigration0016Contract.successor,
  );

  const previousSha256 = sha256Hex(previousMigrationSql);
  if (previousSha256 !== productionMigration0016Contract.previous.fileSha256) {
    throw new Error("Production migration 0015 source digest does not match");
  }
  const targetSha256 = sha256Hex(targetMigrationSql);
  if (targetSha256 !== productionMigration0016Contract.target.fileSha256) {
    throw new Error("Production migration 0016 source digest does not match");
  }
  if (
    /(^|\n)\s*(?:begin|commit|rollback)\s*;/iu.test(targetMigrationSql)
    || /(^|\n)\s*\\/u.test(targetMigrationSql)
  ) {
    throw new Error("Production migration 0016 cannot contain transaction or psql controls");
  }

  return Object.freeze({
    journalSha256,
    previousMigrationSha256: previousSha256,
    targetMigrationSha256: targetSha256,
    targetMigrationSql,
    targetJournalTimestamp:
      productionMigration0016Contract.target.journalTimestamp,
  });
}

export function renderProductionMigration0016(source) {
  const validated = validateProductionMigration0016Sources(source);
  const contract = productionMigration0016Contract;
  const functionNames = contract.target.functionNames
    .map((name) => quoteSqlLiteral(name))
    .join(", ");
  const historySequence = [
    quoteSqlIdentifier(contract.historySequence.schema),
    quoteSqlIdentifier(contract.historySequence.name),
  ].join(".");

  const preconditions = String.raw`
DO $refwatch_preflight$
DECLARE
  actual_migration_count bigint;
  actual_head_id integer;
  actual_head_hash text;
  actual_head_created_at bigint;
  actual_public_table_count bigint;
  actual_sequence_last_value bigint;
  actual_sequence_is_called boolean;
BEGIN
  IF current_user <> ${quoteSqlLiteral(contract.stableOwner)} THEN
    RAISE EXCEPTION 'production migration stable owner role is not active';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.runtime_database_markers
    WHERE marker = ${quoteSqlLiteral(contract.runtimeMarker)}
      AND branch_id = ${quoteSqlLiteral(contract.branchId)}
      AND environment = 'production'
  ) OR (
    SELECT count(*)
    FROM public.runtime_database_markers
    WHERE environment = 'production'
  ) <> 1 THEN
    RAISE EXCEPTION 'production database marker precondition failed';
  END IF;

  SELECT count(*)
  INTO actual_migration_count
  FROM drizzle.__drizzle_migrations;

  SELECT id, hash, created_at
  INTO actual_head_id, actual_head_hash, actual_head_created_at
  FROM drizzle.__drizzle_migrations
  ORDER BY id DESC
  LIMIT 1;

  IF actual_migration_count <> ${contract.previous.migrationCount}
    OR actual_head_id <> ${contract.previous.historyId}
    OR actual_head_hash <> ${quoteSqlLiteral(contract.previous.fileSha256)}
    OR actual_head_created_at <> ${contract.previous.journalTimestamp}
  THEN
    RAISE EXCEPTION 'production migration 0015 history precondition failed';
  END IF;

  SELECT last_value, is_called
  INTO actual_sequence_last_value, actual_sequence_is_called
  FROM ${historySequence};

  IF actual_sequence_last_value <> ${contract.historySequence.previousLastValue}
    OR actual_sequence_is_called IS DISTINCT FROM ${contract.historySequence.previousIsCalled}
  THEN
    RAISE EXCEPTION 'production migration 0015 history sequence precondition failed';
  END IF;

  SELECT count(*)
  INTO actual_public_table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';

  IF actual_public_table_count <> ${contract.previous.publicTableCount}
    OR to_regclass(${quoteSqlLiteral(`public.${contract.target.tableName}`)}) IS NOT NULL
  THEN
    RAISE EXCEPTION 'production migration 0015 schema precondition failed';
  END IF;
END;
$refwatch_preflight$;`.trim();

  const historyInsert = `
INSERT INTO drizzle.__drizzle_migrations ("id", "hash", "created_at")
VALUES (
  ${contract.target.historyId},
  ${quoteSqlLiteral(contract.target.fileSha256)},
  ${contract.target.journalTimestamp}
);
ALTER SEQUENCE ${historySequence}
  RESTART WITH ${contract.historySequence.targetRestartWith};`.trim();

  const postconditions = String.raw`
DO $refwatch_postflight$
DECLARE
  actual_migration_count bigint;
  actual_head_id integer;
  actual_head_hash text;
  actual_head_created_at bigint;
  actual_history_md5 text;
  actual_public_table_count bigint;
  target_table_owner text;
  touched_function_count bigint;
  incorrectly_owned_function_count bigint;
  actual_sequence_last_value bigint;
  actual_sequence_is_called boolean;
BEGIN
  SELECT count(*)
  INTO actual_migration_count
  FROM drizzle.__drizzle_migrations;

  SELECT id, hash, created_at
  INTO actual_head_id, actual_head_hash, actual_head_created_at
  FROM drizzle.__drizzle_migrations
  ORDER BY id DESC
  LIMIT 1;

  SELECT md5(string_agg(id::text || ':' || hash, ',' ORDER BY id))
  INTO actual_history_md5
  FROM drizzle.__drizzle_migrations;

  IF actual_migration_count <> ${contract.target.migrationCount}
    OR actual_head_id <> ${contract.target.historyId}
    OR actual_head_hash <> ${quoteSqlLiteral(contract.target.fileSha256)}
    OR actual_head_created_at <> ${contract.target.journalTimestamp}
    OR actual_history_md5 <> ${quoteSqlLiteral(contract.target.migrationHistoryMd5)}
  THEN
    RAISE EXCEPTION 'production migration 0016 history postcondition failed';
  END IF;

  SELECT last_value, is_called
  INTO actual_sequence_last_value, actual_sequence_is_called
  FROM ${historySequence};

  IF actual_sequence_last_value <> ${contract.historySequence.targetRestartWith}
    OR actual_sequence_is_called IS DISTINCT FROM ${contract.historySequence.targetIsCalled}
  THEN
    RAISE EXCEPTION 'production migration 0016 history sequence postcondition failed';
  END IF;

  SELECT count(*)
  INTO actual_public_table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';

  SELECT pg_get_userbyid(relation.relowner)
  INTO target_table_owner
  FROM pg_class relation
  JOIN pg_namespace namespace
    ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname = ${quoteSqlLiteral(contract.target.tableName)}
    AND relation.relkind IN ('r', 'p');

  IF actual_public_table_count <> ${contract.target.publicTableCount}
    OR target_table_owner IS DISTINCT FROM ${quoteSqlLiteral(contract.stableOwner)}
  THEN
    RAISE EXCEPTION 'production migration 0016 table postcondition failed';
  END IF;

  SELECT
    count(*),
    count(*) FILTER (
      WHERE pg_get_userbyid(procedure_definition.proowner)
        <> ${quoteSqlLiteral(contract.stableOwner)}
    )
  INTO touched_function_count, incorrectly_owned_function_count
  FROM pg_proc procedure_definition
  JOIN pg_namespace namespace
    ON namespace.oid = procedure_definition.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure_definition.proname IN (${functionNames});

  IF touched_function_count <> ${contract.target.functionNames.length}
    OR incorrectly_owned_function_count <> 0
  THEN
    RAISE EXCEPTION 'production migration 0016 function-owner postcondition failed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class relation
    JOIN pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relkind IN ('r', 'p', 'S')
      AND pg_get_userbyid(relation.relowner)
        <> ${quoteSqlLiteral(contract.stableOwner)}
  ) OR EXISTS (
    SELECT 1
    FROM pg_proc procedure_definition
    JOIN pg_namespace namespace
      ON namespace.oid = procedure_definition.pronamespace
    WHERE namespace.nspname = 'public'
      AND pg_get_userbyid(procedure_definition.proowner)
        <> ${quoteSqlLiteral(contract.stableOwner)}
  ) THEN
    RAISE EXCEPTION 'production public object ownership postcondition failed';
  END IF;
END;
$refwatch_postflight$;`.trim();

  return [
    "\\set ON_ERROR_STOP on",
    "BEGIN;",
    `SET LOCAL ROLE ${quoteSqlIdentifier(contract.stableOwner)};`,
    "LOCK TABLE drizzle.__drizzle_migrations IN EXCLUSIVE MODE;",
    preconditions,
    validated.targetMigrationSql,
    historyInsert,
    postconditions,
    "COMMIT;",
    "",
  ].join("\n");
}

export async function executeProductionMigration0016(options = {}) {
  const spawn = options.spawnSyncImpl ?? spawnSync;
  const source = await loadProductionMigration0016Contract();
  const sql = renderProductionMigration0016({
    journalText: await readFile(journalPath, "utf8"),
    previousMigrationSql: await readFile(previousMigrationPath, "utf8"),
    targetMigrationSql: source.targetMigrationSql,
  });
  const contract = productionMigration0016Contract;
  const args = [
    "shell",
    contract.database,
    contract.branch,
    "--org",
    contract.organization,
    "--role",
    "admin",
    "--no-color",
  ];
  const result = spawn("pscale", args, {
    input: sql,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    stdio: ["pipe", "pipe", "pipe"],
    env: {
      ...process.env,
      PSCALE_ALLOW_NONINTERACTIVE_SHELL: "1",
      PSQLRC: "/dev/null",
      PSQL_HISTORY: "/dev/null",
    },
  });
  if (result.error || result.status !== 0) {
    throw new Error("Production migration 0016 execution failed");
  }
}

function requireExactJournalEntry(entry, expected) {
  if (
    entry?.idx !== expected.index
    || entry?.version !== "7"
    || entry?.when !== expected.journalTimestamp
    || entry?.tag !== expected.tag
    || entry?.breakpoints !== true
  ) {
    throw new Error(`Production migration ${expected.tag.slice(0, 4)} journal entry does not match`);
  }
}

function sha256Hex(value) {
  return createHash("sha256").update(value).digest("hex");
}

function quoteSqlLiteral(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function quoteSqlIdentifier(value) {
  return `"${String(value).replaceAll('"', '""')}"`;
}

async function main() {
  const args = process.argv.slice(2);
  const checkOnly = args.length === 1 && args[0] === "--check";
  if (!checkOnly && args.length !== 0) {
    process.stderr.write("Usage: node scripts/apply-production-migration-0016.mjs [--check]\n");
    process.exitCode = 2;
    return;
  }

  try {
    if (checkOnly) {
      await loadProductionMigration0016Contract();
      process.stdout.write("Production migration 0016 source contract verified.\n");
      return;
    }
    await executeProductionMigration0016();
    process.stdout.write("Production migration 0016 applied and verified.\n");
  } catch {
    process.stderr.write(
      checkOnly
        ? "Production migration 0016 source contract check failed.\n"
        : "Production migration 0016 failed without disclosing child output.\n",
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
