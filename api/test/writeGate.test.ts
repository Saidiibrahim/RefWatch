import { describe, expect, it } from "vitest";
import { app } from "../src/index";
import { writesAreDisabled } from "../src/middleware/writeGate";
import type { Env } from "../src/types";

describe("emergency write gate", () => {
  it("requires the explicit disabled value", () => {
    expect(writesAreDisabled({})).toBe(false);
    expect(writesAreDisabled({ WRITE_MODE: "enabled" })).toBe(false);
    expect(writesAreDisabled({ WRITE_MODE: " DISABLED " })).toBe(true);
    expect(writesAreDisabled({ WRITE_MODE: "disable-typo" })).toBe(true);
  });

  it("rejects API mutations before authentication or database access", async () => {
    const response = await app.request("/api/matches", { method: "POST" }, {
      WRITE_MODE: "disabled",
    } as Env);

    expect(response.status).toBe(503);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("Retry-After")).toBe("300");
    await expect(response.json()).resolves.toEqual({ error: "writes_temporarily_disabled" });
  });

  it("rejects webhook mutations while the write gate is active", async () => {
    const response = await app.request("/webhooks/clerk", { method: "POST" }, {
      WRITE_MODE: "disabled",
    } as Env);
    expect(response.status).toBe(503);
  });

  it("keeps health and protected read paths available", async () => {
    const env = { WRITE_MODE: "disabled", REFWATCH_ENV: "test" } as Env;
    const health = await app.request("/health", {}, env);
    const protectedRead = await app.request("/api/me", {}, env);

    expect(health.status).toBe(200);
    expect(protectedRead.status).toBe(401);
  });

  it("allows mutations to reach normal authentication when enabled", async () => {
    const response = await app.request("/api/matches", { method: "POST" }, {
      WRITE_MODE: "enabled",
    } as Env);
    expect(response.status).toBe(401);
  });
});
