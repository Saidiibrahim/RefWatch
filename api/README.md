# RefWatch API

Cloudflare Worker API for the RefWatch iOS client. It authenticates Clerk session tokens, resolves each Clerk subject to an internal `app_users.id`, and is the only component allowed to access PlanetScale or OpenAI.

This directory is the active target backend, but it is not yet production-cut-over. Staging deployment and Worker→Hyperdrive→disposable-database readiness are recorded; they do not prove production deployment/import, authenticated tenant isolation, or iOS end-to-end behavior.

## Architecture

- Hono runs on Cloudflare Workers.
- PlanetScale Postgres is accessed through a Cloudflare Hyperdrive binding in deployed environments.
- Drizzle defines and migrates the Postgres schema.
- `@clerk/backend` verifies native Clerk session tokens with an optional networkless JWT public key; otherwise it uses the Clerk backend/JWKS path with the secret key.
- The API derives `owner_id` from the verified session. Client-supplied owner values are ignored.
- OpenAI requests originate only from the Worker. The assistant response body is streamed through without buffering.

## Local setup

```sh
npm install
cp .dev.vars.example .dev.vars
npm run typecheck
npm test
npm run dev
```

The example file contains placeholders only. Never commit `.dev.vars`.

Run migrations with a direct migration-role connection string:

```sh
DATABASE_URL='postgresql://...' npm run db:migrate
```

Do not use an application runtime credential for schema migrations. Apply generated migrations to a disposable PlanetScale branch and verify them before promoting to production.

## Worker secrets and bindings

Secrets:

- `CLERK_SECRET_KEY`
- `CLERK_PUBLISHABLE_KEY`
- `CLERK_JWT_KEY` (optional PEM public key for networkless token verification)
- `CLERK_WEBHOOK_SIGNING_SECRET`
- `OPENAI_API_KEY`
- `DATABASE_URL` only when not using Hyperdrive

The `staging` Wrangler environment has a real `HYPERDRIVE` binding to the isolated PlanetScale rehearsal branch. Production must use a separate reviewed binding; database passwords remain inside Hyperdrive, not Worker variables or the iOS app.

Example provisioning sequence after creating a PlanetScale Postgres database/branch and Cloudflare Hyperdrive configuration:

```sh
wrangler secret put CLERK_SECRET_KEY --env staging
wrangler secret put CLERK_PUBLISHABLE_KEY --env staging
# Optional for networkless JWT verification:
wrangler secret put CLERK_JWT_KEY --env staging
wrangler secret put CLERK_WEBHOOK_SIGNING_SECRET --env staging
wrangler secret put OPENAI_API_KEY --env staging
wrangler deploy --dry-run --env staging
wrangler deploy --env staging
```

Verify the selected Wrangler environment lists its intended `HYPERDRIVE`; never put a PlanetScale connection string in `wrangler.jsonc` or the iOS app. Staging currently uses development Clerk credentials and intentionally has no webhook signing secret. Configure a production webhook only after identity mapping/reconciliation, then subscribe to `user.created`, `user.updated`, and `user.deleted`.

## Routes

`GET /health`, `GET /health/ready`, and signed `POST /webhooks/clerk` are public. Every `/api/*` route requires `Authorization: Bearer <clerk-session-token>`. Readiness performs a sanitized `select 1`; it is connectivity proof only.

Reference catalog reads are `GET /api/reference-catalog/competitions?seasonYear=<year>` and `GET /api/reference-catalog/teams?seasonYear=<year>`. Catalog rows are global read-only data, but the routes still require Clerk authentication. Migration `0002` creates the tables and ports the idempotent 2026 seed (5 competitions, 54 teams) from legacy migration `0017`; `0003` restores source integrity checks and enforces matching team/competition seasons. The disposable-branch apply/readback passed; production apply remains gated.

The Clerk webhook synchronizes profile fields but is not required to finish sign-in. Middleware resolves a reviewed Clerk-subject mapping and fails closed when it is absent. A development-only `ALLOW_UNMAPPED_CLERK_USERS=true` escape hatch may create users for disposable environments; staging and production must keep it false or absent. User deletion is soft-deleted so a delayed webhook cannot cascade-delete match history.

## Migration note

The 2026-07-14 live Supabase MCP readback, not migration parsing, is the source evidence for cutover. Live `public.users` uses an internal UUID `id` and has no `clerk_user_id`; imported IDs must be retained as `app_users.id`, and a reviewed mapping must populate the new unique `clerk_user_id`. Do not generate replacement IDs for existing rows. The generated migration creates a fresh target schema; branch application, data export/import, identity mapping, count/referential checks, and production promotion are separate, approval-gated operations.

Core source counts to reconcile are `matches=62`, `match_periods=119`, `match_events=579`, and `match_metrics=62`. The complete 39-table inventory and nine live Supabase tables with RLS disabled are recorded in `../docs/generated/db-schema.md` and `../docs/SECURITY.md`; this legacy exposure is not carried forward as a PlanetScale authorization model.

## Verification and remaining gates

Verified locally after the API remediation review on 2026-07-14:

- `npm run typecheck`
- `npm test` (47 tests across 9 files)
- `wrangler deploy --dry-run --env staging`
- staging deployment plus `/health` and Hyperdrive-backed `/health/ready`

These checks do not satisfy the full migration acceptance criteria. Before production cutover:

Validate the access-controlled final Supabase export and reviewed identity map
before any import with `npm run cutover:validate -- .cutover/final-bundle.json`.
The validator requires explicit arrays/counts/table-specific dispositions for
all 39 tables, the repeatable-read boundary, the exact source Auth ID set,
collision-safe reviewed identity contracts, a dependency-complete import plan
for every currently verified import table, and owner/foreign-key integrity.
Previously empty tables without a verified import contract hard-block cutover
if they become non-empty; they cannot be accepted for archival. Passing the
validator does not itself apply data.

Before production traffic, create the access-controlled rollback packet and
validate it with `npm run rollback:validate -- ../.cutover/rollback-packet.json`.
The packet schema requires provider-readback receipts for a pre-uploaded
emergency write-guard Worker version and last-known-good version, zero tolerance
for owner-scope violations, an externally implemented/probed write ledger, and
an already distributable recovery client. The local validator checks packet
shape and bounds; it does not replace provider readback. `WRITE_MODE=disabled`
blocks API/webhook mutations while keeping health and reads available; see the
timestamped rollback-readiness evidence and cutover runbook for exact commands.

- extend the 3/3 disposable-database match-route suite to the remaining CRUD families and verify the same behavior through Clerk-authenticated deployed Worker/Hyperdrive requests;
- run authenticated deployed match-sheet fixture coverage against staging and production after reviewed Clerk identities exist;
- promote/apply and read back the schema on production only after approval; disposable rehearsal already passed;
- import data and Clerk identity mappings with count and referential evidence;
- exercise the deployed staging Worker with authenticated CRUD/idempotency/streaming from iOS; connectivity alone is already recorded;
- apply and read back the bundled reference catalog seed in production PlanetScale, finish iOS test acceptance and Supabase compatibility cleanup, then prove offline backlog, logout cleanup, and watchOS regression checks;
- retain the Supabase rollback path until post-cutover reconciliation is complete.

Legacy Supabase edge functions and migrations under `../RefWatchiOS/Core/Platform/Supabase/` remain read-only migration/contract references. They are not the target deployment path and must not be deleted until their portable contracts and live data have been verified against the Worker/PlanetScale system.
