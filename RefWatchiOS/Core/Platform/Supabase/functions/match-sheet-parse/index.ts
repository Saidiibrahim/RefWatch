import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import {
  buildMatchSheetParseResponsesRequest,
  parseMatchSheetParseClientRequest,
  parseOpenAIResponsesResult,
} from "./contract.ts";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";

interface AuthenticatedUser {
  id: string;
  email?: string | null;
}

interface MatchSheetParseDependencies {
  authenticateUser: (jwt: string) => Promise<AuthenticatedUser | null>;
  fetchImpl: typeof fetch;
  openAiApiKey: string;
}

if (import.meta.main) {
  serve(createMatchSheetParseHandler(loadLiveDependencies()));
}

export function createMatchSheetParseHandler(
  dependencies: MatchSheetParseDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    try {
      if (req.method === "OPTIONS") {
        return new Response(null, {
          status: 204,
          headers: corsHeaders(),
        });
      }

      if (req.method !== "POST") {
        return jsonResponse({ error: "not_found" }, 404);
      }

      const authHeader = req.headers.get("Authorization");
      if (authHeader?.startsWith("Bearer ") !== true) {
        return jsonResponse(
          {
            error: "unauthorized",
            message: "Missing or invalid Authorization header",
          },
          401,
        );
      }

      const jwt = authHeader.slice("Bearer ".length).trim();
      const user = await dependencies.authenticateUser(jwt);
      if (user == null) {
        return jsonResponse(
          {
            error: "unauthorized",
            message: "Failed to validate user session",
          },
          401,
        );
      }

      const rawBody = await parseJsonBody(req);
      const requestPayload = parseMatchSheetParseClientRequest(rawBody);
      const openAiRequest = buildMatchSheetParseResponsesRequest(requestPayload);

      console.log("match-sheet-parse: forwarding request", {
        userId: user.id,
        side: requestPayload.side,
        imageCount: requestPayload.images.length,
        client: req.headers.get("X-RefWatch-Client") ?? "unknown",
      });

      const upstream = await dependencies.fetchImpl(OPENAI_RESPONSES_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${dependencies.openAiApiKey}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(openAiRequest),
        signal: req.signal,
      });

      const requestId = upstream.headers.get("x-request-id");
      const upstreamText = await upstream.text();

      if (!upstream.ok) {
        console.error("match-sheet-parse: upstream error", {
          requestId,
          status: upstream.status,
          body: upstreamText,
        });
        return jsonResponse(
          {
            error: "upstream_error",
            message: extractUpstreamMessage(upstreamText),
            upstreamStatus: upstream.status,
            requestId,
          },
          502,
        );
      }

      const upstreamJson = parseJsonText(upstreamText);
      let result;
      try {
        result = parseOpenAIResponsesResult(
          upstreamJson,
          requestPayload.expectedTeamName,
        );
      } catch (error) {
        return jsonResponse(
          {
            error: "invalid_model_output",
            message: error instanceof Error ? error.message : "OpenAI returned an invalid structured result.",
          },
          422,
        );
      }

      const responseHeaders = corsHeaders();
      responseHeaders.set("Content-Type", "application/json");
      responseHeaders.set("Cache-Control", "no-store");
      if (requestId) {
        responseHeaders.set("x-request-id", requestId);
      }

      return new Response(JSON.stringify(result), {
        status: 200,
        headers: responseHeaders,
      });
    } catch (error) {
      if (error instanceof Response) {
        return error;
      }

      console.error("match-sheet-parse: unexpected failure", error);
      return jsonResponse(
        {
          error: "internal_error",
        },
        500,
      );
    }
  };
}

function loadLiveDependencies(): MatchSheetParseDependencies {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const openAiApiKey = Deno.env.get("OPENAI_API_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variable");
  }

  if (!openAiApiKey) {
    throw new Error("Missing OPENAI_API_KEY environment variable");
  }

  return {
    openAiApiKey,
    fetchImpl: fetch,
    authenticateUser: async (jwt: string) => {
      const supabase = createClient(supabaseUrl, supabaseAnonKey);
      const {
        data: { user },
        error,
      } = await supabase.auth.getUser(jwt);

      if (error || !user) {
        console.error("match-sheet-parse: failed to validate auth token", {
          error: error?.message,
        });
        return null;
      }

      return {
        id: user.id,
        email: user.email,
      };
    },
  };
}

function corsHeaders(): Headers {
  return new Headers({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type, x-refwatch-client",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  });
}

function jsonResponse(body: unknown, status = 200): Response {
  const headers = corsHeaders();
  headers.set("Content-Type", "application/json");
  headers.set("Cache-Control", "no-store");
  return new Response(JSON.stringify(body), {
    status,
    headers,
  });
}

async function parseJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    const payload = await req.json();
    if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
      throw new Error("Request body must be a JSON object.");
    }
    return payload as Record<string, unknown>;
  } catch (error) {
    console.error("match-sheet-parse: invalid request payload", error);
    throw jsonResponse(
      {
        error: "invalid_payload",
      },
      422,
    );
  }
}

function parseJsonText(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch (error) {
    console.error("match-sheet-parse: upstream returned invalid JSON", error);
    throw jsonResponse(
      {
        error: "invalid_upstream_response",
        message: "OpenAI returned malformed JSON.",
      },
      502,
    );
  }
}

function extractUpstreamMessage(upstreamText: string): string {
  if (upstreamText.trim().length === 0) {
    return "OpenAI rejected the parser request.";
  }

  try {
    const payload = JSON.parse(upstreamText) as Record<string, unknown>;
    if (typeof payload.error === "object" && payload.error !== null) {
      const errorRecord = payload.error as Record<string, unknown>;
      if (typeof errorRecord.message === "string" && errorRecord.message.trim().length > 0) {
        return errorRecord.message;
      }
    }
  } catch {
    // Ignore malformed upstream error envelopes and fall back to raw text.
  }

  return upstreamText;
}
