# Backend Migration and Cutover

This runbook governs the migration from Supabase to Clerk authentication, the Cloudflare Workers/Hono API in `api/`, and PlanetScale Postgres. It separates repository implementation from provider operations so local code is never mistaken for a completed production cutover.

## Current status

As of 2026-07-17, with provider and test evidence dated as identified in the active plan:

- Clerk + Cloudflare Workers/Hono + PlanetScale Postgres is the active target architecture.
- The Worker workspace, Drizzle target schema, Clerk/identity implementation, and backend client/repository adapters exist in the repository.
- Production foundation approval was exercised on 2026-07-15. PlanetScale `main` accepted all 16 migrations and reads back 35 public tables, exact 5/54 global catalog seed, 22 mutation-capture plus 6 guard triggers, zero app users, and zero mutation events. Production uses restricted roles and cache-disabled Hyperdrive.
- Worker `refwatch-api` version `e966d6df-b5ff-4288-832c-c8d91e00ce48` is deployed with writes/onboarding disabled, workers.dev and preview URLs disabled by production configuration/control-plane, and no public route. It securely holds the production Clerk publishable/secret keys and `OPENAI_API_KEY`; its issuer/publishable-key pins now match verified `refwatch.ibby.ai`. Localhost production-config probes using the exact read-only runtime role prove database-pin readiness 200 and API/webhook write denial 503; Hyperdrive is separately control-plane verified. Recoverable ledger-key custody is blocked at the source; source remediation, escrow storage, functional recovery, production ledger activation/probe, remaining Clerk setup, final import, identities, traffic, and writes remain incomplete.
- Ledger-key escrow preflight is blocked. The production Worker ledger-secret name exists but its value is non-readable; the exact local Keychain record audited on 2026-07-17 has an empty payload. Cloudflare Secrets Store account/store/edit-permission metadata passed, but no secret was created. Source-custody remediation, stored escrow, functional recovery through a separately approved binding/procedure, and production ledger activation/probe are four distinct gates.
- An isolated Worker/Hyperdrive/PlanetScale/Queue/D1/DLQ rehearsal proved transactional PlanetScale capture with asynchronous idempotent Queue-to-D1 materialization, encrypted replay into two disposable same-contract PostgreSQL targets with zero missing events, and generation-bound poison quarantine plus a retained DLQ receipt. Neither restore target was Supabase, and no production reverse-import procedure is proved. The rehearsal does not satisfy the production ledger or rollback gate.
- Stripe Projects exposes production-capable Clerk resource `clerk-auth-2`; its live production instance now uses verified owned secondary domain `refwatch.ibby.ai`. Stripe Projects metadata may still show historical `production_domain: auth.refwatch.com`; live Clerk Backend API/CLI readback is authoritative, and the managed resource must not be recreated or removed merely to align that metadata. DNS, SSL, and email DNS are complete. Native iOS registration/configuration, Google OAuth, signed webhook, and account-to-internal-user mapping are not complete.
- Root `MIGRATION_OPERATOR_ACTIONS.html` records the replacement-domain and Clerk-access actions complete and now exposes one immediate, non-secret ledger-key recovery-path decision. `CLERK_DASHBOARD_ACTIONS.html` separates later native-app/OAuth/webhook phases. Source remediation, escrow storage, functional recovery, ledger activation/probe, and physical-device availability remain separate gates. Neither page authorizes additional production mutation.
- The active iOS composition builds and routes matches, schedules, journal, teams, competitions, venues, authenticated reference-catalog reads, assistant, and match-sheet parsing through backend adapters without Supabase config.
- Reference-catalog schema/routes and the portable 2026 seed are ported; rehearsal provider readback confirmed 5 competitions and 54 teams.
- The Supabase SDK/package dependency is removed. Simulator iOS/watch acceptance is recorded; physical-device acceptance remains pending because both connected targets were offline during the latest audit. Cleanup of legacy Supabase-named compatibility repositories/types/source paths is not complete.
- Supabase files remain legacy migration/contract evidence and compiled compatibility debt; their presence does not make Supabase the active runtime architecture.
- A sanitized candidate transaction at `2026-07-15T05:48:29.596939Z` revalidated the exact 39-table/1,106-row count and digest contract, schema/RLS hashes, 43 Auth users, 42 profiles, and the approved one-user auth-only discrepancy. It is not final or importable: writes were not quiesced and no direct encrypted row export was captured.

## Approved production decisions

At `2026-07-15T01:32:05Z`, the user approved both then-required decisions:

