import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { Client } from "pg";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  createProductionGreenfieldIdentityActivationReceipt,
  loadProductionGreenfieldIdentityActivationSources,
  renderProductionGreenfieldIdentityActivationSQL,
  runProductionGreenfieldIdentityActivationSession,
  validateProductionGreenfieldIdentityActivationReadback,
  type ProductionGreenfieldIdentityActivationReadback,
} from "../scripts/activate-production-greenfield-identity.mjs";
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
const sessionRole = "refwatch_identity_activation_admin";
let activationSQL = "";

beforeAll(async () => {
  const source = await loadProductionGreenfieldIdentityActivationSources();
  activationSQL = renderProductionGreenfieldIdentityActivationSQL(source);
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
  await rebuildProduction0016Database();
}, 30_000);

describe("production greenfield identity activation disposable PostgreSQL rehearsal", () => {
  it("activates once and preserves the same immutable database rows on retry", async () => {
    const first = await runActivation();
    const firstState = await readIdentityState();
    const retry = await runActivation();
    const retryState = await readIdentityState();

    expect(first.operation).toBe("activated");
    expect(retry.operation).toBe("idempotent_retry");
    expect(firstState).toEqual(retryState);
    expect(firstState).toMatchObject({
      receipt_count: "1",
      activation_count: "1",
      receipt_digest: greenfieldIdentityReceiptDigest,
      clerk_instance_id: productionClerk.instanceId,
    });
    expect(firstState.receipt_id).toBe(first.identity_receipt.id);
    expect(firstState.receipt_activated_at).toBe(
      first.identity_receipt.activated_at_utc,
    );
    expect(firstState.activation_activated_at).toBe(
      first.identity_activation.activated_at_utc,
    );
    expect(firstState.submillisecond_microseconds).toBe("0");
    expect(retry.identity_receipt).toEqual(first.identity_receipt);
    expect(retry.identity_activation).toEqual(first.identity_activation);
  });

  it("accepts only exact history-sequence representations whose next value is 18", async () => {
    const productionEquivalent = await connectedClient("postgres");
    try {
      await productionEquivalent.query(
        "select setval('drizzle.__drizzle_migrations_id_seq', 17, true)",
      );
    } finally {
      await productionEquivalent.end();
    }

    const receipt = await runActivation();
    expect(receipt.operation).toBe("activated");
    expect(receipt).toMatchObject({
      verified_state: {
        history_sequence: {
          data_type: "integer",
          start_value: 1,
          minimum_value: 1,
          maximum_value: 2_147_483_647,
          increment_by: 1,
          cache_size: 1,
          cycle: false,
          last_value: 17,
          is_called: true,
          next_value: 18,
        },
      },
    });
    expect(await identityCounts()).toEqual({ receipts: "1", activations: "1" });

    await rebuildProduction0016Database();
    const notCalled = await connectedClient("postgres");
    try {
      await notCalled.query(
        "select setval('drizzle.__drizzle_migrations_id_seq', 17, false)",
      );
    } finally {
      await notCalled.end();
    }
    const notCalledBefore = await readHistorySequenceState();
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });
    expect(await readHistorySequenceState()).toEqual(notCalledBefore);

    await rebuildProduction0016Database();
    const advanced = await connectedClient("postgres");
    try {
      await advanced.query(
        "select setval('drizzle.__drizzle_migrations_id_seq', 18, true)",
      );
    } finally {
      await advanced.end();
    }

    const advancedBefore = await readHistorySequenceState();
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });
    expect(await readHistorySequenceState()).toEqual(advancedBefore);

    await rebuildProduction0016Database();
    const parameterDrift = await connectedClient("postgres");
    try {
      await parameterDrift.query(
        "alter sequence drizzle.__drizzle_migrations_id_seq cache 2",
      );
    } finally {
      await parameterDrift.end();
    }
    const parameterDriftBefore = await readHistorySequenceState();
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });
    expect(await readHistorySequenceState()).toEqual(parameterDriftBefore);
  });

  it("rejects partial or conflicting receipt and activation state", async () => {
    const client = await connectedClient("postgres");
    try {
      await insertExactReceipt(client);
    } finally {
      await client.end();
    }
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "1", activations: "0" });

    await rebuildProduction0016Database();
    const foreignReceipt = await connectedClient("postgres");
    try {
      await foreignReceipt.query(
        `insert into identity_reconciliation_receipts (
           receipt_digest,
           clerk_instance_id,
           snapshot_captured_at,
           legacy_mapping_count,
           excluded_auth_count,
           mapping_hash,
           status,
           reviewed_at
         ) values ($1, 'ins_conflicting', now(), 1, 0, $2, 'verified', now())`,
        ["c".repeat(64), "b".repeat(64)],
      );
    } finally {
      await foreignReceipt.end();
    }
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "1", activations: "0" });

    await rebuildProduction0016Database();
    const conflicting = await connectedClient("postgres");
    try {
      await conflicting.query("set session_replication_role = replica");
      await conflicting.query(
        `insert into identity_reconciliation_activations
           (receipt_digest, clerk_instance_id)
         values ($1, $2)`,
        ["f".repeat(64), "ins_conflicting"],
      );
      await conflicting.query("set session_replication_role = origin");
    } finally {
      await conflicting.end();
    }
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "1" });
  });

  it("rejects nonzero application data atomically", async () => {
    const client = await connectedClient("postgres");
    try {
      await client.query(
        `insert into app_users (clerk_user_id, email)
         values ('user_preexisting', 'preexisting@example.invalid')`,
      );
    } finally {
      await client.end();
    }

    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });
    expect(await scalarCount("app_users")).toBe("1");
  });

  it("rejects unexpected mapping, tombstone, and webhook receipt state", async () => {
    const mappingClient = await connectedClient("postgres");
    try {
      await mappingClient.query("set session_replication_role = replica");
      await mappingClient.query(
        `insert into identity_reconciliation_legacy_mappings (
           clerk_instance_id,
           clerk_user_id,
           app_user_id,
           receipt_digest
         ) values ($1, 'user_mapping', gen_random_uuid(), $2)`,
        [productionClerk.instanceId, "e".repeat(64)],
      );
      await mappingClient.query("set session_replication_role = origin");
    } finally {
      await mappingClient.end();
    }
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });

    await rebuildProduction0016Database();
    const tombstoneClient = await connectedClient("postgres");
    try {
      await tombstoneClient.query(
        `insert into clerk_user_deletion_tombstones (
           clerk_instance_id,
           clerk_user_id,
           deleted_at
         ) values ($1, 'user_deleted', now())`,
        [productionClerk.instanceId],
      );
    } finally {
      await tombstoneClient.end();
    }
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });

    await rebuildProduction0016Database();
    const webhookClient = await connectedClient("postgres");
    try {
      await webhookClient.query(
        `insert into clerk_webhook_delivery_receipts (
           clerk_instance_id,
           svix_id,
           event_type,
           clerk_user_id,
           payload_hash
         ) values ($1, 'msg_unexpected', 'user.created', 'user_webhook', $2)`,
        [productionClerk.instanceId, "d".repeat(64)],
      );
    } finally {
      await webhookClient.end();
    }
    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });
  });

  it("rejects active ledger state without inserting identity control rows", async () => {
    const client = await connectedClient("postgres");
    try {
      await client.query(
        `insert into mutation_ledger_epochs (
           status,
           capture_enforced,
           baseline_snapshot_id,
           baseline_schema_hash,
           baseline_data_hash
         ) values ('preparing', false, 'unexpected', $1, $2)`,
        ["a".repeat(64), "b".repeat(64)],
      );
    } finally {
      await client.end();
    }

    await expect(runActivation()).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });
    expect(await scalarCount("mutation_ledger_epochs")).toBe("1");
  });

  it("keeps a concurrent application write outside the locked bootstrap window", async () => {
    const blocker = await connectedClient("postgres");
    const observer = await connectedClient("postgres");
    const writer = await connectedClient("postgres");
    try {
      await blocker.query("begin");
      await blocker.query(
        "lock table workout_sessions in access exclusive mode",
      );
      const activation = runActivation();
      await waitForLock(observer, "app_users", "ShareRowExclusiveLock", true);

      let writerCompleted = false;
      const applicationWrite = writer.query(
        `insert into app_users (clerk_user_id, email)
         values ('user_concurrent', 'concurrent@example.invalid')`,
      ).then(() => {
        writerCompleted = true;
      });
      await waitForLock(observer, "app_users", "RowExclusiveLock", false);
      expect(writerCompleted).toBe(false);

      await blocker.query("commit");
      const receipt = await activation;
      await applicationWrite;

      expect(receipt.operation).toBe("activated");
      expect(writerCompleted).toBe(true);
      expect(await scalarCount("app_users")).toBe("1");
      expect(await identityCounts()).toEqual({ receipts: "1", activations: "1" });
    } finally {
      await blocker.query("rollback").catch(() => undefined);
      await Promise.all([blocker.end(), observer.end(), writer.end()]);
    }
  });

  it("pins public resolution even when the inherited search path is shadowed", async () => {
    const client = await connectedClient("postgres");
    try {
      await client.query("create schema shadow authorization postgres");
      await client.query("create table shadow.app_users (marker text not null)");
      await client.query("insert into shadow.app_users values ('unexpected')");
    } finally {
      await client.end();
    }

    const receipt = await runActivation({
      sqlPrefix: "set search_path = shadow, public;",
    });
    expect(receipt.operation).toBe("activated");
    expect(await scalarCount("app_users")).toBe("0");
    expect(await identityCounts()).toEqual({ receipts: "1", activations: "1" });
  });

  it("fails atomically when inherited replication mode disables triggers", async () => {
    await expect(runActivation({
      username: "postgres",
      sqlPrefix: "set session_replication_role = replica;",
    })).rejects.toThrow(genericFailureMessage());
    expect(await identityCounts()).toEqual({ receipts: "0", activations: "0" });
  });
});

