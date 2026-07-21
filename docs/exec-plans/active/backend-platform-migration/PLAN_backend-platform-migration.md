# PLAN_backend-platform-migration

## Purpose / Big Picture
Launch RefWatch as a clean greenfield production system on Clerk authentication,
a Cloudflare Workers/Hono API, and PlanetScale Postgres while preserving the
watch-first match runtime and iOS offline SwiftData behavior. Supabase
identities and application rows are disposable and are not migrated. The iOS
app remains an untrusted API client: Clerk session tokens cross the network,
while database, Clerk secret, webhook, and OpenAI credentials remain
server-side.

## Context and Orientation
- Architecture: `ARCHITECTURE.md`, `docs/design-docs/architecture/overview.md`, `docs/design-docs/architecture/ios.md`, `docs/design-docs/architecture/shared-services.md`
- Current database evidence: `docs/generated/db-schema.md` and `RefWatchiOS/Core/Platform/Supabase/migrations/`
- Auth seam: `RefWatchCore/Sources/RefWatchCore/Protocols/AuthenticationProviding.swift`
- Current iOS adapters: `RefWatchiOS/Core/Platform/Auth/`, `RefWatchiOS/Core/Platform/Supabase/`, and `RefWatchiOS/Core/Platform/AI/`
- New Worker workspace: `api/`
- Repository-mandated physical targets are iPhone 15 Pro Max and Apple Watch Series 9 (45mm). Automated evidence uses same-model iPhone 15 Pro Max and Series 9 (45mm) simulators on the available stable runtimes recorded below.

## 2026-07-20 Greenfield Cutover Override

The append-only authorization in
`evidence/2026-07-20-greenfield-cutover-authorization.md` is authoritative for
the active launch:

- Historical Supabase totals of 43 Auth users, 42 public profiles, and 1,106
  application rows remain point-in-time facts, but all are disposable.
  `testing@refwatch.com` has no separate exclusion or preservation gate.
- No legacy identity map, Clerk import, final Supabase row export, or
  source-to-target row reconciliation is required.
- The target begins with zero `app_users`, zero legacy mappings, and zero
  user-owned application rows. Schema/control rows and the complete
  deterministic global reference seed from reviewed repository sources are
  classified separately and retained.
- A database-enforced `greenfield_zero_legacy_v1` receipt must bind the exact
  authorization digest and production Clerk provenance before genuinely new
  Clerk subjects may receive server-generated internal UUIDs.
- Ledger escrow, recovery, and production activation are deferred and
  non-blocking. Launch requires zero preparing, open, or capture-enforced
  production epochs and zero Queue, cron, or D1 consumers; the existence of
  frozen/archived history or provisioned inactive resources is not evidence of
  an active ledger.
- Destructive stop/guard/reset/reseed/recreate recovery is accepted for the
  initial launch.
- Provider cutover operations are authorized, but authorization is not
  completion. Each provider transition requires sanitized readback evidence and
  both mandatory review roles to return no findings.
- Secrets remain non-disclosing. Commits and publishing are outside scope.

## Plan of Work
1. Establish a PlanetScale Postgres/Hyperdrive Worker foundation and port the canonical data model into Drizzle migrations.
2. Add Clerk bearer authentication, internal user resolution, independently verified Clerk webhooks, owner-scoped CRUD/sync routes, and the two OpenAI-backed routes.
3. Introduce vendor-neutral Swift auth/token/identity seams and a typed backend client, then move repositories behind those seams without changing watch match lifecycle logic.
4. Replace the active iOS auth UI/composition with Clerk, remove compiled Supabase dependencies, update setup/architecture documentation, and verify API/iOS/watch regressions.
5. Bootstrap a clean production target from reviewed schema/reference seeds,
   validate it with an explicit greenfield launch profile, complete bounded
   provider acceptance, cut traffic, and then retire disposable Supabase state.
   Preserve the stateful export/import validators as historical or future
   live-migration tooling.

## Concrete Steps
- `TASK_01_worker-api.md`: Worker, schema, auth, routes, tests.
- `TASK_02_swift-client.md`: Clerk auth, backend client, repository migration, tests.
- `TASK_03_docs-cutover.md`: dependency cleanup, documentation, provider runbook, verification.

## Progress
- [x] Planning critique completed by code-risk and docs/evidence reviewers.
- [x] PlanetScale Postgres + cache-disabled Hyperdrive selected for the deployed Worker; direct `DATABASE_URL` reserved for Drizzle migrations/local tooling.
- [x] Greenfield authorization — the 2026-07-20 operator override makes all
  historical source identities and rows disposable, removes the
  `testing@refwatch.com` and 42-user mapping gates, accepts destructive recovery,
  and authorizes the remaining provider cutover without authorizing commits or
  publishing. The completed `refwatch.ibby.ai` domain lane remains unchanged.
- [x] Production foundation application — Action 1's bounded infrastructure scope is applied/consumed: all 16 migrations, the exact 5/54 seed, read-only roles, Hyperdrive, inactive Queue/DLQ/D1 resources, the production Worker secret name, and the unrouted write-disabled Worker exist. The Worker secret value is non-readable. A 2026-07-17 audit found that the named local Keychain record has an empty payload, so recoverable local key custody is not proved and is not part of this completion claim. The separately authorized owned Clerk replacement-domain batch is also applied/consumed in Worker version `e966d6df-b5ff-4288-832c-c8d91e00ce48`; DNS, SSL, and email DNS verify complete. Action 2's old `auth.refwatch.com` scope remains retired unexercised.
- [x] Production ledger launch decision — escrow, recovery, and activation are
  deferred and non-blocking. The failed 2026-07-17 escrow audit remains intact.
  Production capture must remain inactive; destructive reset/reseed/recreate is
  the accepted initial recovery path.
- [x] Fresh production read-only baseline review closeout — authenticated
  2026-07-20
  PlanetScale, Cloudflare, Clerk, Apple, and operator-page inventories are
  recorded in
  `evidence/2026-07-20-production-greenfield-baseline.md`. At that baseline,
  production PlanetScale was clean, had the exact reviewed 5/54 seed and no
  active ledger, and was at 16 migrations through `0015`; the checked-in target
  was 17 through `0016`. PlanetScale MCP exposes distinct read/write tools and
  authenticated ephemeral `pscale` readwriter/admin access is available; only
  the two durable roles and current Hyperdrive are read-only. The current
  Worker remains unexposed and write/onboarding-disabled, production Clerk has
  zero users, and no application data or durable provider
  configuration/credential mutation occurred. Provider-issued temporary
  MCP/CLI access roles are classified separately. No operator approval is
  pending. The exact `0015` schema/owner/26-category/seed/ledger payload is now
  reproducible from a hashed standalone read-only query. The exact-head atomic
  migration helper and failure-atomic writable role/Hyperdrive helper pass
  local verification; both mandatory final reviewers returned `NO FINDINGS`.
  These reviewed helpers were ready for provider preparation but were not
  executed as part of the baseline; the following preparation item records
  their later execution.
