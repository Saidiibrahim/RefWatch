import { createMiddleware } from "hono/factory";
import type { Env, Variables } from "../types";

const readOnlyMethods = new Set(["GET", "HEAD", "OPTIONS"]);

export function writesAreDisabled(env: Pick<Env, "WRITE_MODE">): boolean {
  if (env.WRITE_MODE == null) return false;
  return env.WRITE_MODE.trim().toLowerCase() !== "enabled";
}

export function writeGate() {
  return createMiddleware<{ Bindings: Env; Variables: Variables }>(async (c, next) => {
    if (writesAreDisabled(c.env) && !readOnlyMethods.has(c.req.method.toUpperCase())) {
      c.header("Cache-Control", "no-store");
      c.header("Retry-After", "300");
      return c.json({ error: "writes_temporarily_disabled" }, 503);
    }
    await next();
  });
}
