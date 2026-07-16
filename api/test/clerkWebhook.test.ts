import { verifyWebhook } from "@clerk/backend/webhooks";
import { Hono } from "hono";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { connectDatabase } from "../src/db/client";
import { provisionNewUserAfterReconciliation, recordClerkUserDeletion } from "../src/services/userOnboarding";
import type { Env } from "../src/types";
import { clerkWebhookRoutes } from "../src/webhooks/clerk";

vi.mock("@clerk/backend/webhooks", () => ({ verifyWebhook: vi.fn() }));
vi.mock("../src/db/client", () => ({ connectDatabase: vi.fn() }));
vi.mock("../src/services/userOnboarding", async (importOriginal) => {
  const original = await importOriginal<typeof import("../src/services/userOnboarding")>();
  return {
    ...original,
    provisionNewUserAfterReconciliation: vi.fn(),
    recordClerkUserDeletion: vi.fn(),
  };
});

const verifyWebhookMock = vi.mocked(verifyWebhook);
const connectDatabaseMock = vi.mocked(connectDatabase);
const provisionMock = vi.mocked(provisionNewUserAfterReconciliation);
const deletionMock = vi.mocked(recordClerkUserDeletion);
const clerkInstanceId = "ins_production";

function webhookApp() {
  const app = new Hono<{ Bindings: Env }>();
  app.route("/webhooks/clerk", clerkWebhookRoutes);
  return app;
}

function databaseWithNoMapping() {
  const limit = vi.fn().mockResolvedValue([]);
  const where = vi.fn(() => ({ limit }));
  const from = vi.fn(() => ({ where }));
  const db = { select: vi.fn(() => ({ from })) };
  return { db, close: vi.fn().mockResolvedValue(undefined) };
}

describe("Clerk webhook onboarding boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    connectDatabaseMock.mockResolvedValue(databaseWithNoMapping() as never);
  });

  it("returns a retryable failure instead of acknowledging an unmapped new user", async () => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: { id: "user_new", email_addresses: [] },
    } as never);
    provisionMock.mockResolvedValue({ kind: "gate_closed" });

    const response = await webhookApp().request("/webhooks/clerk", {
      method: "POST",
      headers: { "svix-id": "evt_created" },
    }, {
      CLERK_WEBHOOK_SIGNING_SECRET: "test",
      CLERK_INSTANCE_ID: clerkInstanceId,
    } as Env);

    expect(response.status).toBe(503);
    expect(response.headers.get("Retry-After")).toBe("300");
    await expect(response.json()).resolves.toEqual({ error: "identity_reconciliation_required" });
    expect(provisionMock).toHaveBeenCalledOnce();
  });

  it("records a tombstone without inventing a mapping for deletion of an unknown subject", async () => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.deleted",
      data: { id: "user_unknown" },
    } as never);

    const response = await webhookApp().request("/webhooks/clerk", {
      method: "POST",
      headers: { "svix-id": "evt_deleted" },
    }, {
      CLERK_WEBHOOK_SIGNING_SECRET: "test",
      CLERK_INSTANCE_ID: clerkInstanceId,
    } as Env);

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ received: true });
    expect(provisionMock).not.toHaveBeenCalled();
    expect(deletionMock).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        clerkInstanceId,
        clerkUserId: "user_unknown",
        webhookEventId: "evt_deleted",
      }),
      expect.objectContaining({
        sourceKind: "clerk_webhook",
        sourceEventId: "evt_deleted",
        workerVersionId: "local-development",
      }),
    );
  });

  it("fails closed when the webhook environment lacks its Clerk instance binding", async () => {
    verifyWebhookMock.mockResolvedValue({
      type: "user.created",
      data: { id: "user_wrong", email_addresses: [] },
    } as never);
    const response = await webhookApp().request("/webhooks/clerk", { method: "POST" }, {
      CLERK_WEBHOOK_SIGNING_SECRET: "test",
    } as Env);
    expect(response.status).toBe(503);
    expect(connectDatabaseMock).not.toHaveBeenCalled();
  });
});