1. Clerk production domain: `auth.refwatch.com`. The user later confirmed they did not own that domain, so the decision and records were retired unexercised. On 2026-07-17, the user separately selected and authorized owned secondary application domain `refwatch.ibby.ai`; its exact five DNS-only CNAMEs, certificates, and Worker publishable-key/issuer refresh are complete.
2. For the preliminary auth-only identity `testing@refwatch.com`, record
   `action: "exclude"` as
   the immediate final cutover-bundle disposition, omit it from the target Clerk mapping/import,
   create no empty `app_users` row or ownership UUID, preserve it in Supabase
   through the rollback/observation window, and perform archival only as a
   separate source-lifecycle action after that window. Do not record the current
   validator disposition as `archive`, and do not archive the source identity
   during migration or rollback preservation.

The later root-HTML Actions 1 and 2 were approved for bounded foundation work.
Action 1's safe foundation scope is applied/consumed. Recoverable source
remediation, Secrets Store escrow, functional recovery, and functional
production ledger activation/probe remain separately gated. Action
2 did not mutate the old Clerk domain or DNS and its `auth.refwatch.com` scope
is retired unexercised; the separately authorized `refwatch.ibby.ai` domain/key
batch is applied/consumed. Neither authorizes identity/data/traffic cutover,
ledger activation, onboarding, or write enablement.
Before applying the second decision, the final repeatable-read source snapshot must
confirm that the same exact auth identity remains the sole auth-only identity
and has no profile or owned data.

Proceed only in the runbook's ordered stages and preserve each independent
provider, source-snapshot, mapping, ledger, rollback, migration, deployment,
reconciliation, and acceptance gate. An approval or read-only status refresh is
never production acceptance.

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

1. Preserve production resource `clerk-auth-2` and development-only `clerk-auth`. The invalid `auth.refwatch.com` records remain retired. Production now uses verified owned secondary domain `refwatch.ibby.ai`; its exact five DNS-only CNAMEs are applied and Clerk reports DNS, SSL, and email DNS complete with zero pending records.
2. Worker `CLERK_ISSUER` and `CLERK_PUBLISHABLE_KEY` are coordinated with `https://clerk.refwatch.ibby.ai`. Install the same public host/key in iOS only after a local `Secrets.xcconfig` or release configuration exists. Register the iOS app only after the Apple App ID Prefix and signed Bundle ID are authoritatively resolved; the repository's unresolved `$(BUNDLE_ID_PREFIX).RefWatch` expression is not sufficient evidence.
3. Put only public app configuration in `RefWatchiOS/Config/Secrets.xcconfig`:
   `BACKEND_API_BASE_URL`, the Clerk publishable key, and the Frontend API host.
   Do not create or populate that local/release file until the native lane and
   configuration destination are explicitly approved.
4. Store `CLERK_SECRET_KEY` and `CLERK_PUBLISHABLE_KEY` in the Worker environment. `CLERK_JWT_KEY` is optional for networkless verification; Clerk secret-key verification works without it.
5. Webhook endpoint creation, a write-disabled routing/guard probe, and later
   signature/provenance plus lifecycle acceptance are separately approved
   stages. After an
   exact reachable HTTPS Worker endpoint is approved, create only the production
   instance endpoint for `user.created`, `user.updated`, and `user.deleted`, and
   stream `CLERK_WEBHOOK_SIGNING_SECRET` through a non-echoing Wrangler path.
   Do not send a sample until the reviewed non-mutating probe is ready; with
   `WRITE_MODE=disabled`, it must return the documented retryable denial and
   mutate no identity. Because the write gate runs before the webhook handler,
   that 503 proves routing and write denial only; it does not prove signature or
   production-instance provenance.
6. Reconcile and import every Clerk-to-internal-user mapping before accepting
   lifecycle processing. This ordering prevents a pre-mapping deletion event
   from being acknowledged without a target row. A later reviewed test must
   separately prove invalid webhook signatures and the exact production-instance
   signing-secret provenance before lifecycle acceptance. Prove invalid/missing
   bearer tokens before enabling production traffic.
7. For later approved Google OAuth/API work, use the installed `gcloud` CLI for
   Google Cloud/API configuration and the installed `gws` CLI only for Google
   Workspace operations. Keep credentials in their approved custody path and
   never print, export, or paste them into chat or evidence.

## PlanetScale and Hyperdrive setup

1. Use PlanetScale Postgres database `refwatch`. Production `main` now contains only the approved 16-migration schema and exact 5/54 global seed; it has no app users or imported application data. Final source import remains separately gated.
2. Create separate least-privilege runtime and migration credentials.
3. Use the migration-role `DATABASE_URL` only with Drizzle tooling:

   ```sh
   cd api
   DATABASE_URL='postgresql://...' npm run db:migrate
   ```