- [x] Production greenfield target preparation — provider execution completed
  under the reviewed helpers while writes/onboarding stayed disabled.
  Production now reads back migration `0016`/17, the exact reviewed 36-table
  catalog with Postgres ownership, zero rows in all 27 target categories, the
  unchanged 5/54 deterministic seed, and no active ledger. Durable
  read/write-data role `hvk7iheytj62` and paired TLS-required/cache-disabled
  Hyperdrive `920ca5b108034b2bb8700cf0201ac55f` were created, and
  `api/wrangler.jsonc` binds both together for the next candidate. Typecheck,
  223 unit, 22 database, 19 mounted-route, and production dry-run checks pass;
  the currently deployed Worker remains unchanged on the old read-only path.
  Every review finding was applied and both mandatory final reviewers returned
  `NO FINDINGS`.
- [ ] Clerk production setup — partial and fully authorized: production
  instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac` uses verified domain
  `refwatch.ibby.ai`, with issuer `https://clerk.refwatch.ibby.ai`. DNS, SSL,
  email DNS, Worker issuer/publishable-key coordination, and the exact Apple
  production identity (`6NV7X5BLU7` /
  `com.IbrahimSaidi.RefWatch` /
  `com.IbrahimSaidi.RefWatch://callback`) are resolved and must not be
  repeated. Native registration state was not authoritatively enumerated;
  release public configuration, Apple/Google OAuth, and the signed lifecycle
  webhook remain to be completed and evidenced.
- [ ] `TASK_01_worker-api.md` — partial: the explicit authorization-bound
  zero-legacy receipt/profile, locked idempotent lifecycle processing, and
  inactive-ledger transaction proof are implemented locally. The explicit
  historical `greenfield_launch_v1` validator and
  `greenfield_destructive_v1` rollback profile were implemented and reviewed.
  The active v2 immutable-version correction is implemented locally; both
  mandatory reviewers returned final `NO FINDINGS`. Typecheck, 108/108 focused launch/rollback/CLI cases
  across 3 files (including promoted-webhook adversarial tests), 268/268
  unit tests across 19 files including runtime-gate/public-route coverage,
  23/23 hermetic database cases across 3 files, 19/19 mounted routes in 1 file,
  36/23/13 mutation coverage, Drizzle
  convergence, and the production Wrangler dry-run pass.
  Production migration `0016` and the dedicated durable read/write-data
  role/Hyperdrive pair are now prepared; the dry-run declares that new pair,
  D1, a Queue producer, and version metadata with no cron/Queue consumer and
  both mutation modes disabled. The local
  route batch covers greenfield onboarding, owner/ref isolation, CRUD,
  idempotency/concurrency, tombstones, stubbed AI routes, inactive-ledger
  behavior, and monotonic collection versions. Both mandatory
  provider-preparation reviewers returned `NO FINDINGS`. Remaining work
  includes digest-checked A/B readbacks, canonical before/after G/L deployment
  readbacks bracketing their probes,
  final A=100%/B=0% public disabled proof, protected override-only B automation
  with one-token/zero-bypass Access, manually signed bounded webhook lifecycle,
  exact rollback validation, B=100% promotion, real Clerk-provider
  three-subscription lifecycle/zero-count cleanup while Access remains active,
  then provider-bound Access removal before deployment history/device exercise,
  post-device production acceptance, and the final inactive-ledger/
  zero-consumer readback. No
  final export/import or legacy registry activation is required.
- [ ] `TASK_02_swift-client.md` — partial: active composition routes cloud
  features through Clerk/BackendAPIClient adapters; unresolved startup auth no
  longer triggers a false logout, and backend identity persists offline while
  revalidating online. Collection sync now uses pull-only cursors, full
  tombstone reconciliation on first/relaunch, inclusive server replay with a
  15-minute client overlap, and strict-newer/dirty-local merge protection; the
  focused cursor suite passes 5/5 on the iPhone 15 Pro Max/iOS 18.5 simulator.
  The fresh full `RefWatchiOSTests` receipt passes 76 XCTest plus 18 Swift
  Testing cases (94/94) on iPhone 15 Pro Max/iOS 17.0.1. A broad Xcode 27
  beta/iOS 18.5 run repeatably aborts with an allocator double-free in 15
  unrelated legacy cases; this is a bounded tool/runtime incompatibility,
  neither a product pass nor failure. The current generic Release simulator
  build succeeds but reads back `CFBundleIdentifier=.RefWatch`, no team,
  localhost backend, a test Clerk key, `clerk.localhost`, and no callback URL
  scheme, so production Release-configuration acceptance remains open.
  Historical iOS UI, watch, and embedded-plist receipts remain point-in-time
  evidence. Physical-device evidence and Supabase-named compatibility cleanup
  remain.
- [ ] `TASK_03_docs-cutover.md` — partial: the greenfield authorization,
  supersession, local zero-legacy identity proof, and code-reviewed staged
  launch/rollback validators are recorded. The reviewed 19-case local
  route/cursor/inactive-ledger proof and fresh production read-only provider
  baseline are also recorded. Executed migration/runtime preparation and exact
  post-preparation receipts are recorded and both mandatory reviewers returned
  `NO FINDINGS`. Active v2 documentation now records packet-carried sanitized
  readbacks, bracketed fallback probes before final A proof, the protected A/B
  lane, bounded manually signed webhook versus promoted provider delivery,
  exact nested rollback, post-provider Access removal, promotion-before-device
  chronology, receipt uniqueness, and final ledger readback; both current v2
  mandatory reviewers returned final `NO FINDINGS`. Remaining work is provider/deployed receipts,
  physical acceptance against promoted B, observed traffic, and post-acceptance
  compatibility/Supabase cleanup.

## Historical Findings and Current Discoveries

Items dated before 2026-07-20 remain point-in-time technical evidence. Any
identity/data preservation requirement in them is superseded by the greenfield
override above.

- The live Supabase MCP readback on 2026-07-14 found that `public.users` has an internal UUID `id` but no `clerk_user_id`. The then-required identity mapping/backfill is no longer a launch requirement; new internal UUIDs remain server-generated.
- The single-statement source snapshot inventories all 39 public tables. Core counts are `matches=62`, `match_periods=119`, `match_events=579`, and `match_metrics=62`; Supabase Auth has 43 identities while `public.users` has 42 profiles.
- A new `2026-07-15T05:48:29.596939Z` candidate transaction re-observed the exact 39-table catalog and unchanged 1,106-row count map under `REPEATABLE READ, READ ONLY`, with server-side per-table data hashes, schema/RLS hashes, 43 Auth users, 42 profiles, 44 Auth identities, and one approved auth-only identity with zero owned rows. It is explicitly non-importable because writes were not quiesced and no direct encrypted row export exists.
- A later read-only Auth migration audit found 13 `$2a$` bcrypt users and 30 users without password digests, plus 22 Apple, 13 email, and 9 Google identities. Every identity email matched its normalized Auth-user email and none was missing. The encrypted final-bundle validator fail-closes on non-bcrypt digests, unreviewed providers, Auth-source drift, or an auth-only digest mismatch. Migrated sign-in proof was then pending; it is preserved only for future stateful-migration tooling and is not a greenfield launch gate.
- Nine live public tables have RLS disabled: `match_officials`, `match_assessments`, `trend_snapshots`, `workout_session_metrics`, `workout_intensity_profile`, `workout_segments`, `coaches`, `feedback_attachments`, and `ai_usage_daily`. This remains a live legacy security risk until direct Supabase access is retired or separately remediated.
- Supabase-specific auth types and UUID assumptions extend into connectivity, persistence, previews, and feature views beyond the initially named files.
- The requested Clerk webhook route requires a distinct `CLERK_WEBHOOK_SIGNING_SECRET` and replay/signature verification.
- The fresh 2026-07-20 PlanetScale baseline proves that branch
  `w3g1f8vcbg34` is ready and writable with no provider read-only reason.
  At that pre-preparation baseline, production had 16 migrations through
  `0015` with 35 tables; the reviewed target was 17 through `0016` with 36
  tables. All 26 then-existing
  application/identity/control categories, all ledger states/rows, and all
  Clerk users are zero; the 5/54 seed digests match. PlanetScale MCP's
  temporary reader, its separate write tool, ephemeral `pscale`
  readwriter/admin sessions, and the two durable read-only production roles
  are separate access paths. Those provider-issued temporary roles are
  access-session artifacts, not durable application credentials. No DML or DDL
  or application-data/durable-configuration mutation was used during the
  baseline.
