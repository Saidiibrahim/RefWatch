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
| `GET /diagnostics/ping` | Lightweight health check for Settings. | Verifies Clerk token and returns `ok`, `clerkUserId`, timestamp. No database dependency beyond verification. |
| `GET /entitlements` | Returns the canonical entitlements snapshot. | Optional until we add paid tiers; still useful for free-tier auditing. |
| `POST /iap/verify` | Validates StoreKit transactions and updates entitlements. | Requires App Store Server API credentials and the entitlements tables. |
| `POST /matches/ingest` (future) | Accepts match summaries uploaded from iOS. | Depends on Phase 2 schema (`matches`, `match_events`, etc.). |

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
4. **Implement token verification** using `@clerk/backend` or a JWKS verifier.
5. **Interact with Postgres** via the Supabase JS client. Respect RLS by running
   with the service role key and manually enforcing authorization rules.
6. **Test locally**
   ```bash
   supabase functions serve <name> --env-file .env.local
   ```
   Use the Settings diagnostic call or curl to verify 200 responses.
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
