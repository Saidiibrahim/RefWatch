import { describe, expect, it } from "vitest";
import {
  assertMutationLedgerEnvelopeSize,
  ledgerEncryptionConfig,
  MUTATION_LEDGER_MAX_ENVELOPE_BYTES,
  persistDeadLetterReceipt,
} from "../src/services/mutationLedgerDelivery";

describe("mutation ledger delivery configuration", () => {
  it("accepts the exact envelope ceiling and rejects an oversized envelope", () => {
    expect(() => assertMutationLedgerEnvelopeSize("a".repeat(MUTATION_LEDGER_MAX_ENVELOPE_BYTES))).not.toThrow();
    expect(() => assertMutationLedgerEnvelopeSize("a".repeat(MUTATION_LEDGER_MAX_ENVELOPE_BYTES + 1)))
      .toThrow("envelope_too_large");
  });

  it("retains prior decryption keys while selecting the current encryption key", () => {
    const oldKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(1)));
    const currentKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(2)));
    const result = ledgerEncryptionConfig({
      MUTATION_LEDGER_ENCRYPTION_KEY: currentKey,
      MUTATION_LEDGER_ENCRYPTION_KEY_ID: "current",
      MUTATION_LEDGER_DECRYPTION_KEYRING: JSON.stringify({ old: oldKey }),
    } as never);
    expect(result).toEqual({
      currentKeyBase64: currentKey,
      currentKeyId: "current",
      decryptionKeys: { old: oldKey, current: currentKey },
    });
  });

  it("rejects an existing dead-letter receipt whose immutable metadata differs", async () => {
    const d1 = new FakeDeadLetterD1();
    const receipt = {
      deadLetterId: "dead-letter-1",
      eventId: "event-1",
      leaseGeneration: 3,
      sourceQueue: "ledger-dlq",
      consumerAttempt: 1,
      disposition: "quarantined" as const,
      receivedAtUTC: "2026-07-15T00:00:00.000Z",
    };
    await expect(persistDeadLetterReceipt(d1 as unknown as D1Database, receipt)).resolves.toBeUndefined();
    await expect(persistDeadLetterReceipt(d1 as unknown as D1Database, {
      ...receipt,
      eventId: "event-conflict",
    })).rejects.toThrow("d1_dead_letter_metadata_conflict");
  });
});

class FakeDeadLetterD1 {
  row: Record<string, string | number> | null = null;

  prepare(query: string) {
    let values: unknown[] = [];
    const statement = {
      bind: (...bound: unknown[]) => {
        values = bound;
        return statement;
      },
      run: async () => {
        if (query.includes("INSERT INTO mutation_ledger_dead_letters") && !this.row) {
          this.row = {
            event_id: String(values[1]),
            lease_generation: Number(values[2]),
            source_queue: String(values[3]),
            dlq_consumer_attempt: Number(values[4]),
            disposition: String(values[5]),
          };
        }
        return { success: true, results: [], meta: {} };
      },
      first: async () => this.row,
    };
    return statement;
  }
}
