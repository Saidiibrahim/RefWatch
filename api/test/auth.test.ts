import { createClerkClient } from "@clerk/backend";
import { Hono } from "hono";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { connectDatabase } from "../src/db/client";
import { clerkAuth, verifyClerkSession } from "../src/middleware/auth";
import {
  GREENFIELD_AUTHORIZATION_DIGEST,
  GREENFIELD_AUTHORIZATION_PROFILE,
  GREENFIELD_ONBOARDING_MODE,
  GREENFIELD_RECONCILIATION_PROFILE,
  GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
  POST_RECONCILIATION_ONBOARDING_MODE,
  PRODUCTION_CLERK_DOMAIN,
  PRODUCTION_CLERK_INSTANCE_ID,
  PRODUCTION_CLERK_ISSUER,
  STATEFUL_RECONCILIATION_PROFILE,
} from "../src/services/identityProfiles";
import { newUserOnboardingConfig } from "../src/services/userOnboarding";
import type { Env, Variables } from "../src/types";

vi.mock("@clerk/backend", () => ({ createClerkClient: vi.fn() }));
vi.mock("../src/db/client", () => ({ connectDatabase: vi.fn() }));

const createClerkClientMock = vi.mocked(createClerkClient);
const connectDatabaseMock = vi.mocked(connectDatabase);

type EnvOverrides = { [Key in keyof Env]?: Env[Key] | undefined };

function greenfieldEnv(overrides: EnvOverrides = {}): Env {
  return {
    WRITE_MODE: "enabled",
    NEW_USER_ONBOARDING_MODE: GREENFIELD_ONBOARDING_MODE,
    IDENTITY_RECONCILIATION_RECEIPT: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
    IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST: GREENFIELD_AUTHORIZATION_DIGEST,
    CLERK_INSTANCE_ID: PRODUCTION_CLERK_INSTANCE_ID,
    CLERK_ISSUER: PRODUCTION_CLERK_ISSUER,
    ...overrides,
  } as Env;
}

function authApp(
  verifier: Parameters<typeof clerkAuth>[0],
): Hono<{ Bindings: Env; Variables: Variables }> {
  const app = new Hono<{ Bindings: Env; Variables: Variables }>();
  app.use("*", clerkAuth(verifier));
  app.get("/", (c) => c.json({
    appUserId: c.get("auth").appUserId,
    clerkUserId: c.get("auth").clerkUserId,
  }));
  return app;
}

function mockAuthenticatedClerkSession(issuer: string | undefined): void {
  createClerkClientMock.mockReturnValue({
    authenticateRequest: vi.fn().mockResolvedValue({
      isAuthenticated: true,
      toAuth: () => ({
        userId: "user_exact",
        sessionClaims: issuer ? { iss: issuer } : {},
      }),
    }),
  } as never);
}

