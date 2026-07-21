import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "../src/db/schema";
import {
  appUsers,
  mutationLedgerEpochs,
  mutationOutboxDeliveries,
  mutationOutboxEvents,
  pages,
  teams,
} from "../src/db/schema";
import {
  freezeMutationLedgerEpoch,
  openMutationLedgerEpoch,
  withMutation,
} from "../src/services/mutationLedger";
import {
  claimPendingDeliveries,
  processLedgerMessage,
  recordLedgerDeliveryFailure,
} from "../src/services/mutationLedgerDelivery";

const expectedDisposableBranchId = "ng9tgmy4pyi5";
const databaseURL = validatedIntegrationDatabaseURL();
const epochId = crypto.randomUUID();
const ownerId = crypto.randomUUID();
const teamId = crypto.randomUUID();
const rejectedOwnerId = crypto.randomUUID();
const lateOwnerId = crypto.randomUUID();
const poisonOwnerId = crypto.randomUUID();
const metadataOwnerId = crypto.randomUUID();
const oversizedPageId = crypto.randomUUID();
const expectedCaptureTriggers = [
  "ai_attachments", "ai_messages", "ai_threads", "ai_usage_daily", "app_users",
  "clerk_user_deletion_tombstones", "clerk_webhook_delivery_receipts", "competitions",
  "match_assessments", "match_events", "match_metrics", "match_periods", "matches", "pages",
  "scheduled_matches", "team_members", "team_officials", "team_tags", "teams", "user_devices",
  "venues", "workout_presets", "workout_sessions",
].map((table) => `${table}_mutation_capture`).sort();

