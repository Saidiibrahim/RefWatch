import { and, asc, count, eq, isNull, lt, or, sql } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import {
  appUsers,
  clerkUserDeletionTombstones,
  clerkWebhookDeliveryReceipts,
  identityReconciliationActivations,
  identityReconciliationLegacyMappings,
  identityReconciliationReceipts,
} from "../db/schema";
import type * as schema from "../db/schema";
import type { Env } from "../types";
import { writesAreDisabled } from "../middleware/writeGate";
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
  sha256Hex,
  type OnboardingMode,
  type ReconciliationProfile,
} from "./identityProfiles";
import { withMutation, type MutationContext, type MutationTransaction } from "./mutationLedger";

const sha256Pattern = /^[0-9a-f]{64}$/;
const clerkInstancePattern = /^ins_[A-Za-z0-9]+$/;

type IdentityOnboardingEnv = Pick<
  Env,
  | "WRITE_MODE"
  | "NEW_USER_ONBOARDING_MODE"
  | "IDENTITY_RECONCILIATION_RECEIPT"
  | "IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST"
  | "CLERK_INSTANCE_ID"
  | "CLERK_ISSUER"
>;

export interface NewUserOnboardingConfig {
  onboardingMode: OnboardingMode;
  reconciliationProfile: ReconciliationProfile;
  receiptDigest: string;
  clerkInstanceId: string;
  clerkIssuer: string | null;
  clerkDomain: string | null;
  authorizationProfile: string | null;
  authorizationDigest: string | null;
}

export interface NewUserProfile {
  clerkInstanceId: string;
  clerkUserId: string;
  email?: string | null;
  displayName?: string | null;
  avatarUrl?: string | null;
  clerkProfileUpdatedAt?: Date | null;
}

export type NewUserProvisioningResult =
  | { kind: "gate_closed" }
  | { kind: "legacy_mapping_missing" }
  | { kind: "subject_deleted" }
  | { kind: "created" | "existing"; user: typeof appUsers.$inferSelect };

export interface ClerkUserDeletion {
  clerkInstanceId: string;
  clerkUserId: string;
  webhookEventId?: string | null;
  deletedAt: Date;
}

export type ClerkLifecycleEventType = "user.created" | "user.updated" | "user.deleted";

export interface ClerkUserLifecycleEvent {
  clerkInstanceId: string;
  clerkUserId: string;
  webhookEventId: string;
  eventType: ClerkLifecycleEventType;
  payloadHash: string;
  occurredAt: Date;
  email?: string | null;
  displayName?: string | null;
  avatarUrl?: string | null;
}

export type ClerkLifecycleResult =
  | { kind: "created" | "existing" | "updated" | "deleted" | "subject_deleted" | "duplicate" }
  | { kind: "gate_closed" | "legacy_mapping_missing" | "delivery_conflict" };

export interface ReconciliationActivationExpectation {
  reconciliationProfile: ReconciliationProfile;
  authorizationDigest?: string;
}

export function greenfieldReconciliationActivationExpectation(): ReconciliationActivationExpectation {
  return {
    reconciliationProfile: GREENFIELD_RECONCILIATION_PROFILE,
    authorizationDigest: GREENFIELD_AUTHORIZATION_DIGEST,
  };
}

