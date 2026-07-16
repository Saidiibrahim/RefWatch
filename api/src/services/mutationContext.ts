import type { Context } from "hono";
import type { Env, Variables } from "../types";
import type { MutationContext } from "./mutationLedger";
import { workerVersionId } from "./workerVersion";

type APIContext = Context<{ Bindings: Env; Variables: Variables }>;

export function httpMutationContext(c: APIContext, routeTemplate: string): MutationContext {
  return {
    sourceKind: "http",
    requestId: crypto.randomUUID(),
    workerVersionId: workerVersionId(c.env),
    idempotencyKey: c.req.header("Idempotency-Key")?.trim() || null,
    appUserId: c.get("auth").appUserId,
    method: c.req.method.toUpperCase(),
    path: routeTemplate,
    actorId: c.get("auth").clerkUserId,
  };
}
