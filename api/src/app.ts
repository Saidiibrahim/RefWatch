import { Hono } from "hono";
import { logger } from "hono/logger";
import { connectDatabase } from "./db/client";
import { clerkAuth, type SessionVerifier } from "./middleware/auth";
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

interface AppOptions {
  sessionVerifier?: SessionVerifier;
}

export function createApp(options: AppOptions = {}) {
  const app = new Hono<{ Bindings: Env; Variables: Variables }>();

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
  app.use("/api/*", options.sessionVerifier ? clerkAuth(options.sessionVerifier) : clerkAuth());
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

  return app;
}
