import type { Env } from "../types";

export function workerVersionId(env?: Pick<Env, "CF_VERSION_METADATA" | "REFWATCH_ENV">): string {
  const versionId = env?.CF_VERSION_METADATA?.id?.trim();
  if (versionId) return versionId;
  if (env?.REFWATCH_ENV === "production" || env?.REFWATCH_ENV === "rehearsal") {
    throw new Error("CF_VERSION_METADATA binding is required for mutation capture");
  }
  return "local-development";
}
