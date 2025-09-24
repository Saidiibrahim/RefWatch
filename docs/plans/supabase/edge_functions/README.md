# Supabase Edge Function Playbook

We are not versioning edge-function code in this repository, but this document
captures everything needed when we are ready to build them inside the Supabase
project.

## When to Build
Start implementing functions once:
- The core tables from `PLAN_Supabase_Database_Schema.md` phase 1–2 are live.
- Clerk session tokens are confirmed working via `SupabaseTokenProvider` in the
  iOS app.
- The Settings connectivity check is ready to be pointed at a real endpoint
  instead of the temporary `todos` table.

## Proposed Functions
| Endpoint | Purpose | Notes |
| --- | --- | --- |
| `GET /diagnostics/ping` | Lightweight health check for Settings. | Verifies Clerk token and returns `{status:'ok', clerk_user_id, timestamp}`. No database dependency beyond verification. |
| `GET /entitlements` | Returns the canonical entitlements snapshot. | Optional until we add paid tiers; still useful for free-tier auditing. |
| `POST /iap/verify` | Validates StoreKit transactions and updates entitlements. | Requires App Store Server API credentials and the entitlements tables. |
| `POST /matches/ingest` (future) | Accepts match summaries uploaded from iOS. | Depends on Phase 2 schema (`matches`, `match_events`, etc.). |
| `GET /ai/threads` | List user threads (paginated). | Verifies Clerk token; selects from `ai_threads` by owner. |
| `POST /ai/threads` | Create a new thread with optional title/instructions/model. | Inserts into `ai_threads`; returns thread. |
| `GET /ai/threads/:id/messages` | Fetch messages for a thread. | Owner-only; ordered by `created_at asc`. |
| `POST /ai/threads/:id/messages` | Append a user message; optionally trigger stream. | Inserts `ai_messages` with `role='user'`. |
| `POST /ai/threads/:id/responses` | Start/continue assistant streaming (Responses API). | Streams tokens; persists `ai_messages` with `role='assistant'`, usage and parts. |
| `DELETE /ai/threads/:id` | Soft delete thread or hard delete. | Use `deleted_at` for soft-delete. |

Keep the list in sync with the architecture plan so we always know which
functions are expected.

## Implementation Checklist
1. **Set up Supabase CLI locally**
   ```bash
   brew install supabase/tap/supabase
   supabase login
   supabase link --project-ref <project>
   ```
2. **Create the function folder** inside `supabase/functions/<name>/index.ts` in
the Supabase project repository (not this app repo).
3. **Add environment variables** through Supabase → Project Settings → Secrets:
   - `CLERK_SECRET_KEY`
   - `CLERK_SESSION_TEMPLATE` (optional, if using templates)
   - `SUPABASE_SERVICE_ROLE_KEY` (implicitly available in Deno env)
   - Any App Store credentials for `iap/verify` (issuer, key ID, private key).
   - `OPENAI_API_KEY` (or provider-specific key) for Responses API.
   - `AI_DEFAULT_MODEL` (e.g., `gpt-4o-mini`).
   - `AI_DEFAULT_TEMPERATURE` (e.g., `0.2`).
   - `AI_DEFAULT_INSTRUCTIONS` (optional system instructions).
4. **Implement token verification** using `@clerk/backend` or a JWKS verifier.
5. **Interact with Postgres** via the Supabase JS client. Respect RLS by running
   with the service role key and manually enforcing authorization rules.
   - For AI endpoints, verify token → resolve `users.id` → execute queries against `ai_threads`/`ai_messages` with explicit `owner_id` checks even when using service role.
   - Use streaming with chunked responses; buffer partials into `content_parts` and update token usage once available from the Responses API usage block.
6. **Test locally**
   ```bash
   supabase functions serve <name> --env-file .env.local
   ```
   Use the Settings diagnostic call or curl to verify 200 responses.
   - For streaming: test `POST /assistant/threads/:id/stream` with EventSource or chunked fetch; confirm incremental inserts into `assistant_messages` and `last_activity_at` updates.
7. **Deploy**
   ```bash
   supabase functions deploy <name>
   ```
8. **Update the iOS app** to call the new endpoint and remove the temporary
   `todos` read.

## Local Notes & TODOs
- Track open questions or future enhancements here (e.g., logging format,
  retry policies).
- Link back to the architecture or schema plans as they evolve.

Maintaining this playbook keeps the Swift project clean while giving the team a
jumping-off point the moment we are ready to add real edge functions.
