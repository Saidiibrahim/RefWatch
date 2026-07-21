import { describe, expect, it } from "vitest";
import { app } from "../src/index";
import {
  cutoverAcceptanceTokenHeader,
  workerVersionOverrideHeader,
} from "../src/middleware/cutoverVersionOverrideGate";
import type { Env } from "../src/types";

const workerVersionId = "0190f8f4-5914-7b6c-9d6a-469a29f92f22";
const token = "bounded-server-side-token";
const overrideValue = `refwatch-api="${workerVersionId}"`;

function cutoverEnv(overrides: Partial<Env> = {}): Env {
  return {
    REFWATCH_ENV: "production",
    CUTOVER_ACCEPTANCE_TOKEN: token,
    CF_VERSION_METADATA: { id: workerVersionId },
    ...overrides,
  } as Env;
}

describe("cutover Worker-version override gate", () => {
  it("leaves normal traffic token-free", async () => {
    const response = await app.request("/health", {}, cutoverEnv());

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      status: "ok",
      worker_version_id: workerVersionId,
    });
  });

  it("permits the exact overridden version only with the server-side token", async () => {
    const response = await app.request("/health", {
      headers: {
        [workerVersionOverrideHeader]: overrideValue,
        [cutoverAcceptanceTokenHeader]: token,
      },
    }, cutoverEnv());

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      worker_version_id: workerVersionId,
    });
  });

  it.each([
    {
      label: "missing token",
      headers: { [workerVersionOverrideHeader]: overrideValue },
      env: {},
    },
    {
      label: "invalid token",
      headers: {
        [workerVersionOverrideHeader]: overrideValue,
        [cutoverAcceptanceTokenHeader]: "wrong",
      },
      env: {},
    },
    {
      label: "served-version mismatch",
      headers: {
        [workerVersionOverrideHeader]: overrideValue,
        [cutoverAcceptanceTokenHeader]: token,
      },
      env: {
        CF_VERSION_METADATA: {
          id: "0190f8f4-5914-7b6c-9d6a-469a29f92f23",
        },
      },
    },
    {
      label: "malformed override",
      headers: {
        [workerVersionOverrideHeader]: `other-worker="${workerVersionId}"`,
        [cutoverAcceptanceTokenHeader]: token,
      },
      env: {},
    },
  ])("fails closed for $label without echoing the token", async ({ headers, env }) => {
    const response = await app.request("/health", { headers }, cutoverEnv(env));

    expect(response.status).toBe(403);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    const body = await response.text();
    expect(body).toContain("cutover_version_override_forbidden");
    expect(body).not.toContain(token);
  });
});
