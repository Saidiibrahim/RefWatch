import { describe, expect, it } from "vitest";
import { Hono } from "hono";
import { clerkAuth } from "../src/middleware/auth";
import { newUserOnboardingConfig } from "../src/services/userOnboarding";
import type { Env, Variables } from "../src/types";

describe("Clerk auth middleware", () => {
  it("fails closed unless the exact post-reconciliation receipt gate is valid", () => {
    const digest = "a".repeat(64);
    expect(newUserOnboardingConfig({})).toBeNull();
    expect(newUserOnboardingConfig({
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: "invalid",
      CLERK_INSTANCE_ID: "ins_production",
    })).toBeNull();
    expect(newUserOnboardingConfig({
      NEW_USER_ONBOARDING_MODE: "post_reconciliation",
      IDENTITY_RECONCILIATION_RECEIPT: digest,
      CLERK_INSTANCE_ID: "ins_production",
      WRITE_MODE: "disabled",
    })).toBeNull();
    expect(newUserOnboardingConfig({
      NEW_USER_ONBOARDING_MODE: " POST_RECONCILIATION ",
      IDENTITY_RECONCILIATION_RECEIPT: digest.toUpperCase(),
      CLERK_INSTANCE_ID: "ins_production",
      WRITE_MODE: "enabled",
    })).toEqual({ receiptDigest: digest, clerkInstanceId: "ins_production" });
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

  it("rejects a verified session attributed to another Clerk instance before database access", async () => {
    const app = new Hono<{ Bindings: Env; Variables: Variables }>();
    app.use("*", clerkAuth(async () => ({
      clerkUserId: "user_wrong_instance",
      clerkInstanceId: "ins_development",
    })));
    app.get("/", (c) => c.json({ ok: true }));
    const response = await app.request("/", { headers: { Authorization: "Bearer valid" } }, {
      CLERK_INSTANCE_ID: "ins_production",
    } as Env);
    expect(response.status).toBe(401);
  });
});