describe("new-user onboarding configuration", () => {
  it("accepts the explicit stateful profile and rejects mixed greenfield authorization", () => {
    const digest = "a".repeat(64);
    expect(newUserOnboardingConfig({
      NEW_USER_ONBOARDING_MODE: " POST_RECONCILIATION ",
      IDENTITY_RECONCILIATION_RECEIPT: digest.toUpperCase(),
      CLERK_INSTANCE_ID: " ins_production ",
      CLERK_ISSUER: "https://issuer.example.test/",
      WRITE_MODE: "enabled",
    })).toEqual({
      onboardingMode: POST_RECONCILIATION_ONBOARDING_MODE,
      reconciliationProfile: STATEFUL_RECONCILIATION_PROFILE,
      receiptDigest: digest,
      clerkInstanceId: "ins_production",
      clerkIssuer: "https://issuer.example.test",
      clerkDomain: null,
      authorizationProfile: null,
      authorizationDigest: null,
    });

    expect(newUserOnboardingConfig({
      NEW_USER_ONBOARDING_MODE: POST_RECONCILIATION_ONBOARDING_MODE,
      IDENTITY_RECONCILIATION_RECEIPT: digest,
      IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST: GREENFIELD_AUTHORIZATION_DIGEST,
      CLERK_INSTANCE_ID: "ins_production",
      WRITE_MODE: "enabled",
    })).toBeNull();
  });

  it("accepts only the exact production-bound greenfield profile", () => {
    expect(newUserOnboardingConfig(greenfieldEnv({
      NEW_USER_ONBOARDING_MODE: " GREENFIELD_BOOTSTRAP ",
      IDENTITY_RECONCILIATION_RECEIPT: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST.toUpperCase(),
      IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST: GREENFIELD_AUTHORIZATION_DIGEST.toUpperCase(),
      CLERK_INSTANCE_ID: ` ${PRODUCTION_CLERK_INSTANCE_ID} `,
      CLERK_ISSUER: `${PRODUCTION_CLERK_ISSUER}/`,
    }))).toEqual({
      onboardingMode: GREENFIELD_ONBOARDING_MODE,
      reconciliationProfile: GREENFIELD_RECONCILIATION_PROFILE,
      receiptDigest: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
      clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
      clerkIssuer: PRODUCTION_CLERK_ISSUER,
      clerkDomain: PRODUCTION_CLERK_DOMAIN,
      authorizationProfile: GREENFIELD_AUTHORIZATION_PROFILE,
      authorizationDigest: GREENFIELD_AUTHORIZATION_DIGEST,
    });
  });

  it.each([
    ["missing write mode", { WRITE_MODE: undefined }],
    ["disabled write mode", { WRITE_MODE: "disabled" }],
    ["missing receipt", { IDENTITY_RECONCILIATION_RECEIPT: undefined }],
    ["wrong receipt", { IDENTITY_RECONCILIATION_RECEIPT: "a".repeat(64) }],
    ["missing authorization digest", { IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST: undefined }],
    ["wrong authorization digest", { IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST: "b".repeat(64) }],
    ["missing issuer", { CLERK_ISSUER: undefined }],
    ["wrong issuer", { CLERK_ISSUER: "https://wrong.example.test" }],
    ["missing instance", { CLERK_INSTANCE_ID: undefined }],
    ["wrong instance", { CLERK_INSTANCE_ID: "ins_wrong" }],
  ] as const)("rejects the greenfield profile with %s", (_label, overrides) => {
    expect(newUserOnboardingConfig(greenfieldEnv(overrides))).toBeNull();
  });

  it("keeps ALLOW_UNMAPPED_CLERK_USERS inert", () => {
    const legacyEscapeEnv = {
      ALLOW_UNMAPPED_CLERK_USERS: "true",
      WRITE_MODE: "enabled",
    } as Env;
    expect(newUserOnboardingConfig(legacyEscapeEnv)).toBeNull();
    expect(newUserOnboardingConfig(greenfieldEnv({
      ALLOW_UNMAPPED_CLERK_USERS: "true",
      IDENTITY_RECONCILIATION_RECEIPT: "c".repeat(64),
    }))).toBeNull();
  });
});

