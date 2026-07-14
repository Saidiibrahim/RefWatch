import { describe, expect, it } from "vitest";
import { Hono } from "hono";
import { allowsUnmappedClerkUsers, clerkAuth } from "../src/middleware/auth";
import type { Env, Variables } from "../src/types";

describe("Clerk auth middleware", () => {
  it("fails closed for unmapped users unless the post-reconciliation flag is explicit", () => {
    expect(allowsUnmappedClerkUsers({})).toBe(false);
    expect(allowsUnmappedClerkUsers({ ALLOW_UNMAPPED_CLERK_USERS: "false" })).toBe(false);
    expect(allowsUnmappedClerkUsers({ ALLOW_UNMAPPED_CLERK_USERS: " true " })).toBe(true);
    expect(allowsUnmappedClerkUsers({
      ALLOW_UNMAPPED_CLERK_USERS: "true",
      WRITE_MODE: "disabled",
    })).toBe(false);
  });
  it("rejects a missing bearer token before database access", async () => {
    const app = new Hono<{ Bindings: Env; Variables: Variables }>();
    app.use("*", clerkAuth(async () => null));
    app.get("/", (c) => c.json({ ok: true }));
    const response = await app.request("/", {}, {} as Env);
    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toMatchObject({ error: "unauthorized" });
  });

  it("maps verifier failures to 401 without leaking details", async () => {
    const app = new Hono<{ Bindings: Env; Variables: Variables }>();
    app.use("*", clerkAuth(async () => { throw new Error("sensitive verifier detail"); }));
    app.get("/", (c) => c.json({ ok: true }));
    const response = await app.request("/", { headers: { Authorization: "Bearer invalid" } }, {} as Env);
    expect(response.status).toBe(401);
    expect(await response.text()).not.toContain("sensitive verifier detail");
  });
});