export function newUserOnboardingConfig(env: IdentityOnboardingEnv): NewUserOnboardingConfig | null {
  if (writesAreDisabled(env)) return null;

  const onboardingMode = env.NEW_USER_ONBOARDING_MODE?.trim().toLowerCase();
  const receiptDigest = env.IDENTITY_RECONCILIATION_RECEIPT?.trim().toLowerCase() ?? "";
  const authorizationDigest = env.IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST?.trim().toLowerCase() ?? "";
  const clerkInstanceId = env.CLERK_INSTANCE_ID?.trim() ?? "";
  const clerkIssuer = normalizeIssuer(env.CLERK_ISSUER);
  if (!sha256Pattern.test(receiptDigest) || !clerkInstancePattern.test(clerkInstanceId)) return null;

  if (onboardingMode === POST_RECONCILIATION_ONBOARDING_MODE) {
    if (authorizationDigest) return null;
    return {
      onboardingMode,
      reconciliationProfile: STATEFUL_RECONCILIATION_PROFILE,
      receiptDigest,
      clerkInstanceId,
      clerkIssuer,
      clerkDomain: null,
      authorizationProfile: null,
      authorizationDigest: null,
    };
  }

  if (onboardingMode !== GREENFIELD_ONBOARDING_MODE) return null;
  if (
    receiptDigest !== GREENFIELD_RECONCILIATION_RECEIPT_DIGEST
    || authorizationDigest !== GREENFIELD_AUTHORIZATION_DIGEST
    || clerkInstanceId !== PRODUCTION_CLERK_INSTANCE_ID
    || clerkIssuer !== PRODUCTION_CLERK_ISSUER
  ) {
    return null;
  }
  return {
    onboardingMode,
    reconciliationProfile: GREENFIELD_RECONCILIATION_PROFILE,
    receiptDigest,
    clerkInstanceId,
    clerkIssuer,
    clerkDomain: PRODUCTION_CLERK_DOMAIN,
    authorizationProfile: GREENFIELD_AUTHORIZATION_PROFILE,
    authorizationDigest,
  };
}

export async function provisionNewUserAfterReconciliation(
  db: NodePgDatabase<typeof schema>,
  env: IdentityOnboardingEnv,
  profile: NewUserProfile,
  mutationContext?: MutationContext,
): Promise<NewUserProvisioningResult> {
  const config = newUserOnboardingConfig(env);
  if (!config || profile.clerkInstanceId !== config.clerkInstanceId) return { kind: "gate_closed" };

  return runMutation(db, mutationContext, async (tx) => {
    await lockClerkSubject(tx, profile.clerkInstanceId, profile.clerkUserId);
    return provisionNewUserInTransaction(tx, config, profile);
  });
}

export async function processClerkUserLifecycleEvent(
  db: NodePgDatabase<typeof schema>,
  env: IdentityOnboardingEnv,
  event: ClerkUserLifecycleEvent,
  mutationContext: MutationContext,
): Promise<ClerkLifecycleResult> {
  if (writesAreDisabled(env)) return { kind: "gate_closed" };
  const configuredInstanceId = env.CLERK_INSTANCE_ID?.trim();
  if (!configuredInstanceId || configuredInstanceId !== event.clerkInstanceId) {
    return { kind: "gate_closed" };
  }
  if (!event.webhookEventId.trim() || !sha256Pattern.test(event.payloadHash)) {
    return { kind: "gate_closed" };
  }

  const config = event.eventType === "user.deleted" ? null : newUserOnboardingConfig(env);
  if (event.eventType !== "user.deleted" && (!config || config.clerkInstanceId !== event.clerkInstanceId)) {
    return { kind: "gate_closed" };
  }

  try {
    return await runMutation(db, mutationContext, async (tx) => {
      await lockWebhookDelivery(tx, event.clerkInstanceId, event.webhookEventId);
      await lockClerkSubject(tx, event.clerkInstanceId, event.clerkUserId);
      const deliveryResult = await recordWebhookDelivery(tx, event);
      if (deliveryResult !== "inserted") return { kind: deliveryResult } as const;

      if (event.eventType === "user.deleted") {
        await recordClerkUserDeletionInTransaction(tx, {
          clerkInstanceId: event.clerkInstanceId,
          clerkUserId: event.clerkUserId,
          webhookEventId: event.webhookEventId,
          deletedAt: event.occurredAt,
        });
        return { kind: "deleted" } as const;
      }

      const provisioned = await provisionNewUserInTransaction(tx, config!, {
        clerkInstanceId: event.clerkInstanceId,
        clerkUserId: event.clerkUserId,
        email: event.email ?? null,
        displayName: event.displayName ?? null,
        avatarUrl: event.avatarUrl ?? null,
        clerkProfileUpdatedAt: event.occurredAt,
      });
      if (provisioned.kind === "gate_closed" || provisioned.kind === "legacy_mapping_missing") {
        throw new RetryableLifecycleError(provisioned.kind);
      }
      if (provisioned.kind === "subject_deleted") return { kind: "subject_deleted" } as const;

      const changed = await updateClerkProfileInTransaction(tx, provisioned.user, event);
      if (provisioned.kind === "created") return { kind: "created" } as const;
      return { kind: changed ? "updated" : "existing" } as const;
    });
  } catch (error) {
    if (error instanceof RetryableLifecycleError) return { kind: error.result };
    throw error;
  }
}

