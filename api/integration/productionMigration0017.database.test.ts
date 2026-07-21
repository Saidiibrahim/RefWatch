import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { Client } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  loadProductionMigration0017Sources,
  productionMigration0017Contract,
  renderProductionMigration0017SQL,
  runProductionMigration0017Session,
  validateProductionMigration0017Readback,
} from "../scripts/apply-production-migration-0017.mjs";
import { productionMigration0016Contract } from "../scripts/apply-production-migration-0016.mjs";
import {
  greenfieldAuthorizationDigest,
  greenfieldAuthorizationProfile,
  greenfieldEmptyMappingHash,
  greenfieldIdentityProfile,
  greenfieldIdentityReceiptDigest,
  productionClerk,
  productionDatabase,
} from "../scripts/greenfield-launch-packet.mjs";

const databaseURL = validatedLocalDatabaseURL();
const sessionRole = "refwatch_migration_0017_admin";
const activationTimestamp = "2026-07-21T03:38:21.452Z";
let migrationSQL = "";
let targetMigrationSQL = "";

beforeAll(async () => {
  const source = await loadProductionMigration0017Sources();
  migrationSQL = renderProductionMigration0017SQL(source);
  targetMigrationSQL = source.targetMigrationSQL;
  const client = await connectedClient("postgres");
  try {
    await client.query(`
      do $$
      begin
        if not exists (select 1 from pg_roles where rolname = '${sessionRole}') then
          create role ${quoteIdentifier(sessionRole)} login;
        end if;
      end
      $$
    `);
    await client.query(
      `grant ${quoteIdentifier("postgres")} to ${quoteIdentifier(sessionRole)}`,
    );
  } finally {
    await client.end();
  }
}, 30_000);

beforeEach(async () => {
  await rebuildActivatedProduction0016Database();
}, 30_000);

afterAll(async () => {
  const client = await connectedClient("postgres");
  try {
    await client.query(`drop role if exists ${quoteIdentifier(sessionRole)}`);
  } finally {
    await client.end();
  }
});