- The fresh 2026-07-20 Cloudflare baseline records current deployment
  `89cff719-0e19-4648-ab09-63a37d806c95` at 100% version
  `e966d6df-b5ff-4288-832c-c8d91e00ce48`, with writes/onboarding disabled,
  no route/custom domain/workers.dev/preview/cron/Queue consumer, and the old
  read-only Hyperdrive still bound. The D1 and Queue resources are provisioned
  but inactive. At that point a new least-privilege writable Hyperdrive and
  distinct candidate/write-guard/last-known-good versions remained required.
- The later 2026-07-20 preparation batch atomically applied `0016`, retained
  the exact 5/54 seed and zero target/ledger state, and provisioned durable
  read/write-data role `hvk7iheytj62` plus Hyperdrive
  `920ca5b108034b2bb8700cf0201ac55f`. Local production config binds that pair
  with writes/onboarding disabled; the deployed Worker is still the unchanged
  baseline version. Preparation review is closed with final `NO FINDINGS`.
- The fresh post-preparation official Clerk SDK readback at
  `2026-07-20T06:43:13.331Z`
  proves exact production-instance provenance and zero users, invitations,
  redirect URLs, and allowed origins. It does not enumerate native-app or
  webhook endpoint/subscription state. The missing Worker webhook secret is
  not evidence that no Clerk endpoint exists. Public social configuration is
  empty.
- API remediation fixed the reviewed ownership, serialization, idempotency,
  deletion, parser, streaming, event-reference, emergency-write, onboarding,
  rollback-ledger, encrypted Auth-source, greenfield-promotion, collection
  versioning, and cursor risks. Its pre-greenfield checkpoint passed typecheck
  and 93 tests across 14 files; the current remediated-v2 aggregate passes
  108/108 focused launch/rollback/CLI cases across 3 files and 268/268 unit tests
  across 19 files, including runtime-gate/public-route coverage. Fresh
  verification also passes 23/23 hermetic database cases across 3 files,
  19/19 mounted-route cases in 1 file and typecheck. The local matrix covers all requested route families with
  strict upstream stubs and no provider calls. The 19/19 real-Postgres provider
  result is preserved as
  2026-07-15 historical evidence and was not rerun after the later route
  changes. Localhost production-config/runtime-role readiness and write denial
  pass, with separate Hyperdrive control-plane readback; deployed
  Worker/Hyperdrive/authenticated behavior remains unproved.
- The write gate now fails closed unless `WRITE_MODE` is explicitly `enabled`; the default development Worker is isolated as `refwatch-api-development`, while production remains `refwatch-api` with writes disabled. Team, competition, venue, and scheduled-match conflict updates enforce ownership atomically, and per-request `pg.Client` queries are sequential to avoid the deprecated concurrent-query path. These are local code/readiness improvements, not a provider deployment.
- The active iOS app now builds and routes matches, schedules, journal, teams,
  competitions, venues, reference-catalog reads, assistant, and match-sheet
  parsing through `BackendAPIClient`; the Supabase SDK/package dependency is
  removed. Collection repositories advance cursors only from completed pulls,
  start each lifetime at an epoch floor for tombstones, overlap later pulls by
  15 minutes, and protect dirty/equal-or-older local state. The focused cursor
  suite passes 5/5 on an iPhone 15 Pro Max/iOS 18.5 simulator, and the fresh
  full iOS suite passes 94/94 on iOS 17.0.1. The current generic Release build
  still contains local placeholder configuration and is not production
  acceptance. Production reference-catalog schema/seed readback passed;
  deployed authenticated proof, physical iPhone/watch acceptance, and legacy
  Supabase-named compatibility repositories/types/source paths remain
  unfinished.
- Reference catalog data is global and read-only, but its Worker endpoints remain authenticated. User-owned team/competition materialization continues through owner-derived backend repository routes; the client never supplies an authoritative owner ID.
- PlanetScale branch `cutover-rehearsal-20260714` accepted the complete ten-migration set. Provider readback found 30 public tables and all three identity validation/immutability triggers; control tables were empty after tests and reference counts remained 5/54/30/3/20. This historical rehearsal statement is superseded for foundation status by the approved 16-migration production apply and exact 5/54 production readback recorded on 2026-07-15.
- Dedicated branch `ledger-rehearsal-20260715` (`ng9tgmy4pyi5`) accepted 16 migrations, including approved migration `0015` at SHA-256 `6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a`. Final rehearsal Worker `b745554c-a4e7-4d58-90f8-36bdedd94e7d` proved exact PostgreSQL/D1 delivery, restricted-reader verification, encrypted replay into two local same-contract PostgreSQL targets with zero missing/mismatched events, generation-bound poison quarantine, three retained DLQ receipts, and four expected-failure D1 immutability checks. All 19 epochs are archived, no lease is active, and integration-only pending/expired rows are explicitly classified. This is isolated evidence, not production acceptance or Supabase reverse-import proof.
- Auth state now distinguishes unresolved startup from confirmed logout, preventing cold-launch local-data deletion. The resolved Clerk-subject/app-user pair is cached for offline launches, revalidated online, and removed on invalidation.
- Staging Worker version `527852d7-8ec8-48c4-b4d0-c521a3308558` reaches the disposable PlanetScale branch through Hyperdrive and passes `select 1` readiness. This is connectivity evidence only; production and the deployed authenticated route matrix remain pending.
- Match-event team/team-member references now round-trip through Core, iOS
  adapters, and Worker ingest/read contracts. Validation batches ownership
  lookups, normalizes UUID case, bounds events to 500 (source maximum observed:
  23), and restricts references to participating active teams. The local
  mounted database matrix proves full-bundle transport and retained-member link
  preservation; deployed authenticated proof remains a gate, but final source
  reconciliation does not.
