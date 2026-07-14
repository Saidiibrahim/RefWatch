import { createClerkClient } from "@clerk/backend";
import { eq } from "drizzle-orm";
import { createMiddleware } from "hono/factory";
import { appUsers } from "../db/schema";
import { connectDatabase } from "../db/client";
import type { Env, Variables } from "../types";
import { writesAreDisabled } from "./writeGate";

export interface VerifiedSession {
  clerkUserId: string;
}

export type SessionVerifier = (request: Request, env: Env) => Promise<VerifiedSession | null>;

export function allowsUnmappedClerkUsers(
  env: Pick<Env, "ALLOW_UNMAPPED_CLERK_USERS" | "WRITE_MODE">,
): boolean {
  return !writesAreDisabled(env)
    && env.ALLOW_UNMAPPED_CLERK_USERS?.trim().toLowerCase() === "true";
}

export const verifyClerkSession: SessionVerifier = async (request, env) => {
  const authorization = request.headers.get("authorization");
  if (!authorization?.match(/^Bearer\s+\S+$/i)) return null;
  const clerk = createClerkClient({
    secretKey: env.CLERK_SECRET_KEY,
    publishableKey: env.CLERK_PUBLISHABLE_KEY,
  });
  const state = await clerk.authenticateRequest(request, {
    acceptsToken: "session_token",
    ...(env.CLERK_JWT_KEY ? { jwtKey: env.CLERK_JWT_KEY } : {}),
  });
  if (!state.isAuthenticated) return null;
  const auth = state.toAuth();
  return auth.userId ? { clerkUserId: auth.userId } : null;
};

export function clerkAuth(verifier: SessionVerifier = verifyClerkSession) {
  return createMiddleware<{ Bindings: Env; Variables: Variables }>(async (c, next) => {
    let session: VerifiedSession | null;
    try {
      session = await verifier(c.req.raw, c.env);
    } catch (error) {
      console.warn("Clerk session verification failed", error);
      return c.json({ error: "unauthorized", message: "Invalid or expired session token" }, 401);
    }
    if (!session) return c.json({ error: "unauthorized", message: "Bearer session token required" }, 401);

    const connection = await connectDatabase(c.env);
    try {
      const [existing] = await connection.db.select().from(appUsers).where(
        eq(appUsers.clerkUserId, session.clerkUserId),
      ).limit(1);
      if (existing?.deletedAt) {
        return c.json({ error: "account_disabled", message: "This account mapping is deleted" }, 403);
      }
      if (!existing && !allowsUnmappedClerkUsers(c.env)) {
        return c.json({
          error: "account_mapping_required",
          message: "This Clerk account has not been linked to a RefWatch user",
        }, 403);
      }
      const user = existing ?? (await connection.db.insert(appUsers).values({
          clerkUserId: session.clerkUserId,
        }).onConflictDoUpdate({
          target: appUsers.clerkUserId,
          set: { updatedAt: new Date() },
        }).returning())[0];
      if (!user) throw new Error("Unable to resolve app user");
      if (user.deletedAt) return c.json({ error: "account_disabled" }, 403);
      c.set("db", connection.db);
      c.set("dbClient", connection.client);
      c.set("auth", {
        clerkUserId: session.clerkUserId,
        appUserId: user.id,
        ...(user.email ? { email: user.email } : {}),
        ...(user.displayName ? { displayName: user.displayName } : {}),
      });
      await next();
    } finally {
      await connection.close();
    }
  });
}
