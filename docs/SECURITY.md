# SECURITY

Security baseline:
- Do not commit secrets or local credential files.
- Keep auth boundaries explicit across watchOS, iOS, and backend services.
- Prefer least-privilege data access and validate sensitive operations.
- Track security-relevant changes in exec plans and release notes.

## Backend migration boundary

- iOS may embed only the Worker base URL, Clerk publishable key, and Clerk Frontend API host.
- PlanetScale credentials, `DATABASE_URL`, `CLERK_SECRET_KEY`, `CLERK_JWT_KEY`, `CLERK_WEBHOOK_SIGNING_SECRET`, `OPENAI_API_KEY`, and Cloudflare administrative tokens are server-side only.
- The Worker must verify a Clerk session token and resolve its subject to an internal `app_users.id` before database access.
- Every user-scoped query, mutation, nested foreign reference, and idempotency key must be scoped to that internal ID. A client-supplied `owner_id` is never authoritative.
- Clerk subjects are strings and must not be parsed as UUIDs. Existing internal user UUIDs must be preserved through import.
- Clerk webhooks require signature verification and ordering/replay-safe handling; authentication must not silently resurrect a deleted internal user.
- OpenAI proxy routes require authenticated, bounded requests. Model allowlists, payload/output limits, and per-user abuse controls are production gates.

## Live legacy risk (2026-07-14)

The source-of-truth Supabase MCP readback found RLS disabled on nine live public tables: `match_officials`, `match_assessments`, `trend_snapshots`, `workout_session_metrics`, `workout_intensity_profile`, `workout_segments`, `coaches`, `feedback_attachments`, and `ai_usage_daily`.

This is a current security risk for any path that permits direct client access to those tables. Do not interpret historical migration files as proof that live RLS is enabled. Until Supabase is retired, restrict exposure and verify the live provider before each release. The target PlanetScale design does not use Supabase RLS; equivalent isolation must be proven in Worker/database-backed tests before cutover.

## Required evidence before production cutover

- Source, config, built-bundle, and log scans show no forbidden server credentials in iOS.
- Database-backed tests cover cross-user reads, writes, deletes, references, idempotency races, and `/api/me` identity creation/resolution.
- Invalid Clerk tokens and webhook signatures fail closed without leaking verifier details.
- Staging binding/readiness evidence shows Hyperdrive with no plaintext database URL; a separate production Worker binding inventory remains required.
- Live Supabase remains an explicit legacy risk/rollback surface until data reconciliation and credential retirement are recorded.

Operational details and setup guidance live in `docs/references/backend-migration-cutover.md`.
