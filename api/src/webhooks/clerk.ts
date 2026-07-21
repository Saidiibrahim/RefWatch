import { verifyWebhook } from "@clerk/backend/webhooks";
import { Hono } from "hono";
import { connectDatabase } from "../db/client";
import {
  processClerkUserLifecycleEvent,
  type ClerkLifecycleEventType,
} from "../services/userOnboarding";
import {
  GREENFIELD_ONBOARDING_MODE,
  PRODUCTION_CLERK_INSTANCE_ID,
  sha256Hex,
} from "../services/identityProfiles";
import type { Env } from "../types";
import { workerVersionId } from "../services/workerVersion";

export const clerkWebhookRoutes = new Hono<{ Bindings: Env }>();

clerkWebhookRoutes.post("/", async (c) => {
  const rawPayload = await c.req.raw.clone().text();
  let event;
  try {
    event = await verifyWebhook(c.req.raw, { signingSecret: c.env.CLERK_WEBHOOK_SIGNING_SECRET });
  } catch {
    console.warn("Rejected invalid Clerk webhook");
    return c.json({ error: "invalid_webhook_signature" }, 400);
  }

  const clerkInstanceId = c.env.CLERK_INSTANCE_ID?.trim();
  if (!clerkInstanceId) return c.json({ error: "clerk_instance_not_configured" }, 503);
  if (
    c.env.NEW_USER_ONBOARDING_MODE?.trim().toLowerCase() === GREENFIELD_ONBOARDING_MODE
    && clerkInstanceId !== PRODUCTION_CLERK_INSTANCE_ID
  ) {
    return c.json({ error: "clerk_instance_misconfigured" }, 503);
  }

  if (!isLifecycleEventType(event.type)) return c.json({ received: true });
  const clerkUserId = event.data.id;
  if (!clerkUserId) return c.json({ error: "invalid_webhook_payload" }, 422);

  const webhookEventId = c.req.header("svix-id")?.trim();
  if (!webhookEventId || !isValidSvixTimestamp(c.req.header("svix-timestamp"))) {
    return c.json({ error: "invalid_webhook_delivery_metadata" }, 422);
  }
  const signedEnvelope = parseSignedLifecycleEnvelope(rawPayload, event.type, clerkUserId);
  if (!signedEnvelope || signedEnvelope.clerkInstanceId !== clerkInstanceId) {
    return c.json({ error: "invalid_webhook_provenance" }, 422);
  }

  const data = event.data as typeof event.data & {
    first_name?: string | null;
    last_name?: string | null;
    image_url?: string | null;
    primary_email_address_id?: string | null;
    email_addresses?: Array<{ id: string; email_address: string }>;
  };
  const email = data.email_addresses
    ?.find((entry) => entry.id === data.primary_email_address_id)?.email_address
    ?? data.email_addresses?.[0]?.email_address
    ?? null;
  const displayName = [data.first_name, data.last_name].filter(Boolean).join(" ") || null;
  const payloadHash = await sha256Hex(rawPayload);
  const mutationContext = {
    sourceKind: "clerk_webhook" as const,
    sourceEventId: webhookEventId,
    requestId: crypto.randomUUID(),
    workerVersionId: workerVersionId(c.env),
    actorId: `${clerkInstanceId}:${clerkUserId}`,
  };

  const connection = await connectDatabase(c.env);
  try {
    const result = await processClerkUserLifecycleEvent(connection.db, c.env, {
      clerkInstanceId,
      clerkUserId,
      webhookEventId,
      eventType: event.type,
      payloadHash,
      occurredAt: signedEnvelope.occurredAt,
      email,
      displayName,
      avatarUrl: data.image_url ?? null,
    }, mutationContext);

    if (result.kind === "gate_closed") {
      c.header("Cache-Control", "no-store");
      c.header("Retry-After", "300");
      return c.json({ error: "identity_reconciliation_required" }, 503);
    }
    if (result.kind === "legacy_mapping_missing") {
      c.header("Cache-Control", "no-store");
      c.header("Retry-After", "300");
      return c.json({ error: "legacy_identity_mapping_missing" }, 503);
    }
    if (result.kind === "delivery_conflict") {
      return c.json({ error: "webhook_delivery_conflict" }, 409);
    }
    return c.json({ received: true });
  } finally {
    await connection.close();
  }
});

function isLifecycleEventType(value: string): value is ClerkLifecycleEventType {
  return value === "user.created" || value === "user.updated" || value === "user.deleted";
}

function isValidSvixTimestamp(value: string | undefined): boolean {
  const seconds = Number(value);
  return Number.isSafeInteger(seconds) && seconds > 0;
}

function parseSignedLifecycleEnvelope(
  rawPayload: string,
  verifiedType: ClerkLifecycleEventType,
  verifiedClerkUserId: string,
): { clerkInstanceId: string; occurredAt: Date } | null {
  let envelope: unknown;
  try {
    envelope = JSON.parse(rawPayload);
  } catch {
    return null;
  }
  if (!isRecord(envelope) || envelope.object !== "event") return null;
  if (envelope.type !== verifiedType || typeof envelope.instance_id !== "string") return null;
  if (!isRecord(envelope.data) || envelope.data.id !== verifiedClerkUserId) return null;
  if (
    typeof envelope.timestamp !== "number"
    || !Number.isSafeInteger(envelope.timestamp)
    || envelope.timestamp <= 0
  ) {
    return null;
  }
  const occurredAt = new Date(envelope.timestamp);
  if (Number.isNaN(occurredAt.getTime())) return null;
  return { clerkInstanceId: envelope.instance_id, occurredAt };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
