---
task_id: 01
plan_id: PLAN_backend-platform-migration
plan_file: ./PLAN_backend-platform-migration.md
title: Build the authenticated Worker API and PlanetScale Postgres schema
phase: Phase 1 - Backend
---

- [x] Create the Hono/Workers workspace, Drizzle Postgres schema/migration, and initial Vitest harness.
- [x] Add Clerk bearer middleware, internal app-user resolution, `/api/me`, and signed Clerk webhook handling.
- [x] Port match ingest/read/delete, schedule, assessment, and library routes with server-derived ownership; apply the API review fixes for assessment/reference ownership, JSONB serialization, idempotency, and deletion sync.
- [x] Port authenticated, season-bounded reference-catalog reads plus the portable idempotent 2026 seed (5 competitions, 54 teams).
- [x] Port assistant streaming and match-sheet parsing with server-side OpenAI access. Routes and OpenAI bounds exist; the legacy portable match-sheet prompt, strict schema, refusal/incomplete handling, field normalization, dropped-row warnings, deduplication, and ordering contract now have Worker tests. Authenticated deployed calls remain part of release acceptance.
- [x] Add focused ownership, idempotency, contract, webhook, AI, event-reference,
  reference-catalog, stateful and greenfield cutover-validator,
  candidate-snapshot, onboarding, rollback, mutation-group ordering,
  envelope-bound, key-rotation, and mutation-ledger tests. The pre-greenfield
  checkpoint passed 93 tests across fourteen files. The historical activation-
  closure aggregate is 281/281 unit tests across 20 files, including runtime-
  gate, public-route, and activation-helper coverage, plus 108/108 focused
  launch/rollback/CLI cases across 3 files and 19/19 focused remediation cases
  across 2 files (13 activation-helper plus 6 shared migration-0016 contract
  cases). The historical migration-0017 convergence checkpoint extends that unit
  corpus to 296/296 across 21 files and adds 11/11 isolated physical-`postgres`
  migration cases. Fresh hermetic verification also includes 23/23 current-
  schema cases across 3 files, the historical 9/9 exact-0016 activation cases,
  and 19/19 mounted-route cases in 1 file. The earlier 19/19 real-Postgres
  provider result from 2026-07-15
  remains historical evidence and was not rerun after these route changes.
- [x] Implement and prove the explicit `greenfield_zero_legacy_v1` bootstrap:
  exact authorization/Clerk provenance, canonical empty mapping receipt,
  immutable activation, server-generated UUIDs, subject locks, tombstones, and
  idempotent create/update/delete lifecycle processing. Preserve the stateful
  positive-mapping path and keep `ALLOW_UNMAPPED_CLERK_USERS` inert. The
  identity batch initially passed typecheck, 129/129 unit tests, 17/17
  hermetic database cases, 4/4 mounted-route cases, 36/23/13 mutation coverage,
  Drizzle convergence, and the production Wrangler dry-run. The activation-
  closure aggregate is the historical 281/281 unit tests across 20 files,
  23/23 current-schema database cases plus 9/9 isolated exact-0016 activation
  cases, and 19/19 mounted-route cases in 1 file. The migration-0017
  convergence checkpoint extends the unit corpus to 296/296 across 21 files
  and adds its separate 11/11 physical-`postgres` rehearsal. Production apply/
  retry, independent primary readback, and both mandatory post-execution reviews
  are complete with final exact `NO FINDINGS`; migration-0017 no longer blocks
  Worker upload.
  Both activation and lifecycle delivery are immutable/idempotent under
  the reviewed lock order; the signed raw Clerk instance must match
  configuration, type/subject must match the verified projection, and timestamp
  must be positive safe-integer milliseconds before database access. This is
  local proof, not production activation.
- [x] Add the beta.3 Clerk profile-event watermark in additive migration
  `0017`, leaving applied/hash-pinned `0016` unchanged. Auth-created rows accept
  their first lifecycle profile; strictly newer deliveries advance the
  watermark, while stale/equal-time and reversed-concurrent updates cannot
  regress profile state. The 23/23 hermetic database suite covers these cases.
  Production `0017` is now applied and independently read back. Both mandatory
  post-execution reviews returned final exact `NO FINDINGS`; migration-0017
  convergence no longer blocks Worker upload. The separate Clerk/Worker
  lineage, continuation, and acceptance gates remain open.
