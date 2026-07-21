import { sql } from "drizzle-orm";
import type { MutationTransaction } from "./mutationLedger";

export type EntityMutationNamespace =
  | "team"
  | "competition"
  | "venue"
  | "scheduled-match"
  | "match"
  | "match-assessment";

interface VersionedEntity {
  updatedAt: Date;
}

const ENTITY_LOCK_PREFIX = "refwatch:entity:v1";
const UNIQUE_LOCK_PREFIX = "refwatch:unique:v1";

/**
 * Acquires the one canonical lock for an entity, then reads its persisted
 * version and derives a timestamp strictly newer than that version.
 *
 * Callers must invoke this inside `withMutation`, which acquires the global
 * shared ledger lock first. Keeping that order prevents deadlocks with ledger
 * open/freeze operations.
 */
export async function lockAndVersionEntity<T extends VersionedEntity>(
  tx: MutationTransaction,
  namespace: EntityMutationNamespace,
  rawId: string,
  loadExisting: (normalizedId: string) => Promise<T | undefined>,
): Promise<{ id: string; existing: T | undefined; updatedAt: Date }> {
  const id = normalizeEntityMutationId(rawId);
  await acquireAdvisoryLock(tx, entityMutationAdvisoryKey(namespace, id));
  const existing = await loadExisting(id);
  const now = new Date();
  const persistedFloor = existing ? existing.updatedAt.getTime() + 1 : now.getTime();
  return {
    id,
    existing,
    updatedAt: new Date(Math.max(now.getTime(), persistedFloor)),
  };
}

export async function acquireSortedAdvisoryLocks(
  tx: MutationTransaction,
  keys: readonly string[],
): Promise<void> {
  for (const key of [...new Set(keys)].sort()) {
    await acquireAdvisoryLock(tx, key);
  }
}

export function entityMutationAdvisoryKey(
  namespace: EntityMutationNamespace,
  rawId: string,
): string {
  return `${ENTITY_LOCK_PREFIX}:${namespace}:${normalizeEntityMutationId(rawId)}`;
}

export function assessmentOwnerMatchAdvisoryKey(ownerId: string, matchId: string): string {
  return `${UNIQUE_LOCK_PREFIX}:match-assessment-owner-match:${normalizeEntityMutationId(ownerId)}:${normalizeEntityMutationId(matchId)}`;
}

export function normalizeEntityMutationId(value: string): string {
  return value.toLowerCase();
}

async function acquireAdvisoryLock(tx: MutationTransaction, key: string): Promise<void> {
  await tx.execute(sql`select pg_advisory_xact_lock(hashtextextended(${key}, 0))`);
}