4. Read back tables, columns, constraints, indexes, functions, enums, migration rows, triggers, and privileges on each disposable branch. On 2026-07-15, the dedicated ledger branch had all 16 migrations, 35 public tables, 22 effective capture triggers, and three ledger-protection triggers; every completed rehearsal epoch was archived with capture enforcement disabled. The original reference-data branch retains the unchanged 5/54/30/3/20 reference counts.
5. Staging uses Hyperdrive configuration `refwatch-planetscale-rehearsal-20260714`. Production foundation uses cache-disabled Hyperdrive `5345de83edfa40b790d5b26df32f56ab` and read-only role `vaqg84rqoedz`; narrowly scoped writes require later approval.
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
until the later write-enablement approval.

Use `wrangler secret put DATABASE_URL` only for an explicitly approved direct-runtime fallback. Production should use Hyperdrive. Run `wrangler deploy --dry-run --env staging` before `wrangler deploy --env staging`; use a separate production environment when approved. Record version, bindings, `/health`, `/health/ready`, and authenticated route evidence. Staging connectivity evidence is recorded in `docs/exec-plans/active/backend-platform-migration/evidence/2026-07-14-staging-worker.md`.

## Data and identity migration

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
5. Apply the bundled idempotent seed, which inserts `reference_competitions` before `reference_teams`, then verify the authenticated catalog routes return 5 competitions and 54 teams for 2026. These rows are global read-only reference data, not user-owned rows. If live provider evidence differs, review and import that evidence rather than silently overwriting it with repository assumptions.
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

### Post-reconciliation new-user gate

Legacy users must be mapped before production traffic. The final cutover-bundle
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
Clerk SDK's verified webhook event has no instance-ID field, so webhook
provenance is bound operationally: create the endpoint in the reviewed
production instance, install only that endpoint's signing secret, record the
provider receipt, and require `CLERK_INSTANCE_ID` before processing. The
deprecated `ALLOW_UNMAPPED_CLERK_USERS` variable does not open this production
path.

## Staging and production gates

Do not route production traffic until all gates have evidence:

Only the staging Worker→Hyperdrive→database connectivity portion is currently
satisfied. It does not satisfy any authenticated or user-flow gate below.

- API typecheck, Workers-runtime tests, database-backed owner/isolation tests, and deploy dry-run pass.
- Match ingest is transactional and concurrency-safe for `Idempotency-Key`.
- Every foreign reference and mutation is tenant-scoped.
- Incremental sync propagates deletions or has a documented reconciliation protocol.
- Clerk deletion/webhook ordering cannot silently restore a deleted account.
- Unmapped Clerk subjects fail closed until the exact reviewed legacy registry
  receives a durable activation row; afterward, only non-legacy,
  non-tombstoned post-reconciliation subjects are eligible.
  `ALLOW_UNMAPPED_CLERK_USERS` never authorizes the production path.
- Assistant and match-sheet routes keep the OpenAI key server-side, enforce bounded usage, and preserve existing response contracts.
- iOS signs in with Clerk, resolves `/api/me`, and sends a bearer token to the Worker.
- Offline SwiftData save/backlog and logout/user-switch cleanup pass.
- iOS build/tests and RefWatchCore/watchOS regression checks pass on the required destinations when available.
- No Supabase, database, Clerk secret, webhook, or OpenAI credential is present in the iOS source, config, bundle, or build logs.

## Cutover and rollback

### Isolated ledger rehearsal procedure

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
recovery strategy.

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

Production foundation version `e966d6df-b5ff-4288-832c-c8d91e00ce48` is already
uploaded with `WRITE_MODE=disabled`, no public/preview URL, and no background
consumers. A later provider-routed guard proof and populated packet remain. Routing 100%
to that recorded version blocks every API and Clerk-webhook mutation with a
retryable 503 while preserving health and reads. Verify the behavior, drain
in-flight requests, freeze/reconcile the ledger, then route to the recorded
last-known-good version. Never improvise a version ID or treat an unavailable
client build as rollback readiness. The transactional ledger is implemented
and provider-proved on isolated resources. Production D1/Queue/DLQ resources
now exist but are inactive. Recoverable source custody is blocked by the empty
Keychain payload; source remediation, Secrets Store escrow, functional recovery,
and the production activation/probe remain separate blockers. Before any production epoch opens, provision
an encrypted access-controlled baseline store, restrict operator/read access,
record immutable artifact hashes, and define retention and verified deletion.
Do not use a plaintext local baseline as production rollback evidence. Reconcile
queued Clerk webhook retries before reopening writes.

The current production ledger-key gate fails before escrow: the named Keychain
record contains no recoverable payload, while the Worker secret value cannot be
read through Wrangler or the dashboard. Do not upload an empty placeholder,
retry from another source, bind a Secrets Store entry, deploy a recovery path,
change the Worker secret/key ID, or rotate until a new exact remediation scope
is reviewed and approved. A future stored Secrets Store entry proves storage
metadata only; functional recovery requires a later non-disclosing binding/use
receipt before any production ledger activation probe.
