import { and, asc, count, eq, sql } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import {
  appUsers,
  clerkUserDeletionTombstones,
  identityReconciliationActivations,
  identityReconciliationLegacyMappings,
  identityReconciliationReceipts,
} from "../db/schema";
import type * as schema from "../db/schema";
import type { Env } from "../types";
import { writesAreDisabled } from "../middleware/writeGate";
import { withMutation, type MutationContext, type MutationTransaction } from "./mutationLedger";

const sha256Pattern = /^[0-9a-f]{64}$/;
const clerkInstancePattern = /^ins_[A-Za-z0-9]+$/;

export interface NewUserOnboardingConfig {
  receiptDigest: string;
  clerkInstanceId: string;
}

export interface NewUserProfile {
  clerkInstanceId: string;
  clerkUserId: string;
  email?: string | null;
  displayName?: string | null;
  avatarUrl?: string | null;
}

export type NewUserProvisioningResult =
  | { kind: "gate_closed" }
  | { kind: "legacy_mapping_missing" | "subject_deleted" }
  | { kind: "created" | "existing"; user: typeof appUsers.$inferSelect };

export interface ClerkUserDeletion {
  clerkInstanceId: string;
  clerkUserId: string;
  webhookEventId?: string | null;
  deletedAt: Date;
}

export function newUserOnboardingConfig(
  env: Pick<Env, "WRITE_MODE" | "NEW_USER_ONBOARDING_MODE" | "IDENTITY_RECONCILIATION_RECEIPT" | "CLERK_INSTANCE_ID">,
): NewUserOnboardingConfig | null {
  if (writesAreDisabled(env)) return null;
  if (env.NEW_USER_ONBOARDING_MODE?.trim().toLowerCase() !== "post_reconciliation") return null;
  const receiptDigest = env.IDENTITY_RECONCILIATION_RECEIPT?.trim().toLowerCase() ?? "";
  const clerkInstanceId = env.CLERK_INSTANCE_ID?.trim() ?? "";
  if (!sha256Pattern.test(receiptDigest) || !clerkInstancePattern.test(clerkInstanceId)) return null;
  return { receiptDigest, clerkInstanceId };
}

export async function provisionNewUserAfterReconciliation(
  db: NodePgDatabase<typeof schema>,
  env: Pick<Env, "WRITE_MODE" | "NEW_USER_ONBOARDING_MODE" | "IDENTITY_RECONCILIATION_RECEIPT" | "CLERK_INSTANCE_ID">,
  profile: NewUserProfile,
  mutationContext?: MutationContext,
): Promise<NewUserProvisioningResult> {
  const config = newUserOnboardingConfig(env);
  if (!config) return { kind: "gate_closed" };
  if (profile.clerkInstanceId !== config.clerkInstanceId) return { kind: "gate_closed" };

  return runMutation(db, mutationContext, async (tx) => {
    await lockClerkSubject(tx, profile.clerkInstanceId, profile.clerkUserId);

    const [tombstone] = await tx.select({ clerkUserId: clerkUserDeletionTombstones.clerkUserId })
      .from(clerkUserDeletionTombstones)
      .where(and(
        eq(clerkUserDeletionTombstones.clerkInstanceId, profile.clerkInstanceId),
        eq(clerkUserDeletionTombstones.clerkUserId, profile.clerkUserId),
      )).limit(1);
    if (tombstone) return { kind: "subject_deleted" } as const;

    const [legacyMapping] = await tx.select({ appUserId: identityReconciliationLegacyMappings.appUserId })
      .from(identityReconciliationLegacyMappings)
      .where(and(
        eq(identityReconciliationLegacyMappings.clerkInstanceId, profile.clerkInstanceId),
        eq(identityReconciliationLegacyMappings.clerkUserId, profile.clerkUserId),
      )).limit(1);
    if (legacyMapping) {
      const [legacyUser] = await tx.select().from(appUsers).where(and(
        eq(appUsers.id, legacyMapping.appUserId),
        eq(appUsers.clerkUserId, profile.clerkUserId),
      )).limit(1);
      return legacyUser
        ? { kind: "existing", user: legacyUser } as const
        : { kind: "legacy_mapping_missing" } as const;
    }

    const [receipt] = await tx.select({
      id: identityReconciliationReceipts.id,
      legacyMappingCount: identityReconciliationReceipts.legacyMappingCount,
    })
      .from(identityReconciliationReceipts)
      .where(and(
        eq(identityReconciliationReceipts.receiptDigest, config.receiptDigest),
        eq(identityReconciliationReceipts.clerkInstanceId, config.clerkInstanceId),
        eq(identityReconciliationReceipts.status, "verified"),
      ))
      .limit(1);
    if (!receipt) return { kind: "gate_closed" } as const;
    const [activation] = await tx.select({ receiptDigest: identityReconciliationActivations.receiptDigest })
      .from(identityReconciliationActivations)
      .where(and(
        eq(identityReconciliationActivations.receiptDigest, config.receiptDigest),
        eq(identityReconciliationActivations.clerkInstanceId, config.clerkInstanceId),
      )).limit(1);
    if (!activation) return { kind: "gate_closed" } as const;

    const [registry] = await tx.select({ value: count() })
      .from(identityReconciliationLegacyMappings)
      .where(and(
        eq(identityReconciliationLegacyMappings.clerkInstanceId, config.clerkInstanceId),
        eq(identityReconciliationLegacyMappings.receiptDigest, config.receiptDigest),
      ));
    if (registry?.value !== receipt.legacyMappingCount) return { kind: "gate_closed" } as const;

    const [created] = await tx.insert(appUsers).values({
      clerkUserId: profile.clerkUserId,
      email: profile.email ?? null,
      displayName: profile.displayName ?? null,
      avatarUrl: profile.avatarUrl ?? null,
    }).onConflictDoNothing({ target: appUsers.clerkUserId }).returning();
    if (created) return { kind: "created", user: created } as const;

    const [existing] = await tx.select().from(appUsers)
      .where(eq(appUsers.clerkUserId, profile.clerkUserId)).limit(1);
    if (!existing) throw new Error("Unable to resolve concurrently provisioned app user");
    return { kind: "existing", user: existing } as const;
  });
}