- The 30 disciplinary codes, three disciplinary rules, and 20 creator-free workout presets were imported into the isolated rehearsal branch with exact ordered-row hashes matching Supabase. The seeded 5/54 competition/team business columns also hash-match. This is not the final repeatable-read import.
- A repository validator rejects any stateful cutover bundle without independently verified encrypted artifact and provider/ledger receipt files, explicit arrays/counts/table-specific dispositions for all 39 source tables, a read-only repeatable-read boundary, the exact source Auth ID set, the exact approved auth-only exclusion and reviewed Clerk/app-user mappings, a dependency-complete plan for every verified import table, and owner/foreign-key integrity. Any previously empty table without a verified import contract hard-blocks that stateful cutover if it becomes non-empty. Mixed global/user workout presets require exact, non-overlapping seed/import row partitions. The final bundle/import were then pending; this validator is now historical/future tooling only.
- Rollback control preparation has an executable write gate and bounded legacy
  packet validator. Fresh 2026-07-20 readback confirms production foundation
  version `e966d6df-b5ff-4288-832c-c8d91e00ce48` remains unexposed and
  write-disabled with the verified `refwatch.ibby.ai` pins and inactive ledger
  resources. The active greenfield contract requires distinct A/B/G/L IDs,
  digest-checked sanitized A/B provider readbacks with validator-recomputed
  exact binding lineage, public A=100%/B=0% disabled proof, protected
  override-only B automation with an exact Access `service_auth` receipt,
  canonical before/after provider readbacks bracketing temporary 100% G/L
  probes before final A proof, an exact nested standalone rollback packet, and
  a manually signed bounded webhook check. B=100% promotion is followed by
  real Clerk-provider lifecycle/cleanup while Access remains active, then
  provider-bound Access removal before deployment history/device exercise,
  post-device production acceptance, and a final
  inactive-ledger/zero-consumer readback. Ledger recovery is not a gate.
- Full RefWatchCore verification is green after correcting two stale test fixtures without changing runtime behavior: 111 XCTest tests executed with 110 passed and 1 explicit skip, and 5 Swift Testing tests passed.
- Fresh route-batch Apple verification passes the full `RefWatchiOSTests`
  target with 76 XCTest plus 18 Swift Testing cases (94/94) on iPhone 15 Pro
  Max/iOS 17.0.1, plus the affected cursor suite 5/5 on iOS 18.5. A broad
  Xcode 27 beta/iOS 18.5 run repeatably aborts in 15 unrelated legacy cases
  with an allocator double-free and is classified as a bounded tool/runtime
  incompatibility, neither a product pass nor failure. The generic Release
  simulator build succeeds, but `CFBundleIdentifier=.RefWatch`, no team,
  localhost backend, a test Clerk key, `clerk.localhost`, and no callback URL
  scheme do not satisfy production configuration acceptance. Historical
  receipts remain: iOS 89/89 and 19 UI pass/2 bounded skips, watch 11/11 UI and
  107 pass/4 simulator-host skips, and the earlier watch/widget version/plist
  checks. Physical iPhone/watch and production Release-configuration acceptance
  remain pending.

## Approved Production Decisions and Application Status
- Clerk production domain: verified owned secondary application domain `refwatch.ibby.ai`; domain change, five DNS-only CNAMEs, certificates, and coordinated Worker key/issuer refresh are complete.
- Superseded preservation decision: the earlier `testing@refwatch.com`
  exclusion/preservation contract and 42-user mapping requirement remain
  historical validator inputs only. All source identities and rows are now
  disposable.
- Authorization scope: the full greenfield provider cutover is authorized.
  Completion still requires ordered evidence and review. Commits and publishing
  remain excluded.

## Decision Log
- Decision: Launch with the `refwatch.greenfield-authorization.v1` /
  `greenfield_zero_legacy_v1` profile and no legacy identity or application-data
  migration.
  Rationale: There are no real production users, active writers, or
  irreplaceable data. A clean target is safer and simpler than preserving
  test-era state.
  Date/Author: 2026-07-20 / User
- Decision: Defer ledger escrow, recovery, and activation for the initial
  launch, and use stop/guard/reset/reseed/recreate as the accepted recovery
  model.
  Rationale: Historical ledger capture is inactive and unnecessary for a
  greenfield launch with disposable state.
  Date/Author: 2026-07-20 / User
- Decision: Authorize all remaining in-scope provider cutover operations while
  keeping secrets non-disclosing and commits/publishing out of scope.
  Rationale: Former approval gates must not interrupt the ordered, reviewed
  cutover.
  Date/Author: 2026-07-20 / User
- Decision: Validate this launch only with explicit
  `greenfield_launch_v1` and `greenfield_destructive_v1` packet profiles while
  preserving `stateful_migration_v1` and profile-less historical rollback
  compatibility.
  Rationale: Greenfield claims require exact schema/seed/clean-state,
  inactive-ledger, acceptance, physical-device, traffic, and destructive
  recovery evidence without weakening future live-migration tooling.
  Date/Author: 2026-07-20 / Codex
- Superseding decision: Use `greenfield_launch_v2` and
  `greenfield_destructive_v2` for the active greenfield closeout while
  retaining v1/stateful compatibility as historical tooling.
  Rationale: Cloudflare bindings are immutable per Worker version; v1
  incorrectly required one version ID to be both write-disabled and
  write-enabled. V2 binds distinct A/B versions through exact sanitized
  provider receipts, equal recomputed script/stable-binding lineage, and an
  approved binding allowlist. Ordinary traffic must stay A=100%/B=0% while a
  protected version override selects B for automation through an exact
  one-token/zero-bypass Access policy; canonical provider readbacks bracket
  temporary G/L deployments/probes before final A proof. Bounded webhook
  lifecycle is manually signed, not provider proof. B is promoted, real Clerk
  delivery/zero-count cleanup follows while Access remains active, and only
  then is Access removal provider-proved before deployment history/device
  acceptance. The exact nested rollback and final inactive-ledger readback are
  required.
  Date/Author: 2026-07-20 / Codex
- Superseded decision: Use `auth.refwatch.com` as the Clerk production domain.
  Rationale: The user initially approved the recommendation, then confirmed they do not own `refwatch.com`; no old-domain DNS scope was exercised. The separately authorized owned replacement `refwatch.ibby.ai` completed on 2026-07-17.
  Date/Author: 2026-07-15 / User
- Decision: Use owned secondary application domain `refwatch.ibby.ai` for the existing production Clerk instance.
  Rationale: The user selected and authorized the owned replacement; exact DNS-only records, certificates, regenerated Worker publishable key, and issuer coordination completed without identity, data, traffic, onboarding, ledger, or write mutation.
  Date/Author: 2026-07-17 / User
- Superseded decision: Record `action: "exclude"` for the preliminary auth-only `testing@refwatch.com`; create no target mapping or empty app-user row, preserve it through rollback/observation, and archive only after that window as a separate source-lifecycle action.
  Historical rationale: The user explicitly approved preservation without
  inventing a migrated application identity. The then-required final source
  confirmation is no longer applicable under the 2026-07-20 greenfield
  authorization.
  Date/Author: 2026-07-15 / User
- Decision: Use PlanetScale Postgres, Drizzle `pg-core`, and Cloudflare Hyperdrive rather than translating to Vitess/MySQL.
  Rationale: The current schema and atomic match ingest are Postgres-shaped; this minimizes semantic drift and preserves transaction behavior.
  Date/Author: 2026-07-14 / Codex
- Decision: Keep `ClerkAuthController` identity as the Clerk subject string, fetch a separate `AuthenticatedIdentity.appUserId` from `/api/me`, and expose that internal ID only through the repository-facing auth adapter.
  Rationale: Clerk subjects are not UUIDs, while legacy repositories still require the internal app UUID for local owner metadata; the Worker remains authoritative for ownership.
  Date/Author: 2026-07-14 / Codex
- Decision: Ignore client owner fields and resolve ownership in authenticated Worker context for every query and mutation.
  Rationale: Client metadata is non-authoritative and cannot provide tenant isolation.
  Date/Author: 2026-07-14 / Codex
- Decision: Keep persisted `ownerSupabaseId` fields during the first cut as legacy storage names, but store only internal `appUserId` values and expose vendor-neutral APIs around them.
  Rationale: Renaming SwiftData properties risks an unrelated destructive store migration.
  Date/Author: 2026-07-14 / Codex
