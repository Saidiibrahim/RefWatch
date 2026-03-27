import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createMatchSheetParseHandler } from "./index.ts";
import { exampleOpenAIResponse, exampleParseRequest } from "./fixtures.ts";

Deno.test("handler rejects non-post methods", async () => {
  const handler = createMatchSheetParseHandler({
    openAiApiKey: "test-key",
    authenticateUser: async () => ({ id: "user-1" }),
    fetchImpl: async () => new Response("{}"),
  });

  const response = await handler(new Request("https://example.com", { method: "GET" }));

  assertEquals(response.status, 404);
});

Deno.test("handler requires authorization", async () => {
  const handler = createMatchSheetParseHandler({
    openAiApiKey: "test-key",
    authenticateUser: async () => ({ id: "user-1" }),
    fetchImpl: async () => new Response("{}"),
  });

  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      body: JSON.stringify(exampleParseRequest),
    }),
  );

  assertEquals(response.status, 401);
});

Deno.test("handler returns normalized completed payload", async () => {
  const capturedRequests: RequestInit[] = [];
  const handler = createMatchSheetParseHandler({
    openAiApiKey: "test-key",
    authenticateUser: async () => ({ id: "user-1" }),
    fetchImpl: async (_url, init) => {
      capturedRequests.push(init ?? {});
      return new Response(JSON.stringify(exampleOpenAIResponse), {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "x-request-id": "req_123",
        },
      });
    },
  });

  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(exampleParseRequest),
    }),
  );

  const json = await response.json();

  assertEquals(response.status, 200);
  assertEquals(json.terminalStatus, "completed");
  assertEquals(json.parsedSheet.status, "draft");
  assertEquals(capturedRequests.length, 1);
});

Deno.test("handler maps refused parser output into a terminal payload", async () => {
  const handler = createMatchSheetParseHandler({
    openAiApiKey: "test-key",
    authenticateUser: async () => ({ id: "user-1" }),
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          status: "completed",
          output: [
            {
              type: "message",
              content: [
                {
                  type: "refusal",
                  refusal: "I cannot parse these screenshots.",
                },
              ],
            },
          ],
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
          },
        },
      ),
  });

  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(exampleParseRequest),
    }),
  );

  const json = await response.json();

  assertEquals(response.status, 200);
  assertEquals(json.terminalStatus, "refused");
  assertEquals(json.warnings[0].code, "refusal");
});

Deno.test("handler rejects malformed structured json", async () => {
  const handler = createMatchSheetParseHandler({
    openAiApiKey: "test-key",
    authenticateUser: async () => ({ id: "user-1" }),
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          status: "completed",
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: "{not json",
                },
              ],
            },
          ],
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
          },
        },
      ),
  });

  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(exampleParseRequest),
    }),
  );

  assertEquals(response.status, 422);
});
