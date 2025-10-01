# Draft — Supabase Edge Functions for iOS Identity & Diagnostics (Retired)

> **Status**: Edge functions are currently disabled for the iOS app. Identity bootstrap now calls Supabase GoTrue directly and writes to `public.users` via PostgREST. This draft remains for reference only and still references the retired Clerk flow where relevant.

> Status: **Draft**. These edge functions are not yet implemented inside the Supabase
> project. This document captures the expected behavior, payload contracts, and
> scaffolding so the Supabase team can deploy them quickly.

## Shared Notes
- Runtime: Supabase Edge Functions (Deno).
- Libraries: `@supabase/supabase-js@2`, `@clerk/backend`, std/http `serve`.
- Environment variables required:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `CLERK_SECRET_KEY`
- All functions expect the inbound request to include a Clerk session token in
  the `Authorization: Bearer <token>` header. The helper `requireClerkSession`
  (below) validates the token and returns the matching Clerk user id.
- Errors should map to HTTP status codes consumed by the iOS diagnostics screen:
  - `401` → invalid/expired Clerk session.
  - `403` → Clerk user is not allowed (rare; defensive guard).
  - `404` → underlying Postgres record missing.
  - `422` → bad payload.
  - `500` → unexpected internal error.

```ts
// _shared/clerk.ts
import { Clerk } from "https://esm.sh/@clerk/backend@1";

const clerk = Clerk({ secretKey: Deno.env.get("CLERK_SECRET_KEY") ?? "" });

export async function requireClerkSession(req: Request) {
  const header = req.headers.get("Authorization") ?? "";
  const [, token] = header.split(" ");
  if (!token) {
    throw new Response(JSON.stringify({ error: "missing authorization" }), { status: 401 });
  }
  try {
    const session = await clerk.sessions.verifyToken(token);
    return { clerkUserId: session.userId, sessionId: session.id };
  } catch (error) {
    console.error("Clerk verification failed", error);
    throw new Response(JSON.stringify({ error: "invalid session" }), { status: 401 });
  }
}
```

```ts
// _shared/supabase.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!url || !serviceRoleKey) {
  throw new Error("Missing Supabase environment variables");
}

export function serviceRoleClient() {
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false },
  });
}
```

---

## 1. `upsert_user_from_clerk`

- **Method**: `POST`
- **Purpose**: Mirror Clerk profile payload into `public.users` via the
  Postgres RPC `public.upsert_user_from_clerk(payload jsonb)` and return the
  resulting row.
- **Request Body**: JSON derived from `SupabaseIdentityPayload` in the iOS app.
- **Response**: `200 OK` with the inserted/updated `users` row (selected fields).

```ts
// upsert_user_from_clerk/index.ts
import { serve } from "https://deno.land/std/http/server.ts";
import { requireClerkSession } from "../_shared/clerk.ts";
import { serviceRoleClient } from "../_shared/supabase.ts";

const supabase = serviceRoleClient();

serve(async (req) => {
  try {
    const { clerkUserId } = await requireClerkSession(req);
    const payload = await req.json().catch(() => null);
    if (!payload || typeof payload !== "object") {
      return new Response(JSON.stringify({ error: "invalid payload" }), { status: 422 });
    }

    // Enforce that the payload clerk id matches the token subject.
    if (payload.clerk_user_id && payload.clerk_user_id !== clerkUserId) {
      return new Response(JSON.stringify({ error: "clerk id mismatch" }), { status: 422 });
    }

    const { data, error } = await supabase.rpc("upsert_user_from_clerk", { payload });
    if (error) {
      console.error("RPC upsert_user_from_clerk failed", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }
    if (!data) {
      return new Response(JSON.stringify({ error: "user row missing" }), { status: 404 });
    }

    return new Response(JSON.stringify({
      id: data.id,
      clerk_user_id: data.clerk_user_id,
      primary_email: data.primary_email,
      display_name: data.display_name,
      clerk_last_synced_at: data.clerk_last_synced_at,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (response) {
    if (response instanceof Response) {
      return response;
    }
    console.error("Unexpected error", response);
    return new Response(JSON.stringify({ error: "internal error" }), { status: 500 });
  }
});
```