async function runActivation(options: {
  username?: string;
  sqlPrefix?: string;
} = {}) {
  const readback = await runProductionGreenfieldIdentityActivationSession(
    localSessionSpecification(options),
    validateProductionGreenfieldIdentityActivationReadback,
  );
  return createProductionGreenfieldIdentityActivationReceipt(
    readback,
  ) as ProductionGreenfieldIdentityActivationReadback & {
    operation: string;
    identity_receipt: Record<string, string>;
    identity_activation: Record<string, string>;
  };
}

function localSessionSpecification(options: {
  username?: string;
  sqlPrefix?: string;
} = {}) {
  const parsed = new URL(databaseURL);
  const environment = { ...process.env };
  delete environment.PGPASSWORD;
  delete environment.PGSERVICE;
  delete environment.PGSERVICEFILE;
  delete environment.PGOPTIONS;
  environment.PGHOST = parsed.hostname;
  environment.PGPORT = parsed.port;
  environment.PGDATABASE = decodeURIComponent(parsed.pathname.slice(1));
  environment.PGUSER = options.username ?? sessionRole;
  environment.PGSSLMODE = parsed.searchParams.get("sslmode") ?? "disable";
  environment.PSQLRC = "/dev/null";
  environment.PSQL_HISTORY = "/dev/null";
  return {
    command: "psql",
    args: ["-X", "--no-psqlrc"],
    sql: options.sqlPrefix
      ? `${options.sqlPrefix}\n${activationSQL}`
      : activationSQL,
    environment,
  };
}

