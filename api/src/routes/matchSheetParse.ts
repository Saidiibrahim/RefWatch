import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { buildOpenAIRequest, matchSheetClientRequest, MAX_MATCH_SHEET_REQUEST_BYTES, parseOpenAIResult } from "./matchSheetContract";

export const matchSheetParseRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

matchSheetParseRoutes.post("/parse", async (c) => {
  const contentLength = Number(c.req.header("content-length"));
  if (Number.isFinite(contentLength) && contentLength > MAX_MATCH_SHEET_REQUEST_BYTES) return c.json({ error: "invalid_request", message: "Match-sheet request exceeds 25 MiB" }, 413);
  let body: unknown;
  try { body = await readBoundedJson(c.req.raw); }
  catch (error) {
    if (error instanceof MatchSheetPayloadTooLargeError) return c.json({ error: "invalid_request", message: "Match-sheet request exceeds 25 MiB" }, 413);
    body = null;
  }
  const parsed = matchSheetClientRequest.safeParse(body);
  if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const upstream = await fetch("https://api.openai.com/v1/responses", { method: "POST", headers: { Authorization: `Bearer ${c.env.OPENAI_API_KEY}`, "Content-Type": "application/json", Accept: "application/json" }, body: JSON.stringify(buildOpenAIRequest(parsed.data)), signal: c.req.raw.signal });
  const requestId = upstream.headers.get("x-request-id"); const text = await upstream.text();
  if (!upstream.ok) return c.json({ error: "upstream_error", message: safeUpstreamMessage(text), upstreamStatus: upstream.status, requestId }, 502);
  try {
    const result = parseOpenAIResult(JSON.parse(text), parsed.data.expected_team_name);
    const headers = new Headers({ "Content-Type": "application/json", "Cache-Control": "no-store" }); if (requestId) headers.set("x-request-id", requestId);
    return new Response(JSON.stringify(result), { status: 200, headers });
  } catch (error) { return c.json({ error: "invalid_model_output", message: error instanceof Error ? error.message : "Invalid structured result", requestId }, 422); }
});

export async function readBoundedJson(request: Request, limit = MAX_MATCH_SHEET_REQUEST_BYTES): Promise<unknown> {
  if (!request.body) return null;
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > limit) {
      await reader.cancel();
      throw new MatchSheetPayloadTooLargeError();
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return JSON.parse(new TextDecoder().decode(bytes));
}

class MatchSheetPayloadTooLargeError extends Error {}

function safeUpstreamMessage(text: string): string {
  try { const value = JSON.parse(text) as { error?: { message?: string } }; return value.error?.message ?? "OpenAI request failed"; } catch { return "OpenAI request failed"; }
}
