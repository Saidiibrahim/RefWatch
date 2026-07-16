import { and, eq, sql } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import {
  mutationOutboxDeliveries,
  mutationOutboxEvents,
} from "../db/schema";
import type * as schema from "../db/schema";
import type { Env } from "../types";

type Database = NodePgDatabase<typeof schema>;
export interface MutationLedgerMessage { eventId: string; leaseGeneration: number }
export const MUTATION_LEDGER_MAX_QUEUE_ATTEMPTS = 6;
export const MUTATION_LEDGER_MAX_ENVELOPE_BYTES = 256 * 1_024;
export const MUTATION_LEDGER_MAX_CAPTURE_BYTES = 240 * 1_024;

export interface LedgerEncryptionConfig {
  currentKeyBase64: string;
  currentKeyId: string;
  decryptionKeys: Record<string, string>;
}

interface ClaimedDelivery {
  [key: string]: unknown;
  event_id: string;
  lease_generation: string | number;
}

interface MaterializedLedgerEvent {
  eventId: string;
  eventSequence: number;
  epochId: string;
  mutationGroupId: string;
  groupOrdinal: number;
  schemaVersion: number;
  sourceKind: string;
  workerVersionId: string;
  contentDigest: string;
  encryptionKeyId: string;
  encryptionNonce: string;
  encryptedEnvelope: string;
}

interface D1LedgerEvent {
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
}

interface D1DeadLetterReceipt {
  event_id: string;
  lease_generation: number;
  source_queue: string;
  dlq_consumer_attempt: number;
  disposition: string;
}

class LedgerDeliveryError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "LedgerDeliveryError";
  }
}

export async function claimPendingDeliveries(
  db: Database,
  limit = 50,
  leaseSeconds = 120,
  epochId?: string,
): Promise<MutationLedgerMessage[]> {
  const boundedLimit = Math.max(1, Math.min(100, Math.trunc(limit)));
  const boundedLease = Math.max(30, Math.min(900, Math.trunc(leaseSeconds)));
  const result = await db.execute<ClaimedDelivery>(sql`
    with candidates as (
      select delivery.event_id
      from mutation_outbox_deliveries delivery
      inner join mutation_outbox_events event on event.event_id = delivery.event_id
      inner join mutation_ledger_epochs epoch on epoch.id = event.epoch_id
      where delivery.state in ('pending', 'leased')
        and delivery.next_attempt_at <= now()
        and (delivery.state = 'pending' or delivery.leased_until <= now())
        and (${epochId ?? null}::uuid is null or event.epoch_id = ${epochId ?? null}::uuid)
        and (${epochId ?? null}::uuid is not null or epoch.baseline_snapshot_id not like 'integration-%')
      order by delivery.next_attempt_at, delivery.event_id
      for update of delivery skip locked
      limit ${boundedLimit}
    )
    update mutation_outbox_deliveries delivery
    set state = 'leased',
        lease_generation = delivery.lease_generation + 1,
        leased_until = now() + (${boundedLease} * interval '1 second'),
        attempt_count = delivery.attempt_count + 1,
        last_error = null,
        updated_at = now()
    from candidates
    where delivery.event_id = candidates.event_id
    returning delivery.event_id, delivery.lease_generation
  `);
  return result.rows.map((row) => ({
    eventId: row.event_id,
    leaseGeneration: Number(row.lease_generation),
  }));
}

