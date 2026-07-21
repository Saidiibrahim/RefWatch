import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { Client } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  productionMigration0016Contract,
  renderProductionMigration0016,
  type ProductionMigration0016Source,
} from "../scripts/apply-production-migration-0016.mjs";

const baseDatabaseURL = validatedLocalDatabaseURL();
const migrationRole = "refwatch_migration_0016_admin";
const databaseNames = {
  success: "refwatch_migration_0016_success",
  preconditionFailure: "refwatch_migration_0016_precondition_failure",
  statementFailure: "refwatch_migration_0016_statement_failure",
  postflightFailure: "refwatch_migration_0016_postflight_failure",
} as const;
let renderedMigration = "";

beforeAll(async () => {
  const source = await migrationSource();
  renderedMigration = renderProductionMigration0016(source);

  const maintenance = new Client({
    connectionString: databaseURL("postgres", "postgres"),
  });
  await maintenance.connect();
  try {
    for (const databaseName of Object.values(databaseNames)) {
      await terminateDatabaseConnections(maintenance, databaseName);
      await maintenance.query(`drop database if exists ${quoteIdentifier(databaseName)}`);
    }
    await maintenance.query(`
      do $$
      begin
        if not exists (select 1 from pg_roles where rolname = '${migrationRole}') then
          create role ${quoteIdentifier(migrationRole)} login;
        end if;
      end
      $$;
    `);
    await maintenance.query(
      `grant ${quoteIdentifier("postgres")} to ${quoteIdentifier(migrationRole)}`,
    );
    for (const databaseName of Object.values(databaseNames)) {
      await maintenance.query(`create database ${quoteIdentifier(databaseName)}`);
      await applyBaselineThrough0015(databaseName);
    }
  } finally {
    await maintenance.end();
  }

  const preconditionClient = await connectedClient(
    databaseNames.preconditionFailure,
  );
  try {
    await preconditionClient.query(
      `update drizzle.__drizzle_migrations
       set hash = repeat('0', 64)
       where id = $1`,
      [productionMigration0016Contract.previous.historyId],
    );
  } finally {
    await preconditionClient.end();
  }

  const statementFailureClient = await connectedClient(
    databaseNames.statementFailure,
  );
  try {
    await statementFailureClient.query(`
      create function public.protect_clerk_webhook_delivery_receipt()
      returns trigger
      language plpgsql
      as $$
      begin
        return new;
      end;
      $$;
    `);
  } finally {
    await statementFailureClient.end();
  }

}, 30_000);

afterAll(async () => {
  const maintenance = new Client({
    connectionString: databaseURL("postgres", "postgres"),
  });
  await maintenance.connect();
  try {
    for (const databaseName of Object.values(databaseNames)) {
      await terminateDatabaseConnections(maintenance, databaseName);
      await maintenance.query(`drop database if exists ${quoteIdentifier(databaseName)}`);
    }
    await maintenance.query(
      `drop role if exists ${quoteIdentifier(migrationRole)}`,
    );
  } finally {
    await maintenance.end();
  }
});

