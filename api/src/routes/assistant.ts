import { Hono } from "hono";
import { z } from "zod";
import type { Env, Variables } from "../types";

const contentPart = z.discriminatedUnion("type", [
  z.object({
    type: z.enum(["input_text", "output_text"]),
    text: z.string().min(1).max(200_000),
    image_url: z.never().optional(),
    detail: z.never().optional(),
  }).strict(),
  z.object({
    type: z.literal("input_image"),
    image_url: z.string().min(1).max(900_000),
    detail: z.enum(["auto", "low", "high", "original"]).optional(),
    text: z.never().optional(),
  }).strict(),
]);

const requestSchema = z.object({
  model: z.enum(["gpt-5.4-mini", "gpt-5.4"]).optional(),
  instructions: z.string().max(20_000).optional(),
  input: z.unknown().optional(),
  // Accepted for compatibility with the native payload, but always overridden below.
  stream: z.boolean().optional(),
  store: z.boolean().optional(),
  messages: z.array(z.object({
    role: z.enum(["user", "assistant", "system", "developer"]),
    content: z.union([
      z.string().max(200_000),
      z.array(contentPart).min(1).max(50),
    ]),
  }).strict()).max(100).optional(),
}).strict();

const MAX_OPENAI_BODY_BYTES = 1_000_000;

export const assistantRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

assistantRoutes.post("/responses", async (c) => {
  const parsed = requestSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const { messages, input: explicitInput, model, instructions } = parsed.data;
  const input = explicitInput ?? messages;
  if (input == null) return c.json({ error: "validation_error", message: "input or messages is required" }, 422);
  let body: string;
  try {
    body = JSON.stringify({
      model: model ?? "gpt-5.4-mini",
      ...(instructions == null ? {} : { instructions }),
      input,
      stream: true,
      store: false,
    });
  } catch {
    return c.json({ error: "validation_error", message: "Request must be JSON serializable" }, 422);
  }
  if (new TextEncoder().encode(body).byteLength > MAX_OPENAI_BODY_BYTES) {
    return c.json({ error: "payload_too_large", message: "Assistant request exceeds 1 MB" }, 422);
  }
  const upstream = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { Authorization: `Bearer ${c.env.OPENAI_API_KEY}`, "Content-Type": "application/json", Accept: "text/event-stream" },
    body,
    signal: c.req.raw.signal,
  });
  if (!upstream.ok) {
    return c.json({ error: "upstream_error", message: "OpenAI request failed", upstreamStatus: upstream.status }, 502, { "Cache-Control": "no-store" });
  }
  const contentType = upstream.headers.get("content-type")?.toLowerCase() ?? "";
  if (!upstream.body || !contentType.includes("text/event-stream")) {
    return c.json({ error: "upstream_error", message: "OpenAI returned an invalid streaming response" }, 502, { "Cache-Control": "no-store" });
  }
  const headers = new Headers({ "Content-Type": "text/event-stream", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" });
  const requestId = upstream.headers.get("x-request-id"); if (requestId) headers.set("x-request-id", requestId);
  return new Response(upstream.body, { status: upstream.status, headers });
});