- [x] Complete the 19-case hermetic mounted-route matrix for matches and their
  children, assessments, teams, competitions, venues, schedules, greenfield
  onboarding, owner/spoof isolation, idempotency/concurrency, tombstones,
  stubbed assistant/match-sheet routes, and inactive-ledger fetch behavior.
  Collection routes use inclusive replay; team replacement preserves retained
  child identities; per-entity locks publish strictly monotonic timestamps even
  at a forced same clock. This is local proof only.
- [ ] Complete the bounded real Clerk-authenticated deployed matrix for production
  health/auth/tenant-isolation/CRUD/idempotency/AI/match-sheet/webhook behavior.
  Provider operations are authorized but remain incomplete until evidenced.
- [x] Close review of the captured fresh read-only production baseline.
  PlanetScale
  `ibrahim-aka-ajax/refwatch/main` (`w3g1f8vcbg34`) is clean, contains the
  exact reviewed 5/54 seed and no active ledger, and is at 16 migrations
  through `0015`; target `0016` is the seventeenth migration. The branch has no
  provider read-only reason, PlanetScale MCP has a separate write tool, and
  ephemeral `pscale` readwriter/admin access passed non-mutating privilege
  probes. Readwriter proves DML capability; only admin can assume `postgres`
  and apply `0016`. The two durable roles and existing Hyperdrive remain
  read-only.
  Cloudflare/Clerk/Apple state and exact IDs are recorded in
  `evidence/2026-07-20-production-greenfield-baseline.md`. Provider-issued
  temporary access roles are classified separately; no application data or
  durable provider configuration/credential mutation occurred, and no operator
  approval is pending. The exact then-current pre-preparation `0015` payload is
  reproducible. The
  atomic migration and failure-atomic writable role/Hyperdrive helpers pass
  30 focused unit cases plus four disposable migration paths within the 22-case
  database suite; both mandatory final reviewers returned `NO FINDINGS`.
  The later production-preparation artifact supersedes only this execution
  state; this baseline remains historical.
- [x] Historical 2026-07-17 batch: API typecheck/93 tests, the 4/4 hermetic local route matrix, Wrangler types/dry-run, production PlanetScale apply/readback, exact 5/54 seed verification, read-only runtime-role/local config readiness, Hyperdrive control-plane readback, write-gate coverage, production Queue/DLQ/D1 provisioning, production ledger secret-name installation, and secure production Clerk/OpenAI secret installation passed. The Worker ledger-secret value was non-readable, and the named Keychain payload audited empty. The provider receipt recorded Worker `e966d6df-b5ff-4288-832c-c8d91e00ce48` as unrouted, write-disabled, without preview URLs or cron/Queue consumers, with Clerk pins matching `refwatch.ibby.ai`; localhost probes recorded readiness 200 and API/webhook denial 503. These are dated receipts, not current provider state; the fresh baseline is recorded separately above.
- [x] Add explicit `greenfield_launch_v1` and `greenfield_destructive_v1`
  validators, with exact Clerk/Worker/PlanetScale pins, canonical sanitized
  receipt-hash recomputation, executable schema/seed/clean/ledger readbacks,
  strict runtime-bound chronology, physical/write/traffic gates, and the
  corrected Worker name `refwatch-api`. Preserve the existing stateful
  export/import validator and profile-less stateful rollback compatibility as
  historical/future migration tooling. At that validator checkpoint, the
  focused 69/69 validator suite
  (49 launch, 17 rollback, 3 CLI), full 193/193 API suite, 18/18 hermetic
  database suite, typecheck, Node syntax checks, and both mandatory re-reviews
  pass; the focused/full/database shorthand is 69/193/18. This is a local
  validation contract, not provider execution or production activation.