async function rebuildProduction0016Database(): Promise<void> {
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
    const journal = JSON.parse(
      await readFile(
        new URL("../src/db/migrations/meta/_journal.json", import.meta.url),
        "utf8",
      ),
    );
    for (const entry of journal.entries.slice(
      0,
      productionMigration0016Contract.target.migrationCount,
    )) {
      const migrationSQL = await readFile(
        new URL(`../src/db/migrations/${entry.tag}.sql`, import.meta.url),
        "utf8",
      );
      const statements = migrationSQL
        .split("--> statement-breakpoint")
        .filter((statement) => statement.trim().length > 0);
      await client.query("begin");
      try {
        for (const statement of statements) await client.query(statement);
        await client.query(
          `insert into drizzle.__drizzle_migrations (hash, created_at)
           values ($1, $2)`,
          [sha256Hex(migrationSQL), entry.when],
        );
        await client.query("commit");
      } catch (error) {
        await client.query("rollback");
        throw error;
      }
    }
    await client.query(
      `alter sequence drizzle.__drizzle_migrations_id_seq restart with 18`,
    );
    await client.query(
      `insert into runtime_database_markers (marker, branch_id, environment)
       values ($1, $2, 'production')`,
      [productionDatabase.runtimeMarker, productionDatabase.branchId],
    );
  } finally {
    await client.end();
  }
}

