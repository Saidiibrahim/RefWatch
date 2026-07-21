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
  checkpoint passed 93 tests across fourteen files; the current aggregate is
  268/268 unit tests across 19 files, including runtime-gate and public-route
  coverage, plus 108/108 focused launch/rollback/CLI cases across 3 files. Fresh
  hermetic verification is 23/23 database cases across 3 files and 19/19
  mounted-route cases in 1 file. The earlier 19/19 real-Postgres
  provider result from 2026-07-15
  remains historical evidence and was not rerun after these route changes.
- [x] Implement and prove the explicit `greenfield_zero_legacy_v1` bootstrap:
  exact authorization/Clerk provenance, canonical empty mapping receipt,
  immutable activation, server-generated UUIDs, subject locks, tombstones, and
  idempotent create/update/delete lifecycle processing. Preserve the stateful
  positive-mapping path and keep `ALLOW_UNMAPPED_CLERK_USERS` inert. The
  identity batch initially passed typecheck, 129/129 unit tests, 17/17
  hermetic database cases, 4/4 mounted-route cases, 36/23/13 mutation coverage,
  Drizzle convergence, and the production Wrangler dry-run. The current
  aggregate after the v2 lineage remediation is 268/268 unit tests across 19
  files, 23/23 hermetic database cases across 3 files, and 19/19 mounted-route
  cases in 1 file.
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
  `0017` remains a source migration and must be applied before deploying this
  code to production.
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
- [x] Supersede the active closeout contract with `greenfield_launch_v2` and
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
  verification is 268/268 across 19 files; typecheck, 23/23 database,
  19/19 mounted-route, and grouped fully redacted Gitleaks checks pass. The
  earlier exact 83-file scan remains historical remediated-v2 evidence.
  Generated Wrangler types are part of this batch. Both mandatory final
  reviewers returned `NO FINDINGS`, as recorded in
  `evidence/2026-07-20-greenfield-worker-version-lineage.md`.
- [x] Prove normal local transactions and fetch handling commit with zero
  ledger epochs/outbox/deliveries and no key, D1, Queue, cron, or consumer
  dependency; separately preserve strict capture in an isolated archived epoch.
  The 18 pre-helper cases within the fresh 22-case hermetic database suite
  prove the inactive and isolated strict paths plus greenfield readback
  anchors, while the mounted fetch harness supplies none of those ledger
  runtime dependencies. Production capture was not activated.
- [x] Complete and review the exact-head, atomic, Postgres-owned production
  `0016` helper and the failure-atomic, non-echoing, least-privilege writable
  runtime credential/Hyperdrive helper. Focused helper tests pass 30/30, four
  disposable database paths prove migration success/rollback, and the final
  code-risk reviewer returned `NO FINDINGS`. No provider execution is claimed.
- [x] Execute the reviewed migration/runtime preparation while `WRITE_MODE`
  remains disabled. Provider execution is complete: production is at exact
  migration `0016`/17, the 36-table catalog and zero-row 27-category target
  read back correctly, durable role `hvk7iheytj62` and Hyperdrive
  `920ca5b108034b2bb8700cf0201ac55f` are provisioned, and the candidate binding
  plus expected role were updated together. Typecheck, 223 unit, 22 database,
  19 mounted-route, and production dry-run checks pass. Both mandatory
  preparation reviewers returned `NO FINDINGS` after their findings were
  applied. Before webhook reachability testing, the next batch must deploy the
  write-disabled candidate and pin distinct write-guard and last-known-good
  versions. The later write-enabled accepted version remains gated by
  activation and bounded acceptance. Preserve the current read-only
  role/Hyperdrive and old Worker version as the emergency write-denial path.