- [x] Record the historical v2 closeout contract with `greenfield_launch_v2` and
  `greenfield_destructive_v2`: distinct disabled/accepted candidates plus
  guard/LKG; packet-carried digest-checked sanitized A/B provider readbacks;
  validator-recomputed equal script/stable-binding lineage and exact approved
  binding/secret-name allowlist; public A=100%/B=0% exact-version
  health/readiness, auth rejection, retryable API/webhook denial, and zero
  mutations; bounded B access through Cloudflare version override + Access
  `service_auth` receipt with one token/zero bypass + Worker-only
  `CUTOVER_ACCEPTANCE_TOKEN` gate; temporary G/L 100% deployment/probes
  bracketed by canonical provider readbacks/timestamps before final A proof;
  exact nested standalone rollback validation; bounded manually signed webhook
  lifecycle through override+token; B=100% promotion with no competitor; real
  Clerk delivery without override/token for exactly three subscriptions and
  lifecycle/retry/delete-wins/zero-count cleanup while Access remains active;
  provider-bound Access removal before deployment history/devices; production
  acceptance after devices; and final
  inactive-ledger/zero-consumer readback. Receipt kinds/IDs are unique and
  Workers.dev/preview exposure is rejected. Focused verification is 108/108
  across 3 files, including six promoted-webhook adversarial tests; full unit
  verification at that v2 checkpoint was 268/268 across 19 files; typecheck,
  23/23 database,
  19/19 mounted-route, and grouped fully redacted Gitleaks checks pass. The
  earlier exact 83-file scan remains historical remediated-v2 evidence.
  Generated Wrangler types are part of this batch. Both mandatory final
  reviewers returned `NO FINDINGS`, as recorded in
  `evidence/2026-07-20-greenfield-worker-version-lineage.md`.
- [x] Prove normal local transactions and fetch handling commit with zero
  ledger epochs/outbox/deliveries and no key, D1, Queue, cron, or consumer
  dependency; separately preserve strict capture in an isolated archived epoch.
  The 18 pre-helper cases within the then-current beta.2 22-case hermetic database suite
  prove the inactive and isolated strict paths plus greenfield readback
  anchors, while the mounted fetch harness supplies none of those ledger
  runtime dependencies. Production capture was not activated.
- [x] Complete and review the exact-head, atomic, Postgres-owned production
  `0016` helper and the failure-atomic, non-echoing, least-privilege writable
  runtime credential/Hyperdrive helper. Focused helper tests pass 30/30, four
  disposable database paths prove migration success/rollback, and the final
  code-risk reviewer returned `NO FINDINGS`. No provider execution is claimed.
- [x] Execute the reviewed migration/runtime preparation while `WRITE_MODE`
  remains disabled. At preparation closure, production was at exact migration
  `0016`/17; the 36-table catalog and zero-row 27-category target read back
  correctly, durable role `hvk7iheytj62` and Hyperdrive
  `920ca5b108034b2bb8700cf0201ac55f` are provisioned, and the candidate binding
  plus expected role were updated together. Typecheck, 223 unit, 22 database,
  19 mounted-route, and production dry-run checks pass. Both mandatory
  preparation reviewers returned `NO FINDINGS` after their findings were
  applied. The later production-0017 convergence item supersedes this
  historical schema-head state. Before webhook reachability testing, the next batch must deploy the
  write-disabled candidate and pin distinct write-guard and last-known-good
  versions. The later write-enabled accepted version remains gated by
  activation and bounded acceptance. Preserve the current read-only
  role/Hyperdrive and old Worker version as the emergency write-denial path.
- [x] Implement the fail-closed one-shot production zero-legacy activation
  helper, exact source/digest checks, 37-relation lock boundary, pre-commit Node
  validation, canonical sanitized receipt, and isolated exact-0016 physical
  `postgres` database suite. Focused remediation tests pass 19/19 across 2 files
  (13 activation-helper plus 6 shared migration-0016 contract cases); the dedicated
  database suite passes 9/9, including both exact next-18 sequence
  representations, rejection of conflicting pairs/catalog drift without row or
  sequence mutation, first/retry/conflict/dirty-state/ledger/concurrency,
  hostile search-path, and disabled-trigger paths. This checkbox is local
  implementation only.
- [x] Both initial mandatory reviews closed before the first production
  attempt. That attempt failed closed and committed zero receipt/activation
  rows under the original one-representation sequence check. Both reopened
  remediation reviewers returned final `NO FINDINGS`. Fresh exact production
  PlanetScale and separate official Clerk zero-user readbacks then gated a
  successful activation and idempotent retry. Primary readback proves one exact
  immutable receipt/activation, the same UUID/timestamps, zero other target
  rows, exact seed/schema, and inactive ledger. Every mandatory post-execution
  finding was applied and both final reviewers returned exact `NO FINDINGS`.
  That batch did not deploy source `0017`, enable writes or onboarding, route
  traffic, or activate the mutation ledger.
