import { verifyWebhook } from "@clerk/backend/webhooks";
import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { connectDatabase } from "../db/client";
import { appUsers } from "../db/schema";
import { allowsUnmappedClerkUsers } from "../middleware/auth";
import type { Env } from "../types";

export const clerkWebhookRoutes = new Hono<{ Bindings: Env }>();

clerkWebhookRoutes.post("/", async (c) => {
  let event;
  try {
    event = await verifyWebhook(c.req.raw, { signingSecret: c.env.CLERK_WEBHOOK_SIGNING_SECRET });
  } catch (error) {
    console.warn("Rejected invalid Clerk webhook", error);
    return c.json({ error: "invalid_webhook_signature" }, 400);
  }

  if (event.type !== "user.created" && event.type !== "user.updated" && event.type !== "user.deleted") {
    return c.json({ received: true });
  }
  const clerkUserId = event.data.id;
  if (!clerkUserId) return c.json({ error: "invalid_webhook_payload" }, 422);
  const connection = await connectDatabase(c.env);
  try {
    const [existing] = await connection.db.select({ id: appUsers.id }).from(appUsers)
      .where(eq(appUsers.clerkUserId, clerkUserId)).limit(1);
    if (!existing && !allowsUnmappedClerkUsers(c.env)) {
      // Acknowledge valid deliveries while the cutover mapping gate is closed. Retrying
      // cannot safely invent the preserved app UUID for a legacy subject.
      return c.json({ received: true, mapping: "pending" });
    }
    if (event.type === "user.deleted") {
      if (!existing) return c.json({ received: true });
      const deletedAt = new Date();
      await connection.db.update(appUsers).set({ deletedAt, updatedAt: deletedAt })
        .where(eq(appUsers.clerkUserId, clerkUserId));
      return c.json({ received: true });
    }
    const data = event.data as typeof event.data & {
      first_name?: string | null; last_name?: string | null; image_url?: string | null;
      primary_email_address_id?: string | null; email_addresses?: Array<{ id: string; email_address: string }>;
    };
    const email = data.email_addresses?.find((entry) => entry.id === data.primary_email_address_id)?.email_address ?? data.email_addresses?.[0]?.email_address ?? null;
    const displayName = [data.first_name, data.last_name].filter(Boolean).join(" ") || null;
    await connection.db.insert(appUsers).values({ clerkUserId, email, displayName, avatarUrl: data.image_url ?? null }).onConflictDoUpdate({
      target: appUsers.clerkUserId,
      // Never clear deletedAt here: webhook retries can arrive out of order after user.deleted.
      set: { email, displayName, avatarUrl: data.image_url ?? null, updatedAt: new Date() },
    });
    return c.json({ received: true });
  } finally {
    await connection.close();
  }
});
