import { verifyWebhook } from "@clerk/backend/webhooks";
import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { connectDatabase } from "../db/client";
import { appUsers } from "../db/schema";
import { provisionNewUserAfterReconciliation, recordClerkUserDeletion } from "../services/userOnboarding";
import type { Env } from "../types";
import { withMutation } from "../services/mutationLedger";
import { workerVersionId } from "../services/workerVersion";

export const clerkWebhookRoutes = new Hono<{ Bindings: Env }>();

clerkWebhookRoutes.post("/", async (c) => {
  let event;
  try {
    event = await verifyWebhook(c.req.raw, { signingSecret: c.env.CLERK_WEBHOOK_SIGNING_SECRET });
  } catch (error) {
    console.warn("Rejected invalid Clerk webhook", error);
    return c.json({ error: "invalid_webhook_signature" }, 400);
  }

  const clerkInstanceId = c.env.CLERK_INSTANCE_ID?.trim();
  if (!clerkInstanceId) return c.json({ error: "clerk_instance_not_configured" }, 503);

  if (event.type !== "user.created" && event.type !== "user.updated" && event.type !== "user.deleted") {
    return c.json({ received: true });
  }
  const clerkUserId = event.data.id;
  if (!clerkUserId) return c.json({ error: "invalid_webhook_payload" }, 422);
  const webhookEventId = c.req.header("svix-id");
  if (!webhookEventId) return c.json({ error: "missing_webhook_event_id" }, 422);
  const mutationContext = () => ({
    sourceKind: "clerk_webhook" as const,
    sourceEventId: webhookEventId,
    requestId: crypto.randomUUID(),
    workerVersionId: workerVersionId(c.env),
    actorId: `${clerkInstanceId}:${clerkUserId}`,
  });
  const connection = await connectDatabase(c.env);
  try {
    const [existing] = await connection.db.select({ id: appUsers.id }).from(appUsers)
      .where(eq(appUsers.clerkUserId, clerkUserId)).limit(1);
    if (event.type === "user.deleted") {
      const deletedAt = new Date();
      await recordClerkUserDeletion(connection.db, {
        clerkInstanceId,
        clerkUserId,
        webhookEventId,
        deletedAt,
      }, mutationContext());
      return c.json({ received: true });
    }
    const data = event.data as typeof event.data & {
      first_name?: string | null; last_name?: string | null; image_url?: string | null;
      primary_email_address_id?: string | null; email_addresses?: Array<{ id: string; email_address: string }>;
    };
    const email = data.email_addresses?.find((entry) => entry.id === data.primary_email_address_id)?.email_address ?? data.email_addresses?.[0]?.email_address ?? null;
    const displayName = [data.first_name, data.last_name].filter(Boolean).join(" ") || null;
    if (!existing) {
      const provisioned = await provisionNewUserAfterReconciliation(connection.db, c.env, {
        clerkInstanceId,
        clerkUserId,
        email,
        displayName,
        avatarUrl: data.image_url ?? null,
      }, mutationContext());
      if (provisioned.kind === "gate_closed") {
        c.header("Cache-Control", "no-store");
        c.header("Retry-After", "300");
        return c.json({ error: "identity_reconciliation_required" }, 503);
      }
      if (provisioned.kind === "legacy_mapping_missing") {
        return c.json({ error: "legacy_identity_mapping_missing" }, 503);
      }
      if (provisioned.kind === "subject_deleted") return c.json({ received: true });
      if (provisioned.kind === "created") return c.json({ received: true });
    }
    await withMutation(connection.db, mutationContext(), (tx) => tx.update(appUsers).set({
        email,
        displayName,
        avatarUrl: data.image_url ?? null,
        updatedAt: new Date(),
        // Never clear deletedAt here: webhook retries can arrive out of order after user.deleted.
      }).where(eq(appUsers.clerkUserId, clerkUserId)));
    return c.json({ received: true });
  } finally {
    await connection.close();
  }
});