### TODOs
- Decide whether to copy additional fields (e.g., metadata blobs) into the edge
  response for diagnostics.
- Add structured logging (trace id, request id) consistent with platform logs.

---

## 2. `upsert_user_device_from_clerk`

- **Method**: `POST`
- **Purpose**: Persist active device & session metadata to `public.user_devices`
  via `public.upsert_user_device_from_clerk(payload jsonb)`.
- **Request Body**: Matches `SupabaseDevicePayload` from the iOS app.
- **Response**: `200 OK` with the resulting `user_devices` row.

```ts
// upsert_user_device_from_clerk/index.ts
import { serve } from "https://deno.land/std/http/server.ts";
import { requireClerkSession } from "../_shared/clerk.ts";
import { serviceRoleClient } from "../_shared/supabase.ts";

const supabase = serviceRoleClient();

serve(async (req) => {
  try {
    const { clerkUserId, sessionId } = await requireClerkSession(req);
    const payload = await req.json().catch(() => null);
    if (!payload || typeof payload !== "object") {
      return new Response(JSON.stringify({ error: "invalid payload" }), { status: 422 });
    }

    // Ensure session id is present; fallback to Clerk session id if missing.
    const mergedPayload = {
      ...payload,
      session_id: payload.session_id ?? sessionId,
    };

    const { data, error } = await supabase.rpc("upsert_user_device_from_clerk", { payload: mergedPayload });
    if (error) {
      if (error.message.includes("No user row exists")) {
        return new Response(JSON.stringify({ error: "user missing" }), { status: 404 });
      }
      console.error("RPC upsert_user_device_from_clerk failed", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    return new Response(JSON.stringify({
      id: data.id,
      user_id: data.user_id,
      session_id: data.session_id,
      platform: data.platform,
      model: data.model,
      last_active_at: data.last_active_at,
      updated_at: data.updated_at,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (response) {
    if (response instanceof Response) {
      return response;
    }
    console.error("Unexpected error", response);
    return new Response(JSON.stringify({ error: "internal error" }), { status: 500 });
  }
});
```

### TODOs
- Consider rate limiting or deduplicating repeated device updates per session.
- Enrich metadata with inferred device model when the payload omits it.

---

## 3. `diagnostics-ping`

- **Method**: `GET`
- **Purpose**: Lightweight health check for Settings Diagnostics; verifies the
  Clerk session and returns timing metadata.
- **Response**: `200 OK` with `{ status: "ok", clerk_user_id, timestamp }`.

```ts
// diagnostics-ping/index.ts
import { serve } from "https://deno.land/std/http/server.ts";
import { requireClerkSession } from "../_shared/clerk.ts";

serve(async (req) => {
  const started = performance.now();
  try {
    const { clerkUserId, sessionId } = await requireClerkSession(req);
    const durationMs = Math.round(performance.now() - started);
    return new Response(JSON.stringify({
      status: "ok",
      clerk_user_id: clerkUserId,
      clerk_session_id: sessionId,
      duration_ms: durationMs,
      timestamp: new Date().toISOString(),
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (response) {
    if (response instanceof Response) {
      return response;
    }
    console.error("Diagnostics ping failed", response);
    return new Response(JSON.stringify({ error: "internal error" }), { status: 500 });
  }
});
```

### TODOs
- Add optional Supabase connectivity probe (e.g., lightweight SQL statement) to
  confirm Postgres availability during diagnostics.
- Wire through a request-id header for correlating iOS logs with backend logs.

---

## Deployment Checklist
1. Copy each folder into the Supabase project repository under
   `supabase/functions/<name>/`.
2. Add the shared helpers under `supabase/functions/_shared/`.
3. Configure environment variables via Supabase → Project Settings → API →
   **Edge Functions**.
4. Deploy: `supabase functions deploy upsert_user_from_clerk` and the others.
5. Update the iOS app to retry the diagnostics buttons after deployment; a 200
   response should populate Supabase identity/device state.
