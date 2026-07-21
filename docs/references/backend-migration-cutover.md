# Backend Migration and Cutover

This runbook governs the greenfield production launch on Clerk authentication,
the Cloudflare Workers/Hono API in `api/`, and PlanetScale Postgres. It also
retains the stateful Supabase-migration procedures as historical/future tooling.
Repository implementation, operator authorization, provider mutation, and
production acceptance are separate facts; none implies another.

## Current status

As of the 2026-07-20 greenfield authorization, with provider and test evidence
dated as identified in the active plan:

- Clerk + Cloudflare Workers/Hono + PlanetScale Postgres is the active target architecture.
- The Worker workspace, Drizzle target schema, Clerk/identity implementation, and backend client/repository adapters exist in the repository.
- The fresh 2026-07-20 baseline first proved 16 migrations through `0015`, 35
  public tables, the exact reviewed 5-competition/54-team seed, and zero rows
  in all 26 then-existing application/identity/control categories. The later
  preparation batch atomically applied `0016`; exact checked-in readbacks now
  prove 17 migration rows, the reviewed 36-table catalog, zero rows in all 27
  target categories, Postgres ownership, the unchanged 5/54 seed, and no
  active ledger. No reset or reseed was needed. "Clean target" never means
  deleting deterministic global reference data reviewed from repository
  sources.
- The fresh Cloudflare readback records Worker `refwatch-api` deployment
  `89cff719-0e19-4648-ab09-63a37d806c95` at 100% version
  `e966d6df-b5ff-4288-832c-c8d91e00ce48`, write/onboarding-disabled, with zero
  zone routes, custom domains, cron schedules, or Queue consumers. Workers.dev
  and preview URLs are disabled. It is current unexposed foundation state, not
  a deployed greenfield candidate or traffic cutover.
- Production ledger capture is deferred and does not gate the initial launch.
  Fresh database readback shows zero total/preparing/open/frozen/archived/
  capture-enforced epochs, revisions, outbox rows, or deliveries; Cloudflare
  readback shows zero cron schedules and Queue consumers plus zero D1
  events/probes/dead letters. The historical 2026-07-17 escrow failure remains
  intact, but its inaccessible key does not need recovery. Provisioned ledger
  resources may remain detached from the active path.
- The isolated ledger rehearsal remains useful proof and future stateful-
  migration tooling. It is not a required greenfield recovery mechanism.
- The exact Clerk production instance is
  `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, its application domain is
  `refwatch.ibby.ai`, and its issuer/Frontend API is
  `https://clerk.refwatch.ibby.ai`. DNS, SSL, email DNS, and the coordinated
  Worker issuer/publishable-key lane were completed previously and must not be
  recreated merely to produce new evidence. Official Clerk SDK readback at
  `2026-07-20T06:43:13.331Z` proves the post-preparation zero state for users,
  invitations, redirect URLs, and allowed origins. It did not enumerate
  native-app or webhook endpoint/subscription state. The earlier
  `2026-07-20T05:22:53.839Z` receipt remains in the historical baseline
  artifact.
- The active iOS composition builds and routes matches, schedules, journal, teams, competitions, venues, authenticated reference-catalog reads, assistant, and match-sheet parsing through backend adapters without Supabase config.
- The latest remediated-v2 focused greenfield/rollback/CLI verification passes
  108/108 across 3 files. Fresh final verification passes typecheck, 268/268
  unit cases across 19 files, 23/23 hermetic database cases, and 19/19
  mounted-route cases. The fresh full iOS
  target passes 94/94 on
  iPhone 15 Pro Max/iOS 17.0.1, and the focused collection-cursor suite passes
  5/5 on iOS 18.5. A broad Xcode 27/iOS 18.5 run has a bounded allocator
  incompatibility in 15 unrelated legacy cases. The current generic Release
  build succeeds but reads back `CFBundleIdentifier=.RefWatch`, no team,
  localhost backend, a test Clerk key, `clerk.localhost`, and no callback URL
  scheme, so production Release acceptance remains open. Authoritative
  production signing metadata instead requires Team/App ID Prefix
  `6NV7X5BLU7`, Bundle ID `com.IbrahimSaidi.RefWatch`, and callback
  `com.IbrahimSaidi.RefWatch://callback`. These prove
  local contracts only; no provider, deployment, live OpenAI, traffic, or
  physical-device acceptance is implied.
- The production-preparation actual-value scan found zero hits in 10,269
  repo-root files using the one locally available fingerprint. The older
  route-batch snapshots found zero hits in 10,259 repo-root files and 569
  Release-app/test-result files. The exact
  post-five-finding/pre-final-review-trail Gitleaks
  8.30.1 snapshot found zero leaks in the 511,420-byte tracked diff and 337,624
  bytes of enumerated untracked non-`.projects` files.
  The final remediated-v2 Gitleaks 8.30.1 receipt scanned exactly 83 current
  modified/untracked files with full redaction and `.projects` excluded; it
  passed after the latest remediation.
  `.projects`, symlinks, excluded local environment files, and unavailable
  production fingerprints remain outside those claims.
- Reference-catalog schema/routes and the portable 2026 seed are ported; rehearsal provider readback confirmed 5 competitions and 54 teams.
- The Supabase SDK/package dependency is removed. Simulator iOS/watch
  acceptance is recorded; physical-device acceptance remains pending because
  no physical iPhone or Apple Watch is connected. Cleanup of legacy
  Supabase-named compatibility repositories/types/source paths is not complete.
- Supabase files remain legacy migration/contract evidence and compiled compatibility debt; their presence does not make Supabase the active runtime architecture.
- The 2026-07-15 source snapshot remains historical point-in-time truth: 1,106
  application rows, 43 Supabase Auth identities, 42 public profiles, and the
  `testing@refwatch.com` auth-only discrepancy existed then. All are disposable
  test-era state. They are neither import inputs nor reconciliation gates for
  this launch.
- The full in-scope provider cutover is authorized, including destructive
  cleanup of disposable source/target state. Authorization is not completion;
  each mutation and acceptance result still requires a sanitized receipt.

The exact fresh inventory, access-path distinctions, provider IDs, and
remaining access/device prerequisites are recorded in
`../exec-plans/active/backend-platform-migration/evidence/2026-07-20-production-greenfield-baseline.md`.
Provider-issued temporary MCP/CLI access roles were used, but no application
data or durable provider configuration/credential mutation occurred. No
operator approval is pending. The baseline's mandatory remediation is applied
and both final reviewers returned `NO FINDINGS`. The subsequent schema/runtime
preparation and sanitized receipts are recorded in
`../exec-plans/active/backend-platform-migration/evidence/2026-07-20-production-greenfield-preparation.md`;
that batch has executed and both mandatory reviewers returned final
`NO FINDINGS`.

## Greenfield production decision

The append-only
`../exec-plans/active/backend-platform-migration/evidence/2026-07-20-greenfield-cutover-authorization.md`
supersedes the legacy-preservation launch objective:

- no Supabase identity, profile, or application row is preserved or imported;
- no legacy UUID-to-Clerk-subject mapping is required;
- the former `testing@refwatch.com` exclusion disposition is historical and no
  longer a launch gate;
- the target begins with zero `app_users`, zero legacy mappings, and zero
  user-owned application rows, while retaining the reviewed deterministic
  global reference seed;
