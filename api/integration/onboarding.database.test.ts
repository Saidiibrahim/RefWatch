import { createHash } from "node:crypto";
import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "../src/db/schema";
import {
  appUsers,
  identityReconciliationActivations,
  identityReconciliationLegacyMappings,
  identityReconciliationReceipts,
} from "../src/db/schema";
import {
  activateIdentityReconciliationReceipt,
  provisionNewUserAfterReconciliation,
  recordClerkUserDeletion,
} from "../src/services/userOnboarding";

const expectedDisposableBranchId = "ng9tgmy4pyi5";
const databaseURL = validatedIntegrationDatabaseURL();
const runSuffix = `${Date.now().toString(36)}${crypto.randomUUID().replaceAll("-", "").slice(0, 8)}`;
const receiptDigest = createHash("sha256").update(`receipt:${runSuffix}`).digest("hex");
const missingReceiptDigest = createHash("sha256").update(`missing:${runSuffix}`).digest("hex");
const clerkInstanceId = `ins_integration${runSuffix}`;
const clerkUserId = `user_integration_post_reconciliation_${runSuffix}`;
const legacyClerkUserId = `user_integration_legacy_${runSuffix}`;
const legacyAppUserId = crypto.randomUUID();
const mappingHash = createHash("sha256").update(JSON.stringify([{
  app_user_id: legacyAppUserId.toLowerCase(),
  clerk_user_id: legacyClerkUserId,
}])).digest("hex");