describe("production migration 0016 disposable PostgreSQL rehearsal", () => {
  it("applies SQL and Drizzle history atomically under stable postgres ownership", async () => {
    const result = runRenderedMigration(databaseNames.success);
    expect(result.status, "sanitized psql exit status").toBe(0);

    const client = await connectedClient(databaseNames.success);
    try {
      const history = await client.query<{
        migration_count: string;
        head_id: number;
        head_hash: string;
        head_created_at: string;
        history_md5: string;
        sequence_last_value: string;
        sequence_is_called: boolean;
      }>(`
        select
          count(*)::text as migration_count,
          (array_agg(id order by id desc))[1] as head_id,
          (array_agg(hash order by id desc))[1] as head_hash,
          (array_agg(created_at order by id desc))[1]::text as head_created_at,
          md5(string_agg(id::text || ':' || hash, ',' order by id)) as history_md5,
          (
            select last_value::text
            from drizzle.__drizzle_migrations_id_seq
          ) as sequence_last_value,
          (
            select is_called
            from drizzle.__drizzle_migrations_id_seq
          ) as sequence_is_called
        from drizzle.__drizzle_migrations
      `);
      expect(history.rows[0]).toEqual({
        migration_count: "17",
        head_id: productionMigration0016Contract.target.historyId,
        head_hash: productionMigration0016Contract.target.fileSha256,
        head_created_at: String(
          productionMigration0016Contract.target.journalTimestamp,
        ),
        history_md5:
          productionMigration0016Contract.target.migrationHistoryMd5,
        sequence_last_value: String(
          productionMigration0016Contract.historySequence.targetRestartWith,
        ),
        sequence_is_called:
          productionMigration0016Contract.historySequence.targetIsCalled,
      });

      const ownership = await client.query<{
        table_owner: string;
        touched_function_count: string;
        touched_function_owners: string;
        non_postgres_public_object_count: string;
      }>(`
        select
          (
            select pg_get_userbyid(relation.relowner)
            from pg_class relation
            join pg_namespace namespace
              on namespace.oid = relation.relnamespace
            where namespace.nspname = 'public'
              and relation.relname = $1
              and relation.relkind in ('r', 'p')
          ) as table_owner,
          (
            select count(*)::text
            from pg_proc procedure_definition
            join pg_namespace namespace
              on namespace.oid = procedure_definition.pronamespace
            where namespace.nspname = 'public'
              and procedure_definition.proname = any($2::text[])
          ) as touched_function_count,
          (
            select array_agg(
              distinct pg_get_userbyid(procedure_definition.proowner)
              order by pg_get_userbyid(procedure_definition.proowner)
            )
            from pg_proc procedure_definition
            join pg_namespace namespace
              on namespace.oid = procedure_definition.pronamespace
            where namespace.nspname = 'public'
              and procedure_definition.proname = any($2::text[])
          ) as touched_function_owners,
          (
            select (
              select count(*)
              from pg_class relation
              join pg_namespace namespace
                on namespace.oid = relation.relnamespace
              where namespace.nspname = 'public'
                and relation.relkind in ('r', 'p', 'S')
                and pg_get_userbyid(relation.relowner) <> 'postgres'
            ) + (
              select count(*)
              from pg_proc procedure_definition
              join pg_namespace namespace
                on namespace.oid = procedure_definition.pronamespace
              where namespace.nspname = 'public'
                and pg_get_userbyid(procedure_definition.proowner) <> 'postgres'
            )
          )::text as non_postgres_public_object_count
      `, [
        productionMigration0016Contract.target.tableName,
        productionMigration0016Contract.target.functionNames,
      ]);
      expect(ownership.rows[0]).toEqual({
        table_owner: "postgres",
        touched_function_count: String(
          productionMigration0016Contract.target.functionNames.length,
        ),
        touched_function_owners: "{postgres}",
        non_postgres_public_object_count: "0",
      });
    } finally {
      await client.end();
    }
  });

  it("changes nothing when the exact 0015 history precondition fails", async () => {
    const result = runRenderedMigration(databaseNames.preconditionFailure);
    expect(result.status, "sanitized psql exit status").not.toBe(0);

    const state = await readFailureState(databaseNames.preconditionFailure);
    expect(state).toMatchObject({
      migration_count: "16",
      head_hash: "0".repeat(64),
      target_table: null,
      sequence_last_value: "16",
      sequence_is_called: true,
    });
  });

  it("rolls back earlier DDL and history when a migration statement fails", async () => {
    const result = runRenderedMigration(databaseNames.statementFailure);
    expect(result.status, "sanitized psql exit status").not.toBe(0);

    const state = await readFailureState(databaseNames.statementFailure);
    expect(state).toMatchObject({
      migration_count: "16",
      head_hash: productionMigration0016Contract.previous.fileSha256,
      target_table: null,
      sequence_last_value: "16",
      sequence_is_called: true,
    });
  });

  it("rolls back DDL, history, and sequence restart so a postflight failure can retry", async () => {
    const injectedPostflightFailure = renderedMigration.replace(
      "DO $refwatch_postflight$",
      `ALTER SEQUENCE "drizzle"."__drizzle_migrations_id_seq"
       RESTART WITH 19;
DO $refwatch_postflight$`,
    );
    expect(injectedPostflightFailure).not.toBe(renderedMigration);

    const result = runRenderedMigration(
      databaseNames.postflightFailure,
      injectedPostflightFailure,
    );
    expect(result.status, "sanitized psql exit status").not.toBe(0);

    const state = await readFailureState(databaseNames.postflightFailure);
    expect(state).toMatchObject({
      migration_count: "16",
      head_hash: productionMigration0016Contract.previous.fileSha256,
      target_table: null,
      sequence_last_value: "16",
      sequence_is_called: true,
    });

    const retry = runRenderedMigration(databaseNames.postflightFailure);
    expect(retry.status, "sanitized retry psql exit status").toBe(0);
    const retryState = await readFailureState(databaseNames.postflightFailure);
    expect(retryState).toMatchObject({
      migration_count: "17",
      head_hash: productionMigration0016Contract.target.fileSha256,
      target_table: productionMigration0016Contract.target.tableName,
      sequence_last_value: "18",
      sequence_is_called: false,
    });
  });
});

async function migrationSource(): Promise<ProductionMigration0016Source> {
  const [journalText, previousMigrationSql, targetMigrationSql] =
    await Promise.all([
      readFile(
        new URL("../src/db/migrations/meta/_journal.json", import.meta.url),
        "utf8",
      ),
      readFile(
        new URL(
          `../src/db/migrations/${productionMigration0016Contract.previous.tag}.sql`,
          import.meta.url,
        ),
        "utf8",
      ),
      readFile(
        new URL(
          `../src/db/migrations/${productionMigration0016Contract.target.tag}.sql`,
          import.meta.url,
        ),
        "utf8",
      ),
    ]);
  return { journalText, previousMigrationSql, targetMigrationSql };
}

