import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_MODEL = "gpt-5.4-mini";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const openAiApiKey = Deno.env.get("OPENAI_API_KEY");

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variable");
}

if (!openAiApiKey) {
  throw new Error("Missing OPENAI_API_KEY environment variable");
}

serve(async (req) => {
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
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse(
        {
          error: "unauthorized",
          message: "Missing or invalid Authorization header",
        },
        401,
      );
    }

    const jwt = authHeader.slice("Bearer ".length).trim();
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(jwt);

    if (authError || !user) {
      console.error("assistant-responses: failed to validate auth token", {
        error: authError?.message,
      });
      return jsonResponse(
        {
          error: "unauthorized",
          message: "Failed to validate user session",
        },
        401,
      );
    }

    const rawBody = await parseJsonBody(req);
    const requestPayload = normalizeRequestPayload(rawBody);

    console.log("assistant-responses: forwarding request", {
      userId: user.id,
      model: requestPayload.model,
      inputCount: Array.isArray(requestPayload.input) ? requestPayload.input.length : 0,
      client: req.headers.get("X-RefWatch-Client") ?? "unknown",
    });

    const upstream = await fetch(OPENAI_RESPONSES_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiApiKey}`,
        "Content-Type": "application/json",
        Accept: "text/event-stream",
      },
      body: JSON.stringify(requestPayload),
      signal: req.signal,
    });

    if (!upstream.body) {
      console.error("assistant-responses: upstream response had no body", {
        status: upstream.status,
      });
      return jsonResponse(
        {
          error: "upstream_error",
          message: "OpenAI returned an empty response body",
        },
        502,
      );
    }

    const headers = new Headers(upstream.headers);
    headers.set("Cache-Control", "no-store");
    headers.set("Access-Control-Allow-Origin", "*");
    headers.set("Access-Control-Allow-Headers", "authorization, content-type, x-refwatch-client");
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");

    const requestId = upstream.headers.get("x-request-id");
    if (requestId) {
      headers.set("x-request-id", requestId);
    }

    return new Response(upstream.body, {
      status: upstream.status,
      headers,
    });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }

    console.error("assistant-responses: unexpected failure", error);
    return jsonResponse(
      {
        error: "internal_error",
      },
      500,
    );
  }
});

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

async function parseJsonBody(req: Request): Promise<JsonObject> {
  try {
    const payload = await req.json();
    if (!isObject(payload)) {
      throw new Error("request body must be a JSON object");
    }
    return payload;
  } catch (error) {
    console.error("assistant-responses: invalid request payload", error);
    throw jsonResponse(
      {
        error: "invalid_payload",
      },
      422,
    );
  }
}

function normalizeRequestPayload(body: JsonObject): JsonObject {
  const input = normalizeInput(body);
  if (input.length === 0) {
    throw jsonResponse(
      {
        error: "invalid_payload",
        message: "Request must include either input or messages with at least one text or image part",
      },
      422,
    );
  }

  const payload: JsonObject = {
    model: DEFAULT_MODEL,
    stream: true,
    store: false,
    input,
  };

  const instructions = readString(body.instructions) ?? readString(body.system_prompt) ?? readString(body.systemPrompt);
  if (instructions) {
    payload.instructions = instructions;
  }

  for (const key of [
    "include",
    "metadata",
    "max_output_tokens",
    "temperature",
    "top_p",
    "parallel_tool_calls",
    "tools",
    "tool_choice",
    "truncation",
    "reasoning",
    "user",
  ]) {
    const value = body[key];
    if (value !== undefined) {
      payload[key] = value;
    }
  }

  return payload;
}

function normalizeInput(body: JsonObject): JsonObject[] {
  const directInput = Array.isArray(body.input) ? body.input : null;
  if (directInput && directInput.length > 0) {
    return directInput.flatMap((item) => normalizeInputItem(item));
  }

  const messages = Array.isArray(body.messages) ? body.messages : null;
  if (messages && messages.length > 0) {
    return messages.flatMap((item) => normalizeMessage(item));
  }

  return [];
}

function normalizeInputItem(item: unknown): JsonObject[] {
  if (!isObject(item)) {
    return [];
  }

  const role = normalizeRole(readString(item.role));
  const parts = normalizeContentParts(item);
  if (parts.length === 0) {
    return [];
  }

  return [
    {
      role,
      content: parts,
    },
  ];
}

function normalizeMessage(item: unknown): JsonObject[] {
  if (!isObject(item)) {
    return [];
  }

  const role = normalizeRole(readString(item.role));
  const parts = normalizeContentParts(item);
  if (parts.length === 0) {
    return [];
  }

  return [
    {
      role,
      content: parts,
    },
  ];
}

function normalizeContentParts(item: JsonObject): JsonObject[] {
  const parts: JsonObject[] = [];

  appendTextPart(parts, readString(item.text));
  appendTextPart(parts, readString(item.content));
  appendTextPart(parts, readString(item.prompt));

  const content = item.content;
  if (Array.isArray(content)) {
    for (const entry of content) {
      const normalized = normalizeContentEntry(entry);
      if (normalized) {
        parts.push(normalized);
      }
    }
  } else if (isObject(content)) {
    const normalized = normalizeContentEntry(content);
    if (normalized) {
      parts.push(normalized);
    }
  }

  const attachments = item.attachments;
  if (Array.isArray(attachments)) {
    for (const attachment of attachments) {
      const normalized = normalizeImageReference(attachment);
      if (normalized) {
        parts.push(normalized);
      }
    }
  }

  const attachment = item.attachment;
  if (attachment !== undefined) {
    const normalized = normalizeImageReference(attachment);
    if (normalized) {
      parts.push(normalized);
    }
  }

  return parts;
}

function normalizeContentEntry(entry: unknown): JsonObject | null {
  if (typeof entry === "string") {
    return {
      type: "input_text",
      text: entry,
    };
  }

  if (!isObject(entry)) {
    return null;
  }

  const type = readString(entry.type);
  if (type === "input_text" || type === "text") {
    const text = readString(entry.text) ?? readString(entry.value);
    return text ? { type: "input_text", text } : null;
  }

  if (type === "input_image" || type === "image") {
    return normalizeImageReference(entry);
  }

  if (readString(entry.text)) {
    return {
      type: "input_text",
      text: readString(entry.text),
    };
  }

  return normalizeImageReference(entry);
}

function normalizeImageReference(value: unknown): JsonObject | null {
  if (typeof value === "string") {
    return {
      type: "input_image",
      image_url: value,
    };
  }

  if (!isObject(value)) {
    return null;
  }

  const detail = readString(value.detail);
  const imageUrl =
    readUrlLike(value.image_url) ??
    readUrlLike(value.imageUrl) ??
    readUrlLike(value.url) ??
    readUrlLike(value.data_url) ??
    readUrlLike(value.dataUrl) ??
    readUrlLike(value.data);
  const fileId = readString(value.file_id) ?? readString(value.fileId) ?? readString(value.id);
  const base64 = readString(value.base64);
  const mimeType = readString(value.mime_type) ?? readString(value.mimeType) ?? readString(value.type);

  if (imageUrl) {
    return {
      type: "input_image",
      image_url: imageUrl,
      ...(detail ? { detail } : {}),
    };
  }

  if (base64 && mimeType) {
    return {
      type: "input_image",
      image_url: `data:${mimeType};base64,${base64}`,
      ...(detail ? { detail } : {}),
    };
  }

  if (fileId) {
    return {
      type: "input_image",
      file_id: fileId,
      ...(detail ? { detail } : {}),
    };
  }

  return null;
}

function appendTextPart(parts: JsonObject[], value: string | null): void {
  const text = value?.trim();
  if (!text) {
    return;
  }

  parts.push({
    type: "input_text",
    text,
  });
}

function normalizeRole(role: string | null): string {
  switch (role) {
    case "assistant":
    case "developer":
    case "system":
    case "tool":
    case "user":
      return role;
    default:
      return "user";
  }
}

function readString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function readUrlLike(value: unknown): string | null {
  if (typeof value === "string") {
    return value.trim().length > 0 ? value.trim() : null;
  }

  if (!isObject(value)) {
    return null;
  }

  return (
    readString(value.url) ??
    readString(value.href) ??
    readString(value.image_url) ??
    readString(value.imageUrl) ??
    readString(value.data_url) ??
    readString(value.dataUrl)
  );
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && Array.isArray(value) === false;
}

type JsonObject = Record<string, unknown>;