export async function recordClerkUserDeletion(
  db: NodePgDatabase<typeof schema>,
  deletion: ClerkUserDeletion,
  mutationContext?: MutationContext,
): Promise<void> {
  await runMutation(db, mutationContext, async (tx) => {
    await lockClerkSubject(tx, deletion.clerkInstanceId, deletion.clerkUserId);
    await recordClerkUserDeletionInTransaction(tx, deletion);
  });
}

export async function activateIdentityReconciliationReceipt(
  db: NodePgDatabase<typeof schema>,
  receiptDigest: string,
  clerkInstanceId: string,
  expected: ReconciliationActivationExpectation = {
    reconciliationProfile: STATEFUL_RECONCILIATION_PROFILE,
  },
): Promise<boolean> {
  if (
    expected.reconciliationProfile === GREENFIELD_RECONCILIATION_PROFILE
    && (
      expected.authorizationDigest !== GREENFIELD_AUTHORIZATION_DIGEST
      || receiptDigest !== GREENFIELD_RECONCILIATION_RECEIPT_DIGEST
      || clerkInstanceId !== PRODUCTION_CLERK_INSTANCE_ID
    )
  ) {
    return false;
  }

  return db.transaction(async (tx) => {
    await tx.execute(sql`select pg_advisory_xact_lock(hashtextextended(${`reconciliation:${clerkInstanceId}`}, 0))`);
    const receiptConditions = [
      eq(identityReconciliationReceipts.receiptDigest, receiptDigest),
      eq(identityReconciliationReceipts.clerkInstanceId, clerkInstanceId),
      eq(identityReconciliationReceipts.status, "verified"),
      eq(identityReconciliationReceipts.reconciliationProfile, expected.reconciliationProfile),
    ];
    if (expected.reconciliationProfile === GREENFIELD_RECONCILIATION_PROFILE) {
      receiptConditions.push(
        eq(identityReconciliationReceipts.authorizationProfile, GREENFIELD_AUTHORIZATION_PROFILE),
        eq(identityReconciliationReceipts.authorizationDigest, GREENFIELD_AUTHORIZATION_DIGEST),
        eq(identityReconciliationReceipts.clerkIssuer, PRODUCTION_CLERK_ISSUER),
        eq(identityReconciliationReceipts.clerkDomain, PRODUCTION_CLERK_DOMAIN),
      );
    } else {
      receiptConditions.push(
        isNull(identityReconciliationReceipts.authorizationProfile),
        isNull(identityReconciliationReceipts.authorizationDigest),
        isNull(identityReconciliationReceipts.clerkIssuer),
        isNull(identityReconciliationReceipts.clerkDomain),
      );
    }

    const [receipt] = await tx.select().from(identityReconciliationReceipts)
      .where(and(...receiptConditions)).limit(1);
    if (!receipt) return false;

    const [existingActivation] = await tx.select({
      receiptDigest: identityReconciliationActivations.receiptDigest,
    }).from(identityReconciliationActivations)
      .where(and(
        eq(identityReconciliationActivations.receiptDigest, receiptDigest),
        eq(identityReconciliationActivations.clerkInstanceId, clerkInstanceId),
      ))
      .limit(1);
    if (existingActivation) return true;

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
    const mappingHash = await sha256Hex(JSON.stringify(mappings.map(({ app_user_id, clerk_user_id }) => ({
      app_user_id: app_user_id.toLowerCase(),
      clerk_user_id,
    }))));
    if (mappingHash !== receipt.mappingHash) return false;

    if (expected.reconciliationProfile === GREENFIELD_RECONCILIATION_PROFILE) {
      if (
        receipt.legacyMappingCount !== 0
        || receipt.excludedAuthCount !== 0
        || receipt.mappingHash !== EMPTY_IDENTITY_MAPPING_HASH
      ) {
        return false;
      }
      const [userCount] = await tx.select({ value: count() }).from(appUsers);
      if (userCount?.value !== 0) return false;
    }

    const activated = await tx.insert(identityReconciliationActivations).values({
      receiptDigest,
      clerkInstanceId,
    }).onConflictDoNothing().returning({ receiptDigest: identityReconciliationActivations.receiptDigest });
    if (activated.length === 1) return true;

    const [existing] = await tx.select({ receiptDigest: identityReconciliationActivations.receiptDigest })
      .from(identityReconciliationActivations)
      .where(and(
        eq(identityReconciliationActivations.receiptDigest, receiptDigest),
        eq(identityReconciliationActivations.clerkInstanceId, clerkInstanceId),
      ))
      .limit(1);
    return Boolean(existing);
  });
}

