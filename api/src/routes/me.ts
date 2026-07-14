import { Hono } from "hono";
import type { Env, Variables } from "../types";

export const meRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

meRoutes.get("/", (c) => {
  const identity = c.get("auth");
  return c.json({
    appUserId: identity.appUserId,
    clerkUserId: identity.clerkUserId,
    email: identity.email ?? null,
    displayName: identity.displayName ?? null,
  });
});