describe("production migration 0017 isolated PostgreSQL rehearsal", () => {
  it("applies once and preserves exact history and activation rows on retry", async () => {
    const identityBefore = await readIdentityState();
    const first = await runMigration();
    const stateAfterFirst = await readMigrationState();
    const identityAfterFirst = await readIdentityState();
    const retry = await runMigration();
    const stateAfterRetry = await readMigrationState();
    const identityAfterRetry = await readIdentityState();

    expect(first.operation).toBe("applied");
    expect(retry.operation).toBe("idempotent_retry");
    expect(stateAfterFirst).toEqual(stateAfterRetry);
    expect(stateAfterFirst).toMatchObject({
      migration_count: "18",
      head_id: 18,
      head_hash: productionMigration0017Contract.target.fileSha256,
      head_created_at: String(
        productionMigration0017Contract.target.journalTimestamp,
      ),
      history_md5: "f2f3ddf416d58b2d9a60749e41af11f7",
      full_history_sha256:
        productionMigration0017Contract.target.fullHistorySha256,
      target_data_type: "timestamp with time zone",
      target_nullable: "YES",
      target_default: null,
      table_owner: "postgres",
      sequence_last_value: "19",
      sequence_is_called: false,
    });
    expect(identityAfterFirst).toEqual(identityBefore);
    expect(identityAfterRetry).toEqual(identityBefore);
    expect(first.identity_receipt).toEqual(retry.identity_receipt);
    expect(first.identity_activation).toEqual(retry.identity_activation);
  });

  it("accepts both exact preflight sequence representations whose next value is 18", async () => {
    expect(await readSequenceState()).toMatchObject({
      last_value: "17",
      is_called: true,
    });
    await expect(runMigration()).resolves.toMatchObject({ operation: "applied" });

    await rebuildActivatedProduction0016Database();
    const client = await connectedClient("postgres");
    try {
      await client.query(
        "select setval('drizzle.__drizzle_migrations_id_seq', 18, false)",
      );
    } finally {
      await client.end();
    }
    expect(await readSequenceState()).toMatchObject({
      last_value: "18",
      is_called: false,
    });
    await expect(runMigration()).resolves.toMatchObject({ operation: "applied" });
    expect(await readSequenceState()).toMatchObject({
      last_value: "19",
      is_called: false,
    });

    await rebuildActivatedProduction0016Database();
    const parameterDrift = await connectedClient("postgres");
    try {
      await parameterDrift.query(
        "alter sequence drizzle.__drizzle_migrations_id_seq cache 2",
      );
    } finally {
      await parameterDrift.end();
    }
    const driftedSequence = await readSequenceState();
    await expect(runMigration()).rejects.toThrow(genericFailureMessage());
    expect(await readSequenceState()).toEqual(driftedSequence);
    expect(await readMigrationState()).toMatchObject({
      migration_count: "17",
      target_data_type: null,
    });
  });

  it("rejects invalid preflight sequence pairs atomically", async () => {
    for (const sequenceState of [
      { lastValue: 17, isCalled: false },
      { lastValue: 18, isCalled: true },
    ]) {
      await rebuildActivatedProduction0016Database();
      const client = await connectedClient("postgres");
      try {
        await client.query(
          "select setval('drizzle.__drizzle_migrations_id_seq', $1, $2)",
          [sequenceState.lastValue, sequenceState.isCalled],
        );
      } finally {
        await client.end();
      }
      const migrationBefore = await readMigrationState();
      const sequenceBefore = await readSequenceState();
      await expect(runMigration(), JSON.stringify(sequenceState)).rejects.toThrow(
        genericFailureMessage(),
      );
      expect(await readMigrationState(), JSON.stringify(sequenceState)).toEqual(
        migrationBefore,
      );
      expect(await readSequenceState(), JSON.stringify(sequenceState)).toEqual(
        sequenceBefore,
      );
    }
  });

  it("rejects non-head migration-history timestamp drift atomically", async () => {
    const client = await connectedClient("postgres");
    try {
      await client.query(
        `update drizzle.__drizzle_migrations
         set created_at = created_at + 1
         where id = $1`,
        [1],
      );
    } finally {
      await client.end();
    }
    const before = await readMigrationState();
    await expect(runMigration()).rejects.toThrow(genericFailureMessage());
    expect(await readMigrationState()).toEqual(before);
  });

  it("rejects Drizzle history catalog drift atomically", async () => {
    const driftCases = [
      {
        name: "id default",
        sql: `alter table drizzle.__drizzle_migrations
          alter column id drop default`,
      },
      {
        name: "sequence OWNED BY",
        sql: `alter sequence drizzle.__drizzle_migrations_id_seq
          owned by none`,
      },
      {
        name: "primary key",
        sql: `alter table drizzle.__drizzle_migrations
          drop constraint __drizzle_migrations_pkey`,
      },
    ];
    for (const driftCase of driftCases) {
      await rebuildActivatedProduction0016Database();
      const client = await connectedClient("postgres");
      try {
        await client.query(driftCase.sql);
      } finally {
        await client.end();
      }
      const migrationBefore = await readMigrationState();
      const catalogBefore = await readDrizzleHistoryCatalogState();
      await expect(runMigration(), driftCase.name).rejects.toThrow(
        genericFailureMessage(),
      );
      expect(await readMigrationState(), driftCase.name).toEqual(migrationBefore);
      expect(await readDrizzleHistoryCatalogState(), driftCase.name).toEqual(
        catalogBefore,
      );
    }
  });

  it("rejects nonzero application data before changing schema or history", async () => {
    const client = await connectedClient("postgres");
    try {
      await client.query(
        `insert into app_users (clerk_user_id, email)
         values ('user_dirty', 'dirty@example.invalid')`,
      );
    } finally {
      await client.end();
    }
    const before = await readMigrationState();
    await expect(runMigration()).rejects.toThrow(genericFailureMessage());
    expect(await readMigrationState()).toEqual(before);
    expect(await scalarCount("app_users")).toBe("1");
  });

  it("rejects mapping, tombstone, and webhook receipt contamination atomically", async () => {
    const dirtyCases = [
      {
        table: "identity_reconciliation_legacy_mappings",
        sql: `insert into identity_reconciliation_legacy_mappings
          (clerk_instance_id, clerk_user_id, app_user_id, receipt_digest)
          values ('ins_dirty', 'user_dirty', gen_random_uuid(), repeat('f', 64))`,
      },
      {
        table: "clerk_user_deletion_tombstones",
        sql: `insert into clerk_user_deletion_tombstones
          (clerk_instance_id, clerk_user_id, deleted_at)
          values ('ins_dirty', 'user_dirty', now())`,
      },
      {
        table: "clerk_webhook_delivery_receipts",
        sql: `insert into clerk_webhook_delivery_receipts
          (clerk_instance_id, svix_id, event_type, clerk_user_id, payload_hash)
          values ('ins_dirty', 'msg_dirty', 'user.created', 'user_dirty', repeat('f', 64))`,
      },
    ];
    for (const dirtyCase of dirtyCases) {
      await rebuildActivatedProduction0016Database();
      const client = await connectedClient("postgres");
      try {
        await client.query("set session_replication_role = replica");
        await client.query(dirtyCase.sql);
        await client.query("set session_replication_role = origin");
      } finally {
        await client.end();
      }
      const before = await readMigrationState();
      await expect(runMigration(), dirtyCase.table).rejects.toThrow(
        genericFailureMessage(),
      );
      expect(await readMigrationState(), dirtyCase.table).toEqual(before);
      expect(await scalarCount(dirtyCase.table), dirtyCase.table).toBe("1");
    }
  });

  it("rejects partial activation control state atomically", async () => {
    const client = await connectedClient("postgres");
    try {
      await client.query("set session_replication_role = replica");
      await client.query("delete from identity_reconciliation_activations");
      await client.query("set session_replication_role = origin");
    } finally {
      await client.end();
    }
    const before = await readMigrationState();
    await expect(runMigration()).rejects.toThrow(genericFailureMessage());
    expect(await readMigrationState()).toEqual(before);
    expect(await identityCounts()).toEqual({ receipts: "1", activations: "0" });
  });

  it("rejects an active ledger epoch atomically", async () => {
    const client = await connectedClient("postgres");
    try {
      await client.query(
        `insert into mutation_ledger_epochs
          (baseline_snapshot_id, baseline_schema_hash, baseline_data_hash)
         values ('dirty', repeat('a', 64), repeat('b', 64))`,
      );
    } finally {
      await client.end();
    }
    const before = await readMigrationState();
    await expect(runMigration()).rejects.toThrow(genericFailureMessage());
    expect(await readMigrationState()).toEqual(before);
    expect(await scalarCount("mutation_ledger_epochs")).toBe("1");
  });

  it("keeps a concurrent application write outside the locked migration window", async () => {
    const blocker = await connectedClient("postgres");
    const observer = await connectedClient("postgres");
    const writer = await connectedClient("postgres");
    try {
      await blocker.query("begin");
      await blocker.query(
        "lock table workout_sessions in access exclusive mode",
      );
      const migration = runMigration();
      await waitForLock(observer, "app_users", "ShareRowExclusiveLock", true);

      let writerCompleted = false;
      const applicationWrite = writer.query(
        `insert into app_users (clerk_user_id, email)
         values ('user_concurrent_0017', 'concurrent-0017@example.invalid')`,
      ).then(() => {
        writerCompleted = true;
      });
      await waitForLock(observer, "app_users", "RowExclusiveLock", false);
      expect(writerCompleted).toBe(false);

      await blocker.query("commit");
      const receipt = await migration;
      await applicationWrite;

      expect(receipt.operation).toBe("applied");
      expect(writerCompleted).toBe(true);
      expect(await scalarCount("app_users")).toBe("1");
      expect(await identityCounts()).toEqual({ receipts: "1", activations: "1" });
      expect(await readMigrationState()).toMatchObject({
        migration_count: "18",
        target_data_type: "timestamp with time zone",
      });
    } finally {
      await blocker.query("rollback").catch(() => undefined);
      await Promise.all([blocker.end(), observer.end(), writer.end()]);
    }
  });

  it("rolls back DDL, history, and sequence on statement and postflight failures", async () => {
    const statementFailureSQL = migrationSQL.replace(
      targetMigrationSQL,
      `${targetMigrationSQL}\nSELECT refwatch_forced_statement_failure;`,
    );
    expect(statementFailureSQL).not.toBe(migrationSQL);
    const beforeStatement = await readMigrationState();
    await expect(runMigration(statementFailureSQL)).rejects.toThrow(
      genericFailureMessage(),
    );
    expect(await readMigrationState()).toEqual(beforeStatement);

    const postflightFailureSQL = migrationSQL.replace(
      "OR target_column_count <> 1\n    OR NOT EXISTS (",
      "OR target_column_count <> 0\n    OR NOT EXISTS (",
    );
    expect(postflightFailureSQL).not.toBe(migrationSQL);
    const beforePostflight = await readMigrationState();
    await expect(runMigration(postflightFailureSQL)).rejects.toThrow(
      genericFailureMessage(),
    );
    expect(await readMigrationState()).toEqual(beforePostflight);
    expect(await readSequenceState()).toMatchObject({ cache_size: "1" });

    await expect(runMigration()).resolves.toMatchObject({ operation: "applied" });
  });
});

