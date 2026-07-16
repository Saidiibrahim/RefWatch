import { and, eq, sql } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import { mutationLedgerEpochs, mutationOutboxEvents } from "../db/schema";
import type * as schema from "../db/schema";

// Fixed namespace key for the ledger barrier. All included writers acquire the
// shared form before any subject/entity lock; open/freeze acquires the exclusive
// form and therefore waits for every earlier writer transaction to finish.
export const MUTATION_LEDGER_LOCK_KEY = 593105010451970337n;

type Database = NodePgDatabase<typeof schema>;
export type MutationTransaction = Parameters<Parameters<Database["transaction"]>[0]>[0];

export type MutationSourceKind = "http" | "clerk_webhook" | "clerk_onboarding" | "admin";

export interface MutationContext {
  sourceKind: MutationSourceKind;
  requestId: string;
  workerVersionId: string;
  mutationGroupId?: string;
  sourceEventId?: string | null;
  idempotencyKey?: string | null;
  appUserId?: string | null;
  method?: string | null;
  path?: string | null;
  actorId?: string | null;
}

export async function withMutation<T>(
  db: Database,
  context: MutationContext,
  work: (tx: MutationTransaction) => Promise<T>,
): Promise<T> {
  const mutationGroupId = context.mutationGroupId ?? crypto.randomUUID();
  return db.transaction(async (tx) => {
    // Global ledger lock must always precede subject/entity advisory locks.
    await tx.execute(sql`select pg_advisory_xact_lock_shared(${MUTATION_LEDGER_LOCK_KEY})`);
    await setLocal(tx, "mutation_group_id", mutationGroupId);
    await setLocal(tx, "group_ordinal", "0");
    await setLocal(tx, "source_kind", context.sourceKind);
    await setLocal(tx, "source_event_id", context.sourceEventId);
    await setLocal(tx, "request_id", context.requestId);
    await setLocal(tx, "idempotency_key", context.idempotencyKey);
    await setLocal(tx, "app_user_id", context.appUserId);
    await setLocal(tx, "method", context.method);
    await setLocal(tx, "path", context.path);
    await setLocal(tx, "actor_id", context.actorId);
    await setLocal(tx, "worker_version_id", context.workerVersionId);
    return work(tx);
  });
}

export async function openMutationLedgerEpoch(db: Database, epochId: string): Promise<boolean> {
  return db.transaction(async (tx) => {
    await tx.execute(sql`select pg_advisory_xact_lock(${MUTATION_LEDGER_LOCK_KEY})`);
    const opened = await tx.update(mutationLedgerEpochs).set({
      status: "open",
      captureEnforced: true,
      openedAt: new Date(),
      updatedAt: new Date(),
    }).where(and(
      eq(mutationLedgerEpochs.id, epochId),
      eq(mutationLedgerEpochs.status, "preparing"),
      eq(mutationLedgerEpochs.captureEnforced, false),
    )).returning({ id: mutationLedgerEpochs.id });
    return opened.length === 1;
  });
}

export async function freezeMutationLedgerEpoch(db: Database, epochId: string): Promise<number | null> {
  return db.transaction(async (tx) => {
    await tx.execute(sql`select pg_advisory_xact_lock(${MUTATION_LEDGER_LOCK_KEY})`);
    const [maximum] = await tx.select({ value: sql<number>`coalesce(max(${mutationOutboxEvents.eventSequence}), 0)` })
      .from(mutationOutboxEvents)
      .where(eq(mutationOutboxEvents.epochId, epochId));
    const highWatermark = Number(maximum?.value ?? 0);
    const frozen = await tx.update(mutationLedgerEpochs).set({
      status: "frozen",
      frozenAt: new Date(),
      frozenEventSequence: highWatermark,
      updatedAt: new Date(),
    }).where(and(
      eq(mutationLedgerEpochs.id, epochId),
      eq(mutationLedgerEpochs.status, "open"),
      eq(mutationLedgerEpochs.captureEnforced, true),
    )).returning({ id: mutationLedgerEpochs.id });
    return frozen.length === 1 ? highWatermark : null;
  });
}

async function setLocal(tx: MutationTransaction, name: string, value: string | null | undefined): Promise<void> {
  await tx.execute(sql`select set_config(${`refwatch.${name}`}, ${value ?? ""}, true)`);
}