- Decision: Treat the 2026-07-14 live Supabase MCP readback as the source schema/cutover evidence; treat repository migrations as historical intent when they disagree.
  Rationale: Provider state determines the real export, identity, RLS, and reconciliation requirements.
  Date/Author: 2026-07-14 / Codex
- Superseded-for-this-launch decision: Fail closed for unmapped Clerk subjects until the final mapping is reconciled and a matching durable reconciliation receipt is activated. After that boundary, permit only server-generated, transactional, idempotent UUID creation for genuinely new Clerk users while writes remain enabled; the deprecated `ALLOW_UNMAPPED_CLERK_USERS` flag never authorizes production creation.
  Rationale: Legacy identities must retain their reviewed UUID mappings, while post-cutover signups need a safe path that cannot open before reconciliation or during a write stop.
  Date/Author: 2026-07-14 / Codex
  Supersession: The stateful validator remains available for a future live
  migration. This launch instead requires an explicit, authorization-bound
  zero-legacy receipt; no generic bypass is permitted.

## Testing Approach
- API: install, typecheck, Vitest, Wrangler type generation and deploy dry-run; cover malformed auth, `/api/me`, tenant isolation, owner spoofing, ingest idempotency/transactions, OpenAI proxy behavior, parser fixtures, and webhook signatures.
- Swift: targeted auth/backend/repository tests, then repository-mandated iOS build and test commands.
- Shared/watch regression: `swift test --package-path RefWatchCore` plus full watchOS unit/UI execution where destinations are available. Timer/haptics/match lifecycle behavior must remain unchanged unless an executable regression proves a product defect; any such fix requires focused coverage and full scheme reruns.
- Security: search source/config/project products and built artifacts for removed Supabase config and forbidden server secrets.
- Provider cutover: fresh disposable PlanetScale branch apply/readback,
  reviewed schema/seed manifest, zero user-owned target counts, staged
  greenfield packets, write-disabled Worker routing, bounded
  health/auth/isolation/onboarding/write proof, physical-device acceptance, and
  destructive rollback before final production traffic.

## Constraints & Considerations
- Preserve user-owned dirty files and never inspect or hand-edit `.projects` or generated `.env` files.
- No PlanetScale, Clerk secret/JWT private key, webhook secret, or OpenAI key may enter the iOS target.
- Do not trust client `owner_id`, parse Clerk subjects as UUIDs, remove SwiftData offline/backlog behavior, or change watch match lifecycle behavior.
- Hard deletes and exclusive timestamp-only incremental cursors are
  insufficient for multi-device deletion propagation. Collection routes use
  inclusive replay and tombstones; clients use pull-only high-water cursors,
  full epoch reconciliation on first/relaunch, a bounded 15-minute overlap, and
  strict-newer/dirty-local guards. The overlap assumes request-scoped
  database-only writes settle within that window; a future longer-lived writer
  requires a server-issued monotonic cursor/revision contract.
- Provider provisioning/deployment and greenfield cutover require readback
  evidence. Provider access gaps must be reported; unavailable physical devices
  block physical acceptance and final traffic cutover, not other safe
  preparation.
- Never inspect or hand-edit `.projects`; never print or persist secret values;
  never activate the production mutation ledger merely because the operation is
  authorized.

## Outcomes & Retrospective
- Repository foundations include the historical read-only production
  Hyperdrive/runtime role, inactive
  Queue/DLQ/D1 resources, securely installed production Clerk/OpenAI keys,
  verified `refwatch.ibby.ai` pins, and an unrouted write-disabled Worker. The
  2026-07-20 override converts the unfinished live-migration lane into a
  greenfield bootstrap. The authorization-bound zero-legacy identity
  implementation now passes its complete local database and code-risk review
  batch. The historical v1 greenfield launch/destructive rollback validators
  passed both mandatory reviews; the active immutable-version v2 correction is
  implemented with both mandatory reviewers at final `NO FINDINGS`. Its remediated local contract
  requires exact sanitized A/B provider receipts and allowlisted bindings,
  bracketed G/L deployment probes before A=100%/B=0% disabled proof, exact
  protected bounded B access, manually signed bounded webhook lifecycle, exact
  standalone rollback validation, B promotion, real Clerk-provider
  three-subscription lifecycle/zero-count cleanup while Access stays active,
  provider-proved Access removal before deployment history/devices, post-device
  production acceptance, and a final inactive-ledger readback.
  Real sanitized provider and acceptance receipts remain required before any
  packet can pass. The
  19-case local route/cursor/inactive-ledger batch has passed both mandatory
  reviews with final `NO FINDINGS`. The fresh read-only production baseline
  confirms a clean target and exact 5/54 seed, zero Clerk users, inactive
  ledger resources, and an unexposed write-disabled Worker without application
  data or durable provider configuration/credential mutation. Its mandatory
  review remediation is applied and both final reviewers returned
  `NO FINDINGS`. Migration `0016` and the separate durable least-privilege
  read/write-data role/Hyperdrive pair are now prepared with exact schema,
  clean-target, seed, owner, and inactive-ledger receipts; both mandatory
  reviewers returned `NO FINDINGS` and the deployed Worker is unchanged. Final
  outcomes depend on final no-findings reviews, remaining Clerk
  native/OAuth/webhook setup, distinct A/B/G/L Worker
  deployment, authenticated bounded acceptance, B promotion, physical-device
  acceptance against promoted B, production acceptance/observation, and
  post-acceptance cleanup—not source import, mapping, or ledger activation.

## Collaboration Review Log
All entries below dated before 2026-07-20 are point-in-time review history.
Their language about pending identity import/export, legacy mappings, final
stateful bundles, ledger recovery, or separate approvals is superseded for this
launch by the greenfield override. The underlying validators and technical
findings remain preserved as historical/future tooling.

- 2026-07-20 greenfield planning reviews: the code-risk role required
  database-enforced authorization/Clerk provenance, locked idempotent webhook
  lifecycle processing, explicit native OAuth callback resolution, staged
  validators, a writable least-privilege runtime, an inert-ledger proof, and a
  fresh disposable database-integration branch. The docs/evidence role required
  authorization-first writing, append-only historical supersession, zero
  pending approvals, exact count/resource taxonomy, per-provider evidence, and
  separately reviewed write/device/traffic phases. The execution plan applies
  every finding; both reviewers returned no findings before implementation.
- 2026-07-20 authorization/docs/operator batch review: the code-risk role found
  two inline `DATABASE_URL` examples that could place a production DSN in shell
  history. Both now require non-echoing provider/secret-manager injection and
  show only the non-secret migration command; its re-review returned no
  findings. The docs/evidence role required fresh-baseline qualification for
  dated Worker/seed/ledger receipts, past-tense treatment of stateful gates,
  whitespace cleanup in the new append-only artifact, and this reviewer trail.
  All findings were applied; its final re-review returned no findings.
- 2026-07-20 zero-legacy identity/bootstrap code-risk review: the reviewer
  found missing signed raw Clerk envelope provenance validation, a direct deletion
  write-gate bypass, a pre-receipt activation/user race, missing strict capture
  for delivery receipts, missing same-Svix and pre-receipt concurrency cases,
  verifier exception details in logs, non-deterministic cross-instance mapping
  lock order, and activation retry failure after the first user. All findings
  were applied and regression-proved. The final code-risk re-review returned no
  findings. Exact implementation, integrity hashes, verification counts, and
  the bounded no-provider claim are recorded in
  `evidence/2026-07-20-greenfield-identity-bootstrap.md`.