describe("database-enforced mutation ledger", () => {
  const pool = new Pool({ connectionString: databaseURL, max: 5 });
  const db = drizzle(pool, { schema });

  beforeAll(async () => {
    await cleanup(pool);
    await db.insert(mutationLedgerEpochs).values({
      id: epochId,
      baselineSnapshotId: "integration-baseline",
      baselineSchemaHash: "a".repeat(64),
      baselineDataHash: "b".repeat(64),
    });
    expect(await openMutationLedgerEpoch(db, epochId)).toBe(true);
  });

  afterAll(async () => {
    await cleanup(pool);
    await pool.end();
  });

  it("rejects direct domain SQL without capture context", async () => {
    await expect(db.insert(appUsers).values({
      id: rejectedOwnerId,
      clerkUserId: "ledger_direct_sql_rejected",
    })).rejects.toThrow(/Failed query/);
    expect(await db.select().from(appUsers).where(eq(appUsers.id, rejectedOwnerId))).toHaveLength(0);
  });

  it("has the complete effective capture-trigger catalog in migrated PostgreSQL", async () => {
    const result = await pool.query(`
      select distinct trigger_name
      from information_schema.triggers
      where trigger_schema = 'public' and trigger_name like '%\\_mutation\\_capture' escape '\\'
      order by trigger_name
    `);
    expect(result.rows.map((row) => row.trigger_name)).toEqual(expectedCaptureTriggers);
  });

  it("captures complete same-transaction row images and delivery rows", async () => {
    await withMutation(db, {
      sourceKind: "http",
      requestId: "ledger-request-1",
      workerVersionId: "44444444-4444-4444-8444-444444444444",
      appUserId: ownerId,
      method: "POST",
      path: "/api/teams",
      idempotencyKey: "team:create:integration",
      actorId: "clerk_integration_owner",
    }, async (tx) => {
      await tx.insert(appUsers).values({
        id: ownerId,
        clerkUserId: "ledger_integration_owner",
      });
      await tx.insert(teams).values({ id: teamId, ownerId, name: "Ledger Team" });
    });

    const events = await db.select().from(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.epochId, epochId))
      .orderBy(mutationOutboxEvents.groupOrdinal);
    expect(events).toHaveLength(2);
    expect(events.map((event) => event.groupOrdinal)).toEqual([1, 2]);
    expect(new Set(events.map((event) => event.mutationGroupId)).size).toBe(1);
    expect(events.map((event) => event.tableName)).toEqual(["app_users", "teams"]);
    expect(events[0]).toMatchObject({
      operation: "insert",
      beforeJSON: null,
      sourceKind: "http",
      requestId: "ledger-request-1",
      method: "POST",
      path: "/api/teams",
    });
    expect(events[0]?.afterJSON).toMatchObject({ id: ownerId, clerk_user_id: "ledger_integration_owner" });
    const deliveries = await db.select({ id: mutationOutboxDeliveries.eventId })
      .from(mutationOutboxDeliveries)
      .innerJoin(mutationOutboxEvents, eq(mutationOutboxDeliveries.eventId, mutationOutboxEvents.eventId))
      .where(eq(mutationOutboxEvents.epochId, epochId));
    expect(deliveries).toHaveLength(2);
  });

  it("rolls the domain mutation back when capture cannot be inserted", async () => {
    await expect(withMutation(db, {
      sourceKind: "http",
      requestId: "ledger-request-invalid",
      workerVersionId: "",
      appUserId: lateOwnerId,
      method: "POST",
      path: "/api/teams",
    }, async (tx) => {
      await tx.insert(appUsers).values({ id: lateOwnerId, clerkUserId: "ledger_invalid_context" });
    })).rejects.toThrow(/Failed query/);
    expect(await db.select().from(appUsers).where(eq(appUsers.id, lateOwnerId))).toHaveLength(0);
    expect(await db.select().from(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.requestId, "ledger-request-invalid"))).toHaveLength(0);
  });

  it("rolls back insert and update mutations that cannot fit the delivery envelope", async () => {
    await expect(withMutation(db, {
      sourceKind: "admin",
      requestId: "ledger-oversized-insert",
      workerVersionId: "44444444-4444-4444-8444-444444444444",
      actorId: "integration-admin",
    }, async (tx) => {
      await tx.insert(pages).values({
        id: oversizedPageId,
        ownerId,
        pageType: "general_note",
        contentText: "x".repeat(250 * 1_024),
      });
    })).rejects.toThrow(/Failed query/);
    expect(await db.select().from(pages).where(eq(pages.id, oversizedPageId))).toHaveLength(0);

    await expect(withMutation(db, {
      sourceKind: "admin",
      requestId: "ledger-oversized-update",
      workerVersionId: "44444444-4444-4444-8444-444444444444",
      actorId: "integration-admin",
    }, async (tx) => {
      await tx.update(teams).set({ name: "x".repeat(250 * 1_024) })
        .where(eq(teams.id, teamId));
    })).rejects.toThrow(/Failed query/);
    const [team] = await db.select({ name: teams.name }).from(teams).where(eq(teams.id, teamId));
    expect(team?.name).toBe("Ledger Team");
    expect(await db.select().from(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.requestId, "ledger-oversized-update"))).toHaveLength(0);
  });

  it("fences a stale consumer and reuses ciphertext after D1 success before PG acknowledgement", async () => {
    const claimed = await claimPendingDeliveries(db, 10, 30, epochId);
    expect(claimed).toHaveLength(2);
    const [first, crashMessage] = claimed;
    if (!first || !crashMessage) throw new Error("missing claimed delivery fixtures");
    const d1 = new FakeD1();
    const keyBase64 = btoa(String.fromCharCode(...new Uint8Array(32).fill(7)));
    const encryption = {
      currentKeyBase64: keyBase64,
      currentKeyId: "integration-key-1",
      decryptionKeys: { "integration-key-1": keyBase64 },
    };
    await expect(processLedgerMessage(db, d1 as unknown as D1Database, first, encryption)).resolves.toBe("delivered");

    d1.failNextRead = true;
    await expect(processLedgerMessage(db, d1 as unknown as D1Database, crashMessage, encryption))
      .rejects.toThrow(/simulated post-D1 crash/);
    const [afterCrash] = await db.select().from(mutationOutboxDeliveries)
      .where(eq(mutationOutboxDeliveries.eventId, crashMessage.eventId));
    expect(afterCrash).toMatchObject({ state: "leased", leaseGeneration: crashMessage.leaseGeneration });
    expect(afterCrash?.encryptedEnvelope).toBeTruthy();
    const persistedCiphertext = afterCrash?.encryptedEnvelope;

    await db.update(mutationOutboxDeliveries).set({
      leasedUntil: new Date(Date.now() - 1_000),
      nextAttemptAt: new Date(Date.now() - 1_000),
    }).where(eq(mutationOutboxDeliveries.eventId, crashMessage.eventId));
    const [retryMessage] = await claimPendingDeliveries(db, 10, 30, epochId);
    expect(retryMessage?.eventId).toBe(crashMessage.eventId);
    expect(retryMessage?.leaseGeneration).toBe(crashMessage.leaseGeneration + 1);
    const rotatedKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(8)));
    const rotatedEncryption = {
      currentKeyBase64: rotatedKey,
      currentKeyId: "integration-key-2",
      decryptionKeys: { "integration-key-1": keyBase64, "integration-key-2": rotatedKey },
    };
    await expect(processLedgerMessage(db, d1 as unknown as D1Database, crashMessage, rotatedEncryption)).resolves.toBe("stale");
    if (!retryMessage) throw new Error("missing retry delivery fixture");
    await expect(processLedgerMessage(db, d1 as unknown as D1Database, retryMessage, rotatedEncryption)).resolves.toBe("delivered");
    const [delivered] = await db.select().from(mutationOutboxDeliveries)
      .where(eq(mutationOutboxDeliveries.eventId, crashMessage.eventId));
    expect(delivered).toMatchObject({ state: "delivered", leaseGeneration: retryMessage.leaseGeneration });
    expect(delivered?.encryptedEnvelope).toBe(persistedCiphertext);
    expect(delivered?.encryptionKeyId).toBe("integration-key-1");
    expect(d1.rows.size).toBe(2);
  });

  it("rejects same-ID D1 rows whose clear metadata differs from the authenticated event", async () => {
    await withMutation(db, {
      sourceKind: "admin",
      requestId: "ledger-metadata-conflict",
      workerVersionId: "44444444-4444-4444-8444-444444444444",
      actorId: "integration-admin",
    }, async (tx) => {
      await tx.insert(appUsers).values({ id: metadataOwnerId, clerkUserId: `ledger_metadata_${metadataOwnerId}` });
    });
    const [message] = await claimPendingDeliveries(db, 1, 30, epochId);
    if (!message) throw new Error("missing metadata-conflict fixture");
    const keyBase64 = btoa(String.fromCharCode(...new Uint8Array(32).fill(9)));
    const encryption = {
      currentKeyBase64: keyBase64,
      currentKeyId: "integration-key-metadata",
      decryptionKeys: { "integration-key-metadata": keyBase64 },
    };
    const d1 = new FakeD1();
    d1.tamperNextReadField = "worker_version_id";
    await expect(processLedgerMessage(db, d1 as unknown as D1Database, message, encryption))
      .rejects.toThrow("d1_metadata_conflict");
    await expect(processLedgerMessage(db, d1 as unknown as D1Database, message, encryption))
      .resolves.toBe("delivered");
  });

  it("records retry state and quarantines a poison delivery at the Queue/DLQ boundary", async () => {
    await withMutation(db, {
      sourceKind: "admin",
      requestId: "ledger-poison-delivery",
      workerVersionId: "44444444-4444-4444-8444-444444444444",
      actorId: "integration-admin",
    }, async (tx) => {
      await tx.insert(appUsers).values({ id: poisonOwnerId, clerkUserId: `ledger_poison_${poisonOwnerId}` });
    });
    const [message] = await claimPendingDeliveries(db, 1, 30, epochId);
    if (!message) throw new Error("missing poison delivery fixture");
    expect(await recordLedgerDeliveryFailure(db, message, new Error("poison\nsecret-free"), 1))
      .toBe("retrying");
    let [delivery] = await db.select().from(mutationOutboxDeliveries)
      .where(eq(mutationOutboxDeliveries.eventId, message.eventId));
    expect(delivery).toMatchObject({ state: "leased", lastError: "queue_attempt=1; code=delivery_failed" });
    expect(await recordLedgerDeliveryFailure(db, message, new Error("terminal poison"), 6))
      .toBe("quarantined");
    [delivery] = await db.select().from(mutationOutboxDeliveries)
      .where(eq(mutationOutboxDeliveries.eventId, message.eventId));
    expect(delivery).toMatchObject({ state: "quarantined", lastError: "queue_attempt=6; code=delivery_failed" });
    expect(delivery?.leasedUntil).toBeNull();
  });

  it("physically rejects mutation or deletion of captured events", async () => {
    const [event] = await db.select({ id: mutationOutboxEvents.eventId }).from(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.epochId, epochId)).limit(1);
    if (!event) throw new Error("missing mutation event fixture");
    await expect(db.update(mutationOutboxEvents).set({ actorId: "changed" })
      .where(eq(mutationOutboxEvents.eventId, event.id))).rejects.toThrow(/Failed query/);
    await expect(db.delete(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.eventId, event.id))).rejects.toThrow(/Failed query/);
  });

  it("waits for an old writer, freezes at an exact watermark, then rejects new writes", async () => {
    let releaseWriter!: () => void;
    let writerHasMutated!: () => void;
    const writerMutated = new Promise<void>((resolve) => { writerHasMutated = resolve; });
    const writerRelease = new Promise<void>((resolve) => { releaseWriter = resolve; });
    const writer = withMutation(db, {
      sourceKind: "admin",
      requestId: "ledger-old-writer",
      workerVersionId: "44444444-4444-4444-8444-444444444444",
      actorId: "integration-admin",
    }, async (tx) => {
      await tx.update(teams).set({ name: "Ledger Team Final" }).where(eq(teams.id, teamId));
      writerHasMutated();
      await writerRelease;
    });
    await writerMutated;

    let freezeResolved = false;
    const freeze = freezeMutationLedgerEpoch(db, epochId).then((value) => {
      freezeResolved = true;
      return value;
    });
    await new Promise((resolve) => setTimeout(resolve, 75));
    expect(freezeResolved).toBe(false);
    releaseWriter();
    await writer;
    const highWatermark = await freeze;
    expect(highWatermark).not.toBeNull();
    expect(highWatermark).toBeGreaterThanOrEqual(3);
    expect(await db.select().from(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.epochId, epochId))).toHaveLength(5);

    await expect(withMutation(db, {
      sourceKind: "admin",
      requestId: "ledger-new-writer",
      workerVersionId: "44444444-4444-4444-8444-444444444444",
      actorId: "integration-admin",
    }, async (tx) => {
      await tx.update(teams).set({ name: "Must Not Commit" }).where(eq(teams.id, teamId));
    })).rejects.toThrow(/Failed query/);
    const [team] = await db.select({ name: teams.name }).from(teams).where(eq(teams.id, teamId));
    expect(team?.name).toBe("Ledger Team Final");
  });
});