- ledger escrow, recovery, and activation are deferred and non-blocking;
- rollback may stop traffic/writes, route to the write-disabled Worker, roll
  back Worker/client versions, reset and reseed PlanetScale, recreate test
  identities, and rerun the greenfield launch; and
- native registration, OAuth, webhook, database migration/reset/seed, Worker
  deployment/routing, onboarding/write enablement, traffic cutover, source
  retirement, and bounded test identities are authorized without another
  approval.

Proceed only in the runbook's ordered stages and preserve each independent
provider, schema/seed, zero-legacy activation, deployment, rollback, traffic,
and acceptance receipt. Do not print secrets, pass them as command arguments,
or put them in evidence. Do not commit or publish this work without a separate
request.

Every meaningful local or provider batch below has a mandatory close condition:
the code-level risk reviewer and the docs/evidence consistency reviewer must
independently review that exact batch, every finding must be applied, and both
roles must be rerun until each explicitly reports no findings before the next
batch starts.

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
- Supabase Auth had 43 identities while `public.users` had 42 profiles. The
  unmatched `testing@refwatch.com` identity and all other identities/rows are
  disposable; no disposition or import is required for the greenfield launch.
- Nine public tables had RLS disabled: `match_officials`, `match_assessments`, `trend_snapshots`, `workout_session_metrics`, `workout_intensity_profile`, `workout_segments`, `coaches`, `feedback_attachments`, and `ai_usage_daily`.

Treat those RLS findings as a live legacy security risk. Do not expose a direct database credential in the new client, and do not assume migrating to PlanetScale preserves RLS; the Worker replaces it with explicit owner-scoped authorization.

## Clerk setup

1. Preserve production resource `clerk-auth-2` and development-only `clerk-auth`. The invalid `auth.refwatch.com` records remain retired. Production now uses verified owned secondary domain `refwatch.ibby.ai`; its exact five DNS-only CNAMEs are applied and Clerk reports DNS, SSL, and email DNS complete with zero pending records.
2. Worker `CLERK_ISSUER` and `CLERK_PUBLISHABLE_KEY` are coordinated with
   `https://clerk.refwatch.ibby.ai`. The authoritative production Team/App ID
   Prefix is `6NV7X5BLU7`, Bundle ID is
   `com.IbrahimSaidi.RefWatch`, application identifier is
   `6NV7X5BLU7.com.IbrahimSaidi.RefWatch`, and callback is
   `com.IbrahimSaidi.RefWatch://callback`. Install the same public Clerk
   host/key in iOS and register/verify that exact callback only through the
   intended local/release configuration.
3. Put only public app configuration in `RefWatchiOS/Config/Secrets.xcconfig`:
   `BACKEND_API_BASE_URL`, the Clerk publishable key, and the Frontend API host.
   The signed identifiers are resolved above; verify the release configuration
   destination and embedded plist before acceptance.
4. Store `CLERK_SECRET_KEY` and `CLERK_PUBLISHABLE_KEY` in the Worker environment. `CLERK_JWT_KEY` is optional for networkless verification; Clerk secret-key verification works without it.
5. Webhook endpoint creation, a write-disabled routing/guard probe, and later
   signature/provenance plus lifecycle acceptance are authorized ordered
   stages. After an
   exact reachable HTTPS Worker endpoint is verified, create only the production
   instance endpoint for `user.created`, `user.updated`, and `user.deleted`, and
   stream `CLERK_WEBHOOK_SIGNING_SECRET` through a non-echoing Wrangler path.
   Do not send a sample until the reviewed non-mutating probe is ready; with
   `WRITE_MODE=disabled`, it must return the documented retryable denial and
   mutate no identity. Because the write gate runs before the webhook handler,
   that 503 proves routing and write denial only; it does not prove signature or
   production-instance provenance.
6. Activate and observe the approved zero-legacy receipt before accepting
   lifecycle mutations. Only in the later bounded test-only window, with
   greenfield onboarding and writes enabled but general production traffic off,
   prove valid/invalid signatures, exact production-instance signing-secret
   provenance, create/update/delete behavior, retry idempotency, and delete-wins
   ordering. Prove invalid/missing bearer tokens before enabling production
   traffic.
7. For Google OAuth/API work, use the installed `gcloud` CLI for
   Google Cloud/API configuration and the installed `gws` CLI only for Google
   Workspace operations. Keep credentials in their approved custody path and
   never print, export, or paste them into chat or evidence.

The fresh official SDK readback used a managed, non-echoing production
environment and returned zero users, invitations, redirect URLs, and allowed
origins. Public social configuration is empty. It did not authoritatively list
native apps or webhook endpoints/subscriptions; the absent Worker webhook
secret proves only that the current Worker is not ready to verify such an
endpoint. Social OAuth, native-app, and webhook administration still require
an authenticated Clerk CLI/dashboard session unless the production Backend API
is verified to support the exact operation. This is an access prerequisite,
not a new approval gate.

## PlanetScale and Hyperdrive setup

1. Use PlanetScale Postgres database `refwatch`, production/default branch
   `main` (`w3g1f8vcbg34`). The fresh baseline found no disposable target rows,
   the exact reviewed 5/54 seed, and no active ledger. The reviewed helper has
   now applied `0016` without reset/reseed, and the exact post-preparation
   readbacks preserve those facts. Continue to record `app_users`, user-owned,
   legacy-mapping, control-state, and global-reference counts separately.
2. Keep access paths distinct. The PlanetScale MCP read query uses a temporary
   `pg_read_all_data` reader, while the MCP also exposes a separate write tool.
   An authenticated ephemeral `pscale` `0.300.0` readwriter session proves DML
   capability through `pg_write_all_data`, but it lacks `postgres` membership
   and public-schema `CREATE` and therefore cannot apply migration `0016`.
   Apply the migration only through the authenticated ephemeral admin path,
   which can use `SET LOCAL ROLE postgres`, while keeping SQL on non-echoing
   stdin. Durable roles `vaqg84rqoedz` and `pz5z3l81py1y` remain read-only.
   The separate durable role `hvk7iheytj62` now carries only
   `pg_read_all_data` and `pg_write_all_data` for the prepared candidate.
   Temporary MCP/CLI roles are access-session artifacts, not durable
   application credentials.
3. Do not run generic production `npm run db:migrate` through a transient
   PlanetScale role: newly created objects could retain that transient owner.
   Do not pipe only migration `0016` under `SET ROLE postgres`, because that
   omits the exact Drizzle history row. The reviewed production helper asserts
   the exact `0015` head/hash, uses `SET LOCAL ROLE postgres`, applies the
   verbatim `0016` SQL and exact Drizzle hash/timestamp insert atomically,
   rolls back on mismatch, and postchecks owners, catalog, and migration
   history. Its tests and mandatory review are closed. Run only its
   non-echoing command:

   ```sh
   cd api
   npm run db:migrate:production:0016
   ```

   The helper applied and verified migration `0016` on 2026-07-20. Do not rerun
   it merely for evidence; its exact-head precondition now fails closed because
   production is already at `0016`.
