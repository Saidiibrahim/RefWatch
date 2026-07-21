import { verifyWebhook } from "@clerk/backend/webhooks";
import { Hono } from "hono";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { connectDatabase } from "../src/db/client";
import {
  PRODUCTION_CLERK_INSTANCE_ID,
  sha256Hex,
} from "../src/services/identityProfiles";
import { processClerkUserLifecycleEvent } from "../src/services/userOnboarding";
import type { Env } from "../src/types";
import { clerkWebhookRoutes } from "../src/webhooks/clerk";

vi.mock("@clerk/backend/webhooks", () => ({ verifyWebhook: vi.fn() }));
vi.mock("../src/db/client", () => ({ connectDatabase: vi.fn() }));
vi.mock("../src/services/userOnboarding", async (importOriginal) => {
  const original = await importOriginal<typeof import("../src/services/userOnboarding")>();
  return {
    ...original,
    processClerkUserLifecycleEvent: vi.fn(),
  };
});

const verifyWebhookMock = vi.mocked(verifyWebhook);
const connectDatabaseMock = vi.mocked(connectDatabase);
const processLifecycleMock = vi.mocked(processClerkUserLifecycleEvent);
const deliveryTimestamp = 1_784_512_000;
const rawPayload = signedPayload("user.created", "user_new");
type EnvOverrides = { [Key in keyof Env]?: Env[Key] | undefined };

function webhookApp() {
  const app = new Hono<{ Bindings: Env }>();
  app.route("/webhooks/clerk", clerkWebhookRoutes);
  return app;
}

function webhookEnv(overrides: EnvOverrides = {}): Env {
  return {
    CLERK_WEBHOOK_SIGNING_SECRET: "test-signing-secret",
    CLERK_INSTANCE_ID: PRODUCTION_CLERK_INSTANCE_ID,
    ...overrides,
  } as Env;
}

function webhookRequest(
  headers: Record<string, string> = {},
  body = rawPayload,
): RequestInit {
  return {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "svix-id": "evt_delivery",
      "svix-timestamp": String(deliveryTimestamp),
      ...headers,
    },
    body,
  };
}

function signedPayload(
  type: "user.created" | "user.updated" | "user.deleted",
  userId: string,
  instanceId: string = PRODUCTION_CLERK_INSTANCE_ID,
  timestamp = deliveryTimestamp * 1_000,
): string {
  return JSON.stringify({
    object: "event",
    instance_id: instanceId,
    timestamp,
    type,
    data: { id: userId },
  });
}

