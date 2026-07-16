import { Hono } from "hono";
import { logger } from "hono/logger";
import { connectDatabase } from "./db/client";
import { clerkAuth } from "./middleware/auth";
import { writeGate } from "./middleware/writeGate";
import { assistantRoutes } from "./routes/assistant";
import { libraryRoutes } from "./routes/library";
import { matchAssessmentRoutes } from "./routes/matchAssessments";
import { matchRoutes } from "./routes/matches";
import { matchSheetParseRoutes } from "./routes/matchSheetParse";
import { meRoutes } from "./routes/me";
import { referenceCatalogRoutes } from "./routes/referenceCatalog";
import { scheduledMatchRoutes } from "./routes/scheduledMatches";
import type { Env, Variables } from "./types";
import { clerkWebhookRoutes } from "./webhooks/clerk";
import {
  claimPendingDeliveries,
  classifyDeadLetter,
  ledgerEncryptionConfig,
  persistDeadLetterReceipt,
  processLedgerMessage,
  recordLedgerDeliveryFailure,
  type MutationLedgerMessage,
} from "./services/mutationLedgerDelivery";

export const app = new Hono<{ Bindings: Env; Variables: Variables }>();

app.use("*", logger());
app.get("/health", (c) => c.json({ status: "ok", environment: c.env.REFWATCH_ENV ?? "unknown" }));
app.get("/health/ready", async (c) => {
  let connection: Awaited<ReturnType<typeof connectDatabase>> | undefined;
  try {
    connection = await connectDatabase(c.env);
    await connection.client.query("select 1 as ready");
    const pinned = c.env.REFWATCH_ENV === "rehearsal" || c.env.REFWATCH_ENV === "production";
    return c.json({
      status: "ready",
      database: "reachable",
      database_identity: pinned ? "verified" : "not_required",
    });
  } catch {
    console.warn("Database readiness check failed");
    return c.json({ status: "not_ready", database: "unavailable" }, 503);
  } finally {
    await connection?.close();
  }
});
app.use("/webhooks/*", writeGate());
app.route("/webhooks/clerk", clerkWebhookRoutes);
app.use("/api/*", writeGate());
app.use("/api/*", clerkAuth());
app.route("/api/me", meRoutes);
app.route("/api/matches", matchRoutes);
app.route("/api/scheduled-matches", scheduledMatchRoutes);
app.route("/api/match-assessments", matchAssessmentRoutes);
app.route("/api/reference-catalog", referenceCatalogRoutes);
app.route("/api", libraryRoutes);
app.route("/api/assistant", assistantRoutes);
app.route("/api/match-sheet", matchSheetParseRoutes);

app.notFound((c) => c.json({ error: "not_found" }, 404));
app.onError((error, c) => {
  console.error("Unhandled API error", error);
  return c.json({ error: "internal_error" }, 500);
});

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