async function provisionNewUserInTransaction(
  tx: MutationTransaction,
  config: NewUserOnboardingConfig,
  profile: NewUserProfile,
): Promise<NewUserProvisioningResult> {
  const [tombstone] = await tx.select({ clerkUserId: clerkUserDeletionTombstones.clerkUserId })
    .from(clerkUserDeletionTombstones)
    .where(and(
      eq(clerkUserDeletionTombstones.clerkInstanceId, profile.clerkInstanceId),
      eq(clerkUserDeletionTombstones.clerkUserId, profile.clerkUserId),
    )).limit(1);
  if (tombstone) return { kind: "subject_deleted" };

  const [legacyMapping] = await tx.select({ appUserId: identityReconciliationLegacyMappings.appUserId })
    .from(identityReconciliationLegacyMappings)
    .where(and(
      eq(identityReconciliationLegacyMappings.clerkInstanceId, profile.clerkInstanceId),
      eq(identityReconciliationLegacyMappings.clerkUserId, profile.clerkUserId),
    )).limit(1);
  if (legacyMapping) {
    if (config.reconciliationProfile === GREENFIELD_RECONCILIATION_PROFILE) {
      return { kind: "gate_closed" };
    }
    const [legacyUser] = await tx.select().from(appUsers).where(and(
      eq(appUsers.id, legacyMapping.appUserId),
      eq(appUsers.clerkUserId, profile.clerkUserId),
    )).limit(1);
    if (legacyUser?.deletedAt) return { kind: "subject_deleted" };
    return legacyUser
      ? { kind: "existing", user: legacyUser }
      : { kind: "legacy_mapping_missing" };
  }

  const receiptConditions = [
    eq(identityReconciliationReceipts.receiptDigest, config.receiptDigest),
    eq(identityReconciliationReceipts.clerkInstanceId, config.clerkInstanceId),
    eq(identityReconciliationReceipts.status, "verified"),
    eq(identityReconciliationReceipts.reconciliationProfile, config.reconciliationProfile),
  ];
  if (config.reconciliationProfile === GREENFIELD_RECONCILIATION_PROFILE) {
    receiptConditions.push(
      eq(identityReconciliationReceipts.authorizationProfile, GREENFIELD_AUTHORIZATION_PROFILE),
      eq(identityReconciliationReceipts.authorizationDigest, GREENFIELD_AUTHORIZATION_DIGEST),
      eq(identityReconciliationReceipts.clerkIssuer, PRODUCTION_CLERK_ISSUER),
      eq(identityReconciliationReceipts.clerkDomain, PRODUCTION_CLERK_DOMAIN),
    );
  } else {
    receiptConditions.push(
      isNull(identityReconciliationReceipts.authorizationProfile),
      isNull(identityReconciliationReceipts.authorizationDigest),
      isNull(identityReconciliationReceipts.clerkIssuer),
      isNull(identityReconciliationReceipts.clerkDomain),
    );
  }

  const [receipt] = await tx.select({
    id: identityReconciliationReceipts.id,
    legacyMappingCount: identityReconciliationReceipts.legacyMappingCount,
    excludedAuthCount: identityReconciliationReceipts.excludedAuthCount,
    mappingHash: identityReconciliationReceipts.mappingHash,
    authorizationDigest: identityReconciliationReceipts.authorizationDigest,
  })
    .from(identityReconciliationReceipts)
    .where(and(...receiptConditions))
    .limit(1);
  if (!receipt) return { kind: "gate_closed" };

  const [activation] = await tx.select({ receiptDigest: identityReconciliationActivations.receiptDigest })
    .from(identityReconciliationActivations)
    .where(and(
      eq(identityReconciliationActivations.receiptDigest, config.receiptDigest),
      eq(identityReconciliationActivations.clerkInstanceId, config.clerkInstanceId),
    )).limit(1);
  if (!activation) return { kind: "gate_closed" };

  const [registry] = await tx.select({ value: count() })
    .from(identityReconciliationLegacyMappings)
    .where(and(
      eq(identityReconciliationLegacyMappings.clerkInstanceId, config.clerkInstanceId),
      eq(identityReconciliationLegacyMappings.receiptDigest, config.receiptDigest),
    ));
  if (registry?.value !== receipt.legacyMappingCount) return { kind: "gate_closed" };
  if (
    config.reconciliationProfile === GREENFIELD_RECONCILIATION_PROFILE
    && (
      receipt.legacyMappingCount !== 0
      || receipt.excludedAuthCount !== 0
      || receipt.mappingHash !== EMPTY_IDENTITY_MAPPING_HASH
      || receipt.authorizationDigest !== GREENFIELD_AUTHORIZATION_DIGEST
    )
  ) {
    return { kind: "gate_closed" };
  }

  const [created] = await tx.insert(appUsers).values({
    clerkUserId: profile.clerkUserId,
    email: profile.email ?? null,
    displayName: profile.displayName ?? null,
    avatarUrl: profile.avatarUrl ?? null,
    clerkProfileUpdatedAt: profile.clerkProfileUpdatedAt ?? null,
  }).onConflictDoNothing({ target: appUsers.clerkUserId }).returning();
  if (created) return { kind: "created", user: created };

  const [existing] = await tx.select().from(appUsers)
    .where(eq(appUsers.clerkUserId, profile.clerkUserId)).limit(1);
  if (!existing) throw new Error("Unable to resolve concurrently provisioned app user");
  if (existing.deletedAt) return { kind: "subject_deleted" };
  return { kind: "existing", user: existing };
}

