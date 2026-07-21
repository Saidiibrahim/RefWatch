import { createClerkClient } from "@clerk/backend";
import { eq } from "drizzle-orm";
import { createMiddleware } from "hono/factory";
import { appUsers } from "../db/schema";
import { connectDatabase } from "../db/client";
import { provisionNewUserAfterReconciliation } from "../services/userOnboarding";
import type { Env, Variables } from "../types";
import { workerVersionId } from "../services/workerVersion";
import { isExactProvenanceOnboardingMode } from "../services/identityProfiles";

export interface VerifiedSession {
  clerkUserId: string;
  clerkInstanceId: string;
}

export type SessionVerifier = (request: Request, env: Env) => Promise<VerifiedSession | null>;

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
  const expectedIssuer = env.CLERK_ISSUER?.trim().replace(/\/$/, "");
  const actualIssuer = auth.sessionClaims?.iss?.replace(/\/$/, "");
  const clerkInstanceId = env.CLERK_INSTANCE_ID?.trim();
  const requiresExactProvenance = env.REFWATCH_ENV === "production"
    || isExactProvenanceOnboardingMode(env.NEW_USER_ONBOARDING_MODE);
  if (!actualIssuer || (expectedIssuer && actualIssuer !== expectedIssuer)) return null;
  if (requiresExactProvenance && (!expectedIssuer || !clerkInstanceId)) return null;
  return auth.userId ? { clerkUserId: auth.userId, clerkInstanceId: clerkInstanceId ?? actualIssuer } : null;
};

export function clerkAuth(verifier: SessionVerifier = verifyClerkSession) {
  return createMiddleware<{ Bindings: Env; Variables: Variables }>(async (c, next) => {
    let session: VerifiedSession | null;
    try {
      session = await verifier(c.req.raw, c.env);
    } catch {
      console.warn("Clerk session verification failed");
      return c.json({ error: "unauthorized", message: "Invalid or expired session token" }, 401);
    }
    if (!session) return c.json({ error: "unauthorized", message: "Bearer session token required" }, 401);
    const requiresExactProvenance = c.env.REFWATCH_ENV === "production"
      || isExactProvenanceOnboardingMode(c.env.NEW_USER_ONBOARDING_MODE);
    if ((c.env.CLERK_INSTANCE_ID && session.clerkInstanceId !== c.env.CLERK_INSTANCE_ID)
      || (requiresExactProvenance && !c.env.CLERK_INSTANCE_ID)) {
      return c.json({ error: "unauthorized", message: "Session belongs to a different Clerk instance" }, 401);
    }

    const connection = await connectDatabase(c.env);
    try {
      const [existing] = await connection.db.select().from(appUsers).where(
        eq(appUsers.clerkUserId, session.clerkUserId),
      ).limit(1);
      if (existing?.deletedAt) {
        return c.json({ error: "account_disabled", message: "This account mapping is deleted" }, 403);
      }
      let user = existing;
      if (!user) {
        const provisioned = await provisionNewUserAfterReconciliation(connection.db, c.env, {
          clerkInstanceId: session.clerkInstanceId,
          clerkUserId: session.clerkUserId,
        }, {
          sourceKind: "clerk_onboarding",
          sourceEventId: `${session.clerkInstanceId}:${session.clerkUserId}:${c.env.IDENTITY_RECONCILIATION_RECEIPT ?? "unbound"}`,
          requestId: crypto.randomUUID(),
          workerVersionId: workerVersionId(c.env),
          actorId: session.clerkUserId,
        });
        if (provisioned.kind !== "created" && provisioned.kind !== "existing") {
          return c.json({
            error: "account_mapping_required",
            message: "This Clerk account has not been linked to a RefWatch user",
          }, 403);
        }
        user = provisioned.user;
      }
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