export async function recordClerkUserDeletion(
  db: NodePgDatabase<typeof schema>,
  deletion: ClerkUserDeletion,
  mutationContext?: MutationContext,
): Promise<void> {
  await runMutation(db, mutationContext, async (tx) => {
    await lockClerkSubject(tx, deletion.clerkInstanceId, deletion.clerkUserId);
    await tx.insert(clerkUserDeletionTombstones).values({
      clerkInstanceId: deletion.clerkInstanceId,
      clerkUserId: deletion.clerkUserId,
      webhookEventId: deletion.webhookEventId ?? null,
      deletedAt: deletion.deletedAt,
    }).onConflictDoUpdate({
      target: [clerkUserDeletionTombstones.clerkInstanceId, clerkUserDeletionTombstones.clerkUserId],
      set: {
        webhookEventId: deletion.webhookEventId ?? null,
        deletedAt: deletion.deletedAt,
        receivedAt: new Date(),
      },
    });
    await tx.update(appUsers).set({ deletedAt: deletion.deletedAt, updatedAt: deletion.deletedAt })
      .where(eq(appUsers.clerkUserId, deletion.clerkUserId));
  });
}

export async function activateIdentityReconciliationReceipt(
  db: NodePgDatabase<typeof schema>,
  receiptDigest: string,
  clerkInstanceId: string,
): Promise<boolean> {
  return db.transaction(async (tx) => {
    await tx.execute(sql`select pg_advisory_xact_lock(hashtextextended(${`reconciliation:${clerkInstanceId}`}, 0))`);
    const [receipt] = await tx.select().from(identityReconciliationReceipts).where(and(
      eq(identityReconciliationReceipts.receiptDigest, receiptDigest),
      eq(identityReconciliationReceipts.clerkInstanceId, clerkInstanceId),
      eq(identityReconciliationReceipts.status, "verified"),
    )).limit(1);
    if (!receipt) return false;

    const mappings = await tx.select({
      app_user_id: identityReconciliationLegacyMappings.appUserId,
      clerk_user_id: identityReconciliationLegacyMappings.clerkUserId,
      actual_clerk_user_id: appUsers.clerkUserId,
    }).from(identityReconciliationLegacyMappings)
      .innerJoin(appUsers, eq(appUsers.id, identityReconciliationLegacyMappings.appUserId))
      .where(and(
        eq(identityReconciliationLegacyMappings.receiptDigest, receiptDigest),
        eq(identityReconciliationLegacyMappings.clerkInstanceId, clerkInstanceId),
      ))
      .orderBy(asc(identityReconciliationLegacyMappings.appUserId));
    if (mappings.length !== receipt.legacyMappingCount) return false;
    if (mappings.some((mapping) => mapping.clerk_user_id !== mapping.actual_clerk_user_id)) return false;
    const mappingHash = await sha256(JSON.stringify(mappings.map(({ app_user_id, clerk_user_id }) => ({
      app_user_id: app_user_id.toLowerCase(),
      clerk_user_id,
    }))));
    if (mappingHash !== receipt.mappingHash) return false;

    const activated = await tx.insert(identityReconciliationActivations).values({
      receiptDigest,
      clerkInstanceId,
    }).onConflictDoNothing().returning({ receiptDigest: identityReconciliationActivations.receiptDigest });
    return activated.length === 1;
  });
}

async function lockClerkSubject(
  tx: Parameters<Parameters<NodePgDatabase<typeof schema>["transaction"]>[0]>[0],
  clerkInstanceId: string,
  clerkUserId: string,
): Promise<void> {
  await tx.execute(sql`select pg_advisory_xact_lock(hashtextextended(${`${clerkInstanceId}:${clerkUserId}`}, 0))`);
}

function runMutation<T>(
  db: NodePgDatabase<typeof schema>,
  context: MutationContext | undefined,
  work: (tx: MutationTransaction) => Promise<T>,
): Promise<T> {
  return context ? withMutation(db, context, work) : db.transaction(work);
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