async function recordWebhookDelivery(
  tx: MutationTransaction,
  event: ClerkUserLifecycleEvent,
): Promise<"inserted" | "duplicate" | "delivery_conflict"> {
  const [inserted] = await tx.insert(clerkWebhookDeliveryReceipts).values({
    clerkInstanceId: event.clerkInstanceId,
    webhookEventId: event.webhookEventId,
    eventType: event.eventType,
    clerkUserId: event.clerkUserId,
    payloadHash: event.payloadHash,
  }).onConflictDoNothing().returning({
    webhookEventId: clerkWebhookDeliveryReceipts.webhookEventId,
  });
  if (inserted) return "inserted";

  const [existing] = await tx.select().from(clerkWebhookDeliveryReceipts).where(and(
    eq(clerkWebhookDeliveryReceipts.clerkInstanceId, event.clerkInstanceId),
    eq(clerkWebhookDeliveryReceipts.webhookEventId, event.webhookEventId),
  )).limit(1);
  if (
    existing
    && existing.eventType === event.eventType
    && existing.clerkUserId === event.clerkUserId
    && existing.payloadHash === event.payloadHash
  ) {
    return "duplicate";
  }
  return "delivery_conflict";
}

async function updateClerkProfileInTransaction(
  tx: MutationTransaction,
  currentUser: typeof appUsers.$inferSelect,
  event: ClerkUserLifecycleEvent,
): Promise<boolean> {
  const email = event.email ?? null;
  const displayName = event.displayName ?? null;
  const avatarUrl = event.avatarUrl ?? null;
  const profileChanged = currentUser.email !== email
    || currentUser.displayName !== displayName
    || currentUser.avatarUrl !== avatarUrl;
  const updated = await tx.update(appUsers).set({
    email,
    displayName,
    avatarUrl,
    clerkProfileUpdatedAt: event.occurredAt,
    updatedAt: sql`greatest(${appUsers.updatedAt}, ${event.occurredAt})`,
  }).where(and(
    eq(appUsers.id, currentUser.id),
    isNull(appUsers.deletedAt),
    or(
      isNull(appUsers.clerkProfileUpdatedAt),
      lt(appUsers.clerkProfileUpdatedAt, event.occurredAt),
    ),
  )).returning({ id: appUsers.id });
  return profileChanged && updated.length === 1;
}