async function insertExactReceipt(client: Client): Promise<void> {
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
     ) values ($1, $2, now(), 0, 0, $3, 'verified', now(), now(),
       $4, $5, $6, $7, $8)`,
    [
      greenfieldIdentityReceiptDigest,
      productionClerk.instanceId,
      greenfieldEmptyMappingHash,
      greenfieldIdentityProfile,
      greenfieldAuthorizationProfile,
      greenfieldAuthorizationDigest,
      productionClerk.issuer,
      productionClerk.domain,
    ],
  );
}

async function readIdentityState() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query<{
      receipt_count: string;
      activation_count: string;
      receipt_id: string;
      receipt_digest: string;
      clerk_instance_id: string;
      receipt_activated_at: string;
      activation_activated_at: string;
      submillisecond_microseconds: string;
    }>(`
      select
        (select count(*)::text from identity_reconciliation_receipts)
          as receipt_count,
        (select count(*)::text from identity_reconciliation_activations)
          as activation_count,
        receipts.id::text as receipt_id,
        receipts.receipt_digest,
        receipts.clerk_instance_id,
        to_char(
          receipts.activated_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
        ) as receipt_activated_at,
        to_char(
          activations.activated_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
        ) as activation_activated_at,
        mod(
          extract(microseconds from receipts.activated_at)::bigint,
          1000
        )::text as submillisecond_microseconds
      from identity_reconciliation_receipts receipts
      join identity_reconciliation_activations activations
        using (receipt_digest, clerk_instance_id)
    `);
    return result.rows[0];
  } finally {
    await client.end();
  }
}

async function identityCounts() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query<{
      receipts: string;
      activations: string;
    }>(`
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

async function readHistorySequenceState() {
  const client = await connectedClient("postgres");
  try {
    const result = await client.query<{
      data_type: string;
      start_value: string;
      minimum_value: string;
      maximum_value: string;
      increment_by: string;
      cache_size: string;
      cycle: boolean;
      last_value: string;
      is_called: boolean;
    }>(`
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
  return "Production greenfield identity activation execution failed";
}

function validatedLocalDatabaseURL(): string {
  if (process.env.REFWATCH_ALLOW_LOCAL_DATABASE_TESTS !== "1") {
    throw new Error(
      "Local identity activation tests require the explicit local-test gate",
    );
  }
  const value = process.env.REFWATCH_IDENTITY_ACTIVATION_LOCAL_DATABASE_URL;
  if (!value) {
    throw new Error("REFWATCH_IDENTITY_ACTIVATION_LOCAL_DATABASE_URL is required");
  }
  const parsed = new URL(value);
  if (
    !["127.0.0.1", "localhost", "::1"].includes(parsed.hostname)
    || parsed.pathname !== "/postgres"
  ) {
    throw new Error(
      "Identity activation tests require the isolated loopback postgres database",
    );
  }
  return value;
}