async function runMigration(sql = migrationSQL) {
  return runProductionMigration0017Session(
    localSessionSpecification(sql),
    validateProductionMigration0017Readback,
  );
}

function localSessionSpecification(sql: string) {
  const parsed = new URL(databaseURL);
  const environment = { ...process.env };
  delete environment.PGPASSWORD;
  delete environment.PGSERVICE;
  delete environment.PGSERVICEFILE;
  delete environment.PGOPTIONS;
  environment.PGHOST = parsed.hostname;
  environment.PGPORT = parsed.port;
  environment.PGDATABASE = decodeURIComponent(parsed.pathname.slice(1));
  environment.PGUSER = sessionRole;
  environment.PGSSLMODE = parsed.searchParams.get("sslmode") ?? "disable";
  environment.PSQLRC = "/dev/null";
  environment.PSQL_HISTORY = "/dev/null";
  return {
    command: "psql",
    args: ["-X", "--no-psqlrc"],
    sql,
    environment,
  };
}

async function rebuildActivatedProduction0016Database(): Promise<void> {
  const client = await connectedClient("postgres");
  try {
    await client.query("drop schema if exists public cascade");
    await client.query("drop schema if exists drizzle cascade");
    await client.query("create schema public authorization postgres");
    await client.query("create schema drizzle authorization postgres");
    await client.query(`
      create table drizzle.__drizzle_migrations (
        id serial primary key,
        hash text not null,
        created_at bigint
      )
    `);
    const journal = JSON.parse(await readFile(
      new URL("../src/db/migrations/meta/_journal.json", import.meta.url),
      "utf8",
    ));
    for (const entry of journal.entries.slice(
      0,
      productionMigration0016Contract.target.migrationCount,
    )) {
      const migrationSource = await readFile(
        new URL(`../src/db/migrations/${entry.tag}.sql`, import.meta.url),
        "utf8",
      );
      const statements = migrationSource
        .split("--> statement-breakpoint")
        .filter((statement) => statement.trim().length > 0);
      await client.query("begin");
      try {
        for (const statement of statements) await client.query(statement);
        await client.query(
          `insert into drizzle.__drizzle_migrations (hash, created_at)
           values ($1, $2)`,
          [sha256Hex(migrationSource), entry.when],
        );
        await client.query("commit");
      } catch (error) {
        await client.query("rollback");
        throw error;
      }
    }
    await client.query(
      `insert into runtime_database_markers (marker, branch_id, environment)
       values ($1, $2, 'production')`,
      [productionDatabase.runtimeMarker, productionDatabase.branchId],
    );
    await client.query(
      `insert into identity_reconciliation_receipts (
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
       ) values ($1, $2, $3, 0, 0, $4, 'verified', $3, $3, $5, $6, $7, $8, $9)`,
      [
        greenfieldIdentityReceiptDigest,
        productionClerk.instanceId,
        activationTimestamp,
        greenfieldEmptyMappingHash,
        greenfieldIdentityProfile,
        greenfieldAuthorizationProfile,
        greenfieldAuthorizationDigest,
        productionClerk.issuer,
        productionClerk.domain,
      ],
    );
    await client.query(
      `insert into identity_reconciliation_activations
        (receipt_digest, clerk_instance_id, activated_at)
       values ($1, $2, $3)`,
      [
        greenfieldIdentityReceiptDigest,
        productionClerk.instanceId,
        activationTimestamp,
      ],
    );
  } finally {
    await client.end();
  }
}