export async function processLedgerMessage(
  db: Database,
  d1: D1Database,
  message: MutationLedgerMessage,
  encryption: LedgerEncryptionConfig,
): Promise<"delivered" | "stale"> {
  const materialized = await loadOrMaterialize(db, message, encryption);
  if (!materialized) return "stale";

  await d1.prepare(`
    INSERT INTO mutation_ledger_events (
      event_id, event_sequence, epoch_id, mutation_group_id, group_ordinal,
      schema_version, source_kind, worker_version_id, content_digest,
      encryption_key_id, encryption_nonce, encrypted_envelope, materialized_at_utc
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(event_id) DO NOTHING
  `).bind(
    materialized.eventId,
    materialized.eventSequence,
    materialized.epochId,
    materialized.mutationGroupId,
    materialized.groupOrdinal,
    materialized.schemaVersion,
    materialized.sourceKind,
    materialized.workerVersionId,
    materialized.contentDigest,
    materialized.encryptionKeyId,
    materialized.encryptionNonce,
    materialized.encryptedEnvelope,
    new Date().toISOString(),
  ).run();

  const existing = await d1.prepare(`
    SELECT event_sequence, epoch_id, mutation_group_id, group_ordinal,
           schema_version, source_kind, worker_version_id, content_digest,
           encryption_key_id, encryption_nonce, encrypted_envelope
    FROM mutation_ledger_events WHERE event_id = ?
  `).bind(materialized.eventId).first<D1LedgerEvent>();
  if (!existing) throw new LedgerDeliveryError("d1_missing_event");
  assertD1Metadata(existing, materialized);
  const decryptionKey = encryption.decryptionKeys[existing.encryption_key_id];
  if (!decryptionKey) throw new LedgerDeliveryError("encryption_key_unavailable");
  const decrypted = await decryptEnvelope({
    keyBase64: decryptionKey,
    eventId: materialized.eventId,
    schemaVersion: materialized.schemaVersion,
    contentDigest: existing.content_digest,
    nonceBase64: existing.encryption_nonce,
    ciphertextBase64: existing.encrypted_envelope,
  });
  if (await sha256Hex(decrypted) !== existing.content_digest) {
    throw new LedgerDeliveryError("d1_authentication_mismatch");
  }

  const acknowledged = await db.update(mutationOutboxDeliveries).set({
    state: "delivered",
    deliveredAt: new Date(),
    leasedUntil: null,
    updatedAt: new Date(),
  }).where(and(
    eq(mutationOutboxDeliveries.eventId, message.eventId),
    eq(mutationOutboxDeliveries.state, "leased"),
    eq(mutationOutboxDeliveries.leaseGeneration, message.leaseGeneration),
  )).returning({ id: mutationOutboxDeliveries.eventId });
  return acknowledged.length === 1 ? "delivered" : "stale";
}

export async function recordLedgerDeliveryFailure(
  db: Database,
  message: MutationLedgerMessage,
  error: unknown,
  queueAttempt: number,
  now = new Date(),
): Promise<"retrying" | "quarantined" | "stale"> {
  const boundedAttempt = Math.max(1, Math.trunc(queueAttempt));
  const quarantined = boundedAttempt >= MUTATION_LEDGER_MAX_QUEUE_ATTEMPTS;
  const delaySeconds = Math.min(900, 2 ** Math.min(boundedAttempt, 9));
  const result = await db.update(mutationOutboxDeliveries).set({
    state: quarantined ? "quarantined" : "leased",
    lastError: `queue_attempt=${boundedAttempt}; code=${deliveryErrorCode(error)}`,
    nextAttemptAt: new Date(now.getTime() + delaySeconds * 1_000),
    leasedUntil: quarantined ? null : undefined,
    updatedAt: now,
  }).where(and(
    eq(mutationOutboxDeliveries.eventId, message.eventId),
    eq(mutationOutboxDeliveries.state, "leased"),
    eq(mutationOutboxDeliveries.leaseGeneration, message.leaseGeneration),
  )).returning({ id: mutationOutboxDeliveries.eventId });
  if (result.length !== 1) return "stale";
  return quarantined ? "quarantined" : "retrying";
}

export async function classifyDeadLetter(
  db: Database,
  message: MutationLedgerMessage,
): Promise<"quarantined" | "stale"> {
  const [delivery] = await db.select({
    state: mutationOutboxDeliveries.state,
    leaseGeneration: mutationOutboxDeliveries.leaseGeneration,
  }).from(mutationOutboxDeliveries)
    .where(eq(mutationOutboxDeliveries.eventId, message.eventId))
    .limit(1);
  return delivery?.state === "quarantined" && delivery.leaseGeneration === message.leaseGeneration
    ? "quarantined"
    : "stale";
}

export async function persistDeadLetterReceipt(
  d1: D1Database,
  receipt: {
    deadLetterId: string;
    eventId: string;
    leaseGeneration: number;
    sourceQueue: string;
    consumerAttempt: number;
    disposition: "quarantined" | "stale";
    receivedAtUTC: string;
  },
): Promise<void> {
  await d1.prepare(`
    INSERT INTO mutation_ledger_dead_letters (
      dead_letter_id, event_id, lease_generation, source_queue,
      dlq_consumer_attempt, disposition, received_at_utc
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(dead_letter_id) DO NOTHING
  `).bind(
    receipt.deadLetterId,
    receipt.eventId,
    receipt.leaseGeneration,
    receipt.sourceQueue,
    receipt.consumerAttempt,
    receipt.disposition,
    receipt.receivedAtUTC,
  ).run();
  const existing = await d1.prepare(`
    SELECT event_id, lease_generation, source_queue, dlq_consumer_attempt, disposition
    FROM mutation_ledger_dead_letters
    WHERE dead_letter_id = ?
  `).bind(receipt.deadLetterId).first<D1DeadLetterReceipt>();
  if (!existing) throw new LedgerDeliveryError("d1_missing_dead_letter");
  const fields: Array<[keyof D1DeadLetterReceipt, string | number]> = [
    ["event_id", receipt.eventId],
    ["lease_generation", receipt.leaseGeneration],
    ["source_queue", receipt.sourceQueue],
    ["dlq_consumer_attempt", receipt.consumerAttempt],
    ["disposition", receipt.disposition],
  ];
  if (fields.some(([field, value]) => String(existing[field]) !== String(value))) {
    throw new LedgerDeliveryError("d1_dead_letter_metadata_conflict");
  }
}