4. The reproducible pre-preparation baseline query is
   `api/scripts/production-greenfield-baseline-readback-0015.sql`, SHA-256
   `5cce6740a72f7336767215c8673f1ee760a1025db239db2f0edddc23ef41dd05`.
   It emits the complete then-current schema/owner contract, exact 26-category
   pre-`0016` inventory, 5/54 seed, target-only table state, and inactive-ledger
   counts in one sanitized historical payload. Read back tables, columns,
   constraints,
   indexes, functions, enums, migration
   rows, triggers, and privileges on each disposable branch. On 2026-07-15, the
   dedicated ledger branch had all 16 migrations, 35 public tables, 22 effective
   capture triggers, and three ledger-protection triggers; every completed
   rehearsal epoch was archived with capture enforcement disabled. The original
   reference-data branch historically read back 5/54/30/3/20 rows across its
   reference tables. Those live counts are not automatically the greenfield
   deterministic seed; only reviewed repository sources are seed authority.
   The current production greenfield target is 17 migrations through
   `0016_careless_steel_serpent`. The beta.3 source adds migration `0017` for
   Clerk profile-event ordering, but it does not alter or repin the applied
   `0016` receipt. Before deploying that source, apply and read back the exact
   reviewed `0017` migration and repin the launch validator to the resulting
   schema/history contract. After applying the production target, use the exact checked-in
   `greenfield-schema-readback.sql`, `greenfield-clean-target-readback.sql`, and
   `greenfield-ledger-readback.sql` queries described below rather than
   hand-authored count or schema claims.
5. Staging uses Hyperdrive configuration
   `refwatch-planetscale-rehearsal-20260714`. Fresh production readback confirms
   cache-disabled/TLS-required Hyperdrive
   `5345de83edfa40b790d5b26df32f56ab` still targets branch
   `w3g1f8vcbg34` through read-only role `vaqg84rqoedz`, with connection limit
   10. Preserve it with the old Worker version as the emergency write-disabled
   path. Prepared candidate Hyperdrive
   `920ca5b108034b2bb8700cf0201ac55f` uses durable role `hvk7iheytj62`, TLS
   `require`, disabled cache, and connection limit 10. Keep every database
   password in memory through a
   non-echoing channel only—never an argument, stdout, or file. If Cloudflare
   creation or exact readback fails, delete the new PlanetScale credential
   automatically. Before acceptance, prove read/write data access without
   administrative capability and read back the exact branch, TLS requirement,
   disabled cache, and connection limit. Preserve the old role, Hyperdrive, and
   Worker version, then update candidate `HYPERDRIVE` and
   `EXPECTED_DATABASE_ROLE_ID` together. The reviewed helper implements this
   contract, including exact Cloudflare-account and production-marker pins,
   rolled-back row-write proof, bounded command/database timeouts, cleanup
   discovery retries, and refusal to delete pre-existing IDs. Its tests and
   mandatory implementation review are closed. It executed successfully in the
   provider-preparation batch:

   ```sh
   cd api
   REFWATCH_ALLOW_PRODUCTION_RUNTIME_PROVISIONING=1 \
     node scripts/provision-production-runtime.mjs --execute
   ```

   The command emitted only a sanitized paired role/Hyperdrive receipt; its two
   candidate configuration IDs are now applied together. Do not rerun it:
   exact-name collision guards intentionally fail closed.
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

Only the exact normalized `WRITE_MODE=enabled` value permits API/webhook
mutations. Missing, blank, disabled, or unknown values fail closed. The default
Wrangler target is the separate `refwatch-api-development` Worker; generic
deploy/dry-run commands target development, while production commands must
always specify `--env production`. Production remains explicitly disabled
until the greenfield bootstrap and bounded authenticated acceptance prerequisites
are satisfied.

Use `wrangler secret put DATABASE_URL` only for a reviewed direct-runtime
fallback. Production should use Hyperdrive. Run `wrangler deploy --dry-run
--env production` before `wrangler deploy --env production`. Record version,
bindings, route, `/health`, `/health/ready`, and authenticated route evidence.
Staging connectivity evidence is recorded in
`docs/exec-plans/active/backend-platform-migration/evidence/2026-07-14-staging-worker.md`.

The 2026-07-20 production dry-run declared `HYPERDRIVE`, D1
`MUTATION_LEDGER`, Queue producer `MUTATION_LEDGER_QUEUE`, and
`CF_VERSION_METADATA`, with no cron/Queue consumer and both mutation modes
disabled. The post-preparation dry-run binds exact role `hvk7iheytj62` and
Hyperdrive `920ca5b108034b2bb8700cf0201ac55f`; separate provisioning proof
confirmed effective read/write data access without administrative capability.
The receipt proves the build and declared configuration only because the
deployed Worker remains unchanged. Declared inert resources are not the same as
the mounted local harness that supplies no ledger key, Queue, D1, cron, or
consumer.

Fresh control-plane readback additionally records current deployment
`89cff719-0e19-4648-ab09-63a37d806c95` at 100% version
`e966d6df-b5ff-4288-832c-c8d91e00ce48`. It has the old read-only Hyperdrive,
disabled modes, correct Clerk pins, and no route/custom domain/workers.dev/
preview/cron/Queue consumer. Its secret-name inventory does not include
`CLERK_WEBHOOK_SIGNING_SECRET`, and its variables predate the greenfield
identity receipt. `api.refwatch.ibby.ai` is currently unused and is the
recommended exact custom hostname for the next reviewed write-disabled
candidate; no route was created by the baseline.

## Greenfield target and identity bootstrap

1. Inventory the current production state read-only: migrations/schema,
   deterministic reference data, target identities and user-owned rows,
   reconciliation controls, ledger state, consumers, Clerk provenance, and
   Worker versions/routes/bindings. This before-state inventory is complete and
   remains distinct from the later post-preparation launch receipt.
2. Stop traffic and writes as needed, apply the reviewed greenfield-bootstrap
   migration only through the exact-head, atomic, Postgres-owned production
   helper after its tests and review close, clear or reset disposable target
   state, and reseed only the deterministic 5/54 reference catalog from
   reviewed repository migration `0002`. This completed without reset/reseed
   because the target was already clean and the seed already matched.
3. After preparation, capture the pinned schema, seed, clean-target, inactive-
   ledger, and Clerk readbacks. The schema must be migration `0016`/17 with the
   full reviewed catalog; the clean target must contain zero application/
   identity/control rows and zero Clerk users; and the ledger must have zero
   preparing/open/capture-enforced epochs, zero cron schedules and Queue
   consumers, and zero D1 ledger rows. These post-preparation receipts, not the
   initial inventory, enter the launch packet. Database portions and an
   authenticated `2026-07-20T06:43:13.331Z` exact-instance Clerk refresh with
   zero users/invitations/redirect URLs/allowed origins are captured; both
   mandatory preparation reviewers returned final `NO FINDINGS`.
4. Create, activate transactionally, and read back the
   `greenfield_zero_legacy_v1` receipt for exactly zero mappings, the canonical
   empty mapping hash, the 2026-07-20 authorization digest, and exact production
   Clerk instance. Activation must follow the clean-target and Clerk readbacks.
5. Create `/webhooks/clerk` for only `user.created`, `user.updated`, and
   `user.deleted`; put only newly required/changed values—at least its signing
   secret and `CUTOVER_ACCEPTANCE_TOKEN`—with non-echoing
   `wrangler versions secret put` on stdin. Never request or reinstall the
   inaccessible ledger-key value. Final source S preserves unchanged existing
   bindings; sanitized A/B readbacks must each contain exactly the six allowed
   secret names/types. S is bounded by exact ID/time, required-name operator
   confirmation, documented preservation, and provider history. Then upload A
   followed sequentially by B. Carry the
   digest-checked `worker.secret_lineage` and provider-history receipt. Require
   zero unexpected versions, secret mutations, or upload overrides and
   `secret_values_recorded=false`. This is provider-history-bounded,
   operator-confirmed sequencing under documented preservation behavior, not a
   provider-observed parent link or direct secret-value comparison.