function validatedIntegrationDatabaseURL(): string {
  const value = process.env.REFWATCH_INTEGRATION_DATABASE_URL;
  if (!value || process.env.REFWATCH_ALLOW_DESTRUCTIVE_INTEGRATION_TESTS !== "1") {
    throw new Error("Database integration requires the managed ephemeral-role runner and explicit destructive-test opt-in");
  }
  const parsed = new URL(value);
  const username = decodeURIComponent(parsed.username);
  if (parsed.protocol !== "postgresql:" || !username.startsWith("pscale_api_") || !username.endsWith(`.${expectedDisposableBranchId}`)) {
    throw new Error("Database integration URL does not target the expected disposable PlanetScale branch");
  }
  if (parsed.searchParams.get("sslmode") !== "verify-full") {
    throw new Error("Database integration requires sslmode=verify-full");
  }
  return value;
}

class FakeD1 {
  rows = new Map<string, {
    event_sequence: number;
    epoch_id: string;
    mutation_group_id: string;
    group_ordinal: number;
    schema_version: number;
    source_kind: string;
    worker_version_id: string;
    content_digest: string;
    encryption_key_id: string;
    encryption_nonce: string;
    encrypted_envelope: string;
  }>();
  failNextRead = false;
  tamperNextReadField?: string;