async function readMigrationState() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query<{
      migration_count: string;
      head_id: number;
      head_hash: string;
      head_created_at: string;
      history_md5: string;
      full_history_sha256: string;
      target_data_type: string | null;
      target_nullable: string | null;
      target_default: string | null;
      table_owner: string;
      sequence_last_value: string;
      sequence_is_called: boolean;
    }>(`
      select
        (select count(*)::text from drizzle.__drizzle_migrations)
          as migration_count,
        (select id from drizzle.__drizzle_migrations order by id desc limit 1)
          as head_id,
        (select hash from drizzle.__drizzle_migrations order by id desc limit 1)
          as head_hash,
        (select created_at::text from drizzle.__drizzle_migrations order by id desc limit 1)
          as head_created_at,
        (select md5(string_agg(id::text || ':' || hash, ',' order by id))
         from drizzle.__drizzle_migrations) as history_md5,
        (
          select encode(
            sha256(
              convert_to(
                string_agg(
                  id::text || ':' || hash || ':' || created_at::text,
                  ','
                  order by id
                ),
                'UTF8'
              )
            ),
            'hex'
          )
          from drizzle.__drizzle_migrations
        ) as full_history_sha256,
        (select data_type from information_schema.columns
         where table_schema = 'public' and table_name = 'app_users'
           and column_name = 'clerk_profile_updated_at') as target_data_type,
        (select is_nullable from information_schema.columns
         where table_schema = 'public' and table_name = 'app_users'
           and column_name = 'clerk_profile_updated_at') as target_nullable,
        (select column_default from information_schema.columns
         where table_schema = 'public' and table_name = 'app_users'
           and column_name = 'clerk_profile_updated_at') as target_default,
        (select pg_get_userbyid(relation.relowner)
         from pg_class relation join pg_namespace namespace
           on namespace.oid = relation.relnamespace
         where namespace.nspname = 'public' and relation.relname = 'app_users')
          as table_owner,
        (select last_value::text from drizzle.__drizzle_migrations_id_seq)
          as sequence_last_value,
        (select is_called from drizzle.__drizzle_migrations_id_seq)
          as sequence_is_called
    `);
    return result.rows[0];
  } finally {
    await client.end();
  }
}

