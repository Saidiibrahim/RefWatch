# RefWatch API

Cloudflare Worker API for the RefWatch iOS client. It authenticates Clerk session tokens, resolves each Clerk subject to an internal `app_users.id`, and is the only component allowed to access PlanetScale or OpenAI.

This directory is the active target backend, but it is not yet production-cut-over. The production schema/5–54 seed, read-only runtime Hyperdrive, inactive ledger resources, production Clerk/OpenAI secret names, and unrouted write-disabled Worker foundation are deployed. Ledger-key recovery is blocked because the approved Keychain source yields no recovered key bytes and the installed Worker secret is non-readable. Source remediation, Secrets Store escrow, functional recovery, and production ledger activation/probe are separate gates. Webhook signing-secret custody, remaining Clerk setup, data/identity import, authenticated deployed tenant isolation, traffic, writes, and iOS end-to-end acceptance also remain incomplete and separately gated.

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
npm run test:local:routes
npm run dev
```

The example file contains placeholders only. Never commit `.dev.vars`.
`test:local:routes` starts a temporary loopback-only PostgreSQL cluster, applies
the current migrations, runs the partial mounted-route/owner-isolation matrix,
and removes the cluster. It is an optional local verification step that requires
`initdb`, `pg_ctl`, `pg_isready`, and `createdb` on `PATH`; it uses no
PlanetScale or provider credential.

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

The `staging` Wrangler environment has a real `HYPERDRIVE` binding to the isolated PlanetScale rehearsal branch. Production uses the separate reviewed cache-disabled Hyperdrive and a read-only runtime role while writes remain disabled; database passwords remain inside Hyperdrive, not Worker variables or the iOS app.

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

Verify the selected Wrangler environment lists its intended `HYPERDRIVE`; never put a PlanetScale connection string in `wrangler.jsonc` or the iOS app. Staging currently uses development Clerk credentials and intentionally has no webhook signing secret. Do not create the production webhook until its exact endpoint/secret/probe stage is approved. A write-disabled sample can prove only routing and guard denial because the gate runs before signature verification; accept lifecycle processing only after mapping/reconciliation and separate signature/provenance proof, with events limited to `user.created`, `user.updated`, and `user.deleted`.

The top-level Wrangler target is the separate `refwatch-api-development` Worker.
Generic `npm run deploy` and `npm run dry-run` therefore target development;
production commands must always specify `--env production`. Only the exact
normalized `WRITE_MODE=enabled` value permits API/webhook mutations. Missing,
blank, disabled, or unknown values fail closed; production remains explicitly
disabled until a later approval.

## Routes

`GET /health`, `GET /health/ready`, and signed `POST /webhooks/clerk` are public. Every `/api/*` route requires `Authorization: Bearer <clerk-session-token>`. Readiness performs a sanitized `select 1`; it is connectivity proof only.

Reference catalog reads are `GET /api/reference-catalog/competitions?seasonYear=<year>` and `GET /api/reference-catalog/teams?seasonYear=<year>`. Catalog rows are global read-only data, but the routes still require Clerk authentication. Migration `0002` creates the tables and ports the idempotent 2026 seed (5 competitions, 54 teams) from legacy migration `0017`; `0003` restores source integrity checks and enforces matching team/competition seasons. Production primary readback confirms the exact 5/54 seed; authenticated route acceptance remains gated.

The Clerk webhook synchronizes profile fields but is not required to finish sign-in. Middleware resolves every imported Clerk subject through a receipt-linked legacy mapping registry. The final registry is hash/count validated before a separate activation row is written. Unmapped subjects fail closed until that activation exists and `NEW_USER_ONBOARDING_MODE=post_reconciliation`, `IDENTITY_RECONCILIATION_RECEIPT`, exact `CLERK_INSTANCE_ID`, exact `CLERK_ISSUER`, and enabled writes all agree. Only a subject absent from the legacy registry and durable deletion tombstones may receive a server-generated UUID transactionally and idempotently. Subject-scoped advisory locks serialize create/delete races. Bearer provenance is checked against JWT `iss`; webhook provenance depends on installing the signing secret from the reviewed production-instance endpoint, because the installed Clerk SDK's verified event contract has no instance-ID field. The deprecated `ALLOW_UNMAPPED_CLERK_USERS` variable never authorizes production creation.

## Migration note

The 2026-07-14 live Supabase MCP readback, not migration parsing, is the source evidence for cutover. Live `public.users` uses an internal UUID `id` and has no `clerk_user_id`; imported IDs must be retained as `app_users.id`, and a reviewed mapping must populate the new unique `clerk_user_id`. Do not generate replacement IDs for existing rows. The generated migration creates a fresh target schema; branch application, data export/import, identity mapping, count/referential checks, and production promotion are separate, approval-gated operations.

Core source counts to reconcile are `matches=62`, `match_periods=119`, `match_events=579`, and `match_metrics=62`. The complete 39-table inventory and nine live Supabase tables with RLS disabled are recorded in `../docs/generated/db-schema.md` and `../docs/SECURITY.md`; this legacy exposure is not carried forward as a PlanetScale authorization model.

## Verification and remaining gates

Historical checkpoint verified after the API remediation review on 2026-07-14:

- `npm test` (52 tests across 10 files)
- `wrangler deploy --dry-run --env staging`
- staging deployment plus `/health` and Hyperdrive-backed `/health/ready`

Current local checkpoint verified on 2026-07-17:

- `npm run typecheck`
- `npm test` (93 tests across 14 files)
- `npm run test:local:routes` (4 partial mounted-route/owner-isolation cases on
  a fresh loopback-only PostgreSQL cluster; not Clerk/PlanetScale/deployed proof)

These checks do not satisfy the full migration acceptance criteria. Before production cutover:

Validate the encrypted final Supabase export and reviewed identity map before
any import after the approved secret manager injects inherited
`CUTOVER_BUNDLE_KEY_B64`, `CUTOVER_EXPECTED_QUERY_SHA256`, and
`CUTOVER_EXPECTED_GENERATOR_SHA256`, and
`CUTOVER_EXPECTED_CREATOR_RECEIPT_SHA256`. Run `npm run cutover:validate --
.cutover/final-bundle.enc
.cutover/final-bundle.manifest.json
.cutover/provider-quiescence-receipt.json
.cutover/ledger-quiescence-receipt.json
.cutover/artifact-creator-receipt.json`. Never type secret or release-packet
values into shell history. The verifier checks the exact RefWatch source and
reviewed exporter hashes, real file modes,
ownership, no-follow opens, ciphertext size/hash, AES-256-GCM authentication,
in-memory decryption, plaintext hash, and the actual provider/ledger receipt
bindings; it never accepts a plaintext final-bundle path.
The validator requires explicit arrays/counts/table-specific dispositions for
all 39 tables, the repeatable-read boundary, the exact source Auth ID set,
encrypted allowlisted Auth-user/identity rows with normalized email and only
the observed bcrypt/email/Apple/Google contract, the exact approved auth-only
exclusion, a dependency-complete import plan
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
- retain the verified production schema/5–54 foundation unchanged until the later import approval;
- import data and Clerk identity mappings with count and referential evidence;
- capture the final source rows only through one quiesced direct session into authenticated encryption; `scripts/supabase-candidate-snapshot.sql` is a sanitized count/hash preflight and cannot be promoted to the final export;
- exercise the deployed staging Worker with authenticated CRUD/idempotency/streaming from iOS; connectivity alone is already recorded;
- prove the already-applied production reference catalog through authenticated routes, finish iOS test acceptance and Supabase compatibility cleanup, then prove offline backlog, logout cleanup, and watchOS regression checks;
- retain the Supabase rollback path until post-cutover reconciliation is complete.

Legacy Supabase edge functions and migrations under `../RefWatchiOS/Core/Platform/Supabase/` remain read-only migration/contract references. They are not the target deployment path and must not be deleted until their portable contracts and live data have been verified against the Worker/PlanetScale system.