  prepare(query: string) {
    let values: unknown[] = [];
    const statement = {
      bind: (...bound: unknown[]) => {
        values = bound;
        return statement;
      },
      run: async () => {
        if (query.includes("INSERT INTO mutation_ledger_events")) {
          const eventId = String(values[0]);
          if (!this.rows.has(eventId)) {
            this.rows.set(eventId, {
              event_sequence: Number(values[1]),
              epoch_id: String(values[2]),
              mutation_group_id: String(values[3]),
              group_ordinal: Number(values[4]),
              schema_version: Number(values[5]),
              source_kind: String(values[6]),
              worker_version_id: String(values[7]),
              content_digest: String(values[8]),
              encryption_key_id: String(values[9]),
              encryption_nonce: String(values[10]),
              encrypted_envelope: String(values[11]),
            });
          }
        }
        return { success: true, results: [], meta: {} };
      },
      first: async () => {
        if (this.failNextRead) {
          this.failNextRead = false;
          throw new Error("simulated post-D1 crash");
        }
        const row = this.rows.get(String(values[0])) ?? null;
        if (row && this.tamperNextReadField) {
          const field = this.tamperNextReadField;
          this.tamperNextReadField = undefined;
          return { ...row, [field]: `${String(row[field as keyof typeof row])}-tampered` };
        }
        return row;
      },
    };
    return statement;
  }
}

async function cleanup(pool: Pool): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("begin");
    const epoch = await client.query("select status from mutation_ledger_epochs where id = $1", [epochId]);
    if (epoch.rows[0]?.status === "open") {
      await client.query("rollback");
      await freezeMutationLedgerEpoch(drizzle(pool, { schema }), epochId);
      await client.query("begin");
    }
    await client.query("update mutation_ledger_epochs set status = 'archived', capture_enforced = false, updated_at = now() where id = $1 and status in ('preparing', 'frozen')", [epochId]);
    await client.query("delete from teams where id = $1", [teamId]);
    await client.query("delete from pages where id = $1", [oversizedPageId]);
    await client.query("delete from app_users where id = any($1::uuid[])", [[ownerId, rejectedOwnerId, lateOwnerId, poisonOwnerId, metadataOwnerId]]);
    await client.query("commit");
  } catch (error) {
    await client.query("rollback");
    throw error;
  } finally {
    client.release();
  }
}