- [x] Apply and read back additive production migration `0017` through only
  the reviewed gated admin helper before uploading any beta.3 Worker version.
  Local implementation is complete: source/contract pins, all-table locks,
  full `(id, hash, created_at)` history digest, exact history-table/primary-key/
  default/serial/`OWNED BY` control contract, activation/clean/seed/ledger
  preconditions, validate-before-commit, canonical receipt, idempotent retry,
  invalid sequence-pair and control-drift rejection, locked concurrent-writer
  proof, 14/14 unit cases, and 11/11 isolated physical-`postgres` cases. Timeout,
  transport, or missing post-commit sentinel remains an ambiguous failure that
  requires exact primary readback plus the idempotent retry. Mandatory pre-
  execution code/docs reviews and the supplemental SQL review returned exact
  `NO FINDINGS`. The reviewed fixed stdin-only command applied `0017`; the
  first/retry canonical receipt SHA-256 values are
  `d7a7dabb6a919459132d3820bc9728fd15226ee6880926f535899a733a1407be` and
  `aaac7e2585a3184ed7cc871b16a9109636db049de7cd6daf3850405a75b38a14`.
  Independent primary readback proves exact 18-row/383-column 0017, all pinned
  history/catalog controls, sequence `(19,false)`, the nullable `timestamptz`
  target column, unchanged identity UUID/timestamps, exact 5/54 seed, zero
  other target rows, and inactive ledger. The launch validator targets this
  exact current catalog while activation remains pinned to historical 0016.
  Both mandatory post-execution reviewers returned final exact `NO FINDINGS`,
  closing migration-0017 convergence and unblocking Worker upload from this
  prerequisite. No Worker upload/deployment, routing, writes/onboarding,
  traffic, Clerk, or mutation-ledger state changed; later Worker lineage and
  acceptance gates remain incomplete.
- [ ] Complete and review the fail-closed same-process production Clerk/Worker
  cutover implementation across
  `scripts/prepare-production-clerk-webhook.mjs`,
  `scripts/prepare-production-greenfield-worker-lineage.mjs`, and
  `scripts/execute-production-greenfield-cutover.mjs`. Local implementations
  are present, and their current checkpoint passes 455/455 full unit tests
  across 25 files, all 43 database cases (23 current-schema + 9
  exact-0016 activation + 11 migration-0017), 19/19 mounted routes, typecheck,
  all three source checks, production dry-run, Wrangler generated-types check,
  mutation coverage, a fully redacted changed-file credential scan with
  `.projects` excluded and uninspected, and `git diff --check`. The earlier
  131/131 focused and 427/427 full-unit checkpoint remains historical. Final
  review closure, the trusted audit reader/live fixtures, and bounded
  continuation wiring remain open. Keep
  `clerk:webhook:production:check`, `worker:lineage:production:check`, and
  `cutover:production:check` source-only and non-mutating. Standalone execution
  of the Clerk and lineage helpers must fail closed. For this Clerk/Worker lane,
  only the outer `cutover:production` package script may supply explicit
  `--execute`, with
  `REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER=1`; it must remain unusable
  until reviewed provider-guard and bounded continuation callbacks are wired.
- [ ] Close the active `greenfield_launch_v3` / `greenfield_destructive_v3`
  continuation review. The source binds the exact Cloudflare Custom Domain,
  zero conflicting zone routes, and no manual DNS origin while preserving v2
  only as historical validation. Do not execute until both mandatory reviews,
  every remediation, and final review closure are recorded.
  Prepare only the exact disabled Clerk lifecycle endpoint and keep its signing
  secret plus the generated acceptance token memory-only through lineage,
  post-lineage review quorum, fresh provider guards, and continuation. Install
  only those two newly required Worker secret names with bytes on Wrangler
  stdin and one exact version delta per mutation; preserve the four existing
  bindings without reading their values; create exactly the intermediate
  secret-source version, final S, A, B, and G in order while reading unchanged
  L.
  Enforce exactly five new versions total, zero unexpected versions, exact
  command targeting, unchanged 100% L deployment, pairwise-distinct IDs, exact
  A/B script/stable-binding lineage, generic non-echoing failures, and canonical
  sanitized receipts. The local checks pass; no production execution may occur
  until the reviewed continuation is wired and both mandatory reviewers return
  final exact `NO FINDINGS`.
