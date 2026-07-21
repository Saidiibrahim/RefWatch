# RefWatch API

Cloudflare Worker API for the RefWatch iOS client. It authenticates Clerk session tokens, resolves each Clerk subject to an internal `app_users.id`, and is the only component allowed to access PlanetScale or OpenAI.

This directory is the active target backend, but authorization is not a claim
that production cutover is complete. The 2026-07-20 launch is greenfield: all
historical Supabase identities and application rows are disposable, no legacy
mapping/import is required, and PlanetScale must start with zero `app_users`,
zero legacy mappings, and zero user-owned rows while retaining the deterministic
global reference seed reviewed from repository sources. The production Clerk
instance is `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, the domain is
`refwatch.ibby.ai`, and the issuer/Frontend API is
`https://clerk.refwatch.ibby.ai`. Ledger escrow/recovery/activation is deferred
and non-blocking; require zero preparing, open, or capture-enforced epochs and
zero Queue, cron, or D1 consumers, not absence of provisioned resources.
Initial rollback may stop traffic/writes, route to the write-disabled Worker,
restore Worker/client versions, reset/reseed PlanetScale, recreate test
identities, and rerun the launch.

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
npm run test:db
npm run test:local:routes
npm run dev
```

The example file contains placeholders only. Never commit `.dev.vars`.
`test:db` and `test:local:routes` each start a temporary loopback-only
PostgreSQL cluster, apply the current migrations, run their bounded database or
mounted-route matrix, and remove the cluster. They require `initdb`, `pg_ctl`,
`pg_isready`, and `createdb` on `PATH` and use no PlanetScale or provider
credential. The former remote disposable-branch rehearsal remains available
only under the explicit historical command
`test:db:historical:planetscale-rehearsal`.

Use a non-echoing secret-manager/provider injection to populate
`DATABASE_URL` in the process environment before opening the migration shell.
Then run only the visible command:

```sh
npm run db:migrate
```

Never place a real connection string in an inline command, shell history,
evidence, or chat. Do not use an application runtime credential for schema
migrations. Apply generated migrations to a disposable PlanetScale branch and
verify them before promoting to production.

## Worker secrets and bindings

Secrets:

- `CLERK_SECRET_KEY`
- `CLERK_PUBLISHABLE_KEY`
- `CLERK_JWT_KEY` (optional PEM public key for networkless token verification)
- `CLERK_WEBHOOK_SIGNING_SECRET`
- `CUTOVER_ACCEPTANCE_TOKEN` (server-only bounded-version gate; never iOS or
  evidence)
- `OPENAI_API_KEY`
- `DATABASE_URL` only when not using Hyperdrive

The `staging` Wrangler environment has a real `HYPERDRIVE` binding to the
isolated PlanetScale rehearsal branch. The historical production foundation
still preserves its cache-disabled read-only Hyperdrive/runtime role as the
emergency write-denial path. The 2026-07-20 preparation batch provisioned a
separate durable least-privilege read/write-data role and paired
cache-disabled/TLS-required Hyperdrive. The local production candidate config
binds that new pair while writes and onboarding remain disabled; the deployed
Worker is unchanged. Both mandatory preparation reviewers returned
`NO FINDINGS`; distinct disabled/accepted candidate plus guard/LKG deployment
remains pending.
Database passwords remain inside Hyperdrive, not Worker variables or the iOS
app.

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

Verify the selected Wrangler environment lists its intended `HYPERDRIVE`; never
put a PlanetScale connection string in `wrangler.jsonc` or the iOS app. The
production sequence is not yet executed. It must upload A/B/G/L, bracket each
temporary 100% G/L probe with canonical provider readbacks, restore A=100%/
B=0%, and only then collect the final write-disabled A proof. Before those
uploads, only newly required/changed secrets (at least webhook signing and
cutover acceptance) use non-echoing `wrangler versions secret put` via stdin.
Final source S preserves unchanged existing bindings; operator-confirmed
sequential A then B uploads are bounded by a digest-checked provider history.
Sanitized A/B readbacks must expose exactly the six allowed secret names/types.
S is bounded by its exact ID/time, the required-name operator confirmation,
documented Wrangler preservation, and provider history.
During bounded
automation, `/api/*` selects B through the version override, exact Access
`service_auth` policy, and Worker cutover token. The packet's
`acceptance.checks.webhook_lifecycle` is instead a manually signed lifecycle
with `delivery_source=manual_signed_harness`, the exact override/token header
names and presence flags, and valid/invalid signature outcomes; it is not real
Clerk-provider delivery. After B=100% promotion, keep `/api/*` Access
active and collect `traffic_and_writes.promoted_webhook_acceptance` from the
real Clerk endpoint with no override or cutover-token header. That receipt must
prove exactly `user.created`, `user.updated`, and `user.deleted`, signature,
create/update/delete/retry/delete-wins behavior, and cleanup to zero test
identity/application rows. Remove Access only after that receipt, then capture
deployment history and begin devices.

The top-level Wrangler target is the separate `refwatch-api-development` Worker.
Generic `npm run deploy` and `npm run dry-run` therefore target development;
production commands must always specify `--env production`. Only the exact
normalized `WRITE_MODE=enabled` value permits API/webhook mutations. Missing,
blank, disabled, or unknown values fail closed. The 2026-07-17 receipt recorded
production as disabled; the reviewed 2026-07-20 baseline reverified writes and
onboarding disabled. Production must remain disabled until the reviewed
greenfield activation/promotion phase.

## Routes

`GET /health`, `GET /health/ready`, and signed `POST /webhooks/clerk` are public. Every `/api/*` route requires `Authorization: Bearer <clerk-session-token>`. Readiness performs a sanitized `select 1`; it is connectivity proof only.

Reference catalog reads are `GET /api/reference-catalog/competitions?seasonYear=<year>` and `GET /api/reference-catalog/teams?seasonYear=<year>`. Catalog rows are global read-only data, but the routes still require Clerk authentication. Migration `0002` creates the tables and ports the idempotent 2026 seed (5 competitions, 54 teams) from legacy migration `0017`; `0003` restores source integrity checks and enforces matching team/competition seasons. The 2026-07-20 post-preparation readback reconfirmed the exact production 5/54 seed and both business digests. Authenticated deployed route acceptance remains pending.

User-owned collection routes return tombstones on an inclusive
`updated_at >= updatedAfter` boundary. Their writes take namespace-qualified
per-entity transaction advisory locks and assign
`max(current time, persisted updated_at + 1 millisecond)`, so same-clock
update/delete/resurrection operations remain strictly ordered for incremental
sync. Team replacement normalizes UUID case, accepts at most 100 members, 25
officials, and 50 tags, bulk-upserts retained children, and deletes only
explicit removals; an idempotent retry therefore cannot null a historical
match-event/member reference.

The active Swift collection repositories use only completed pulls as cursor
high-water marks. First/relaunch pulls start at the Unix epoch, later pulls
replay a 15-minute overlap, and local merge accepts only strictly newer rows
without overwriting dirty local state. The overlap assumes these request-scoped,
database-only writes settle within 15 minutes; a future longer-running writer
needs a server-issued monotonic cursor/revision contract.

The Clerk webhook synchronizes profile fields but is not required to finish
sign-in. For the initial launch, middleware remains fail-closed until a verified
`greenfield_zero_legacy_v1` receipt for
`ins_3GWFGUd1rI6hx5lWlUxMYAkxdac` has a durable activation row and
`NEW_USER_ONBOARDING_MODE=greenfield_bootstrap`,
`IDENTITY_RECONCILIATION_RECEIPT`,
`IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST`, exact `CLERK_INSTANCE_ID`,
exact `CLERK_ISSUER`, and enabled writes all agree. Only a subject absent from
durable deletion tombstones may then receive a server-generated UUID
transactionally and idempotently. Subject-scoped advisory locks serialize
create/delete races. Bearer provenance is checked against JWT `iss`. After
Clerk signature verification, the webhook additionally parses the same signed
raw envelope. Its `instance_id` must match the exact configured production
instance; its event type and subject must match the verified SDK projection;
and its event timestamp must be positive safe-integer milliseconds. Durable
instance-plus-Svix-ID receipts make delivery retries idempotent and conflicting
reuse fail closed. The deprecated `ALLOW_UNMAPPED_CLERK_USERS` variable never
authorizes production creation.

Local webhook unit tests mock the official
`@clerk/backend/webhooks.verifyWebhook` call and prove handler wiring plus
fail-closed behavior around that boundary. Hermetic database tests enter below
cryptographic verification and prove lifecycle/idempotency/tombstone behavior
on real PostgreSQL. Real valid/invalid Clerk signature acceptance remains a
deployed production-acceptance check.

## Greenfield launch note

The 2026-07-14 live Supabase inventory remains historical point-in-time
evidence: 43 Auth identities, 42 profiles, and 1,106 application rows, including
the auth-only `testing@refwatch.com` identity. All are disposable. Do not import
their UUIDs, rows, credentials, or identity mappings. New Clerk subjects receive
server-generated internal UUIDs only through the activated greenfield bootstrap.

Clean-target evidence must report zero app users and zero user-owned rows
separately from schema/control tables and deterministic global reference data.
Use only reviewed repository migrations/sources for that global seed and record
its exact digest/counts. Historical source counts are not launch reconciliation
gates.

The encrypted cutover-bundle, legacy mapping/activation, isolated ledger
rehearsal, and stateful rollback validators remain intentionally available as
historical/future live-migration tooling. Do not weaken them, and do not require
their Supabase preservation, mapping, export, or ledger receipts for the
`greenfield_zero_legacy_v1` launch.

### Greenfield launch packet

Populate a sanitized, gitignored launch packet and run:

```sh
npm run launch:validate -- ../.cutover/greenfield-launch-packet.json
```

The packet must explicitly declare `greenfield_launch_v2`; omitted, unknown,
or mixed stateful/greenfield claims fail closed. The validator pins Clerk
instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, domain `refwatch.ibby.ai`, issuer
`https://clerk.refwatch.ibby.ai`, Worker `refwatch-api` in `production`, and
PlanetScale organization/database/branch
`ibrahim-aka-ajax/refwatch/main` (`w3g1f8vcbg34`). The authorization digest
`17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b`
is the SHA-256 of the canonical JSON payload recorded in the 2026-07-20
authorization artifact, not the Markdown-file digest.

The reviewed production target is 17 migrations through
`0016_careless_steel_serpent`. The checked-in beta.3 source is 18 migrations
through additive `0017_ambiguous_hedge_knight`; production remains at `0016`
until a later reviewed provider operation applies `0017`. Run the exact
sanitized read-only provider
queries whose paths and hashes are pinned by the validator:

- `scripts/greenfield-schema-readback.sql`: migration history plus the complete
  36-table/382-column catalog contract, including table properties/RLS,
  constraints, indexes, triggers, functions, and enums;
- `scripts/greenfield-clean-target-readback.sql`: exact 5/54 deterministic seed
  plus zero application/control rows before bootstrap; and
- `scripts/greenfield-ledger-readback.sql`: zero preparing/open/capture-enforced
  epochs while allowing classified frozen/archived inactive history.

Every embedded sanitized receipt digest is recomputed from its canonical
payload. Strict stage chronology binds baseline, zero-legacy activation,
disabled candidate A, bounded accepted candidate B, B promotion, promoted
provider-webhook acceptance, Access removal, physical iPhone/watch and Release
configuration, production acceptance/observation, and an unexpired rollback
window to the validator's runtime clock. A and B must
have distinct version IDs, equal script ETags, and equal stable-binding hashes
that normalize only the two stage-mode values. The packet carries exact
sanitized A/B `wrangler versions view --json` receipts, including their
digests; validation recomputes each stable hash and enforces the exact approved
production plain/resource bindings and secret-name/type set without reading or
persisting secret values. Invalid binding diagnostics identify only the
field/contract and never echo a rejected value.

The digest-checked `worker.secret_lineage` receipt separately proves exact
non-disclosing Cloudflare inheritance. Non-echoing
`wrangler versions secret put` via stdin is used only for newly required or
changed secrets, including at least `CLERK_WEBHOOK_SIGNING_SECRET` and
`CUTOVER_ACCEPTANCE_TOKEN`; final source version S preserves unchanged existing
bindings. The receipt binds exact S/A/B IDs and times, operator-confirmed
sequential S→A→B uploads, and S's required-name operator confirmation.
Sanitized A/B readbacks expose the exact six-name/type set. The receipt also
requires zero unexpected intervening versions, zero intervening secret
mutations, zero upload secret overrides, passed operator/non-echoing status,
`secret_values_recorded=false`, and the canonical provider-history digest.
Cloudflare list/view does not expose cryptographic parent links or secret-value
equality, so direct comparison is deliberately impossible. The deferred ledger
key is neither recovered nor rotated.

The provider sequence must first bracket temporary G=100% and L=100% probes
with canonical deployment-readback digests and before/after timestamps,
restoring A=100%/B=0% after each. Launch validation waits for both
after-readbacks. Both proofs must fall strictly inside the rollback window,
complete by validation time, use the same route with unique deployment/probe/
provider receipts, and satisfy G-after < L-before; launch binds that route to
the initial A route. It must then collect the final public A=100%/B=0% proof: A's
exact version from health/readiness, missing/invalid bearer rejection,
retryable API/webhook denial, and zero mutations.

B must receive zero ordinary traffic during bounded automation. `/api/*` requests
select it with `Cloudflare-Workers-Version-Overrides` behind an exact Access
`service_auth` receipt with one service token and zero bypass, plus
`X-RefWatch-Cutover-Token` backed by server-only
`CUTOVER_ACCEPTANCE_TOKEN`. Access application, policy, and service-token IDs
must be sanitized Cloudflare provider IDs (32 hexadecimal characters or a
canonical UUID). The bounded `acceptance.checks.webhook_lifecycle` uses
`delivery_source=manual_signed_harness`, endpoint `/webhooks/clerk`, exact
`Cloudflare-Workers-Version-Overrides` and `X-RefWatch-Cutover-Token` names
with both presence flags true, and passed valid-signature acceptance plus
invalid-signature rejection. It does not claim delivery by Clerk.

After bounded automation, B must be promoted to 100% with no competitor while
`/api/*` Access remains active. The real Clerk endpoint then sends no override
or cutover-token header. The
`traffic_and_writes.promoted_webhook_acceptance` receipt must bind exactly
three subscriptions (`user.created`, `user.updated`, `user.deleted`), prove
signature/create/update/delete/retry/delete-wins behavior, and clean test
identities/application rows to zero. Only afterward may the provider-bound
Access-removal receipt precede exact deployment history and all device/Release
evidence. Devices exercise promoted B, production acceptance follows those
receipts, and the final post-observation readback must still show inactive
ledger capture and zero consumers. Workers.dev and preview URLs remain
disabled.

The launch packet requires a separately validated
`greenfield_destructive_v2` rollback packet with four distinct Worker versions,
exact Worker name `refwatch-api`, exact nested standalone packet/digest/window/
thresholds/probes/client, proved write-guard and last-known-good versions, a
distributable recovery client, and stop/guard/version rollback plus PlanetScale
reset/reseed, test-identity recreation, and acceptance rerun. The launch
validator invokes the standalone rollback validator. Receipt kinds and IDs
must be unique. Ledger escrow/recovery/activation and Supabase reverse import
must be false.

## Verification and remaining gates

Historical checkpoint verified after the API remediation review on 2026-07-14:

- `npm test` (52 tests across 10 files)
- `wrangler deploy --dry-run --env staging`
- staging deployment plus `/health` and Hyperdrive-backed `/health/ready`

Historical local checkpoint verified on 2026-07-17:

- `npm run typecheck`
- `npm test` (93 tests across 14 files)
- `npm run test:local:routes` (4 partial mounted-route/owner-isolation cases on
  a fresh loopback-only PostgreSQL cluster; not Clerk/PlanetScale/deployed proof)

The 2026-07-20 greenfield identity batch adds migration `0016`, exact
authorization/Clerk provenance, immutable activation and delivery receipts,
transactional lifecycle idempotency, and hermetic zero-legacy/concurrency/
inactive-ledger/isolated-strict-capture proofs. After the active v2
code-risk remediation, the current focused greenfield/rollback/CLI suite passes
108/108 across 3 files. The full unit suite passes 268/268 across 19 files;
typecheck, Node syntax, Wrangler generated-types check, 23/23 database cases,
19/19 mounted-route cases, and mutation coverage (36/23/13 tables plus 5/2
writers) pass. The production dry-run passes at 1534.77 KiB, gzip 277.07 KiB.
The focused Swift
collection-cursor suite passes 5/5 on the iPhone 15 Pro Max/iOS 18.5 simulator.
The fresh full iOS target passes 76 XCTest plus 18 Swift Testing cases (94/94)
on iPhone 15 Pro Max/iOS 17.0.1. A broad Xcode 27 beta/iOS 18.5 run repeatedly
hits an allocator double-free in 15 unrelated legacy cases while the affected
cursor suite remains green; this is a bounded tool/runtime incompatibility,
neither a product pass nor failure.

The generic Release simulator build succeeds, but reads back
`CFBundleIdentifier=.RefWatch`,
localhost backend, `pk_test_local_placeholder`, and no
`CLERK_FRONTEND_API_HOST` plist entry. It is not production
Release-configuration acceptance. The current preparation-batch actual-value
scan finds zero hits in 10,269 repo-root files using the one locally available
fingerprint, and its thirteen changed files pass fully redacted Gitleaks 8.30.1.
The older route-batch snapshots remain 10,259 repo files, 569 files across the
Release app plus three test-result bundles, and zero leaks in the exact
511,420-byte tracked plus 337,624-byte enumerated untracked Gitleaks corpus.
`.projects` and unavailable production fingerprints remain outside every
claim. Those are historical preparation/route receipts. The preceding July 20
v2 Gitleaks 8.30.1 receipt scanned exactly 83 then-current modified/untracked
files with full redaction and `.projects` excluded. That count is historical;
beta.3 publish safety is recorded in its release-preparation evidence. See the
active plan's production-preparation evidence.

The production Wrangler dry-run passes at 1532.36 KiB (gzip 276.43 KiB) and
declares `HYPERDRIVE`, D1 `MUTATION_LEDGER`, Queue producer
`MUTATION_LEDGER_QUEUE`, and `CF_VERSION_METADATA`, with no cron or Queue
consumer and writes/onboarding disabled. It now binds exact prepared role
`hvk7iheytj62` and Hyperdrive `920ca5b108034b2bb8700cf0201ac55f`; the
provisioning helper separately proved effective read/write data privileges
without administrative capability. The deployed Worker has not received this
configuration, so the dry-run remains build/configuration proof rather than
deployed runtime acceptance. Exact preparation receipts and that batch's closed
mandatory review trail are recorded in the active plan evidence. The active v2
contract's mandatory reviewers also returned final `NO FINDINGS`. These checks still do not satisfy
deployed Clerk, traffic, production Release configuration, or physical-device
acceptance.

Before bounded acceptance writes, validate the exact nested destructive
rollback packet and collect the staged launch packet's provider readbacks. The
complete `greenfield_launch_v2` packet is the final closeout gate and cannot
pass until B has been promoted at 100% with no competitor, the real Clerk
provider webhook receipt and zero-count cleanup have completed, Access has
been provider-proved removed, physical-device and Release receipts have
exercised promoted B, production acceptance follows those receipts, observation
completes, and the final ledger/consumer readback remains inactive/zero. Its
final validation must prove:

- the exact authorization digest, production Clerk instance/domain/issuer, and
  production Worker/environment;
- reviewed schema plus deterministic seed, zero legacy mappings, zero app users
  and user-owned rows before bootstrap, zero preparing/open/capture-enforced
  ledger epochs, and zero Queue/cron/D1 consumers;
- distinct disabled candidate, accepted candidate, emergency write-guard, and
  last-known-good Worker IDs, with packet-carried provider readbacks, exact
  approved bindings, A/B code/stable-binding lineage, exact digest-checked
  S→A→B non-echoing secret inheritance, and canonical before/after G/L
  deployment readbacks inside the rollback window, completed by validation,
  ordered G-after < L-before, on the same initial route with unique receipts,
  before restored A=100%/B=0%;
- bounded health, invalid/missing bearer, `/api/me`, zero-legacy onboarding,
  tenant isolation, owner-spoof, CRUD/idempotency, tombstone, assistant,
  match-sheet, `manual_signed_harness` webhook lifecycle with exact
  override/token header names/presence and valid/invalid signature outcomes, and
  `write_round_trip` acceptance;
- bounded B access only through the version override, Cloudflare Access
  `service_auth` policy with one service token/zero bypass, and server-only
  cutover token gate;
- exact B=100% promotion with no competing version followed, while Access
  remains active, by real Clerk-provider webhook delivery without
  override/token headers: exactly three subscriptions, signature/create/update/
  delete/retry/delete-wins proof, and cleanup to zero test identity/application
  rows; then provider-bound Access removal before deployment history/devices,
  with no Workers.dev/preview exposure;
- iOS sign-in/backend identity, offline backlog, logout/user switching, and
  available iPhone 15 Pro Max/Apple Watch Series 9 (45mm) acceptance against
  promoted B;
- explicit traffic/onboarding/write configuration and a monitored cutover
  result followed by the final inactive-ledger/zero-consumer readback; and
- the exact validated standalone rollback packet/digest/window/thresholds/
  probes/client for destructive stop/guard/version rollback plus PlanetScale
  reset/reseed and identity recreation.

`WRITE_MODE=disabled` blocks API/webhook mutations while keeping health and
reads available. Do not enable it until the bootstrap receipt and bounded
acceptance state agree. Never record credential values in arguments, logs,
evidence, or chat. Do not commit or publish without a separate request.

### Historical/future stateful migration validators

For a future live migration that must preserve users/data, validate the
encrypted Supabase export and reviewed identity map with `npm run
cutover:validate` and the encrypted bundle, detached manifest, provider/
ledger-quiescence receipts, and artifact-creator receipt. Its inherited
`CUTOVER_*` key/hash values remain secret-manager inputs. The validator's
39-table, auth-identity, legacy exclusion, dependency, integrity, file-policy,
and AES-256-GCM checks remain unchanged; passing it does not apply data.

Likewise,
`npm run rollback:validate -- ../.cutover/rollback-packet.json` accepts explicit
`stateful_migration_v1`, `greenfield_destructive_v1`, and
`greenfield_destructive_v2` profiles. For historical compatibility only, a
profile-less packet is interpreted as `stateful_migration_v1`; an explicitly
unknown profile fails. The stateful profile still requires a provider-proved
external write ledger and distributable recovery client. Greenfield v1 remains
accepted as historical tooling; active closeout uses v2 with four distinct
A/B/G/L IDs and both guard/LKG probe receipts. Legacy
export/mapping/ledger requirements are not silently weakened and do not gate
the explicit greenfield destructive profile.

Legacy Supabase edge functions and migrations under
`../RefWatchiOS/Core/Platform/Supabase/` remain read-only contract references
until their portable behavior is verified in the Worker/PlanetScale path.
Their historical data-preservation role is not a launch gate; remove obsolete
compatibility code and source credentials only in a reviewed cleanup batch.