6. Temporarily deploy G at 100% with no competitor. Its canonical provider
   deployment readback digest and before/after timestamps must bracket the
   operational probe; prove exact G health/readiness, disabled retryable denial,
   and zero mutations. Restore A=100%/B=0% and capture the after-readback.
   Repeat the same bracketed 100% probe/restoration contract for L. Launch
   validation waits for both after-readbacks. Both proofs must lie inside the
   rollback window and complete by validation time; require G-after < L-before,
   the same production route, and distinct deployment/probe/provider receipt
   IDs. The launch packet binds that route ID to the initial A route.
7. Collect the final public A=100%/B=0% proof at
   `api.refwatch.ibby.ai/*`, with A set to `WRITE_MODE=disabled` and
   `NEW_USER_ONBOARDING_MODE=disabled`. Prove `/health` and `/health/ready`
   report exact A, missing/invalid bearer rejection, retryable 503 API/webhook
   denial, and zero identity/application mutations. Keep Workers.dev and
   preview URLs disabled.
8. Validate the exact nested standalone `greenfield_destructive_v2` packet,
   digest, window, thresholds, G/L probes, distributable client, and destructive
   reset/reseed/recreate procedure.
9. While ordinary deployment remains A=100%/B=0%, create an exact
   Cloudflare Access `service_auth` policy receipt for
   `api.refwatch.ibby.ai/api/*` with exactly one service token and zero bypass
   rules. Bounded requests may select B only with
   `Cloudflare-Workers-Version-Overrides` through that Access policy and the
   Worker-enforced `X-RefWatch-Cutover-Token` backed by
   `CUTOVER_ACCEPTANCE_TOKEN`. Missing/invalid Worker tokens return 403. Only
   now run the full
   missing/invalid bearer, `/api/me`, new-user onboarding, tenant-isolation,
   owner-spoof, CRUD, idempotency, tombstone, assistant, match-sheet, webhook
   signature/provenance/create/update/delete/retry/delete-wins, and
   `write_round_trip` matrix. New subjects receive only server-generated UUIDs;
   preserve subject locks, deletion tombstones, issuer verification, and
   instance-plus-Svix-ID delivery receipts. Specifically,
   `acceptance.checks.webhook_lifecycle` records
   `delivery_source=manual_signed_harness`, endpoint `/webhooks/clerk`, exact
   `Cloudflare-Workers-Version-Overrides` and
   `X-RefWatch-Cutover-Token` names with both presence flags true, and passed
   valid-signature acceptance plus invalid-signature rejection. It is not
   Clerk-provider delivery.
10. After bounded automated acceptance, promote B to 100% with no competing
    version while keeping `/api/*` Access active. Without any version override
    or cutover-token header, run the real Clerk-provider lifecycle and record
    `traffic_and_writes.promoted_webhook_acceptance`: exact subscriptions
    `user.created`, `user.updated`, and `user.deleted`; signature acceptance;
    create/update/delete/retry/delete-wins; and cleanup to zero test
    identity/application rows.
11. Only after promoted webhook acceptance, remove the bounded Access policy
    and record its provider-bound removal receipt, then capture the exact
    deployment-history readback.
12. Complete iPhone 15 Pro Max, Apple Watch Series 9 (45mm), and embedded
    Release-configuration acceptance against promoted B.
13. Only after device/release acceptance, record production acceptance,
    complete the monitored observation, and capture a final production
    readback proving no active ledger epoch and zero Queue, cron, D1, or other
    consumers. Add every bound receipt and pass `greenfield_launch_v2`
    validation.

`ALLOW_UNMAPPED_CLERK_USERS` remains deprecated and cannot authorize creation
at any stage.

## Greenfield launch-packet validation

Create the sanitized packet outside the repository or under the gitignored
`.cutover/` directory, then run from `api/`:

```sh
npm run launch:validate -- ../.cutover/greenfield-launch-packet.json
```

The packet must explicitly use `greenfield_launch_v2`; an omitted or unknown
profile and mixed legacy/stateful claims fail closed. It pins:

- the canonical authorization-payload digest
  `17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b`
  (not a digest of the Markdown artifact);
- Clerk instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, domain
  `refwatch.ibby.ai`, and issuer `https://clerk.refwatch.ibby.ai`;
- Worker `refwatch-api` in `production`; and
- PlanetScale `ibrahim-aka-ajax/refwatch/main`, branch ID
  `w3g1f8vcbg34`, runtime marker
  `refwatch:production:w3g1f8vcbg34`.

Use these exact sanitized read-only query artifacts:

- schema/migration query `api/scripts/greenfield-schema-readback.sql`,
  SHA-256
  `391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd`;
- seed/clean-target query
  `api/scripts/greenfield-clean-target-readback.sql`, SHA-256
  `eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352`;
  and
- inactive-ledger query `api/scripts/greenfield-ledger-readback.sql`,
  SHA-256
  `0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b`.

The schema receipt must prove migration head
`0016_careless_steel_serpent`, count/head ID 17, migration-history MD5
`73ad9d2a055b09e83324a50f74ed94dd`, and the reviewed full catalog: 36
tables/table properties, 382 columns, 106 constraints, 77 indexes, 32 triggers,
10 functions, and 27 enum labels with their exact digests recorded in
`docs/exec-plans/active/backend-platform-migration/evidence/2026-07-20-greenfield-launch-validator.md`.
The clean receipt must
prove the exact reviewed 5-competition/54-team seed and zero rows across every
listed application/identity/control table before bootstrap. The ledger receipt
may classify existing frozen/archived history, but preparing, open, and
capture-enforced epochs plus Queue, cron, and D1 consumers must all be zero.

All embedded sanitized receipt digests are recomputed from canonical payloads
and bound, where applicable, to the exact stage Worker, Clerk instance, and
database branch. Receipt kinds and receipt IDs are unique. Baselines precede
zero-legacy activation; disabled A and accepted B are created/read back
afterward. The provider sequence must hold ordinary traffic at A=100%/B=0%
while protected bounded requests select B. The bounded webhook lifecycle is
manually signed through override+Worker-token headers. B promotion to 100%
precedes real Clerk-provider webhook acceptance without those headers; Access
remains active through that proof. Provider-bound Access removal then precedes
deployment-history readback and physical-device/Release acceptance. Production
acceptance follows those device receipts, then observation and the final
inactive-ledger/zero-consumer readback. The validator uses its runtime `now` to
reject future completion and an already expired rollback window; simultaneous
major-stage timestamps do not pass.

For the A/B lineage readback, pass each parsed
`wrangler versions view --json` response to exported
`sanitizeWorkerVersionReadback` in
`api/scripts/greenfield-launch-packet.mjs`; it uses
`computeStableWorkerBindingSha256` and emits the packet-safe receipt. The
packet carries the exact version/timestamps, script ETag, approved resources
and bindings, stable hash, and receipt digest. Validation digest-checks that
receipt, recomputes the stable hash, and enforces the exact production
plain/resource binding allowlist plus secret-name/type set. Only
`WRITE_MODE`/`NEW_USER_ONBOARDING_MODE` values normalize between A/B. Do not
persist raw author metadata or secret values. Provider readback cannot expose
secret values, so the exact non-disclosing `worker.secret_lineage` below is
separately required. Validator failures identify only the offending
field/contract and never echo an invalid binding value.