describe("post-reconciliation onboarding against real Postgres", () => {
  const pool = new Pool({ connectionString: databaseURL, max: 4 });
  const db = drizzle(pool, { schema });

  beforeAll(async () => {
    await db.insert(identityReconciliationReceipts).values({
      receiptDigest,
      clerkInstanceId,
      snapshotCapturedAt: new Date("2026-07-15T00:00:00Z"),
      legacyMappingCount: 1,
      excludedAuthCount: 1,
      mappingHash,
      status: "verified",
      reviewedAt: new Date("2026-07-15T00:05:00Z"),
    });
    await db.insert(appUsers).values({ id: legacyAppUserId, clerkUserId: legacyClerkUserId });
    await db.insert(identityReconciliationLegacyMappings).values({
      clerkInstanceId,
      clerkUserId: legacyClerkUserId,
      appUserId: legacyAppUserId,
      receiptDigest,
    });
    expect(await activateIdentityReconciliationReceipt(db, receiptDigest, clerkInstanceId)).toBe(true);
  });

  afterAll(async () => {
    await pool.end();
  });

  it("requires a matching durable receipt and the enabled write mode", async () => {
    const missing = await provisionNewUserAfterReconciliation(db, {
      WRITE_MODE: "enabled",
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: missingReceiptDigest,
      CLERK_INSTANCE_ID: clerkInstanceId,
    }, { clerkInstanceId, clerkUserId });
    expect(missing).toEqual({ kind: "gate_closed" });

    const disabled = await provisionNewUserAfterReconciliation(db, {
      WRITE_MODE: "disabled",
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: receiptDigest,
      CLERK_INSTANCE_ID: clerkInstanceId,
    }, { clerkInstanceId, clerkUserId });
    expect(disabled).toEqual({ kind: "gate_closed" });
    expect(await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId))).toHaveLength(0);
  });

  it("creates one server-generated app UUID across concurrent retries", async () => {
    const env = {
      WRITE_MODE: "enabled",
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: receiptDigest,
      CLERK_INSTANCE_ID: clerkInstanceId,
    } as const;
    const [first, second] = await Promise.all([
      provisionNewUserAfterReconciliation(db, env, { clerkInstanceId, clerkUserId, email: "new@example.com" }),
      provisionNewUserAfterReconciliation(db, env, { clerkInstanceId, clerkUserId, email: "new@example.com" }),
    ]);
    expect(new Set([first.kind, second.kind])).toEqual(new Set(["created", "existing"]));
    if (first.kind === "gate_closed" || second.kind === "gate_closed") throw new Error("onboarding gate unexpectedly closed");
    expect(first.user.id).toBe(second.user.id);
    expect(first.user.id).toMatch(/^[0-9a-f-]{36}$/);
    const rows = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId));
    expect(rows).toHaveLength(1);
    expect(rows[0]?.id).toBe(first.user.id);
  });

  it("makes the activated registry and preserved app-user identity immutable", async () => {
    await expect(db.update(identityReconciliationLegacyMappings)
      .set({ clerkUserId: "user_integration_swapped" })
      .where(eq(identityReconciliationLegacyMappings.clerkUserId, legacyClerkUserId)))
      .rejects.toThrow(/Failed query/);
    await expect(db.update(appUsers).set({ clerkUserId: "user_integration_corrupted" })
      .where(eq(appUsers.id, legacyAppUserId)))
      .rejects.toThrow(/Failed query/);
    await expect(db.delete(appUsers).where(eq(appUsers.id, legacyAppUserId)))
      .rejects.toThrow(/Failed query/);
    await expect(db.update(identityReconciliationActivations)
      .set({ clerkInstanceId: "ins_integration_changed" })
      .where(eq(identityReconciliationActivations.receiptDigest, receiptDigest)))
      .rejects.toThrow(/Failed query/);
    await expect(db.delete(identityReconciliationActivations)
      .where(eq(identityReconciliationActivations.receiptDigest, receiptDigest)))
      .rejects.toThrow(/Failed query/);
    const result = await provisionNewUserAfterReconciliation(db, {
      WRITE_MODE: "enabled",
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: receiptDigest,
      CLERK_INSTANCE_ID: clerkInstanceId,
    }, { clerkInstanceId, clerkUserId: legacyClerkUserId });
    expect(result.kind).toBe("existing");
    if (result.kind === "existing") expect(result.user.id).toBe(legacyAppUserId);
  });

  it("serializes activation against an in-flight registry mutation", async () => {
    const concurrentReceipt = createHash("sha256").update(`concurrent:${runSuffix}`).digest("hex");
    const concurrentAppUserId = crypto.randomUUID();
    const concurrentSubject = `user_integration_activation_race_${runSuffix}`;
    const normalized = JSON.stringify([{ app_user_id: concurrentAppUserId, clerk_user_id: concurrentSubject }]);
    const concurrentHash = createHash("sha256").update(normalized).digest("hex");
    await db.insert(identityReconciliationReceipts).values({
      receiptDigest: concurrentReceipt,
      clerkInstanceId,
      snapshotCapturedAt: new Date("2026-07-15T00:00:00Z"),
      legacyMappingCount: 1,
      excludedAuthCount: 1,
      mappingHash: concurrentHash,
      status: "verified",
      reviewedAt: new Date("2026-07-15T00:05:00Z"),
    });
    await db.insert(appUsers).values({ id: concurrentAppUserId, clerkUserId: concurrentSubject });
    await db.insert(identityReconciliationLegacyMappings).values({
      clerkInstanceId,
      clerkUserId: concurrentSubject,
      appUserId: concurrentAppUserId,
      receiptDigest: concurrentReceipt,
    });

    const mutator = await pool.connect();
    try {
      await mutator.query("begin");
      await mutator.query(
        "update identity_reconciliation_legacy_mappings set clerk_user_id = $1 where clerk_instance_id = $2 and clerk_user_id = $3",
        [`user_integration_activation_race_swapped_${runSuffix}`, clerkInstanceId, concurrentSubject],
      );
      const activation = activateIdentityReconciliationReceipt(db, concurrentReceipt, clerkInstanceId);
      await new Promise((resolve) => setTimeout(resolve, 50));
      await mutator.query("commit");
      await expect(activation).resolves.toBe(false);
    } catch (error) {
      await mutator.query("rollback");
      throw error;
    } finally {
      mutator.release();
    }
    expect(await db.select().from(identityReconciliationActivations)
      .where(eq(identityReconciliationActivations.receiptDigest, concurrentReceipt))).toHaveLength(0);
  });

  it("records delete-before-create and permanently rejects resurrection", async () => {
    const deletedSubject = `user_integration_deleted_first_${runSuffix}`;
    await recordClerkUserDeletion(db, {
      clerkInstanceId,
      clerkUserId: deletedSubject,
      webhookEventId: "evt_deleted_first",
      deletedAt: new Date(),
    });
    const result = await provisionNewUserAfterReconciliation(db, {
      WRITE_MODE: "enabled",
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: receiptDigest,
      CLERK_INSTANCE_ID: clerkInstanceId,
    }, { clerkInstanceId, clerkUserId: deletedSubject });
    expect(result).toEqual({ kind: "subject_deleted" });
    expect(await db.select().from(appUsers).where(eq(appUsers.clerkUserId, deletedSubject))).toHaveLength(0);
  });

  it("serializes concurrent create and delete so deletion wins", async () => {
    const subject = `user_integration_concurrent_delete_${runSuffix}`;
    const env = {
      WRITE_MODE: "enabled",
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: receiptDigest,
      CLERK_INSTANCE_ID: clerkInstanceId,
    } as const;
    await Promise.all([
      provisionNewUserAfterReconciliation(db, env, { clerkInstanceId, clerkUserId: subject }),
      recordClerkUserDeletion(db, {
        clerkInstanceId,
        clerkUserId: subject,
        webhookEventId: "evt_concurrent_delete",
        deletedAt: new Date(),
      }),
    ]);
    const [row] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, subject));
    expect(row == null || row.deletedAt != null).toBe(true);
    expect(await provisionNewUserAfterReconciliation(db, env, {
      clerkInstanceId,
      clerkUserId: subject,
    })).toEqual({ kind: "subject_deleted" });
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
