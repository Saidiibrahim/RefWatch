# Backend Migration and Cutover

This runbook governs the migration from Supabase to Clerk authentication, the Cloudflare Workers/Hono API in `api/`, and PlanetScale Postgres. It separates repository implementation from provider operations so local code is never mistaken for a completed production cutover.

## Current status

As of 2026-07-14:

- Clerk + Cloudflare Workers/Hono + PlanetScale Postgres is the active target architecture.
- The Worker workspace, Drizzle target schema, Clerk/identity implementation, and backend client/repository adapters exist in the repository.
- Staging Worker deployment and Hyperdrive-backed `select 1` readiness passed against the disposable PlanetScale branch. Production provider deployment/bindings remain untouched.
- A disposable PlanetScale branch migration/readback and hash-matched global rehearsal (5 competitions, 54 teams, 30 disciplinary codes, 3 rules, and 20 creator-free workout presets) passed; remaining Supabase import and production migration are not complete.
- Clerk production domain/account-to-internal-user mapping is not complete; staging currently uses development Clerk credentials and has no webhook signing secret.
- The active iOS composition builds and routes matches, schedules, journal, teams, competitions, venues, authenticated reference-catalog reads, assistant, and match-sheet parsing through backend adapters without Supabase config.
- Reference-catalog schema/routes and the portable 2026 seed are ported; rehearsal provider readback confirmed 5 competitions and 54 teams.
- The Supabase SDK/package dependency is removed. Simulator iOS/watch acceptance is recorded; physical-device acceptance remains pending because both connected targets were offline during the latest audit. Cleanup of legacy Supabase-named compatibility repositories/types/source paths is not complete.
- Supabase files remain legacy migration/contract evidence and compiled compatibility debt; their presence does not make Supabase the active runtime architecture.

## Trust boundary

- iOS may contain `BACKEND_API_BASE_URL`, `CLERK_PUBLISHABLE_KEY`, and `CLERK_FRONTEND_API_HOST`.
- iOS authenticates with Clerk and sends only a Clerk session token to the Worker.
- The Worker verifies the token, resolves the Clerk subject to `app_users.id`, and derives `owner_id` server-side.
- Client `owner_id` values are ignored or validated as non-authoritative metadata.
- Only the Worker may hold Clerk secret/JWT material, the webhook signing secret, PlanetScale/Hyperdrive access, and `OPENAI_API_KEY`.
- watchOS match timing, haptics, lifecycle, and local recovery do not depend on cloud availability.

## Source database evidence

The canonical source snapshot is the live Supabase MCP readback from 2026-07-14 in `docs/generated/db-schema.md`. Do not substitute repository migration parsing for live provider evidence.

Important preliminary inventory facts:

- `public.users.id` is the internal UUID identity.
- Live `public.users` has no `clerk_user_id` column, despite historical migration files that describe one.
- Core source counts were `matches=62`, `match_periods=119`, `match_events=579`, and `match_metrics=62`.
- The source has 39 public tables. Seventeen are non-empty and 22 are empty; the timestamped evidence records every count.
- Supabase Auth has 43 identities while `public.users` has 42 profiles. The unmatched identity requires a reviewed disposition before import.
- Nine public tables had RLS disabled: `match_officials`, `match_assessments`, `trend_snapshots`, `workout_session_metrics`, `workout_intensity_profile`, `workout_segments`, `coaches`, `feedback_attachments`, and `ai_usage_daily`.

Treat those RLS findings as a live legacy security risk. Do not expose a direct database credential in the new client, and do not assume migrating to PlanetScale preserves RLS; the Worker replaces it with explicit owner-scoped authorization.

## Clerk setup