The separate `worker.secret_lineage` receipt must use
`worker_secret_lineage:sequential_inheritance` and the exact installation
method `wrangler_versions_secret_put_stdin_then_sequential_uploads`. It binds
non-echoing stdin puts for only newly required/changed values to final source
version S, which preserves unchanged bindings, then operator-confirmed
sequential S→A and A→B uploads with exact IDs/timestamps. The v2 packet carries
no sanitized binding readback for S; sanitized A/B readbacks must expose exactly
the six reviewed production secret names/types, while S is bounded by exact
ID/time, required-name operator confirmation, documented preservation, and
provider history. Require zero intervening versions/secret mutations/upload overrides,
`secret_values_recorded=false`, operator confirmation, and a canonical
provider-history digest. This is derived from documented Wrangler preservation
behavior; list/view exposes neither cryptographic parent links nor readable
secret equality. Never request/reinstall the inaccessible ledger-key value.

The packet requires 14 bounded health/auth/tenant/onboarding/CRUD/idempotency/
tombstone/assistant/match-sheet/webhook/write receipts, an activated exact
zero-legacy identity receipt, four distinct A/B/G/L Worker versions, equal A/B
script ETags and stable-binding hashes, passing iPhone 15 Pro Max, Apple Watch
Series 9 (45mm), and Release-configuration receipts, explicit
write/onboarding/traffic state, and a completed production observation.
Initial public deployment must be A=100%/B=0%, with exact-version A
health/readiness, auth rejection, retryable API/webhook denial, and zero
mutations. B receives zero ordinary traffic; bounded selection requires the
version override, an exact Access `service_auth` receipt with one service token
and zero bypass, and the Worker-only cutover-token gate. The bounded
`acceptance.checks.webhook_lifecycle` is manually signed through override +
cutover-token headers, records `manual_signed_harness`, both exact header names
and presence flags, and valid/invalid signature outcomes; it is not provider
delivery. Access application/policy/service-token IDs must be sanitized
Cloudflare provider IDs (32 hexadecimal characters or canonical UUIDs). G/L probes require
canonical provider deployment-readback digests and timestamps bracketing each
probe strictly inside the rollback window, complete by validation time, and
obey G-after < L-before. They use the same route, unique deployment/probe/
provider receipts, and the launch packet binds their route to initial A.
Promotion requires B=100% and no competitor.
While Access remains active, `traffic_and_writes.promoted_webhook_acceptance`
must then prove real Clerk delivery without override/token headers, exactly
three subscriptions, signature/create/update/delete/retry/delete-wins behavior,
and cleanup to zero test identity/application rows. Access removal follows that
receipt and precedes exact route/deployment/history and device evidence. No
Workers.dev/preview exposure is allowed. Production acceptance follows devices,
and the final ledger/consumer readback follows observation.

Its rollback section must bind a separately validated
`greenfield_destructive_v2` packet and exact digest for Worker `refwatch-api`,
including its unexpired window, thresholds, bracketed guard/LKG probes,
distributable recovery client, and approved stop/guard/Worker-client rollback/
PlanetScale reset/reseed/test-user recreation/acceptance-rerun sequence. Launch
validation calls the standalone rollback validator. Ledger escrow/recovery/
activation and Supabase reverse import must be false.

## Historical/future stateful migration tooling (not an initial-launch gate)

The repository intentionally retains the encrypted Supabase cutover-bundle,
legacy identity-mapping activation, isolated ledger rehearsal, and stateful
rollback validators. They preserve the reviewed procedure for historical
evidence and any future migration in which real users/data must be retained.
They do not gate the authorized zero-legacy greenfield launch. If that tooling
is used in a future stateful migration, the following procedure applies:

1. Use the 2026-07-14 preliminary inventory and the 2026-07-15 sanitized
   candidate contract under the active plan's
   `evidence/` directory for migration preparation. Immediately before final
   delta export, capture a new provider snapshot inside one
   `REPEATABLE READ, READ ONLY` transaction, recording the exact transaction
   SQL, UTC timestamp, all 39 counts, identity discrepancy, RLS state, and
   sanitized output. Execute the exact checked-in
   `api/scripts/supabase-candidate-snapshot.sql` as the sanitized preflight, but
   do not send full rows through generic MCP. The preliminary and candidate
   inventories do not satisfy the final cutover gate.
2. Export user and user-owned rows without changing their UUID primary/foreign keys.
3. Build a reviewed mapping from each existing internal user UUID to a Clerk subject. Do not infer that mapping from a missing `public.users.clerk_user_id` column.
   The live Auth contract is 13 bcrypt users, 30 users without password
   digests, and 22 Apple/13 email/9 Google identities with complete normalized
   email parity. Export only the validator's encrypted allowlist. Use bcrypt
   digest migration for the 13 password users; configure production Apple and
   Google connections for returning social users, who must reauthorize and
   pass migrated-account-linking acceptance before traffic cutover.
4. Import `app_users` first, preserving internal UUIDs, then import dependent tables in foreign-key order.
5. Apply the bundled idempotent seed, which inserts `reference_competitions`
   before `reference_teams`, then verify the authenticated catalog routes return
   the reviewed deterministic counts. These rows are global read-only reference
   data, not user-owned rows. A greenfield launch takes its seed from reviewed
   repository sources; a future stateful migration must separately review any
   live-provider difference.
6. Reconcile per-table counts, orphan checks, ownership, timestamps, JSON payloads, and representative match bundles.
7. Verify all 39 source-table dispositions and counts, including explicit
   zero-row exclusions, then document every expected difference before
   promotion.
8. Stream the final row export directly from the same quiesced database session
   into authenticated encryption with separate key custody. Require directory
   mode 0700, file mode 0600, exclusive no-symlink creation, complete framing,
   atomic fsync/rename, server/local digest parity, a named retention owner and
   event, and verified deletion after the observation window. A gitignored
   plaintext file and MCP transcript are not acceptable production artifacts.
9. Validate only through `api/scripts/validate-cutover-bundle.mjs` with the
   encrypted artifact, detached manifest, actual provider/ledger quiescence
   receipts, and artifact-creator receipt. Have the approved secret manager
   inject the key plus reviewed query/generator hashes as inherited variables;
   never put values in command history. The verifier must pass its exact source/
   exporter policy and real no-follow/mode/owner/size/hash,
   AES-256-GCM authentication, in-memory decryption, recomputed row digest, and
   receipt-binding checks before import. Rerun with receipts covering the import
   completion boundary before write enablement.
10. Keep export artifacts access-controlled and remove temporary credentials after reconciliation.

### Historical post-reconciliation new-user gate

For a future stateful migration, legacy users must be mapped before production
traffic. The final cutover-bundle
validator computes a deterministic receipt digest tied to the exact production
Clerk instance, normalized mapping hash, legacy mapping count, approved
auth-only exclusion, and normalized per-subject mappings held only inside the
encrypted bundle. Sanitized stdout contains only the count and hashes. In one
reviewed import sequence, insert preserved `app_users`, the `verified` receipt,
and every receipt-linked row in `identity_reconciliation_legacy_mappings`. Run
the transactional activation helper, which refuses to create an
`identity_reconciliation_activations` row unless registry count/hash and every
subject-to-UUID `app_users` row match. Only then install
`NEW_USER_ONBOARDING_MODE=post_reconciliation`,
`IDENTITY_RECONCILIATION_RECEIPT=<64-hex digest>`, exact
`CLERK_INSTANCE_ID`, and exact `CLERK_ISSUER`. Do not activate this mode while
`WRITE_MODE=disabled`.