async function readIdentityState() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query(`
      select
        receipts.id::text as receipt_id,
        receipts.receipt_digest,
        receipts.clerk_instance_id,
        to_char(receipts.snapshot_captured_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as snapshot_captured_at,
        to_char(receipts.reviewed_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as reviewed_at,
        to_char(receipts.activated_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as receipt_activated_at,
        to_char(activations.activated_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as activation_activated_at
      from identity_reconciliation_receipts receipts
      join identity_reconciliation_activations activations
        using (receipt_digest, clerk_instance_id)
    `);
    return result.rows[0];
  } finally {
    await client.end();
  }
}

async function readSequenceState() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query(`
      select
        format_type(sequence_definition.seqtypid, null) as data_type,
        sequence_definition.seqstart::text as start_value,
        sequence_definition.seqmin::text as minimum_value,
        sequence_definition.seqmax::text as maximum_value,
        sequence_definition.seqincrement::text as increment_by,
        sequence_definition.seqcache::text as cache_size,
        sequence_definition.seqcycle as cycle,
        sequence_state.last_value::text as last_value,
        sequence_state.is_called
      from pg_sequence sequence_definition
      cross join drizzle.__drizzle_migrations_id_seq sequence_state
      where sequence_definition.seqrelid
        = 'drizzle.__drizzle_migrations_id_seq'::regclass
    `);
    return result.rows[0];
  } finally {
    await client.end();
  }
}