- 2026-07-20 zero-legacy identity/bootstrap docs/evidence review: the reviewer
  found overstated webhook timestamp agreement, stale inactive-ledger task
  state, stale current-test-count wording, and a missing review closure trail.
  The timestamp contract is now stated exactly, the task is complete, the
  93-test checkpoint is historical, the then-current identity-batch 129/17/4
  results are explicit, and this disposition is recorded. The final
  docs/evidence re-review returned no findings.
- 2026-07-20 greenfield launch-validator code-risk review: the initial review
  found six issues in self-attested schema/seed evidence, missing exact target
  and clean counts, unbound acceptance/device/traffic receipts, unsafe invalid
  CLI output, missing rollback-packet binding, and broken profile-less stateful
  compatibility. A second review found four issues in non-executable provider
  schema proof, non-recomputed receipt digests, rejection of authorized inactive
  ledger history, and missing baseline/stage ordering. Later reviews found that
  the partial catalog contract allowed manual drift and that future or
  simultaneous stage timestamps could pass. All findings were applied through
  exact production pins, executable schema/seed/clean/ledger queries, full
  catalog counts/digests, canonical sanitized receipt-hash recomputation,
  inactive-history classification, strict runtime-bound chronology, exact
  destructive rollback binding, and retained stateful compatibility. The
  preliminary authorization-digest alert was withdrawn after confirming that
  the pin is the canonical JSON payload digest, not the Markdown-file hash.
  Final reviewer `/root/validator_code_risk_review` returned `NO FINDINGS`;
  exact contracts, hashes, and 69/193/18 verification receipts are recorded in
  `evidence/2026-07-20-greenfield-launch-validator.md`.
- 2026-07-20 greenfield launch-validator docs/evidence review: the reviewer
  found incorrect bootstrap/provider sequencing, a stale 52-test focused
  validator count, transient route-count wording, missing `write_round_trip`
  acceptance, and imprecise inactive-ledger summaries. All five findings were
  applied: both runbook sequences now order inventory, preparation, pinned
  post-preparation schema/seed/clean/ledger/Clerk readbacks, disabled-candidate
  deployment, deployed Worker-version/binding/route readback, initial
  disabled-traffic verification, guard/rollback proof, disabled webhook
  denial, receipt activation/observation, bounded writes-enabled acceptance,
  devices/release, and production traffic/observation; the current shorthand is
  69/193/18, with 49 launch, 17 rollback, and 3 CLI focused cases; route
  evidence preserves only the 15/15
  pre-remediation validator checkpoint within that artifact; and the
  acceptance/ledger contracts are exact. Final reviewer
  `/root/validator_docs_consistency_review` returned `NO FINDINGS`. The later
  19-case route batch is recorded separately and does not retroactively change
  the validator checkpoint.
- 2026-07-20 greenfield local route/cursor code-risk review: the reviewer found
  wholesale team-child replacement could null historical event/member links;
  push receipts and nil first-sync cursors could skip tombstones; UUID
  comparisons were case-sensitive; inclusive replay could churn or overwrite
  dirty local state; and a simple inclusive boundary missed late commits.
  Bounded retained-ID bulk upserts, normalized UUIDs, pull-only cursors, epoch
  first/relaunch reconciliation, a 15-minute overlap, and strict-newer/
  dirty-local guards applied those findings. A final high finding showed
  same-clock writers could still publish an equal timestamp; namespace-qualified
  per-entity locks plus `max(now, persisted + 1 millisecond)` and forced-clock
  update/update and delete/resurrection regressions resolved it. Final reviewer
  `/root/route_matrix_code_risk_review` returned `NO FINDINGS`. Exact local
  scope and verification are recorded in
  `evidence/2026-07-20-greenfield-local-route-matrix.md`; independent
  docs/evidence reviewer `/root/route_docs_consistency_review` returned
  `NO FINDINGS` after all six findings were applied.
- 2026-07-20 greenfield local route/cursor docs/evidence review: the reviewer
  found six medium issues: stale/incomplete Apple coverage and an unbounded
  Release claim; omitted dry-run binding/read-only-role inventory;
  non-reproducible credential-scan scope; and overclaimed cryptographic webhook
  verification; then the revised scope incorrectly denied the scanner's sole
  bounded in-memory credential-fingerprint use; and finally the Gitleaks corpus
  sizes drifted after those fixes while remaining labeled current-final.
  All six were applied through
  the fresh 94-case full and
  five-case focused Apple receipts, bounded Xcode 27 incompatibility, explicit
  local-placeholder Release readback, sanitized binding/mode/role inventory,
  exact source/product/log/Gitleaks scan corpora, and mocked-verifier versus
  real-Postgres versus deployed-crypto proof boundaries. The scope now records
  the in-memory comparison fingerprint and that no value was printed or
  persisted. The rerun 511,420/337,624-byte Gitleaks receipt is labeled as the
  exact post-five-finding/pre-final-review-trail snapshot rather than a
  self-referential current-final corpus. After the review-only append, the
  repo-root actual-value scan still reported one available fingerprint, 10,259
  files, and zero hits, and `git diff --check` passed. Final reviewer
  `/root/route_docs_consistency_review` returned exactly `NO FINDINGS`.
- 2026-07-20 production-baseline first code-risk review:
  `/root/production_baseline_code_risk_review` found a high migration
  ownership/history-atomicity risk in applying `0016` through a transient
  PlanetScale role and a medium failure-atomicity/secret-custody gap in the
  writable credential-to-Hyperdrive handoff. Required remediations are an
  exact-`0015`-preconditioned atomic `SET LOCAL ROLE postgres` migration plus
  Drizzle-history helper with owner/catalog/history postchecks, and an
  in-memory non-echoing credential/Hyperdrive helper with rollback cleanup,
  least-privilege verification, exact configuration readback, old-path
  preservation, and coordinated candidate binding/role updates. Both findings
  were applied in `api/scripts/apply-production-migration-0016.mjs` and
  `api/scripts/provision-production-runtime.mjs` with focused unit and
  disposable-PostgreSQL coverage.
- 2026-07-20 production-baseline first docs/evidence review:
  `/root/production_baseline_docs_review` found three medium issues: the
  baseline was checked complete before review closure, temporary MCP/CLI
  access credentials conflicted with overbroad no-credential/no-provider-
  mutation language, and the exact current `0015` 26-category receipt was not
  reproducible from a retained query. All three are applied through open
  lifecycle markers, precise temporary-versus-durable access wording, and
  `api/scripts/production-greenfield-baseline-readback-0015.sql` with its hash
  and full sanitized live payload. The final re-review and its two additional
  wording findings are recorded below.
- 2026-07-20 production-baseline final code-risk review:
  `/root/baseline_final_code_risk` additionally found and resolved the
  non-interactive `pscale shell` opt-in/startup-file risk, a missing postflight
  rollback rehearsal, a provider-command timeout/cleanup race, an unpinned
  Cloudflare account, an insufficient effective-write proof, and missing
  PostgreSQL connection/query bounds. The final helper contract uses fixed
  production pins, SQL/password on stdin or in-memory client fields only,
  exact marker plus rolled-back row-write proof, cleanup discovery retries,
  old-resource refusal, and sanitized output. Focused helper tests pass 30/30,
  full API tests pass 223/223, hermetic database tests pass 22/22, mounted
  routes pass 19/19, and typecheck/source/syntax/diff checks pass. Final
  reviewer `/root/baseline_final_code_risk` returned `NO FINDINGS`.
