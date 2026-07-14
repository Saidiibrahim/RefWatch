import type { Context } from "hono";

export interface APIErrorBody {
  error: string;
  message?: string;
  details?: unknown;
}

export function errorJSON(
  c: Context,
  status: 400 | 401 | 403 | 404 | 409 | 422 | 500 | 502,
  error: string,
  message?: string,
  details?: unknown,
) {
  const body: APIErrorBody = { error };
  if (message) body.message = message;
  if (details !== undefined) body.details = details;
  return c.json(body, status);
}

export async function readJSON(request: Request): Promise<unknown> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    throw new HTTPError(415, "unsupported_media_type", "Content-Type must be application/json");
  }
  try {
    return await request.json();
  } catch {
    throw new HTTPError(422, "invalid_json", "Request body is not valid JSON");
  }
}

export class HTTPError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
  }
}

const defaultOpaqueJSONKeys = new Set([
  "awayMatchSheet",
  "content",
  "finalScore",
  "homeMatchSheet",
  "metadata",
  "payload",
  "responseBody",
  "result",
]);

/** Converts API DTO property names while leaving domain-owned JSONB documents untouched. */
export function snakeCaseJSON(value: unknown, opaqueJSONKeys = defaultOpaqueJSONKeys): unknown {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map((item) => snakeCaseJSON(item, opaqueJSONKeys));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [
      key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`),
      opaqueJSONKeys.has(key) ? item : snakeCaseJSON(item, opaqueJSONKeys),
    ]));
  }
  return value;
}