async function readDrizzleHistoryCatalogState() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query(`
      select
        (
          select count(*)::text
          from pg_attribute
          where attrelid = 'drizzle.__drizzle_migrations'::regclass
            and attnum > 0
            and not attisdropped
        ) as column_count,
        (
          select format_type(atttypid, atttypmod)
          from pg_attribute
          where attrelid = 'drizzle.__drizzle_migrations'::regclass
            and attname = 'id'
        ) as id_type,
        (
          select attnotnull
          from pg_attribute
          where attrelid = 'drizzle.__drizzle_migrations'::regclass
            and attname = 'id'
        ) as id_not_null,
        (
          select pg_get_expr(column_default.adbin, column_default.adrelid)
          from pg_attrdef column_default
          join pg_attribute attribute
            on attribute.attrelid = column_default.adrelid
           and attribute.attnum = column_default.adnum
          where column_default.adrelid
            = 'drizzle.__drizzle_migrations'::regclass
            and attribute.attname = 'id'
        ) as id_default,
        (
          select format_type(atttypid, atttypmod)
          from pg_attribute
          where attrelid = 'drizzle.__drizzle_migrations'::regclass
            and attname = 'hash'
        ) as hash_type,
        (
          select attnotnull
          from pg_attribute
          where attrelid = 'drizzle.__drizzle_migrations'::regclass
            and attname = 'hash'
        ) as hash_not_null,
        (
          select format_type(atttypid, atttypmod)
          from pg_attribute
          where attrelid = 'drizzle.__drizzle_migrations'::regclass
            and attname = 'created_at'
        ) as created_at_type,
        (
          select attnotnull
          from pg_attribute
          where attrelid = 'drizzle.__drizzle_migrations'::regclass
            and attname = 'created_at'
        ) as created_at_not_null,
        (
          select count(*)::text
          from pg_constraint
          where conrelid = 'drizzle.__drizzle_migrations'::regclass
            and contype = 'p'
        ) as primary_key_count,
        (
          select pg_get_constraintdef(oid, true)
          from pg_constraint
          where conrelid = 'drizzle.__drizzle_migrations'::regclass
            and contype = 'p'
        ) as primary_key_definition,
        pg_get_serial_sequence(
          'drizzle.__drizzle_migrations',
          'id'
        ) as serial_sequence,
        (
          select count(*)::text
          from pg_depend dependency
          where dependency.classid = 'pg_class'::regclass
            and dependency.objid
              = 'drizzle.__drizzle_migrations_id_seq'::regclass
            and dependency.refclassid = 'pg_class'::regclass
            and dependency.refobjid
              = 'drizzle.__drizzle_migrations'::regclass
            and dependency.deptype = 'a'
        ) as owned_by_count,
        (
          select attribute.attname
          from pg_depend dependency
          join pg_attribute attribute
            on attribute.attrelid = dependency.refobjid
           and attribute.attnum = dependency.refobjsubid
          where dependency.classid = 'pg_class'::regclass
            and dependency.objid
              = 'drizzle.__drizzle_migrations_id_seq'::regclass
            and dependency.refclassid = 'pg_class'::regclass
            and dependency.refobjid
              = 'drizzle.__drizzle_migrations'::regclass
            and dependency.deptype = 'a'
        ) as owned_by_column
    `);
    return result.rows[0];
  } finally {
    await client.end();
  }
}

async function identityCounts() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query(`
      select
        (select count(*)::text from identity_reconciliation_receipts)
          as receipts,
        (select count(*)::text from identity_reconciliation_activations)
          as activations
    `);
    return result.rows[0];
  } finally {
    await client.end();
  }
}

async function scalarCount(tableName: string): Promise<string> {
  if (!/^[a-z][a-z0-9_]*$/u.test(tableName)) throw new Error("Invalid table");
  const client = await connectedClient("postgres");
  try {
    const result = await client.query<{ count: string }>(
      `select count(*)::text as count from ${quoteIdentifier(tableName)}`,
    );
    return result.rows[0].count;
  } finally {
    await client.end();
  }
}

async function waitForLock(
  client: Client,
  tableName: string,
  mode: string,
  granted: boolean,
): Promise<void> {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const result = await client.query<{ present: boolean }>(`
      select exists (
        select 1
        from pg_locks locks
        join pg_class relation on relation.oid = locks.relation
        join pg_namespace namespace on namespace.oid = relation.relnamespace
        where namespace.nspname = 'public'
          and relation.relname = $1
          and locks.mode = $2
          and locks.granted = $3
      ) as present
    `, [tableName, mode, granted]);
    if (result.rows[0].present) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error(`Timed out waiting for ${mode}`);
}

async function connectedClient(username: string): Promise<Client> {
  const parsed = new URL(databaseURL);
  parsed.username = username;
  parsed.password = "";
  const client = new Client({ connectionString: parsed.toString() });
  await client.connect();
  return client;
}

function quoteIdentifier(value: string): string {
  return `"${value.replaceAll('"', '""')}"`;
}

function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function genericFailureMessage(): string {
  return "Production migration 0017 execution failed";
}

function validatedLocalDatabaseURL(): string {
  if (process.env.REFWATCH_ALLOW_LOCAL_DATABASE_TESTS !== "1") {
    throw new Error("Migration 0017 database tests require the explicit local-test gate");
  }
  const value = process.env.REFWATCH_MIGRATION_0017_LOCAL_DATABASE_URL;
  if (!value) {
    throw new Error("REFWATCH_MIGRATION_0017_LOCAL_DATABASE_URL is required");
  }
  const parsed = new URL(value);
  if (
    !["127.0.0.1", "localhost", "::1"].includes(parsed.hostname)
    || parsed.pathname !== "/postgres"
  ) {
    throw new Error("Migration 0017 tests require the isolated loopback postgres database");
  }
  return value;
}