describe("Clerk webhook onboarding boundary", () => {
  let close: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.clearAllMocks();
    close = vi.fn().mockResolvedValue(undefined);
    connectDatabaseMock.mockResolvedValue({
      db: { marker: "database" },
      client: {},
      close,
    } as never);
    processLifecycleMock.mockResolvedValue({ kind: "created" });
  });

  it("rejects an invalid signature without opening a database connection", async () => {
    verifyWebhookMock.mockRejectedValue(new Error("signature details must not escape"));

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest(),
      webhookEnv(),
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "invalid_webhook_signature" });
    expect(connectDatabaseMock).not.toHaveBeenCalled();
    expect(processLifecycleMock).not.toHaveBeenCalled();
    const verifiedRequest = verifyWebhookMock.mock.calls[0]?.[0];
    expect(verifiedRequest).toBeInstanceOf(Request);
    await expect(verifiedRequest!.clone().text()).resolves.toBe(rawPayload);
  });

  it.each([
    ["missing delivery id", { "svix-id": "" }],
    ["missing timestamp", { "svix-timestamp": "" }],
    ["invalid timestamp", { "svix-timestamp": "not-a-timestamp" }],
  ])("rejects %s metadata before database access", async (_label, headers) => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: { id: "user_new", email_addresses: [] },
    } as never);

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest(headers),
      webhookEnv(),
    );

    expect(response.status).toBe(422);
    await expect(response.json()).resolves.toEqual({
      error: "invalid_webhook_delivery_metadata",
    });
    expect(connectDatabaseMock).not.toHaveBeenCalled();
    expect(processLifecycleMock).not.toHaveBeenCalled();
  });

  it.each([
    [
      "another Clerk instance",
      signedPayload("user.created", "user_new", "ins_other"),
    ],
    [
      "a mismatched event type",
      signedPayload("user.updated", "user_new"),
    ],
    [
      "a mismatched Clerk subject",
      signedPayload("user.created", "user_other"),
    ],
    [
      "an invalid event timestamp",
      signedPayload("user.created", "user_new", PRODUCTION_CLERK_INSTANCE_ID, 0),
    ],
    [
      "a non-event envelope",
      JSON.stringify({
        object: "not_an_event",
        instance_id: PRODUCTION_CLERK_INSTANCE_ID,
        timestamp: deliveryTimestamp * 1_000,
        type: "user.created",
        data: { id: "user_new" },
      }),
    ],
  ])("rejects a signed lifecycle payload from %s before database access", async (_label, body) => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: { id: "user_new", email_addresses: [] },
    } as never);

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest({}, body),
      webhookEnv(),
    );

    expect(response.status).toBe(422);
    await expect(response.json()).resolves.toEqual({ error: "invalid_webhook_provenance" });
    expect(connectDatabaseMock).not.toHaveBeenCalled();
    expect(processLifecycleMock).not.toHaveBeenCalled();
  });

  it("fails closed before database access when the Clerk instance binding is missing", async () => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: { id: "user_new", email_addresses: [] },
    } as never);

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest(),
      webhookEnv({ CLERK_INSTANCE_ID: undefined }),
    );

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({ error: "clerk_instance_not_configured" });
    expect(connectDatabaseMock).not.toHaveBeenCalled();
    expect(processLifecycleMock).not.toHaveBeenCalled();
  });

  it("rejects a non-production Clerk instance in greenfield mode before database access", async () => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: { id: "user_new", email_addresses: [] },
    } as never);

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest({}, signedPayload("user.created", "user_new", "ins_other")),
      webhookEnv({
        NEW_USER_ONBOARDING_MODE: "greenfield_bootstrap",
        CLERK_INSTANCE_ID: "ins_other",
      }),
    );

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({ error: "clerk_instance_misconfigured" });
    expect(connectDatabaseMock).not.toHaveBeenCalled();
    expect(processLifecycleMock).not.toHaveBeenCalled();
  });

  it.each([
    ["gate_closed", "identity_reconciliation_required"],
    ["legacy_mapping_missing", "legacy_identity_mapping_missing"],
  ] as const)("returns a retryable no-store response for %s", async (kind, error) => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: {
        id: "user_new",
        first_name: "New",
        last_name: "Referee",
        image_url: "https://images.example.test/avatar.png",
        primary_email_address_id: "email_primary",
        email_addresses: [
          { id: "email_secondary", email_address: "secondary@example.test" },
          { id: "email_primary", email_address: "primary@example.test" },
        ],
      },
    } as never);
    processLifecycleMock.mockResolvedValue({ kind });

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest(),
      webhookEnv(),
    );

    expect(response.status).toBe(503);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("Retry-After")).toBe("300");
    await expect(response.json()).resolves.toEqual({ error });
    expect(processLifecycleMock).toHaveBeenCalledWith(
      expect.objectContaining({ marker: "database" }),
      expect.objectContaining({ CLERK_INSTANCE_ID: PRODUCTION_CLERK_INSTANCE_ID }),
      expect.objectContaining({
        clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
        clerkUserId: "user_new",
        webhookEventId: "evt_delivery",
        eventType: "user.created",
        payloadHash: await sha256Hex(rawPayload),
        occurredAt: new Date(deliveryTimestamp * 1_000),
        email: "primary@example.test",
        displayName: "New Referee",
        avatarUrl: "https://images.example.test/avatar.png",
      }),
      expect.objectContaining({
        sourceKind: "clerk_webhook",
        sourceEventId: "evt_delivery",
        workerVersionId: "local-development",
        actorId: `${PRODUCTION_CLERK_INSTANCE_ID}:user_new`,
      }),
    );
    expect(close).toHaveBeenCalledOnce();
  });

  it.each([
    ["duplicate", "user.created"],
    ["deleted", "user.deleted"],
    ["subject_deleted", "user.updated"],
  ] as const)("acknowledges the %s lifecycle result", async (kind, eventType) => {
    verifyWebhookMock.mockResolvedValue({
      type: eventType,
      data: { id: "user_lifecycle", email_addresses: [] },
    } as never);
    processLifecycleMock.mockResolvedValue({ kind });

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest({}, signedPayload(eventType, "user_lifecycle")),
      webhookEnv(),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ received: true });
    expect(processLifecycleMock).toHaveBeenCalledOnce();
    expect(close).toHaveBeenCalledOnce();
  });

  it("rejects a reused delivery id with conflicting provenance", async () => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.updated",
      data: { id: "user_conflict", email_addresses: [] },
    } as never);
    processLifecycleMock.mockResolvedValue({ kind: "delivery_conflict" });

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest({}, signedPayload("user.updated", "user_conflict")),
      webhookEnv(),
    );

    expect(response.status).toBe(409);
    await expect(response.json()).resolves.toEqual({ error: "webhook_delivery_conflict" });
    expect(close).toHaveBeenCalledOnce();
  });

  it("closes the database connection when lifecycle processing fails", async () => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: { id: "user_failure", email_addresses: [] },
    } as never);
    processLifecycleMock.mockRejectedValue(new Error("database failure"));

    const response = await webhookApp().request(
      "/webhooks/clerk",
      webhookRequest({}, signedPayload("user.created", "user_failure")),
      webhookEnv(),
    );

    expect(response.status).toBe(500);
    expect(close).toHaveBeenCalledOnce();
  });
});
