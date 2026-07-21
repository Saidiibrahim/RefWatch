import { createHash } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "../src/db/schema";
import {
  appUsers,
  clerkUserDeletionTombstones,
  clerkWebhookDeliveryReceipts,
  identityReconciliationActivations,
  identityReconciliationLegacyMappings,
  identityReconciliationReceipts,
  mutationLedgerEpochs,
  mutationOutboxDeliveries,
  mutationOutboxEvents,
} from "../src/db/schema";
import {
  EMPTY_IDENTITY_MAPPING_HASH,
  GREENFIELD_AUTHORIZATION_DIGEST,
  GREENFIELD_AUTHORIZATION_PROFILE,
  GREENFIELD_ONBOARDING_MODE,
  GREENFIELD_RECONCILIATION_PROFILE,
  GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
  POST_RECONCILIATION_ONBOARDING_MODE,
  PRODUCTION_CLERK_DOMAIN,
  PRODUCTION_CLERK_INSTANCE_ID,
  PRODUCTION_CLERK_ISSUER,
  STATEFUL_RECONCILIATION_PROFILE,
} from "../src/services/identityProfiles";
import {
  freezeMutationLedgerEpoch,
  openMutationLedgerEpoch,
  type MutationContext,
} from "../src/services/mutationLedger";
import {
  activateIdentityReconciliationReceipt,
  greenfieldReconciliationActivationExpectation,
  processClerkUserLifecycleEvent,
  provisionNewUserAfterReconciliation,
  recordClerkUserDeletion,
  type ClerkLifecycleEventType,
  type ClerkUserLifecycleEvent,
} from "../src/services/userOnboarding";

const databaseURL = validatedLocalDatabaseURL();
const pool = new Pool({ connectionString: databaseURL, max: 12 });
const db = drizzle(pool, { schema });
const runSuffix = `${Date.now().toString(36)}${crypto.randomUUID().replaceAll("-", "").slice(0, 8)}`;
const baseTime = new Date("2026-07-20T00:00:00.000Z");

const greenfieldEnv = {
  WRITE_MODE: "enabled",
  NEW_USER_ONBOARDING_MODE: GREENFIELD_ONBOARDING_MODE,
  IDENTITY_RECONCILIATION_RECEIPT: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
  IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST: GREENFIELD_AUTHORIZATION_DIGEST,
  CLERK_INSTANCE_ID: PRODUCTION_CLERK_INSTANCE_ID,
  CLERK_ISSUER: PRODUCTION_CLERK_ISSUER,
} as const;

afterAll(async () => {
  await pool.end();
});