1. Use the Stripe Projects CLI-managed RefWatch Clerk application and configure native iOS sign-in methods. Current project status confirms the service exists, but its managed configuration does not yet establish a production domain.
2. Register the iOS bundle identifier and configure the Frontend API associated domain.
3. Put only the publishable key and Frontend API host in `RefWatchiOS/Config/Secrets.xcconfig`.
4. Store `CLERK_SECRET_KEY` and `CLERK_PUBLISHABLE_KEY` in the Worker environment. `CLERK_JWT_KEY` is optional for networkless verification; Clerk secret-key verification works without it.
5. Reconcile and import every Clerk-to-internal-user mapping before enabling `POST /webhooks/clerk` for `user.created`, `user.updated`, and `user.deleted`; store `CLERK_WEBHOOK_SIGNING_SECRET` with Wrangler. This ordering prevents a pre-mapping deletion event from being acknowledged without a target row.
6. Prove invalid/missing bearer tokens and webhook signatures are rejected before enabling production traffic.

## PlanetScale and Hyperdrive setup

1. Use PlanetScale Postgres database `refwatch`. The disposable branch `cutover-rehearsal-20260714` already passed schema application/readback; keep production `main` untouched until the production gate.
2. Create separate least-privilege runtime and migration credentials.
3. Use the migration-role `DATABASE_URL` only with Drizzle tooling:

   ```sh
   cd api
   DATABASE_URL='postgresql://...' npm run db:migrate
   ```

4. Read back tables, columns, constraints, and indexes on the disposable branch. On 2026-07-14, all six migrations applied and readback found 26 public tables, the five required legacy/reference tables, 5 reference competitions, and 54 reference teams.
5. Staging uses Hyperdrive configuration `refwatch-planetscale-rehearsal-20260714` and least-privilege role `refwatch-worker-rehearsal` against the disposable branch. Create a separate production configuration only at the production gate.
6. Configure the environment-specific `HYPERDRIVE` binding in `api/wrangler.jsonc`; confirm `wrangler deploy --dry-run --env staging` (or the intended production environment) lists it. See the staging evidence artifact under the active plan.
7. Never commit a connection string or put one in iOS configuration.

## Worker setup

Local development:

```sh
cd api
npm install
cp .dev.vars.example .dev.vars
npm run typecheck
npm test
npm run dev
```

Deployment secrets:

```sh
wrangler secret put CLERK_SECRET_KEY --env staging
wrangler secret put CLERK_PUBLISHABLE_KEY --env staging
# Optional networkless verification key:
wrangler secret put CLERK_JWT_KEY --env staging
wrangler secret put CLERK_WEBHOOK_SIGNING_SECRET --env staging
wrangler secret put OPENAI_API_KEY --env staging
```

Enter secret values only into the interactive prompt. Do not pass them as
shell arguments, echo them, persist them in command history, or record them in
evidence artifacts.

Use `wrangler secret put DATABASE_URL` only for an explicitly approved direct-runtime fallback. Production should use Hyperdrive. Run `wrangler deploy --dry-run --env staging` before `wrangler deploy --env staging`; use a separate production environment when approved. Record version, bindings, `/health`, `/health/ready`, and authenticated route evidence. Staging connectivity evidence is recorded in `docs/exec-plans/active/backend-platform-migration/evidence/2026-07-14-staging-worker.md`.

## Data and identity migration

1. Use the 2026-07-14 single-statement inventory under the active plan's
   `evidence/` directory for migration preparation. Immediately before final
   delta export, capture a new provider snapshot inside one
   `REPEATABLE READ, READ ONLY` transaction, recording the exact transaction
   SQL, UTC timestamp, all 39 counts, identity discrepancy, RLS state, and
   sanitized output. The preliminary inventory does not satisfy that final
   cutover gate.