export function ledgerEncryptionConfig(env: Env): LedgerEncryptionConfig {
  const keyBase64 = env.MUTATION_LEDGER_ENCRYPTION_KEY?.trim();
  const keyId = env.MUTATION_LEDGER_ENCRYPTION_KEY_ID?.trim();
  if (!keyBase64 || !keyId) throw new Error("Mutation ledger encryption binding is incomplete");
  let configuredKeys: unknown = {};
  if (env.MUTATION_LEDGER_DECRYPTION_KEYRING?.trim()) {
    try {
      configuredKeys = JSON.parse(env.MUTATION_LEDGER_DECRYPTION_KEYRING);
    } catch {
      throw new Error("Mutation ledger decryption keyring is invalid JSON");
    }
  }
  if (!configuredKeys || typeof configuredKeys !== "object" || Array.isArray(configuredKeys)) {
    throw new Error("Mutation ledger decryption keyring must be an object");
  }
  const decryptionKeys = { ...(configuredKeys as Record<string, string>), [keyId]: keyBase64 };
  for (const [configuredKeyId, value] of Object.entries(decryptionKeys)) {
    if (!configuredKeyId.trim() || typeof value !== "string" || fromBase64(value).byteLength !== 32) {
      throw new Error("Mutation ledger decryption keyring contains an invalid key");
    }
  }
  return { currentKeyBase64: keyBase64, currentKeyId: keyId, decryptionKeys };
}

async function loadOrMaterialize(
  db: Database,
  message: MutationLedgerMessage,
  encryption: LedgerEncryptionConfig,
): Promise<MaterializedLedgerEvent | null> {
  const [row] = await db.select({
    delivery: mutationOutboxDeliveries,
    event: mutationOutboxEvents,
  }).from(mutationOutboxDeliveries)
    .innerJoin(mutationOutboxEvents, eq(mutationOutboxDeliveries.eventId, mutationOutboxEvents.eventId))
    .where(and(
      eq(mutationOutboxDeliveries.eventId, message.eventId),
      eq(mutationOutboxDeliveries.state, "leased"),
      eq(mutationOutboxDeliveries.leaseGeneration, message.leaseGeneration),
    )).limit(1);
  if (!row) return null;

  let contentDigest = row.delivery.contentDigest;
  let encryptedEnvelope = row.delivery.encryptedEnvelope;
  let encryptionNonce = row.delivery.encryptionNonce;
  let encryptionKeyId = row.delivery.encryptionKeyId;
  if (!contentDigest || !encryptedEnvelope || !encryptionNonce || !encryptionKeyId) {
    const envelope = canonicalJSONString({
      schema_version: row.event.schemaVersion,
      event_id: row.event.eventId,
      event_sequence: row.event.eventSequence,
      epoch_id: row.event.epochId,
      mutation_group_id: row.event.mutationGroupId,
      group_ordinal: row.event.groupOrdinal,
      entity_type: row.event.tableName,
      entity_id: row.event.entityKey,
      entity_revision: row.event.entityRevision,
      operation: row.event.operation,
      before: row.event.beforeJSON,
      after: row.event.afterJSON,
      source_kind: row.event.sourceKind,
      source_event_id: row.event.sourceEventId,
      request_id: row.event.requestId,
      idempotency_key: row.event.idempotencyKey,
      app_user_id: row.event.appUserId,
      method: row.event.method,
      path: row.event.path,
      actor_id: row.event.actorId,
      worker_version_id: row.event.workerVersionId,
      captured_at_utc: row.event.capturedAt.toISOString(),
    });
    assertMutationLedgerEnvelopeSize(envelope);
    contentDigest = await sha256Hex(envelope);
    const encrypted = await encryptEnvelope({
      keyBase64: encryption.currentKeyBase64,
      keyId: encryption.currentKeyId,
      eventId: row.event.eventId,
      schemaVersion: row.event.schemaVersion,
      contentDigest,
      plaintext: envelope,
    });
    const persisted = await db.update(mutationOutboxDeliveries).set({
      contentDigest,
      encryptedEnvelope: encrypted.ciphertextBase64,
      encryptionNonce: encrypted.nonceBase64,
      encryptionKeyId: encryption.currentKeyId,
      updatedAt: new Date(),
    }).where(and(
      eq(mutationOutboxDeliveries.eventId, message.eventId),
      eq(mutationOutboxDeliveries.state, "leased"),
      eq(mutationOutboxDeliveries.leaseGeneration, message.leaseGeneration),
      sql`${mutationOutboxDeliveries.encryptedEnvelope} is null`,
    )).returning({ id: mutationOutboxDeliveries.eventId });
    if (!persisted.length) {
      return loadOrMaterialize(db, message, encryption);
    }
    encryptedEnvelope = encrypted.ciphertextBase64;
    encryptionNonce = encrypted.nonceBase64;
    encryptionKeyId = encryption.currentKeyId;
  }

  return {
    eventId: row.event.eventId,
    eventSequence: row.event.eventSequence,
    epochId: row.event.epochId,
    mutationGroupId: row.event.mutationGroupId,
    groupOrdinal: row.event.groupOrdinal,
    schemaVersion: row.event.schemaVersion,
    sourceKind: row.event.sourceKind,
    workerVersionId: row.event.workerVersionId,
    contentDigest,
    encryptionKeyId,
    encryptionNonce,
    encryptedEnvelope,
  };
}