describe("zero-legacy greenfield identity bootstrap against disposable local PostgreSQL", () => {
  it("rejects zero-count stateful, unknown-profile, and malformed greenfield receipts", async () => {
    await expect(db.insert(identityReconciliationReceipts).values({
      receiptDigest: hash(`zero-stateful:${runSuffix}`),
      clerkInstanceId: `ins_zero_stateful_${runSuffix}`,
      reconciliationProfile: STATEFUL_RECONCILIATION_PROFILE,
      snapshotCapturedAt: baseTime,
      legacyMappingCount: 0,
      excludedAuthCount: 0,
      mappingHash: EMPTY_IDENTITY_MAPPING_HASH,
      status: "verified",
      reviewedAt: baseTime,
    })).rejects.toThrow(/Failed query/);

    await expect(db.insert(identityReconciliationReceipts).values({
      receiptDigest: hash(`unknown-profile:${runSuffix}`),
      clerkInstanceId: `ins_unknown_profile_${runSuffix}`,
      reconciliationProfile: "unknown_profile",
      snapshotCapturedAt: baseTime,
      legacyMappingCount: 0,
      excludedAuthCount: 0,
      mappingHash: EMPTY_IDENTITY_MAPPING_HASH,
      status: "verified",
      reviewedAt: baseTime,
    })).rejects.toThrow(/Failed query/);

    await expect(db.insert(identityReconciliationReceipts).values({
      receiptDigest: hash(`stateful-with-authorization:${runSuffix}`),
      clerkInstanceId: `ins_stateful_authorization_${runSuffix}`,
      reconciliationProfile: STATEFUL_RECONCILIATION_PROFILE,
      authorizationProfile: GREENFIELD_AUTHORIZATION_PROFILE,
      authorizationDigest: GREENFIELD_AUTHORIZATION_DIGEST,
      snapshotCapturedAt: baseTime,
      legacyMappingCount: 1,
      excludedAuthCount: 0,
      mappingHash: hash("stateful-with-authorization"),
      status: "verified",
      reviewedAt: baseTime,
    })).rejects.toThrow(/Failed query/);

    const malformedGreenfieldReceipts = [
      ["receipt digest", { receiptDigest: hash(`wrong-greenfield-receipt:${runSuffix}`) }],
      ["Clerk instance", { clerkInstanceId: `ins_wrong_${runSuffix}` }],
      ["authorization profile", { authorizationProfile: "refwatch.wrong-authorization.v1" }],
      ["authorization digest", { authorizationDigest: "0".repeat(64) }],
      ["Clerk issuer", { clerkIssuer: "https://wrong.example.test" }],
      ["Clerk domain", { clerkDomain: "wrong.example.test" }],
      ["legacy mapping count", { legacyMappingCount: 1 }],
      ["excluded auth count", { excludedAuthCount: 1 }],
      ["mapping hash", { mappingHash: hash(`wrong-empty-map:${runSuffix}`) }],
      ["verification status", { status: "unreviewed" }],
    ] as const;
    for (const [label, override] of malformedGreenfieldReceipts) {
      await expect(
        db.insert(identityReconciliationReceipts).values({
          ...exactGreenfieldReceipt(),
          ...override,
        }),
        label,
      ).rejects.toThrow(/Failed query/);
    }

    expect(await db.select().from(identityReconciliationReceipts)).toHaveLength(0);
  });

  it("serializes activation against an app-user insert that began before the receipt committed", async () => {
    const receiptWriter = await pool.connect();
    const appUserWriter = await pool.connect();
    const preReceiptSubject = `user_greenfield_pre_receipt_${runSuffix}`;
    try {
      await receiptWriter.query("begin");
      const receipt = exactGreenfieldReceipt();
      await receiptWriter.query(
        `insert into identity_reconciliation_receipts (
          receipt_digest, clerk_instance_id, reconciliation_profile,
          authorization_profile, authorization_digest, clerk_issuer, clerk_domain,
          snapshot_captured_at, legacy_mapping_count, excluded_auth_count,
          mapping_hash, status, reviewed_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [
          receipt.receiptDigest,
          receipt.clerkInstanceId,
          receipt.reconciliationProfile,
          receipt.authorizationProfile,
          receipt.authorizationDigest,
          receipt.clerkIssuer,
          receipt.clerkDomain,
          receipt.snapshotCapturedAt,
          receipt.legacyMappingCount,
          receipt.excludedAuthCount,
          receipt.mappingHash,
          receipt.status,
          receipt.reviewedAt,
        ],
      );

      await appUserWriter.query("begin");
      await appUserWriter.query(
        "insert into app_users (clerk_user_id) values ($1)",
        [preReceiptSubject],
      );
      await receiptWriter.query("commit");

      let activationSettled = false;
      const activation = activateIdentityReconciliationReceipt(
        db,
        GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
        PRODUCTION_CLERK_INSTANCE_ID,
        greenfieldReconciliationActivationExpectation(),
      ).finally(() => {
        activationSettled = true;
      });
      await new Promise((resolve) => setTimeout(resolve, 50));
      expect(activationSettled).toBe(false);

      await appUserWriter.query("commit");
      await expect(activation).resolves.toBe(false);
    } catch (error) {
      await receiptWriter.query("rollback").catch(() => undefined);
      await appUserWriter.query("rollback").catch(() => undefined);
      throw error;
    } finally {
      receiptWriter.release();
      appUserWriter.release();
    }

    expect(await db.select().from(identityReconciliationActivations)
      .where(eq(identityReconciliationActivations.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID)))
      .toHaveLength(0);
    await db.delete(appUsers).where(eq(appUsers.clerkUserId, preReceiptSubject));
    expect(await db.select().from(appUsers)).toHaveLength(0);
  });

  it("rolls back the webhook receipt atomically while activation is absent", async () => {
    const event = lifecycleEvent(
      `greenfield_preactivation_${runSuffix}`,
      "user.created",
      `svix_preactivation_${runSuffix}`,
      1,
      { email: "must-not-persist@example.com" },
    );

    expect(await processClerkUserLifecycleEvent(
      db,
      greenfieldEnv,
      event,
      mutationContext(event.webhookEventId),
    )).toEqual({ kind: "gate_closed" });
    expect(await db.select().from(appUsers)).toHaveLength(0);
    expect(await db.select().from(clerkWebhookDeliveryReceipts)
      .where(eq(clerkWebhookDeliveryReceipts.webhookEventId, event.webhookEventId))).toHaveLength(0);
  });

  it("requires the exact greenfield activation expectation and activates idempotently at zero users and mappings", async () => {
    expect(await db.select().from(appUsers)).toHaveLength(0);
    expect(await db.select().from(identityReconciliationLegacyMappings)).toHaveLength(0);

    expect(await activateIdentityReconciliationReceipt(
      db,
      GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
      PRODUCTION_CLERK_INSTANCE_ID,
    )).toBe(false);
    expect(await activateIdentityReconciliationReceipt(
      db,
      GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
      PRODUCTION_CLERK_INSTANCE_ID,
      {
        reconciliationProfile: GREENFIELD_RECONCILIATION_PROFILE,
        authorizationDigest: "0".repeat(64),
      },
    )).toBe(false);

    const expected = greenfieldReconciliationActivationExpectation();
    expect(await activateIdentityReconciliationReceipt(
      db,
      GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
      PRODUCTION_CLERK_INSTANCE_ID,
      expected,
    )).toBe(true);
    expect(await activateIdentityReconciliationReceipt(
      db,
      GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
      PRODUCTION_CLERK_INSTANCE_ID,
      expected,
    )).toBe(true);
    expect(await db.select().from(identityReconciliationActivations)
      .where(eq(identityReconciliationActivations.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID)))
      .toHaveLength(1);
  });

  it("makes the activated greenfield receipt and activation physically immutable", async () => {
    await expect(db.update(identityReconciliationReceipts)
      .set({ reviewedAt: new Date(baseTime.getTime() + 1_000) })
      .where(eq(identityReconciliationReceipts.receiptDigest, GREENFIELD_RECONCILIATION_RECEIPT_DIGEST)))
      .rejects.toThrow(/Failed query/);
    await expect(db.delete(identityReconciliationReceipts)
      .where(eq(identityReconciliationReceipts.receiptDigest, GREENFIELD_RECONCILIATION_RECEIPT_DIGEST)))
      .rejects.toThrow(/Failed query/);
    await expect(db.update(identityReconciliationActivations)
      .set({ activatedAt: new Date(baseTime.getTime() + 1_000) })
      .where(eq(identityReconciliationActivations.receiptDigest, GREENFIELD_RECONCILIATION_RECEIPT_DIGEST)))
      .rejects.toThrow(/Failed query/);
    await expect(db.delete(identityReconciliationActivations)
      .where(eq(identityReconciliationActivations.receiptDigest, GREENFIELD_RECONCILIATION_RECEIPT_DIGEST)))
      .rejects.toThrow(/Failed query/);
  });

  it("rejects deletion lifecycle delivery while writes are disabled without recording state", async () => {
    const clerkUserId = `user_greenfield_disabled_delete_${runSuffix}`;
    const event = lifecycleEvent(
      clerkUserId,
      "user.deleted",
      `svix_disabled_delete_${runSuffix}`,
      2,
    );
    expect(await processClerkUserLifecycleEvent(
      db,
      { ...greenfieldEnv, WRITE_MODE: "disabled" },
      event,
      mutationContext(event.webhookEventId),
    )).toEqual({ kind: "gate_closed" });
    expect(await db.select().from(clerkWebhookDeliveryReceipts).where(and(
      eq(clerkWebhookDeliveryReceipts.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID),
      eq(clerkWebhookDeliveryReceipts.webhookEventId, event.webhookEventId),
    ))).toHaveLength(0);
    expect(await db.select().from(clerkUserDeletionTombstones).where(and(
      eq(clerkUserDeletionTombstones.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID),
      eq(clerkUserDeletionTombstones.clerkUserId, clerkUserId),
    ))).toHaveLength(0);
  });

  it("creates one server UUID across concurrent provisioning and idempotent retries", async () => {
    const clerkUserId = `user_greenfield_provision_${runSuffix}`;
    const results = await Promise.all(Array.from({ length: 8 }, () =>
      provisionNewUserAfterReconciliation(db, greenfieldEnv, {
        clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
        clerkUserId,
        email: "greenfield-provision@example.com",
      })));
    expect(results.filter((result) => result.kind === "created")).toHaveLength(1);
    expect(results.filter((result) => result.kind === "existing")).toHaveLength(7);

    const accepted = results.filter(
      (result): result is Extract<typeof result, { kind: "created" | "existing" }> =>
        result.kind === "created" || result.kind === "existing",
    );
    expect(new Set(accepted.map((result) => result.user.id)).size).toBe(1);
    expect(accepted[0]?.user.id).toMatch(/^[0-9a-f-]{36}$/);

    const retry = await provisionNewUserAfterReconciliation(db, greenfieldEnv, {
      clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
      clerkUserId,
      email: "greenfield-provision@example.com",
    });
    expect(retry.kind).toBe("existing");
    if (retry.kind !== "existing") throw new Error("idempotent greenfield retry did not resolve");
    expect(retry.user.id).toBe(accepted[0]?.user.id);
    expect(await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId))).toHaveLength(1);
    expect(await activateIdentityReconciliationReceipt(
      db,
      GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
      PRODUCTION_CLERK_INSTANCE_ID,
      greenfieldReconciliationActivationExpectation(),
    )).toBe(true);
  });

  it("rejects every legacy mapping under the greenfield receipt and activated instance", async () => {
    const clerkUserId = `user_greenfield_provision_${runSuffix}`;
    const [user] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId));
    if (!user) throw new Error("missing greenfield provisioning fixture");

    await expect(db.insert(identityReconciliationLegacyMappings).values({
      clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
      clerkUserId,
      appUserId: user.id,
      receiptDigest: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
    })).rejects.toThrow(/Failed query/);
    expect(await db.select().from(identityReconciliationLegacyMappings)
      .where(eq(identityReconciliationLegacyMappings.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID)))
      .toHaveLength(0);
  });

  it("processes lifecycle create/update/duplicate/conflict and makes delivery receipts immutable", async () => {
    const clerkUserId = `user_greenfield_lifecycle_${runSuffix}`;
    const created = lifecycleEvent(
      clerkUserId,
      "user.created",
      `svix_lifecycle_create_${runSuffix}`,
      10,
      { email: "created@example.com", displayName: "Created" },
    );
    const concurrentRetries = await Promise.all(
      Array.from({ length: 8 }, () => processLifecycle(created)),
    );
    expect(concurrentRetries.filter((result) => result.kind === "created")).toHaveLength(1);
    expect(concurrentRetries.filter((result) => result.kind === "duplicate")).toHaveLength(7);

    const conflictingDelivery = {
      ...created,
      payloadHash: hash(`changed-payload:${runSuffix}`),
      email: "must-not-win@example.com",
    };
    expect(await processLifecycle(conflictingDelivery)).toEqual({ kind: "delivery_conflict" });

    const updated = lifecycleEvent(
      clerkUserId,
      "user.updated",
      `svix_lifecycle_update_${runSuffix}`,
      11,
      { email: "updated@example.com", displayName: "Updated" },
    );
    expect(await processLifecycle(updated)).toEqual({ kind: "updated" });
    expect(await processLifecycle(updated)).toEqual({ kind: "duplicate" });

    const staleUpdate = lifecycleEvent(
      clerkUserId,
      "user.updated",
      `svix_lifecycle_stale_update_${runSuffix}`,
      10.5,
      { email: "stale@example.com", displayName: "Stale" },
    );
    expect(await processLifecycle(staleUpdate)).toEqual({ kind: "existing" });

    const equalTimeUpdate = lifecycleEvent(
      clerkUserId,
      "user.updated",
      `svix_lifecycle_equal_time_update_${runSuffix}`,
      11,
      { email: "equal-time@example.com", displayName: "Equal Time" },
    );
    expect(await processLifecycle(equalTimeUpdate)).toEqual({ kind: "existing" });

    const [user] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId));
    expect(user).toMatchObject({
      email: "updated@example.com",
      displayName: "Updated",
      deletedAt: null,
    });
    expect(await db.select().from(clerkWebhookDeliveryReceipts).where(and(
      eq(clerkWebhookDeliveryReceipts.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID),
      eq(clerkWebhookDeliveryReceipts.clerkUserId, clerkUserId),
    ))).toHaveLength(4);
    expect(await db.select().from(mutationOutboxEvents)).toHaveLength(0);
    expect(await db.select().from(mutationOutboxDeliveries)).toHaveLength(0);

    await expect(db.update(clerkWebhookDeliveryReceipts)
      .set({ payloadHash: hash(`receipt-mutation:${runSuffix}`) })
      .where(and(
        eq(clerkWebhookDeliveryReceipts.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID),
        eq(clerkWebhookDeliveryReceipts.webhookEventId, created.webhookEventId),
      ))).rejects.toThrow(/Failed query/);
    await expect(db.delete(clerkWebhookDeliveryReceipts).where(and(
      eq(clerkWebhookDeliveryReceipts.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID),
      eq(clerkWebhookDeliveryReceipts.webhookEventId, created.webhookEventId),
    ))).rejects.toThrow(/Failed query/);
  });

  it("keeps the newest Clerk profile when updates arrive concurrently in reverse order", async () => {
    const subjects = Array.from(
      { length: 6 },
      (_, index) => `user_greenfield_profile_order_${index}_${runSuffix}`,
    );
    await Promise.all(subjects.map(async (clerkUserId, index) => {
      expect(await processLifecycle(lifecycleEvent(
        clerkUserId,
        "user.created",
        `svix_profile_order_create_${index}_${runSuffix}`,
        30 + index * 3,
        { email: `created-${index}@example.com` },
      ))).toEqual({ kind: "created" });

      const older = lifecycleEvent(
        clerkUserId,
        "user.updated",
        `svix_profile_order_older_${index}_${runSuffix}`,
        31 + index * 3,
        { email: `older-${index}@example.com` },
      );
      const newer = lifecycleEvent(
        clerkUserId,
        "user.updated",
        `svix_profile_order_newer_${index}_${runSuffix}`,
        32 + index * 3,
        { email: `newer-${index}@example.com` },
      );
      await Promise.all(index % 2 ? [processLifecycle(newer), processLifecycle(older)] : [
        processLifecycle(older),
        processLifecycle(newer),
      ]);

      const [user] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId));
      expect(user?.email).toBe(`newer-${index}@example.com`);
      expect(user?.clerkProfileUpdatedAt).toEqual(newer.occurredAt);
    }));
  });

  it("makes webhook deletion terminal across retries and later updates", async () => {
    const clerkUserId = `user_greenfield_lifecycle_${runSuffix}`;
    const deleted = lifecycleEvent(
      clerkUserId,
      "user.deleted",
      `svix_lifecycle_delete_${runSuffix}`,
      20,
    );
    expect(await processLifecycle(deleted)).toEqual({ kind: "deleted" });
    expect(await processLifecycle(deleted)).toEqual({ kind: "duplicate" });

    const afterDelete = lifecycleEvent(
      clerkUserId,
      "user.updated",
      `svix_lifecycle_after_delete_${runSuffix}`,
      21,
      { email: "must-not-resurrect@example.com", displayName: "Must Not Resurrect" },
    );
    expect(await processLifecycle(afterDelete)).toEqual({ kind: "subject_deleted" });

    const [user] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId));
    expect(user?.deletedAt).not.toBeNull();
    expect(user?.email).toBe("updated@example.com");
    const [tombstone] = await db.select().from(clerkUserDeletionTombstones).where(and(
      eq(clerkUserDeletionTombstones.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID),
      eq(clerkUserDeletionTombstones.clerkUserId, clerkUserId),
    ));
    expect(tombstone?.webhookEventId).toBe(deleted.webhookEventId);
  });

  it("keeps delete-wins ordering across concurrent create/delete and update/delete permutations", async () => {
    const concurrentSubjects = Array.from(
      { length: 6 },
      (_, index) => `user_greenfield_concurrent_${index}_${runSuffix}`,
    );
    await Promise.all(concurrentSubjects.map(async (clerkUserId, index) => {
      const created = lifecycleEvent(
        clerkUserId,
        "user.created",
        `svix_concurrent_create_${index}_${runSuffix}`,
        30 + index * 2,
        { email: `created-${index}@example.com` },
      );
      const deleted = lifecycleEvent(
        clerkUserId,
        "user.deleted",
        `svix_concurrent_delete_${index}_${runSuffix}`,
        31 + index * 2,
      );
      const results = await Promise.all([processLifecycle(created), processLifecycle(deleted)]);
      expect(results[1]).toEqual({ kind: "deleted" });
      expect(["created", "subject_deleted"]).toContain(results[0]?.kind);

      const [user] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId));
      expect(user == null || user.deletedAt != null).toBe(true);
      expect(await db.select().from(clerkUserDeletionTombstones).where(and(
        eq(clerkUserDeletionTombstones.clerkInstanceId, PRODUCTION_CLERK_INSTANCE_ID),
        eq(clerkUserDeletionTombstones.clerkUserId, clerkUserId),
      ))).toHaveLength(1);

      const laterUpdate = lifecycleEvent(
        clerkUserId,
        "user.updated",
        `svix_concurrent_later_update_${index}_${runSuffix}`,
        100 + index,
        { email: `must-not-resurrect-${index}@example.com` },
      );
      expect(await processLifecycle(laterUpdate)).toEqual({ kind: "subject_deleted" });
      const [afterUpdate] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId));
      expect(afterUpdate?.email).not.toBe(`must-not-resurrect-${index}@example.com`);
    }));

    const updateDeleteSubject = `user_greenfield_update_delete_${runSuffix}`;
    const initial = lifecycleEvent(
      updateDeleteSubject,
      "user.created",
      `svix_update_delete_initial_${runSuffix}`,
      200,
      { email: "initial@example.com" },
    );
    expect(await processLifecycle(initial)).toEqual({ kind: "created" });
    const update = lifecycleEvent(
      updateDeleteSubject,
      "user.updated",
      `svix_update_delete_update_${runSuffix}`,
      201,
      { email: "concurrent-update@example.com" },
    );
    const deletion = lifecycleEvent(
      updateDeleteSubject,
      "user.deleted",
      `svix_update_delete_delete_${runSuffix}`,
      202,
    );
    const [updateResult, deleteResult] = await Promise.all([
      processLifecycle(update),
      processLifecycle(deletion),
    ]);
    expect(["updated", "subject_deleted"]).toContain(updateResult.kind);
    expect(deleteResult).toEqual({ kind: "deleted" });
    const [deletedUser] = await db.select().from(appUsers)
      .where(eq(appUsers.clerkUserId, updateDeleteSubject));
    expect(deletedUser?.deletedAt).not.toBeNull();

    const impossibleResurrection = lifecycleEvent(
      updateDeleteSubject,
      "user.updated",
      `svix_update_delete_resurrection_${runSuffix}`,
      203,
      { email: "resurrection@example.com" },
    );
    expect(await processLifecycle(impossibleResurrection)).toEqual({ kind: "subject_deleted" });
    const [stillDeleted] = await db.select().from(appUsers)
      .where(eq(appUsers.clerkUserId, updateDeleteSubject));
    expect(stillDeleted?.email).not.toBe("resurrection@example.com");
  });

  it("preserves strict capture when an isolated mutation-ledger epoch is explicitly opened", async () => {
    const epochId = crypto.randomUUID();
    await db.insert(mutationLedgerEpochs).values({
      id: epochId,
      baselineSnapshotId: `greenfield-local-${runSuffix}`,
      baselineSchemaHash: hash(`greenfield-local-schema:${runSuffix}`),
      baselineDataHash: hash(`greenfield-local-data:${runSuffix}`),
    });
    expect(await openMutationLedgerEpoch(db, epochId)).toBe(true);

    const clerkUserId = `user_greenfield_active_ledger_${runSuffix}`;
    const event = lifecycleEvent(
      clerkUserId,
      "user.created",
      `svix_active_ledger_${runSuffix}`,
      300,
      { email: "active-ledger@example.com" },
    );
    expect(await processLifecycle(event)).toEqual({ kind: "created" });

    const captured = await db.select().from(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.epochId, epochId))
      .orderBy(mutationOutboxEvents.groupOrdinal);
    expect(captured.map((entry) => entry.tableName)).toEqual([
      "clerk_webhook_delivery_receipts",
      "app_users",
    ]);
    expect(captured.map((entry) => entry.groupOrdinal)).toEqual([1, 2]);
    expect(await db.select().from(mutationOutboxDeliveries)).toHaveLength(2);

    expect(await freezeMutationLedgerEpoch(db, epochId)).toBe(2);
    const archived = await db.update(mutationLedgerEpochs).set({
      status: "archived",
      captureEnforced: false,
      updatedAt: new Date(),
    }).where(eq(mutationLedgerEpochs.id, epochId)).returning({
      id: mutationLedgerEpochs.id,
    });
    expect(archived).toHaveLength(1);
  });
});

describe("stateful post-reconciliation onboarding remains supported", () => {
  const receiptDigest = hash(`stateful-receipt:${runSuffix}`);
  const missingReceiptDigest = hash(`stateful-missing:${runSuffix}`);
  const clerkInstanceId = `ins_${runSuffix}`;
  const clerkUserId = `user_stateful_new_${runSuffix}`;
  const legacyClerkUserId = `user_stateful_legacy_${runSuffix}`;
  const legacyAppUserId = crypto.randomUUID();
  const mappingHash = hash(JSON.stringify([{
    app_user_id: legacyAppUserId.toLowerCase(),
    clerk_user_id: legacyClerkUserId,
  }]));
  const statefulEnv = {
    WRITE_MODE: "enabled",
    NEW_USER_ONBOARDING_MODE: POST_RECONCILIATION_ONBOARDING_MODE,
    IDENTITY_RECONCILIATION_RECEIPT: receiptDigest,
    CLERK_INSTANCE_ID: clerkInstanceId,
  } as const;

  beforeAll(async () => {
    await db.insert(identityReconciliationReceipts).values({
      receiptDigest,
      clerkInstanceId,
      reconciliationProfile: STATEFUL_RECONCILIATION_PROFILE,
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
    expect(await activateIdentityReconciliationReceipt(db, receiptDigest, clerkInstanceId)).toBe(true);
  });

  it("requires a matching durable receipt and enabled writes", async () => {
    expect(await provisionNewUserAfterReconciliation(db, {
      ...statefulEnv,
      IDENTITY_RECONCILIATION_RECEIPT: missingReceiptDigest,
    }, { clerkInstanceId, clerkUserId })).toEqual({ kind: "gate_closed" });

    expect(await provisionNewUserAfterReconciliation(db, {
      ...statefulEnv,
      WRITE_MODE: "disabled",
    }, { clerkInstanceId, clerkUserId })).toEqual({ kind: "gate_closed" });
    expect(await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId))).toHaveLength(0);
  });

  it("creates one server-generated app UUID across concurrent stateful retries", async () => {
    const [first, second] = await Promise.all([
      provisionNewUserAfterReconciliation(db, statefulEnv, {
        clerkInstanceId,
        clerkUserId,
        email: "stateful-new@example.com",
      }),
      provisionNewUserAfterReconciliation(db, statefulEnv, {
        clerkInstanceId,
        clerkUserId,
        email: "stateful-new@example.com",
      }),
    ]);
    expect(new Set([first.kind, second.kind])).toEqual(new Set(["created", "existing"]));
    if (
      (first.kind !== "created" && first.kind !== "existing")
      || (second.kind !== "created" && second.kind !== "existing")
    ) {
      throw new Error("stateful onboarding gate unexpectedly closed");
    }
    expect(first.user.id).toBe(second.user.id);
    expect(await db.select().from(appUsers).where(eq(appUsers.clerkUserId, clerkUserId))).toHaveLength(1);
  });

  it("makes the activated stateful registry and preserved app-user identity immutable", async () => {
    await expect(db.update(identityReconciliationLegacyMappings)
      .set({ clerkUserId: `user_stateful_swapped_${runSuffix}` })
      .where(eq(identityReconciliationLegacyMappings.clerkUserId, legacyClerkUserId)))
      .rejects.toThrow(/Failed query/);
    await expect(db.update(appUsers)
      .set({ clerkUserId: `user_stateful_corrupted_${runSuffix}` })
      .where(eq(appUsers.id, legacyAppUserId)))
      .rejects.toThrow(/Failed query/);
    await expect(db.delete(appUsers).where(eq(appUsers.id, legacyAppUserId)))
      .rejects.toThrow(/Failed query/);
    await expect(db.update(identityReconciliationActivations)
      .set({ activatedAt: new Date() })
      .where(eq(identityReconciliationActivations.receiptDigest, receiptDigest)))
      .rejects.toThrow(/Failed query/);
    await expect(db.delete(identityReconciliationActivations)
      .where(eq(identityReconciliationActivations.receiptDigest, receiptDigest)))
      .rejects.toThrow(/Failed query/);

    const result = await provisionNewUserAfterReconciliation(db, statefulEnv, {
      clerkInstanceId,
      clerkUserId: legacyClerkUserId,
    });
    expect(result.kind).toBe("existing");
    if (result.kind === "existing") expect(result.user.id).toBe(legacyAppUserId);
  });

  it("serializes activation against an in-flight stateful registry mutation", async () => {
    const concurrentReceipt = hash(`stateful-concurrent:${runSuffix}`);
    const concurrentInstance = `ins_${runSuffix}race`;
    const concurrentAppUserId = crypto.randomUUID();
    const concurrentSubject = `user_stateful_activation_race_${runSuffix}`;
    const concurrentHash = hash(JSON.stringify([{
      app_user_id: concurrentAppUserId,
      clerk_user_id: concurrentSubject,
    }]));
    await db.insert(identityReconciliationReceipts).values({
      receiptDigest: concurrentReceipt,
      clerkInstanceId: concurrentInstance,
      reconciliationProfile: STATEFUL_RECONCILIATION_PROFILE,
      snapshotCapturedAt: new Date("2026-07-15T00:00:00Z"),
      legacyMappingCount: 1,
      excludedAuthCount: 1,
      mappingHash: concurrentHash,
      status: "verified",
      reviewedAt: new Date("2026-07-15T00:05:00Z"),
    });
    await db.insert(appUsers).values({ id: concurrentAppUserId, clerkUserId: concurrentSubject });
    await db.insert(identityReconciliationLegacyMappings).values({
      clerkInstanceId: concurrentInstance,
      clerkUserId: concurrentSubject,
      appUserId: concurrentAppUserId,
      receiptDigest: concurrentReceipt,
    });

    const mutator = await pool.connect();
    try {
      await mutator.query("begin");
      await mutator.query(
        "update identity_reconciliation_legacy_mappings set clerk_user_id = $1 where clerk_instance_id = $2 and clerk_user_id = $3",
        [`user_stateful_activation_race_swapped_${runSuffix}`, concurrentInstance, concurrentSubject],
      );
      const activation = activateIdentityReconciliationReceipt(db, concurrentReceipt, concurrentInstance);
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

  it("records delete-before-create and serializes concurrent create/delete", async () => {
    const deletedFirst = `user_stateful_deleted_first_${runSuffix}`;
    await recordClerkUserDeletion(db, {
      clerkInstanceId,
      clerkUserId: deletedFirst,
      webhookEventId: `evt_stateful_deleted_first_${runSuffix}`,
      deletedAt: new Date(),
    });
    expect(await provisionNewUserAfterReconciliation(db, statefulEnv, {
      clerkInstanceId,
      clerkUserId: deletedFirst,
    })).toEqual({ kind: "subject_deleted" });

    const concurrentSubject = `user_stateful_concurrent_delete_${runSuffix}`;
    await Promise.all([
      provisionNewUserAfterReconciliation(db, statefulEnv, {
        clerkInstanceId,
        clerkUserId: concurrentSubject,
      }),
      recordClerkUserDeletion(db, {
        clerkInstanceId,
        clerkUserId: concurrentSubject,
        webhookEventId: `evt_stateful_concurrent_delete_${runSuffix}`,
        deletedAt: new Date(),
      }),
    ]);
    const [row] = await db.select().from(appUsers).where(eq(appUsers.clerkUserId, concurrentSubject));
    expect(row == null || row.deletedAt != null).toBe(true);
    expect(await provisionNewUserAfterReconciliation(db, statefulEnv, {
      clerkInstanceId,
      clerkUserId: concurrentSubject,
    })).toEqual({ kind: "subject_deleted" });
  });
});

function exactGreenfieldReceipt() {
  return {
    receiptDigest: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
    clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
    reconciliationProfile: GREENFIELD_RECONCILIATION_PROFILE,
    authorizationProfile: GREENFIELD_AUTHORIZATION_PROFILE,
    authorizationDigest: GREENFIELD_AUTHORIZATION_DIGEST,
    clerkIssuer: PRODUCTION_CLERK_ISSUER,
    clerkDomain: PRODUCTION_CLERK_DOMAIN,
    snapshotCapturedAt: baseTime,
    legacyMappingCount: 0,
    excludedAuthCount: 0,
    mappingHash: EMPTY_IDENTITY_MAPPING_HASH,
    status: "verified",
    reviewedAt: baseTime,
  };
}

function lifecycleEvent(
  clerkUserId: string,
  eventType: ClerkLifecycleEventType,
  webhookEventId: string,
  seconds: number,
  profile: Pick<ClerkUserLifecycleEvent, "email" | "displayName" | "avatarUrl"> = {},
): ClerkUserLifecycleEvent {
  return {
    clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
    clerkUserId,
    webhookEventId,
    eventType,
    payloadHash: hash(JSON.stringify({ clerkUserId, eventType, webhookEventId, seconds, profile })),
    occurredAt: new Date(baseTime.getTime() + seconds * 1_000),
    ...profile,
  };
}

function mutationContext(webhookEventId: string): MutationContext {
  return {
    sourceKind: "clerk_webhook",
    requestId: webhookEventId,
    sourceEventId: webhookEventId,
    workerVersionId: "77777777-7777-4777-8777-777777777777",
    method: "POST",
    path: "/webhooks/clerk",
    actorId: PRODUCTION_CLERK_INSTANCE_ID,
  };
}

function processLifecycle(event: ClerkUserLifecycleEvent) {
  return processClerkUserLifecycleEvent(db, greenfieldEnv, event, mutationContext(event.webhookEventId));
}

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function validatedLocalDatabaseURL(): string {
  const value = process.env.REFWATCH_LOCAL_DATABASE_URL;
  if (!value || process.env.REFWATCH_ALLOW_LOCAL_DATABASE_TESTS !== "1") {
    throw new Error("Database integration requires the hermetic loopback-only runner");
  }
  const parsed = new URL(value);
  if (
    parsed.protocol !== "postgresql:"
    || parsed.hostname !== "127.0.0.1"
    || parsed.pathname !== "/refwatch_greenfield_integration"
    || decodeURIComponent(parsed.username) !== "postgres"
    || parsed.password !== ""
    || parsed.searchParams.get("sslmode") !== "disable"
  ) {
    throw new Error("Database integration URL must target the exact disposable loopback database");
  }
  return value;
}