async function applyBaselineThrough0015(databaseName: string): Promise<void> {
  const journal = JSON.parse(
    await readFile(
      new URL("../src/db/migrations/meta/_journal.json", import.meta.url),
      "utf8",
    ),
  );
  const client = await connectedClient(databaseName);
  try {
    await client.query("create schema drizzle");
    await client.query(`
      create table drizzle.__drizzle_migrations (
        id serial primary key,
        hash text not null,
        created_at bigint
      )
    `);

    for (const entry of journal.entries.slice(
      0,
      productionMigration0016Contract.previous.migrationCount,
    )) {
      const migrationSql = await readFile(
        new URL(`../src/db/migrations/${entry.tag}.sql`, import.meta.url),
        "utf8",
      );
      const statements = migrationSql
        .split("--> statement-breakpoint")
        .filter((statement) => statement.trim().length > 0);
      await client.query("begin");
      try {
        for (const statement of statements) {
          await client.query(statement);
        }
        await client.query(
          `insert into drizzle.__drizzle_migrations (hash, created_at)
           values ($1, $2)`,
          [sha256Hex(migrationSql), entry.when],
        );
        await client.query("commit");
      } catch (error) {
        await client.query("rollback");
        throw error;
      }
    }

    await client.query(
      `insert into public.runtime_database_markers
         (marker, branch_id, environment)
       values ($1, $2, 'production')`,
      [
        productionMigration0016Contract.runtimeMarker,
        productionMigration0016Contract.branchId,
      ],
    );
  } finally {
    await client.end();
  }
}

function runRenderedMigration(
  databaseName: string,
  migrationSQL = renderedMigration,
) {
  const parsed = new URL(databaseURL(databaseName, migrationRole));
  const env = { ...process.env };
  delete env.PGPASSWORD;
  delete env.PGSERVICE;
  delete env.PGSERVICEFILE;
  delete env.PGOPTIONS;
  env.PGHOST = parsed.hostname;
  env.PGPORT = parsed.port;
  env.PGDATABASE = decodeURIComponent(parsed.pathname.slice(1));
  env.PGUSER = decodeURIComponent(parsed.username);
  env.PGSSLMODE = parsed.searchParams.get("sslmode") ?? "disable";

  return spawnSync("psql", ["-X", "--no-psqlrc"], {
    input: migrationSQL,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    stdio: ["pipe", "pipe", "pipe"],
    env,
  });
}

async function readFailureState(databaseName: string) {
  const client = await connectedClient(databaseName);
  try {
    const result = await client.query<{
      migration_count: string;
      head_hash: string;
      target_table: string | null;
      sequence_last_value: string;
      sequence_is_called: boolean;
    }>(`
      select
        (select count(*)::text from drizzle.__drizzle_migrations)
          as migration_count,
        (
          select hash
          from drizzle.__drizzle_migrations
          order by id desc
          limit 1
        ) as head_hash,
        to_regclass($1)::text as target_table,
        (
          select last_value::text
          from drizzle.__drizzle_migrations_id_seq
        ) as sequence_last_value,
        (
          select is_called
          from drizzle.__drizzle_migrations_id_seq
        ) as sequence_is_called
    `, [`public.${productionMigration0016Contract.target.tableName}`]);
    return result.rows[0];
  } finally {
    await client.end();
  }
}

async function connectedClient(databaseName: string): Promise<Client> {
  const client = new Client({
    connectionString: databaseURL(databaseName, "postgres"),
  });
  await client.connect();
  return client;
}

async function terminateDatabaseConnections(
  client: Client,
  databaseName: string,
): Promise<void> {
  await client.query(
    `select pg_terminate_backend(pid)
     from pg_stat_activity
     where datname = $1
       and pid <> pg_backend_pid()`,
    [databaseName],
  );
}

function databaseURL(databaseName: string, username: string): string {
  const parsed = new URL(baseDatabaseURL);
  parsed.username = username;
  parsed.password = "";
  parsed.pathname = `/${databaseName}`;
  return parsed.toString();
}

function quoteIdentifier(value: string): string {
  return `"${value.replaceAll('"', '""')}"`;
}

function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function validatedLocalDatabaseURL(): string {
  if (process.env.REFWATCH_ALLOW_LOCAL_DATABASE_TESTS !== "1") {
    throw new Error(
      "Local database integration tests require the explicit local-test gate",
    );
  }
  const value = process.env.REFWATCH_LOCAL_DATABASE_URL;
  if (!value) throw new Error("REFWATCH_LOCAL_DATABASE_URL is required");
  const parsed = new URL(value);
  if (!["127.0.0.1", "localhost", "::1"].includes(parsed.hostname)) {
    throw new Error(
      "Local database integration tests require a loopback database",
    );
  }
  return value;
}