With the gate closed, an unmapped bearer subject fails closed and an unmapped
`user.created` or `user.updated` webhook returns retryable `503` instead of
being silently acknowledged. With the exact registry activated, only a subject
absent from both the legacy registry and deletion tombstones may receive a
server-generated UUID. Subject-scoped transaction locks serialize create/delete
races so deletion wins, including delete-before-create. Imported legacy users
continue to use preserved UUIDs; a missing/mismatched legacy row fails closed.
Bearer JWT issuer must match the selected production instance. The installed
Clerk SDK's typed verified-event projection omits envelope-level
`instance_id`/`timestamp`, while Clerk's signed raw event contains them. The
handler therefore verifies the signature, parses that same signed raw envelope,
requires its instance to match configuration, requires its type and subject to
match the verified SDK projection, and validates its timestamp as positive
safe-integer milliseconds before database access. Operational provenance still
requires creating the endpoint in the reviewed production instance, installing
only that endpoint's signing secret, and recording the provider receipt. The deprecated
`ALLOW_UNMAPPED_CLERK_USERS` variable does not open this future stateful path.

## Local collection-sync baseline

Treat `updatedAfter` as an inclusive replay boundary. Team, competition, venue,
schedule, match, and assessment routes return rows and tombstones at
`updated_at >= updatedAfter`. Each collection entity uses a
namespace-qualified transaction advisory lock and advances its timestamp to
`max(now, persisted updated_at + 1 millisecond)`, including delete and
resurrection. This makes the later mutation visible even when two requests
observe the same clock instant.

The iOS team, competition, venue, schedule, and match repositories:

- advance the collection high-water cursor only after a completed pull, never
  from a single-record push acknowledgement;
- start first/relaunch pulls at the Unix epoch for full tombstone
  reconciliation;
- subtract a 15-minute overlap from later completed-pull cursors;
- accept only strictly newer remote rows; and
- preserve locally dirty active rows and tombstones during replay.

The 15-minute overlap addresses request-scoped writes that receive a timestamp
then commit behind a later request. It is a bounded assumption, not a durable
unbounded server cursor. Keep collection writes request-scoped and
database-only; a future longer-running/background writer must add a
server-issued monotonic revision/cursor or a separately reviewed equivalent.
Every repository relaunch intentionally returns to the epoch floor.

Team replacement is bounded at 100 members, 25 officials, and 50 tags. Child
UUIDs are case-normalized, retained children are bulk-upserted, and only
explicit removals are deleted so an idempotent retry cannot null historical
match-event/member links. Match and assessment references must be owned and
active. Assessment owner/match uniqueness and all entity versions are
advisory-lock serialized.

The exact local proof and review trail are in
`../exec-plans/active/backend-platform-migration/evidence/2026-07-20-greenfield-local-route-matrix.md`.
Do not substitute it for the deployed production matrix.

Local webhook unit tests mock the official Clerk verifier boundary, while
hermetic PostgreSQL tests exercise lifecycle/idempotency/tombstone processing
below cryptographic verification. They do not prove real valid/invalid webhook
signatures. Perform that proof only against the configured production endpoint
in the bounded deployed matrix.

## Staging and production gates

Do not route production traffic until all gates have evidence:

The prior staging Worker→Hyperdrive→database connectivity receipt does not
satisfy any current production authenticated or user-flow gate below.

- API typecheck, Workers-runtime tests, database-backed owner/isolation tests, and deploy dry-run pass.
- Match ingest is transactional and concurrency-safe for `Idempotency-Key`.
- Every foreign reference and mutation is tenant-scoped.
- Incremental sync uses the inclusive/tombstone/overlap/relaunch protocol above,
  and deployed acceptance must exercise active rows plus tombstones across
  repeated pulls.
- Clerk deletion/webhook ordering cannot silently restore a deleted account.
- Unmapped Clerk subjects fail closed until the exact
  `greenfield_zero_legacy_v1` receipt for
  `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac` receives a durable activation row and
  `NEW_USER_ONBOARDING_MODE=greenfield_bootstrap` agrees with it; afterward,
  only non-tombstoned new subjects are eligible.
  `ALLOW_UNMAPPED_CLERK_USERS` never authorizes the production path.
- Assistant and match-sheet routes keep the OpenAI key server-side, enforce bounded usage, and preserve existing response contracts.
- iOS signs in with Clerk, resolves `/api/me`, and sends a bearer token to the Worker.
- Offline SwiftData save/backlog and logout/user-switch cleanup pass.
- iOS build/tests and RefWatchCore/watchOS regression checks pass on the required destinations when available.
- No Supabase, database, Clerk secret, webhook, or OpenAI credential is present in the iOS source, config, bundle, or build logs.

## Cutover and rollback

### Greenfield initial-launch procedure

1. Inventory the current provider state read-only: migrations/schema,
   deterministic seed, target users/data, reconciliation controls, ledger and
   consumers, exact Clerk provenance, and Worker versions/routes/bindings.
2. Apply migration `0016` only through the reviewed exact-head, atomic,
   Postgres-owned production helper; stop traffic/writes and reset disposable
   target state if needed; then reseed the reviewed deterministic 5/54
   reference catalog.
   Stop here for beta.3 source: do not deploy the Worker or continue activation
   until the exact reviewed production `0017` apply/readback is recorded and
   the launch validator's schema/history pins are updated. The existing
   production receipt remains the immutable `0016` receipt.
3. Capture the pinned post-preparation schema, seed, clean-target, inactive-
   ledger, and Clerk receipts. Require zero target application/control rows and
   Clerk users, zero preparing/open/capture-enforced epochs, and zero
   Queue/cron/D1 consumers.
4. Create, transactionally activate, and observe the exact
   `greenfield_zero_legacy_v1` receipt after the clean-target/Clerk readbacks.
5. Create the exact Clerk webhook and install its signing secret plus
   `CUTOVER_ACCEPTANCE_TOKEN` as only newly required/changed values via
   non-echoing Wrangler stdin. Let source S preserve unchanged existing
   bindings—including the inaccessible ledger-key binding without requesting
   its value—then upload A and B sequentially. Retain the provider-history-
   bounded/operator-confirmed `worker.secret_lineage`; sanitized A/B readbacks
   must expose exactly the six allowed secret names/types without values. Bound
   S by exact ID/time, required-name operator confirmation, documented
   preservation, and provider history.
6. Temporarily deploy G=100% with no competitor; bracket its probe with
   canonical provider deployment readbacks/digests/timestamps, prove exact
   version plus disabled denial/no-mutation, and restore A=100%/B=0%. Repeat for
   L and wait for both after-readbacks. Keep both inside the rollback window and
   complete by validation time; require G-after < L-before, the same initial
   route, and unique deployment/probe/provider receipts.
7. Collect the final public A=100%/B=0% proof: exact A health/readiness, bearer
   rejection, retryable API/webhook denial, zero mutations, and no
   Workers.dev/preview exposure.