async function recordClerkUserDeletionInTransaction(
  tx: MutationTransaction,
  deletion: ClerkUserDeletion,
): Promise<void> {
  await tx.insert(clerkUserDeletionTombstones).values({
    clerkInstanceId: deletion.clerkInstanceId,
    clerkUserId: deletion.clerkUserId,
    webhookEventId: deletion.webhookEventId ?? null,
    deletedAt: deletion.deletedAt,
  }).onConflictDoUpdate({
    target: [clerkUserDeletionTombstones.clerkInstanceId, clerkUserDeletionTombstones.clerkUserId],
    set: {
      webhookEventId: sql`case
        when excluded.deleted_at >= ${clerkUserDeletionTombstones.deletedAt}
          then excluded.webhook_event_id
        else ${clerkUserDeletionTombstones.webhookEventId}
      end`,
      deletedAt: sql`greatest(${clerkUserDeletionTombstones.deletedAt}, excluded.deleted_at)`,
      receivedAt: new Date(),
    },
  });
  await tx.update(appUsers).set({
    deletedAt: sql`greatest(coalesce(${appUsers.deletedAt}, ${deletion.deletedAt}), ${deletion.deletedAt})`,
    updatedAt: sql`greatest(${appUsers.updatedAt}, ${deletion.deletedAt})`,
  }).where(eq(appUsers.clerkUserId, deletion.clerkUserId));
}

async function lockClerkSubject(
  tx: MutationTransaction,
  clerkInstanceId: string,
  clerkUserId: string,
): Promise<void> {
  await tx.execute(sql`select pg_advisory_xact_lock(hashtextextended(${`${clerkInstanceId}:${clerkUserId}`}, 0))`);
}

async function lockWebhookDelivery(
  tx: MutationTransaction,
  clerkInstanceId: string,
  webhookEventId: string,
): Promise<void> {
  await tx.execute(sql`select pg_advisory_xact_lock(hashtextextended(${`clerk-webhook:${clerkInstanceId}:${webhookEventId}`}, 0))`);
}

function runMutation<T>(
  db: NodePgDatabase<typeof schema>,
  context: MutationContext | undefined,
  work: (tx: MutationTransaction) => Promise<T>,
): Promise<T> {
  return context ? withMutation(db, context, work) : db.transaction(work);
}

function normalizeIssuer(value: string | undefined): string | null {
  const normalized = value?.trim().replace(/\/$/, "");
  return normalized || null;
}

class RetryableLifecycleError extends Error {
  constructor(readonly result: "gate_closed" | "legacy_mapping_missing") {
    super(result);
    this.name = "RetryableLifecycleError";
  }
}