describe("Clerk auth middleware", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("rejects a missing bearer token before database access", async () => {
    const app = authApp(async () => null);
    const response = await app.request("/", {}, {} as Env);
    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toMatchObject({ error: "unauthorized" });
    expect(connectDatabaseMock).not.toHaveBeenCalled();
  });

  it("maps verifier failures to 401 without leaking details", async () => {
    const warning = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const app = authApp(async () => { throw new Error("sensitive verifier detail"); });
    try {
      const response = await app.request(
        "/",
        { headers: { Authorization: "Bearer invalid" } },
        {} as Env,
      );
      expect(response.status).toBe(401);
      expect(await response.text()).not.toContain("sensitive verifier detail");
      expect(warning).toHaveBeenCalledWith("Clerk session verification failed");
      expect(JSON.stringify(warning.mock.calls)).not.toContain("sensitive verifier detail");
      expect(connectDatabaseMock).not.toHaveBeenCalled();
    } finally {
      warning.mockRestore();
    }
  });

  it("verifies the exact Clerk issuer and returns the configured instance provenance", async () => {
    mockAuthenticatedClerkSession(`${PRODUCTION_CLERK_ISSUER}/`);
    const request = new Request("https://api.refwatch.test/api/me", {
      headers: { Authorization: "Bearer valid" },
    });

    await expect(verifyClerkSession(request, greenfieldEnv({
      CLERK_SECRET_KEY: "test-secret-key",
      CLERK_PUBLISHABLE_KEY: "test-publishable-key",
    }))).resolves.toEqual({
      clerkUserId: "user_exact",
      clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
    });
  });

  it.each([
    ["missing actual issuer", undefined, {}],
    ["wrong actual issuer", "https://wrong.example.test", {}],
    ["missing configured issuer", PRODUCTION_CLERK_ISSUER, { CLERK_ISSUER: undefined }],
    ["missing configured instance", PRODUCTION_CLERK_ISSUER, { CLERK_INSTANCE_ID: undefined }],
  ] as const)("rejects %s during exact-provenance session verification", async (
    _label,
    actualIssuer,
    overrides,
  ) => {
    mockAuthenticatedClerkSession(actualIssuer);
    const request = new Request("https://api.refwatch.test/api/me", {
      headers: { Authorization: "Bearer valid" },
    });

    await expect(verifyClerkSession(
      request,
      greenfieldEnv(overrides),
    )).resolves.toBeNull();
    expect(connectDatabaseMock).not.toHaveBeenCalled();
  });

  it.each([
    ["stateful onboarding", { NEW_USER_ONBOARDING_MODE: POST_RECONCILIATION_ONBOARDING_MODE }],
    ["greenfield onboarding", { NEW_USER_ONBOARDING_MODE: GREENFIELD_ONBOARDING_MODE }],
    ["production", { REFWATCH_ENV: "production" }],
  ] as const)("requires an exact Clerk instance for %s before database access", async (_label, env) => {
    const app = authApp(async () => ({
      clerkUserId: "user_exact",
      clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
    }));
    const response = await app.request(
      "/",
      { headers: { Authorization: "Bearer valid" } },
      env as Env,
    );
    expect(response.status).toBe(401);
    expect(connectDatabaseMock).not.toHaveBeenCalled();
  });

  it("rejects a verified session attributed to another Clerk instance before database access", async () => {
    const app = authApp(async () => ({
      clerkUserId: "user_wrong_instance",
      clerkInstanceId: "ins_development",
    }));
    const response = await app.request(
      "/",
      { headers: { Authorization: "Bearer valid" } },
      greenfieldEnv(),
    );
    expect(response.status).toBe(401);
    expect(connectDatabaseMock).not.toHaveBeenCalled();
  });

  it("accepts a session with the exact configured provenance and closes its connection", async () => {
    const close = vi.fn().mockResolvedValue(undefined);
    const limit = vi.fn().mockResolvedValue([{
      id: "0f4a4718-2b95-4788-bc1c-73be5871d01e",
      clerkUserId: "user_exact",
      email: null,
      displayName: null,
      deletedAt: null,
    }]);
    const where = vi.fn(() => ({ limit }));
    const from = vi.fn(() => ({ where }));
    connectDatabaseMock.mockResolvedValue({
      db: { select: vi.fn(() => ({ from })) },
      client: {},
      close,
    } as never);
    const app = authApp(async () => ({
      clerkUserId: "user_exact",
      clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
    }));

    const response = await app.request(
      "/",
      { headers: { Authorization: "Bearer valid" } },
      greenfieldEnv(),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      appUserId: "0f4a4718-2b95-4788-bc1c-73be5871d01e",
      clerkUserId: "user_exact",
    });
    expect(close).toHaveBeenCalledOnce();
  });
});