8. Validate the exact nested `greenfield_destructive_v2` packet and digest with
   `npm run rollback:validate -- ../.cutover/rollback-packet.json`, including
   window, thresholds, G/L probes, client, and destructive instructions.
9. Keep A=100%/B=0% for ordinary traffic. Record an exact Access `service_auth`
   policy receipt for `api.refwatch.ibby.ai/api/*` with one service token and
   zero bypass; select B only with the Cloudflare version override through that
   policy and the Worker-only cutover-token gate. Then prove
   missing/invalid bearer rejection, `/api/me`, zero-legacy onboarding, tenant
   isolation, owner-spoof rejection, CRUD, idempotency, tombstones, assistant,
   match-sheet, webhook signature/provenance/lifecycle/retry/delete-wins,
   `write_round_trip`, iOS identity resolution, offline backlog, and logout/user
   switching. The bounded webhook receipt must encode
   `manual_signed_harness`, exact override/token header names with both present,
   and valid-signature acceptance plus invalid-signature rejection; it is not
   provider-delivery evidence. Do not
   make live OpenAI calls in local tests.
10. Promote B=100% with no competitor while `/api/*` Access remains active.
    Without override/cutover-token headers, collect the real Clerk-provider
    promoted-webhook receipt for the exact three subscriptions, signature,
    create/update/delete/retry/delete-wins behavior, and cleanup to zero test
    identity/application rows.
11. Remove the bounded Access policy only after that receipt, capture its
    provider-bound removal receipt, and then capture exact deployment history.
12. Exercise promoted B on iPhone 15 Pro Max and Apple Watch Series 9 (45mm),
    including clean account creation, match lifecycle, sync/offline backlog,
    logout/user switching, watch handoff, assistant/match sheet where
    applicable, and embedded Release configuration. Close this as its own
    reviewed batch.
13. Only after physical/release acceptance, record production acceptance and
    observe health/auth/isolation/errors/database pressure/webhook/onboarding
    signals. Capture the final inactive-ledger/zero-consumer readback, add the
    bound receipts, then run
    `npm run launch:validate -- ../.cutover/greenfield-launch-packet.json` as
    the final closeout gate. Close traffic/observation as their own reviewed
    batch.
14. On failure, stop traffic and writes, route to the emergency write-disabled
   Worker, restore the last-known-good Worker/client, reset and reseed
   PlanetScale, recreate disposable test identities, and rerun the launch. No
   production ledger or Supabase reverse import is required for this authorized
   destructive recovery.
15. After accepted traffic observation, retire disposable Supabase
   identities/data and obsolete
   credentials/functions/configuration, then remove safe compatibility debt and
   detach unused ledger resources. Record each completed cleanup; authorization
   is not evidence that cleanup already occurred.

If the iPhone 15 Pro Max or Apple Watch Series 9 (45mm) is unavailable, record
that external blocker and continue every other safe stage. Do not represent
device acceptance as passed, do not complete final traffic cutover, and do not
retire the rollback/source path.

### Historical/future isolated ledger rehearsal procedure

Use this sequence only with the allowlisted disposable branch and isolated
Cloudflare resources. Load connection URLs and key material through the
operator's approved secret channel; never place their values in command history
or evidence. The scripts refuse a non-PlanetScale source, the wrong branch, a
non-local replay target, a missing disposable marker, or an absent explicit
opt-in.

1. Confirm the deployed rehearsal Worker version and expected branch,
   runtime-role, and database-marker bindings. Create the baseline and probe in
   one atomic epoch-opening operation:

   ```sh
   cd api
   REFWATCH_ALLOW_LEDGER_REHEARSAL_PROBE=1 \
   REFWATCH_LEDGER_REHEARSAL_DATABASE_URL="$REFWATCH_LEDGER_REHEARSAL_DATABASE_URL" \
   REFWATCH_LEDGER_BASELINE_OUTPUT=../.cutover/ledger-rehearsal/baseline.json \
   REFWATCH_LEDGER_WORKER_VERSION_ID="$REFWATCH_LEDGER_WORKER_VERSION_ID" \
   node scripts/create-ledger-rehearsal-probe.mjs
   ```

2. Keep the epoch frozen while delivery drains. Read PostgreSQL until every row
   through `frozen_event_sequence` is `delivered` and has no active lease:

   ```sql
   select e.id, e.status, e.capture_enforced, e.frozen_event_sequence,
          count(*) filter (where d.state = 'delivered') as delivered,
          count(*) filter (where d.state <> 'delivered') as undelivered,
          count(*) filter (
            where d.state = 'leased' and d.leased_until > now()
          ) as active_leases
   from mutation_ledger_epochs e
   join mutation_outbox_events o on o.epoch_id = e.id
   join mutation_outbox_deliveries d on d.event_id = o.event_id
   where e.id = :'epoch_id'
     and o.event_sequence <= e.frozen_event_sequence
   group by e.id;
   ```

   Abort if the epoch is not `frozen`, capture enforcement is not true, the
   count differs from the expected event count, any row is undelivered, or any
   lease remains.

3. Take two candidate D1 reads of the exact epoch and one candidate dead-letter
   read. Retain raw JSON only in the access-controlled temporary workspace. The
   CLI result alone does not prove primary service; the checker must inspect the
   provider metadata and reject any non-primary read:

   ```sh
   npx wrangler d1 execute refwatch-mutation-ledger-rehearsal-20260715 \
     --remote --env rehearsal --json --command \
     "select * from mutation_ledger_events where epoch_id='$EPOCH_ID' order by event_sequence" \
     > ../.cutover/ledger-rehearsal/d1-read-one.json
   npx wrangler d1 execute refwatch-mutation-ledger-rehearsal-20260715 \
     --remote --env rehearsal --json --command \
     "select * from mutation_ledger_events where epoch_id='$EPOCH_ID' order by event_sequence" \
     > ../.cutover/ledger-rehearsal/d1-read-two.json
   npx wrangler d1 execute refwatch-mutation-ledger-rehearsal-20260715 \
     --remote --env rehearsal --json --command \
     "select * from mutation_ledger_dead_letters where event_id='$POISON_EVENT_ID'" \
     > ../.cutover/ledger-rehearsal/d1-dead-letter.json
   ```

4. Run the independent checker while the epoch remains frozen. It pins the
   exact durable verifier role, opens a read-only transaction, rejects effective
   DML privileges on all 22 captured domain tables, and rejects non-primary or
   unstable D1 reads. It does not prove absence of DML on the 13 control/
   excluded tables or absence of schema-creation privileges:

   ```sh
   REFWATCH_LEDGER_REHEARSAL_READONLY_URL="$REFWATCH_LEDGER_REHEARSAL_READONLY_URL" \
   REFWATCH_LEDGER_VERIFY_EPOCH_ID="$EPOCH_ID" \
   REFWATCH_LEDGER_VERIFY_POISON_EVENT_ID="$POISON_EVENT_ID" \
   REFWATCH_LEDGER_D1_READ_ONE="$(<../.cutover/ledger-rehearsal/d1-read-one.json)" \
   REFWATCH_LEDGER_D1_READ_TWO="$(<../.cutover/ledger-rehearsal/d1-read-two.json)" \
   REFWATCH_LEDGER_D1_DEAD_LETTER_READ="$(<../.cutover/ledger-rehearsal/d1-dead-letter.json)" \
   node scripts/verify-ledger-rehearsal.mjs
   ```