2. Export user and user-owned rows without changing their UUID primary/foreign keys.
3. Build a reviewed mapping from each existing internal user UUID to a Clerk subject. Do not infer that mapping from a missing `public.users.clerk_user_id` column.
4. Import `app_users` first, preserving internal UUIDs, then import dependent tables in foreign-key order.
5. Apply the bundled idempotent seed, which inserts `reference_competitions` before `reference_teams`, then verify the authenticated catalog routes return 5 competitions and 54 teams for 2026. These rows are global read-only reference data, not user-owned rows. If live provider evidence differs, review and import that evidence rather than silently overwriting it with repository assumptions.
6. Reconcile per-table counts, orphan checks, ownership, timestamps, JSON payloads, and representative match bundles.
7. Verify all 39 source-table dispositions and counts, including explicit
   zero-row exclusions, then document every expected difference before
   promotion.
8. Keep export artifacts access-controlled and remove temporary credentials after reconciliation.

## Staging and production gates

Do not route production traffic until all gates have evidence:

Only the staging Worker→Hyperdrive→database connectivity portion is currently
satisfied. It does not satisfy any authenticated or user-flow gate below.

- API typecheck, Workers-runtime tests, database-backed owner/isolation tests, and deploy dry-run pass.
- Match ingest is transactional and concurrency-safe for `Idempotency-Key`.
- Every foreign reference and mutation is tenant-scoped.
- Incremental sync propagates deletions or has a documented reconciliation protocol.
- Clerk deletion/webhook ordering cannot silently restore a deleted account.
- Unmapped Clerk subjects fail closed in production; the development-only
  `ALLOW_UNMAPPED_CLERK_USERS` escape hatch is absent or false.
- Assistant and match-sheet routes keep the OpenAI key server-side, enforce bounded usage, and preserve existing response contracts.
- iOS signs in with Clerk, resolves `/api/me`, and sends a bearer token to the Worker.
- Offline SwiftData save/backlog and logout/user-switch cleanup pass.
- iOS build/tests and RefWatchCore/watchOS regression checks pass on the required destinations when available.
- No Supabase, database, Clerk secret, webhook, or OpenAI credential is present in the iOS source, config, bundle, or build logs.

## Cutover and rollback

1. Capture the final repeatable-read Supabase snapshot described above, take
   the final export from that boundary, and record the cutover cursor/time.
2. Quiesce or dual-write only through an explicitly reviewed procedure; avoid untracked split-brain writes.
3. Import/reconcile the final delta, deploy the Worker, then enable the Clerk/backend iOS path.
4. Monitor authentication failures, owner-scope violations, sync backlog, OpenAI proxy errors, and database connection pressure.
5. Define a time-bounded rollback window before cutover. During it, keep the
   source export immutable and Supabase available read-only; do not accept
   writes through both systems.
6. Roll back by stopping the new Worker write path, restoring the last verified
   client/backend release, and reconciling any post-cutover PlanetScale writes
   from the audit ledger before reopening Supabase writes. Never reverse-import
   partial PlanetScale writes without a reviewed, table-specific procedure.
7. Retire Supabase credentials/functions only after the rollback window, count reconciliation, and production acceptance evidence are complete.

### Operational packet and emergency write stop

Before cutover, populate the gitignored `.cutover/rollback-packet.json` and run
`npm run rollback:validate -- ../.cutover/rollback-packet.json` from `api/`.
The local validator requires the named owner, strict unexpired UTC window and
bounded thresholds, distinct candidate/last-known-good/write-guard Worker IDs,
declared provider/guard receipts, restricted external write-ledger
location/schema/probe receipt, and an already distributable recovery client.
It checks packet structure, not provider existence. Owner-scope violations
always trigger rollback at the first occurrence.

Pre-upload a production version with `WRITE_MODE=disabled` using the exact
Wrangler commands in the timestamped rollback-control evidence, after the
currently absent production environment exists. Routing 100%
to that recorded version blocks every API and Clerk-webhook mutation with a
retryable 503 while preserving health and reads. Verify the behavior, drain
in-flight requests, freeze/reconcile the ledger, then route to the recorded
last-known-good version. Never improvise a version ID or treat an unavailable
client build as rollback readiness. The actual transactional mutation ledger
and its provider probe are still unimplemented production blockers. Reconcile
queued Clerk webhook retries before reopening writes.