export function canonicalJSONString(value: unknown): string {
  return JSON.stringify(canonicalValue(value));
}

export function assertMutationLedgerEnvelopeSize(envelope: string): void {
  if (new TextEncoder().encode(envelope).byteLength > MUTATION_LEDGER_MAX_ENVELOPE_BYTES) {
    throw new LedgerDeliveryError("envelope_too_large");
  }
}

function canonicalValue(value: unknown): unknown {
  if (value === null || typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Canonical JSON does not support non-finite numbers");
    return value;
  }
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (typeof value === "object") {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, item]) => [key, canonicalValue(item)]));
  }
  throw new Error(`Canonical JSON does not support ${typeof value}`);
}

function deliveryErrorCode(error: unknown): string {
  return error instanceof LedgerDeliveryError ? error.code : "delivery_failed";
}

function assertD1Metadata(existing: D1LedgerEvent, expected: MaterializedLedgerEvent): void {
  const fields: Array<[keyof D1LedgerEvent, string | number]> = [
    ["event_sequence", expected.eventSequence],
    ["epoch_id", expected.epochId],
    ["mutation_group_id", expected.mutationGroupId],
    ["group_ordinal", expected.groupOrdinal],
    ["schema_version", expected.schemaVersion],
    ["source_kind", expected.sourceKind],
    ["worker_version_id", expected.workerVersionId],
    ["content_digest", expected.contentDigest],
    ["encryption_key_id", expected.encryptionKeyId],
    ["encryption_nonce", expected.encryptionNonce],
    ["encrypted_envelope", expected.encryptedEnvelope],
  ];
  if (fields.some(([field, value]) => String(existing[field]) !== String(value))) {
    throw new LedgerDeliveryError("d1_metadata_conflict");
  }
}

async function encryptEnvelope(input: {
  keyBase64: string;
  keyId: string;
  eventId: string;
  schemaVersion: number;
  contentDigest: string;
  plaintext: string;
}): Promise<{ nonceBase64: string; ciphertextBase64: string }> {
  const key = await importEncryptionKey(input.keyBase64);
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt({
    name: "AES-GCM",
    iv: toArrayBuffer(nonce),
    additionalData: toArrayBuffer(aad(input.eventId, input.schemaVersion, input.contentDigest)),
  }, key, toArrayBuffer(new TextEncoder().encode(input.plaintext)));
  return { nonceBase64: toBase64(nonce), ciphertextBase64: toBase64(new Uint8Array(ciphertext)) };
}

async function decryptEnvelope(input: {
  keyBase64: string;
  eventId: string;
  schemaVersion: number;
  contentDigest: string;
  nonceBase64: string;
  ciphertextBase64: string;
}): Promise<string> {
  const key = await importEncryptionKey(input.keyBase64);
  const plaintext = await crypto.subtle.decrypt({
    name: "AES-GCM",
    iv: toArrayBuffer(fromBase64(input.nonceBase64)),
    additionalData: toArrayBuffer(aad(input.eventId, input.schemaVersion, input.contentDigest)),
  }, key, toArrayBuffer(fromBase64(input.ciphertextBase64)));
  return new TextDecoder().decode(plaintext);
}

function aad(eventId: string, schemaVersion: number, contentDigest: string): Uint8Array {
  return new TextEncoder().encode(`refwatch-ledger:${eventId}:${schemaVersion}:${contentDigest}`);
}

async function importEncryptionKey(keyBase64: string): Promise<CryptoKey> {
  const bytes = fromBase64(keyBase64);
  if (bytes.byteLength !== 32) throw new Error("Mutation ledger encryption key must be 32 bytes");
  return crypto.subtle.importKey("raw", toArrayBuffer(bytes), "AES-GCM", false, ["encrypt", "decrypt"]);
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function toBase64(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  return value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength) as ArrayBuffer;
}
