import { createApp } from "./app";
import { connectDatabase } from "./db/client";
import {
  claimPendingDeliveries,
  classifyDeadLetter,
  ledgerEncryptionConfig,
  persistDeadLetterReceipt,
  processLedgerMessage,
  recordLedgerDeliveryFailure,
  type MutationLedgerMessage,
} from "./services/mutationLedgerDelivery";
import type { Env } from "./types";

export const app = createApp();

export default {
  fetch: app.fetch,
  async scheduled(_controller, env): Promise<void> {
    if (!env.MUTATION_LEDGER_QUEUE) throw new Error("Mutation ledger Queue binding is missing");
    const connection = await connectDatabase(env);
    try {
      const messages = await claimPendingDeliveries(connection.db);
      if (messages.length) await env.MUTATION_LEDGER_QUEUE.sendBatch(messages.map((body) => ({ body })));
    } finally {
      await connection.close();
    }
  },
  async queue(batch, env): Promise<void> {
    if (!env.MUTATION_LEDGER) throw new Error("Mutation ledger D1 binding is missing");
    const connection = await connectDatabase(env);
    try {
      if (env.MUTATION_LEDGER_DLQ_NAME && batch.queue === env.MUTATION_LEDGER_DLQ_NAME) {
        for (const message of batch.messages) {
          const disposition = await classifyDeadLetter(connection.db, message.body);
          await persistDeadLetterReceipt(env.MUTATION_LEDGER, {
            deadLetterId: message.id,
            eventId: message.body.eventId,
            leaseGeneration: message.body.leaseGeneration,
            sourceQueue: batch.queue,
            consumerAttempt: message.attempts,
            disposition,
            receivedAtUTC: new Date().toISOString(),
          });
          message.ack();
        }
        return;
      }
      const encryption = ledgerEncryptionConfig(env);
      for (const message of batch.messages) {
        try {
          await processLedgerMessage(connection.db, env.MUTATION_LEDGER, message.body, encryption);
          message.ack();
        } catch (error) {
          const disposition = await recordLedgerDeliveryFailure(
            connection.db,
            message.body,
            error,
            message.attempts,
          ).catch(() => "stale" as const);
          console.error("Mutation ledger delivery failed", {
            eventId: message.body.eventId,
            queueAttempt: message.attempts,
            disposition,
          });
          message.retry();
        }
      }
    } finally {
      await connection.close();
    }
  },
} satisfies ExportedHandler<Env, MutationLedgerMessage>;
