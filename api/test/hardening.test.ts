import { afterEach, describe, expect, it, vi } from "vitest";
import { assistantRoutes } from "../src/routes/assistant";
import type { Env } from "../src/types";
import { snakeCaseJSON } from "../src/utils/json";

afterEach(() => vi.unstubAllGlobals());

describe("JSON response casing", () => {
  it("snake-cases database columns without rewriting JSONB domain keys", () => {
    const value = snakeCaseJSON({
      updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      finalScore: { homeYellowCards: 2, nestedValue: { playerDisplayName: "A" } },
      payload: { eventType: "yellowCard", playerName: "A" },
      wrapper: { createdAt: new Date("2026-07-14T00:00:00.000Z") },
    });
    expect(value).toEqual({
      updated_at: "2026-07-14T00:00:00.000Z",
      final_score: { homeYellowCards: 2, nestedValue: { playerDisplayName: "A" } },
      payload: { eventType: "yellowCard", playerName: "A" },
      wrapper: { created_at: "2026-07-14T00:00:00.000Z" },
    });
  });
});

describe("assistant proxy constraints", () => {
  it("rejects unapproved models before calling OpenAI", async () => {
    const fetchMock = vi.fn(); vi.stubGlobal("fetch", fetchMock);
    const response = await assistantRoutes.request("/responses", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ model: "arbitrary-model", messages: [{ role: "user", content: "hello" }] }),
    }, { OPENAI_API_KEY: "server-secret" } as Env);
    expect(response.status).toBe(422);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("whitelists the upstream payload and forces safe streaming options", async () => {
    let upstreamBody = ""; let authorization = "";
    vi.stubGlobal("fetch", vi.fn(async (_url: string, init?: RequestInit) => {
      upstreamBody = String(init?.body); authorization = new Headers(init?.headers).get("Authorization") ?? "";
      return new Response("data: done\n\n", { status: 200, headers: { "Content-Type": "text/event-stream", "x-request-id": "req_1" } });
    }));
    const response = await assistantRoutes.request("/responses", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ model: "gpt-5.4-mini", messages: [{ role: "user", content: "hello" }] }),
    }, { OPENAI_API_KEY: "server-secret" } as Env);
    expect(response.status).toBe(200);
    expect(authorization).toBe("Bearer server-secret");
    expect(JSON.parse(upstreamBody)).toMatchObject({ model: "gpt-5.4-mini", stream: true, store: false });
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("Content-Type")).toContain("text/event-stream");
  });

  it("accepts and normalizes the active Swift structured payload", async () => {
    let upstreamBody: Record<string, unknown> = {};
    vi.stubGlobal("fetch", vi.fn(async (_url: string, init?: RequestInit) => {
      upstreamBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response("data: done\n\n", {
        status: 200,
        headers: { "Content-Type": "text/event-stream" },
      });
    }));
    const messages = [{
      role: "user",
      content: [
        { type: "input_text", text: "Review this decision" },
        { type: "input_image", image_url: "data:image/jpeg;base64,ZmFrZQ==", detail: "high" },
      ],
    }, {
      role: "assistant",
      content: [{ type: "output_text", text: "Previous response" }],
    }];

    const response = await assistantRoutes.request("/responses", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-5.4-mini",
        instructions: "Be concise.",
        messages,
        stream: false,
        store: true,
      }),
    }, { OPENAI_API_KEY: "server-secret" } as Env);

    expect(response.status).toBe(200);
    expect(upstreamBody).toEqual({
      model: "gpt-5.4-mini",
      instructions: "Be concise.",
      input: messages,
      stream: true,
      store: false,
    });
    expect(upstreamBody).not.toHaveProperty("messages");
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });
});