5. Prepare each local PostgreSQL restore target with the full current migration
   set and an exact disposable marker. Export only the frozen epoch from D1,
   then run both guarded restores:

   ```sh
   REFWATCH_ALLOW_DESTRUCTIVE_LEDGER_REPLAY=1 \
   REFWATCH_LEDGER_BASELINE_PATH=../.cutover/ledger-rehearsal/baseline.json \
   REFWATCH_LEDGER_D1_EXPORT_PATH=../.cutover/ledger-rehearsal/d1-read-one.json \
   REFWATCH_LEDGER_REHEARSAL_SOURCE_URL="$REFWATCH_LEDGER_REHEARSAL_READONLY_URL" \
   REFWATCH_LEDGER_REPLAY_TARGET_URL="$LOCAL_REPLAY_DATABASE_URL" \
   REFWATCH_LEDGER_REPLAY_TARGET_MARKER="$LOCAL_REPLAY_MARKER" \
   REFWATCH_LEDGER_REPLAY_TARGET_KIND=same_schema \
   REFWATCH_LEDGER_DECRYPTION_KEYRING="$REFWATCH_LEDGER_DECRYPTION_KEYRING" \
   node scripts/replay-ledger-rehearsal.mjs

   REFWATCH_ALLOW_DESTRUCTIVE_LEDGER_REPLAY=1 \
   REFWATCH_LEDGER_BASELINE_PATH=../.cutover/ledger-rehearsal/baseline.json \
   REFWATCH_LEDGER_D1_EXPORT_PATH=../.cutover/ledger-rehearsal/d1-read-one.json \
   REFWATCH_LEDGER_REHEARSAL_SOURCE_URL="$REFWATCH_LEDGER_REHEARSAL_READONLY_URL" \
   REFWATCH_LEDGER_REPLAY_TARGET_URL="$SECOND_LOCAL_REPLAY_DATABASE_URL" \
   REFWATCH_LEDGER_REPLAY_TARGET_MARKER="$SECOND_LOCAL_REPLAY_MARKER" \
   REFWATCH_LEDGER_REPLAY_TARGET_KIND=second_same_contract \
   REFWATCH_LEDGER_DECRYPTION_KEYRING="$REFWATCH_LEDGER_DECRYPTION_KEYRING" \
   node scripts/replay-ledger-rehearsal.mjs
   ```

6. Archive only after the checker and both restores succeed:

   ```sql
   update mutation_ledger_epochs
   set status = 'archived', capture_enforced = false, updated_at = now()
   where id = :'epoch_id'
     and status = 'frozen'
     and capture_enforced = true;
   ```

   Require exactly one affected row and read it back. On any failure, do not
   alter bound hashes or delete evidence. Preserve the epoch frozen for
   investigation; if capture must be disabled, use the reviewed archive
   transition and record the failed/superseded disposition explicitly.

7. For the poison path, use only the guarded script. It refuses the wrong
   PlanetScale branch or D1 database and requires an explicit opt-in:

   ```sh
   REFWATCH_ALLOW_LEDGER_POISON_PROBE=1 \
   REFWATCH_LEDGER_REHEARSAL_DATABASE_URL="$REFWATCH_LEDGER_REHEARSAL_DATABASE_URL" \
   REFWATCH_LEDGER_WORKER_VERSION_ID="$REFWATCH_LEDGER_WORKER_VERSION_ID" \
   REFWATCH_LEDGER_D1_DATABASE=refwatch-mutation-ledger-rehearsal-20260715 \
   REFWATCH_LEDGER_D1_DATABASE_ID=d6fd2757-0cfa-4468-97bc-c543de824917 \
   npm run mutation:poison-rehearsal
   ```

   The script delays normal delivery, atomically creates the poison epoch/event,
   writes the deliberate immutable D1 `worker_version_id` conflict, confirms a
   primary readback, then releases delivery. Require PostgreSQL state
   `quarantined`, exact lease generation, sanitized error code, and a D1 receipt
   with disposition `quarantined`. A stale-generation receipt is a failed proof.
   Separately run update and delete negative tests against both D1 events and
   dead letters; all four must fail with `SQLITE_CONSTRAINT_TRIGGER`.

8. Reconcile every retained epoch, not only the final proof. Classify provider
   replay epochs, guarded poison epochs, and `integration-*` fake-D1 fixtures
   separately. Report pending, leased, quarantined, active-lease, D1-event, and
   DLQ counts without rewriting archived history. The live scheduler excludes
   `integration-*` baselines unless an epoch ID is explicitly requested.

The reported replay duration covers only the scripted local procedure. It is
not a production RTO. The second target is another disposable same-contract
PostgreSQL database, not Supabase. Production rollback still requires a
reviewed table-specific reverse-import procedure or another explicitly approved
recovery strategy only when a future launch elects to preserve state.

### Historical stateful-migration cutover sequence

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

### Rollback packet profiles

The rollback validator accepts explicit `stateful_migration_v1`,
`greenfield_destructive_v1`, and `greenfield_destructive_v2` profiles. An older
packet that omits `rollback_profile` is interpreted as
`stateful_migration_v1` for historical compatibility; an explicitly unknown
profile fails. Every profile requires exact Worker name `refwatch-api`,
environment `production`, strict unexpired UTC bounds, a proved write guard,
and an already distributable recovery client. Stateful and greenfield v1 retain
their three-version compatibility contract. Active greenfield v2 requires
distinct disabled-candidate, accepted-candidate, guard, and LKG IDs plus both
guard and LKG probe receipts.

Populate the gitignored `.cutover/rollback-packet.json` and run
`npm run rollback:validate -- ../.cutover/rollback-packet.json` from `api/`.
The stateful profile additionally requires a restricted external write-ledger
location/schema/probe receipt. Its external-ledger requirements do not gate the
greenfield launch recovery profiles. Both greenfield profiles require the exact
destructive reset/reseed/recreate sequence and require ledger
escrow/recovery/activation plus Supabase reverse import to be false. Only v2 is
valid for the active production greenfield closeout. The local validator checks
packet structure, chronology, and bounds; it does not prove provider existence.
Owner-scope violations always trigger rollback at the first occurrence.

Production foundation version `e966d6df-b5ff-4288-832c-c8d91e00ce48` was
recorded with `WRITE_MODE=disabled`, no public/preview URL, and no background
consumers. Reverify it rather than assuming it is still deployable. For a future
stateful cutover, routing to a provider-verified write-guard version blocks API
and Clerk-webhook mutation while preserving health and reads; drain in-flight
requests, freeze/reconcile the ledger, then route to the recorded
last-known-good version. Never improvise a version ID or treat an unavailable
client build as rollback readiness. The transactional ledger was proved on
isolated resources. Production D1/Queue/DLQ resources may exist while inactive.
Before any future production epoch opens, provision an encrypted access-
controlled baseline store, restrict operator/read access, record immutable
artifact hashes, and define retention and verified deletion. Do not use a
plaintext local baseline as stateful rollback evidence. Reconcile queued Clerk
webhook retries before reopening writes.

The 2026-07-17 production ledger-key audit failed before escrow: the named Keychain
record contains no recoverable payload, while the Worker secret value cannot be
read through Wrangler or the dashboard. Preserve that evidence unchanged; do
not upload a placeholder or recover/activate the key for the initial greenfield
launch. If ledger capture is deliberately adopted later, treat storage,
functional recovery, and activation as distinct reviewed stages and keep key
material out of arguments, logs, chat, and evidence.
