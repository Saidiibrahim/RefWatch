import { describe, expect, it } from "vitest";
import { app } from "../src/index";
import type { Env } from "../src/types";

describe("public routes", () => {
  it("exposes health without authentication or database access", async () => {
    const response = await app.request("/health", {}, { REFWATCH_ENV: "test" } as Env);
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      status: "ok",
      environment: "test",
      worker_version_id: "unknown",
    });
  });

  it("fails readiness without exposing database errors when no binding exists", async () => {
    const response = await app.request("/health/ready", {}, {} as Env);
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      status: "not_ready",
      database: "unavailable",
    });
  });

  it("does not expose protected routes without a bearer token", async () => {
    const response = await app.request("/api/me", {}, {} as Env);
    expect(response.status).toBe(401);
  });

  it("protects the reference catalog behind Clerk authentication", async () => {
    const response = await app.request("/api/reference-catalog/teams?seasonYear=2026", {}, {} as Env);
    expect(response.status).toBe(401);
  });
});
