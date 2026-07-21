import { createMiddleware } from "hono/factory";
import type { Env, Variables } from "../types";

export const workerVersionOverrideHeader = "Cloudflare-Workers-Version-Overrides";
export const cutoverAcceptanceTokenHeader = "X-RefWatch-Cutover-Token";

const workerName = "refwatch-api";
const versionIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function constantTimeEqual(left: string, right: string): boolean {
  const length = Math.max(left.length, right.length);
  let mismatch = left.length ^ right.length;
  for (let index = 0; index < length; index += 1) {
    mismatch |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return mismatch === 0;
}

function exactOverriddenVersion(value: string): string | null {
  const trimmed = value.trim();
  const prefix = `${workerName}="`;
  if (!trimmed.startsWith(prefix) || !trimmed.endsWith("\"")) return null;
  const versionId = trimmed.slice(prefix.length, -1);
  return versionIdPattern.test(versionId) ? versionId : null;
}

/**
 * Version B is held at zero ordinary traffic during bounded acceptance. A
 * server-side harness can select it with Cloudflare's version-override header,
 * but only while also presenting the non-echoed cutover token. Normal
 * production traffic never needs or receives this token.
 */
export function cutoverVersionOverrideGate() {
  return createMiddleware<{ Bindings: Env; Variables: Variables }>(async (c, next) => {
    const overrideHeader = c.req.header(workerVersionOverrideHeader);
    if (!overrideHeader) {
      await next();
      return;
    }

    const overriddenVersion = exactOverriddenVersion(overrideHeader);
    const servedVersion = c.env.CF_VERSION_METADATA?.id;
    const expectedToken = c.env.CUTOVER_ACCEPTANCE_TOKEN;
    const suppliedToken = c.req.header(cutoverAcceptanceTokenHeader);
    if (
      !overriddenVersion
      || !servedVersion
      || overriddenVersion !== servedVersion
      || !expectedToken
      || !suppliedToken
      || !constantTimeEqual(suppliedToken, expectedToken)
    ) {
      c.header("Cache-Control", "no-store");
      return c.json({ error: "cutover_version_override_forbidden" }, 403);
    }

    await next();
  });
}