- 2026-07-20 production-baseline final docs/evidence review:
  `/root/baseline_final_docs_review` found two remaining medium wording
  inconsistencies: the exec-plan index still called the already captured
  baseline pending, and the runbook conflated readwriter DML capability with
  admin migration capability. Both were applied by separating captured
  baseline from post-preparation verification and reserving `0016` for the
  ephemeral admin plus `SET LOCAL ROLE postgres` path. The final reviewer
  returned `NO FINDINGS`.
- 2026-07-20 production-baseline closure-only consistency pass: the code-risk
  reviewer found stale `api/README.md` wording that still treated the captured
  production baseline as future work, and the docs/evidence reviewer found the
  same issue plus runbook wording that still called the two reviewed
  preparation helpers open or unreviewed. At that point, the API guide and
  runbook distinguished the closed read-only baseline from the authorized but
  not-yet-executed provider-preparation batch. Both closure-only re-reviews
  returned `NO FINDINGS`.
- Planning code-risk reviewer: recommended Postgres/Hyperdrive, explicit identity readiness, owner-safe mutations, webhook signing, contract-first routes, and delayed Supabase dependency removal. Applied to the plan.
- Planning docs/evidence reviewer: required exec-plan artifacts, broader architecture/security docs, detailed schema/cutover evidence, and honest partial-acceptance language. Applied to the plan.
- API implementation reviewer: reported findings in assessment ownership, schedule references, JSONB serialization, idempotency, parser contract, tests, deletion sync/webhook ordering, OpenAI abuse controls, and deployment typing/bindings. The API remediation batch applied findings 1-4 and 7-9; the legacy parser normalization contract was subsequently ported and locally tested. The later real-Postgres match suite superseded the earlier missing-database-proof status. Broader CRUD, authenticated deployment, provider deployment, and data import were explicit gates for the then-active stateful plan; legacy data import is not a greenfield gate.
- Documentation/governance batch: incorporated the live Supabase MCP identity/count/RLS readback, server/client secret boundary, provider cutover/rollback runbook, and truthful partial status across canonical docs. Applied on 2026-07-14.
- Documentation reviewer: found two stale path/terminology issues and one pre-existing toolchain-version inconsistency. All were applied in the documentation batch.
- Reference-catalog batch: added authenticated, season-bounded Worker reads, target Drizzle tables/migration with a portable idempotent 5-competition/54-team seed, and a vendor-neutral Swift service. Unit/route coverage verifies bearer protection, seed cardinality, and contract decoding; the approved production-foundation apply and sanitized provider readback now prove exactly 5 competitions and 54 teams with zero application users.
- Reference-catalog reviewer: found missing source validation checks, possible team/competition season drift, and low-risk mutable registry debt. Database checks plus a composite season foreign key were added in migration `0003`; the registry pattern remains compatibility debt for later composition cleanup.
- Cutover code-risk reviewer `/root/code_risk_plan_review`: found cold-launch false logout/data deletion, unsafe just-in-time UUID creation, venue cast risk, missing persisted offline identity, event-reference parity, webhook ordering, and database-test gaps. The false logout, fail-closed mapping, safe cast, migration ordering, persisted cache, and event-reference transport are applied. The latest review also found UUID-case, query-amplification, and unrelated-team event-reference gaps; batching, bounds, normalization, and participating-team enforcement resolved them. The real-Postgres match suite supersedes the focused database gap; webhook ledger/ordering, populated event-reference transport, broader CRUD, and authenticated deployed proof remain explicit gates.
- Cutover docs/evidence reviewer `/root/docs_evidence_plan_review`: found stale source counts/table coverage, missing identity disposition/evidence artifacts, stale assistant architecture, insecurely underspecified secret ingestion, and incomplete rollback. Canonical counts, schema/product/runbook docs, secure secret handling, and timestamped artifacts were applied. Production domain/identity decisions and the final stateful rollback packet were then gated; the greenfield launch uses its separate destructive rollback profile.
- Staging/evidence re-reviews: the docs reviewer required the preliminary/final snapshot split, five-table rehearsal correction, Clerk verification fallback wording, reproducible staging/global-data evidence, and narrower secret-audit claims. All were applied. The stronger audit found legacy migration/config resources in the app bundle; synchronized-group exclusions—including the future local `Secrets.xcconfig` and migrations directory—now prevent packaging while preserving repository evidence.
- Final code-risk re-review: event-reference implementation findings are resolved and focused helper tests cover validation/batching behavior. Query-aware SQL assertions and the later 3/3 real-Postgres match suite supersede the earlier mock-only tenant/concurrency gap; populated event-reference transport plus broader CRUD and deployed proof remain.
- Final docs/evidence re-review: adjacent status docs, JWT-key comment, reviewer trail, scan scope, and bundle-enumeration evidence were synchronized. Production identity/import/authenticated routes/database tests/devices/rollback remain open.
- Parser/validator re-review: the three validator relation/disposition gaps were resolved with regression tests. Local match-sheet contract/normalizer parity is complete; authenticated deployed fixture and end-to-end proof remain open.
- 2026-07-15 production-decision-gate documentation review: `/root/docs_evidence_plan_review` found the two required approvals were not encoded as hard gates and that several checklist items mixed completed staging/simulator proof with open production/physical proof. The gate and status splits are applied across the plan, tasks, evidence index, and runbook. Its remaining independent seed-versus-compatibility-cleanup lifecycle finding is also applied. `/root/code_risk_plan_review` found the auth-only recommendation needed the validator's exact immediate `action: "exclude"` semantics, with archival reserved for a separate post-observation-window source operation. That precision is applied. Neither reviewer found an authorization for production mutation or a false production-acceptance claim; no high/medium finding is deferred.
- Approved Clerk provisioning did not update development-only `clerk-auth` in place. Stripe Projects created a separate production-capable resource named `clerk-auth-2`; both managed resources remain present. Its managed metadata may retain historical `production_domain: auth.refwatch.com`; live Clerk Backend API/CLI readback is authoritative and proves verified owned secondary domain `refwatch.ibby.ai`. Five DNS-only CNAMEs and coordinated Worker key/issuer refresh are applied without printing secrets. Do not recreate/remove the managed resource merely to align stale metadata. Native-app, OAuth, and webhook completion remain pending.
- Domain-control correction: the operator confirmed they do not own `refwatch.com`, so those five historical DNS targets remain retired. The operator subsequently selected owned `refwatch.ibby.ai`; Clerk change-domain, fresh DNS targets, certificates, and Worker key/issuer coordination completed on 2026-07-17. iOS public configuration remains pending because no local/release `Secrets.xcconfig` exists.
- Post-reconciliation onboarding review: the code-risk reviewer found that failing closed forever made genuine production signups unusable, while the old generic escape hatch was unsafe for legacy identities. The remediation added a durable receipt tied to the exact production Clerk instance and normalized final mapping, required enabled writes plus explicit post-reconciliation mode, created only server-generated UUIDs transactionally/idempotently, and returned retryable failure for premature `user.created`/`user.updated` webhooks. Local and real-Postgres coverage passed; legacy receipt generation/import/activation were then cutover gates. The active launch instead requires the authorization-bound zero-legacy receipt.
- Post-reconciliation onboarding docs/evidence re-review: no high finding. Its four medium findings were applied. The initially referenced migration role was subsequently reassigned to `postgres`, deleted, and absent from sanitized role readback. Historical 26/6 and 27/7 evidence now points to the superseding 30-table/8-migration readback.
- Post-reconciliation onboarding code-risk re-review: two high findings were applied. A receipt-linked exact legacy mapping registry plus transactional count/hash activation prevents missing/corrupted legacy mappings from receiving replacement UUIDs. Durable instance+subject deletion tombstones and advisory locks make deletion win over delayed/concurrent creation. Bearer sessions bind to the configured issuer/instance. Installed Clerk SDK evidence shows verified webhook events contain no instance-ID field, so webhook provenance must be proved by the production-instance endpoint/signing-secret installation receipt plus required `CLERK_INSTANCE_ID`; deployed proof remains pending.
- Final code-risk re-review found an activated-registry mutation/concurrency medium. Migrations `0008_immutable_identity_registry.sql` and `0009_harden_identity_registry_trigger.sql` now reject activated registry/app-user/activation mutation, validate activation at the database boundary, and coordinate activation with registry/app-user writers through the same transaction advisory lock. Real-Postgres regressions prove post-activation mutation rejection and that an in-flight mutation makes activation fail. The mandatory final reviewer confirmed no remaining high/medium blocker for this batch.
- Ledger rehearsal review found a high asynchronous-only envelope limit and medium replay-order, verifier-role, coverage, scheduler/test-isolation, and DLQ idempotency gaps. Migration `0015`, schema-derived foreign-key ordering, exact read-only verifier checks, all-migration/AST coverage, integration-epoch scheduler exclusion, and compare-after-insert DLQ receipts resolve them. Evidence review found summary-only receipts, stale Worker binding, incomplete per-epoch/poison/D1 negative proof, and overbroad non-touch wording; the v6 receipt bundle and qualified production statement resolve them. Both mandatory final re-reviews report no blocker.
- Final code-risk re-review found no blocker. One medium remains accepted and documented: the verifier proves a read-only transaction and absence of effective DML on the 22 captured domain tables, not on 13 control/excluded tables or schema creation. One low remains: static coverage does not model later trigger drops/renames, while current provider readback independently confirms 22 live triggers.
- Candidate source-snapshot planning review rejected full-row MCP output and gitignored plaintext as high-risk. Applied: the checked-in query returns only counts/digests from an exact 39-table, minimized-Auth, read-only repeatable-read contract; the stateful final-bundle validator requires a fresh secure export, exact table keys, continuous quiescence receipts, encryption/mode/no-symlink/atomic-write evidence, server/local digest parity, and candidate/final separation. Full encrypted export transport was a blocker for that stateful plan and is not required for the greenfield launch.
- Candidate/final-export implementation re-review found and resolved plaintext-CLI, self-attested provenance, wrong-project/exporter, auth-only binding, catalog-gate, mapping-output, creator-receipt, atomic-write, and end-to-end test gaps. That verifier/foundation batch passed the then-current 78/78 suite. Its later pre-greenfield aggregate was 93/93 across 14 files plus the separate 4/4 hermetic local route matrix; the subsequent 2026-07-20 identity checkpoint was 129/129, 17/17 hermetic database cases, and 4/4 partial mounted routes. The beta.3 result is 108/108 focused, 268/268 unit, 23/23 database, and 19/19 mounted routes with typecheck passing. The July 20 exact 83-file redacted Gitleaks receipt remains historical; the provider/deployed matrix remains open.
- Beta.3 release review found that profile fields could regress under delayed
  Clerk `user.updated` delivery. Applied: additive migration `0017` introduces
  a nullable Clerk profile-event watermark, webhook processing advances only
  on a strictly newer provider timestamp, auth-created rows accept their first
  profile, and stale/equal/reversed-concurrent regressions are covered. Applied
  migration `0016` was not rewritten; production still requires a separately
  reviewed `0017` apply before this Worker code may deploy.
- 2026-07-20 active v2 review remediation: code-risk findings were applied to
  the local launch/rollback contract and are reflected in the current docs:
  provider-derived sanitized A/B receipts with stable-hash recomputation and
  exact binding allowlists, public A=100%/B=0% proof, protected override-only B
  automation with an exact one-token/zero-bypass Access receipt, canonical
  before/after G/L deployment readbacks bracketing each probe before final A
  proof, manually signed bounded webhook lifecycle, exact nested standalone
  rollback validation, receipt-kind/ID uniqueness, B promotion, real Clerk
  provider lifecycle/zero-count cleanup while Access remains active, then
  provider-bound Access removal before deployment history/devices, and a final
  post-observation inactive-ledger readback. The code-level
  final re-review `/root/v2_code_risk_review` and independent
  docs/evidence consistency re-review `/root/v2_docs_review` each returned
  `NO FINDINGS`; no provider mutation is claimed by this remediation.
- 2026-07-17 local route-safety review: the code-risk reviewer found a default-open write gate and non-atomic owner upserts; the docs reviewer found the default development deploy shared the production Worker name. All were applied: missing/unknown write mode now fails closed, development has a distinct Worker name, conflict updates are owner-predicated without owner mutation, nested team rows remain untouched on foreign conflicts, and per-request database reads are sequential. Final code-risk and docs/evidence re-reviews report no remaining high/medium code/config finding. Evidence remains explicitly partial.
- 2026-07-17 post-documentation review: the code-risk reviewer narrowed the disabled webhook probe to routing/write-denial evidence, aligned the gated iOS configuration instructions, and bounded the local delete claim. The docs/evidence reviewer split the consumed Action 1 foundation from the pending escrow/functional-ledger gate, marked the prior 19/19 provider result as historical and not rerun after route changes, corrected the live-Clerk-versus-managed-metadata wording, and added the local PostgreSQL prerequisite. All findings were applied; that batch's executable proof was exactly 93/93 unit tests plus 4/4 hermetic local cases, with no provider operation.
- Historical 2026-07-17 final code-risk pass: found the top-level quick start still read as immediate authority to create iOS cloud configuration, repeat production provisioning, register Clerk native/OAuth configuration, and create a webhook. The then-current README labeled those production steps approval-gated, preserved the existing foundation, required authoritative Apple identifiers, and routed future operators to the staged runbook. The 2026-07-20 override now authorizes those ordered operations without changing their prerequisites or security boundaries.
- Historical 2026-07-17 production ledger-key escrow preflight: the operator selected Cloudflare Secrets Store and authorized a non-disclosing copy with no bind/deploy/rotation/activation. Account/store/edit-permission metadata passed, but fail-closed source validation found the exact Keychain record's payload empty. Both mandatory reviewers classified this as a high blocker for the then-active stateful plan. No secret was created. The 2026-07-20 greenfield decision defers escrow, recovery, and activation; no remediation or rotation is required for launch.
- 2026-07-17 final ledger-key escrow reviews: the code-risk reviewer found no high-severity scope breach and the docs/evidence reviewer confirmed the four-gate split, Action 1 consumption, historical custody supersession, uncreated Secrets Store target, and one immediate non-secret recovery decision. Their consistency findings were applied by acknowledging authenticated metadata-only Cloudflare readback, aligning both operator pages, and distinguishing successful payload inspection from the failed source precondition. No provider mutation occurred.
