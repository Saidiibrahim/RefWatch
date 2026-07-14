# PLAN_backend-platform-migration

## Purpose / Big Picture
Replace the active Supabase integration with Clerk authentication, a Cloudflare Workers/Hono API, and PlanetScale Postgres while preserving the watch-first match runtime and iOS offline SwiftData behavior. The iOS app remains an untrusted API client: Clerk session tokens cross the network, while database, Clerk secret, webhook, and OpenAI credentials remain server-side.

## Context and Orientation
- Architecture: `ARCHITECTURE.md`, `docs/design-docs/architecture/overview.md`, `docs/design-docs/architecture/ios.md`, `docs/design-docs/architecture/shared-services.md`
- Current database evidence: `docs/generated/db-schema.md` and `RefWatchiOS/Core/Platform/Supabase/migrations/`
- Auth seam: `RefWatchCore/Sources/RefWatchCore/Protocols/AuthenticationProviding.swift`
- Current iOS adapters: `RefWatchiOS/Core/Platform/Auth/`, `RefWatchiOS/Core/Platform/Supabase/`, and `RefWatchiOS/Core/Platform/AI/`
- New Worker workspace: `api/`
- Repository-mandated physical targets are iPhone 15 Pro Max and Apple Watch Series 9 (45mm). Automated evidence uses same-model iPhone 15 Pro Max and Series 9 (45mm) simulators on the available stable runtimes recorded below.

## Plan of Work
1. Establish a PlanetScale Postgres/Hyperdrive Worker foundation and port the canonical data model into Drizzle migrations.
2. Add Clerk bearer authentication, internal user resolution, independently verified Clerk webhooks, owner-scoped CRUD/sync routes, and the two OpenAI-backed routes.
3. Introduce vendor-neutral Swift auth/token/identity seams and a typed backend client, then move repositories behind those seams without changing watch match lifecycle logic.
4. Replace the active iOS auth UI/composition with Clerk, remove compiled Supabase dependencies, update setup/architecture documentation, and verify API/iOS/watch regressions.
5. Treat live Supabase account/data export-import and production cutover as a separately evidenced provider operation; do not claim it from code/schema generation alone.

## Concrete Steps
- `TASK_01_worker-api.md`: Worker, schema, auth, routes, tests.
- `TASK_02_swift-client.md`: Clerk auth, backend client, repository migration, tests.
- `TASK_03_docs-cutover.md`: dependency cleanup, documentation, provider runbook, verification.

## Progress
- [x] Planning critique completed by code-risk and docs/evidence reviewers.
- [x] PlanetScale Postgres + cache-disabled Hyperdrive selected for the deployed Worker; direct `DATABASE_URL` reserved for Drizzle migrations/local tooling.
- [ ] `TASK_01_worker-api.md` — partial: review remediation, authenticated routes/schema/seed, typecheck, 47 tests across 9 files plus 3 real-Postgres match-route tests, Wrangler dry-run, six-migration disposable PlanetScale apply/readback, staging Worker/Hyperdrive readiness, strict 39-table cutover validation, bounded rollback-packet validation, emergency write gating, and legacy match-sheet normalizer/warning parity passed. Broader database-backed/authenticated deployed route coverage, final source bundle/import, production environment/external ledger, populated rollback packet/guard upload, and production migration/deployment remain.
- [ ] `TASK_02_swift-client.md` — partial: active composition routes cloud features through Clerk/BackendAPIClient adapters; unresolved startup auth no longer triggers a false logout, and backend identity persists offline while revalidating online. Generic builds, 89/89 iOS unit tests, and the full 21-case iOS UI target (19 pass, 2 bounded skips, 0 failures) pass on iPhone 15 Pro Max simulators. The Series 9 watch simulator passes 11/11 UI cases and 107 unit cases with 4 explicit skips and no failures. Watch/widget versions are aligned and verified at `0.8.2 (1)`. Physical-device evidence and Supabase-named compatibility cleanup remain.
- [ ] `TASK_03_docs-cutover.md` — partial: canonical docs and timestamped source/rehearsal/review/staging evidence are updated. Supabase package scans and actual-value source/config/app+watch bundle/build-log scans passed for the two available forbidden secret fingerprints; staging secret-name/config readback is recorded. Active compatibility cleanup, production identity/provider decisions, provider cutover, and final acceptance evidence remain.

## Surprises & Discoveries
- The live Supabase MCP readback on 2026-07-14 overrides migration-file assumptions: `public.users` has an internal UUID `id` but no `clerk_user_id`. Identity mapping/backfill must be explicit while preserving internal UUIDs.
- The single-statement source snapshot inventories all 39 public tables. Core counts are `matches=62`, `match_periods=119`, `match_events=579`, and `match_metrics=62`; Supabase Auth has 43 identities while `public.users` has 42 profiles.
- Nine live public tables have RLS disabled: `match_officials`, `match_assessments`, `trend_snapshots`, `workout_session_metrics`, `workout_intensity_profile`, `workout_segments`, `coaches`, `feedback_attachments`, and `ai_usage_daily`. This remains a live legacy security risk until direct Supabase access is retired or separately remediated.
- Supabase-specific auth types and UUID assumptions extend into connectivity, persistence, previews, and feature views beyond the initially named files.
- The requested Clerk webhook route requires a distinct `CLERK_WEBHOOK_SIGNING_SECRET` and replay/signature verification.
- API remediation fixed the reviewed assessment/reference owner checks, JSONB serialization, idempotency claim flow, deletion sync/account-deletion handling, streaming-bounded match-sheet inputs/output tokens, bounded/batched event-reference validation, legacy match-sheet parsing normalization/warnings, and emergency rollback write control. Typecheck and 47 tests across 9 files pass. A separate real-Postgres suite passes 3/3 for match-route concurrency, idempotency, spoofed-owner/reference rejection, and owner-scoped reads/deletes; broader CRUD, Clerk, Hyperdrive, and authenticated deployed coverage remain deferred.
- The active iOS app now builds and routes matches, schedules, journal, teams, competitions, venues, reference-catalog reads, assistant, and match-sheet parsing through `BackendAPIClient`; the Supabase SDK/package dependency is removed. Simulator unit/UI execution is green. Production reference-catalog apply/readback, physical iPhone/watch acceptance, and legacy Supabase-named compatibility repositories/types/source paths remain unfinished; disposable rehearsal readback passed.
- Reference catalog data is global and read-only, but its Worker endpoints remain authenticated. User-owned team/competition materialization continues through owner-derived backend repository routes; the client never supplies an authoritative owner ID.
- PlanetScale branch `cutover-rehearsal-20260714` accepted the complete six-migration set after correcting migration `0003` dependency ordering. Provider readback found 26 public tables, all required legacy/reference tables, and the expected 5/54 reference catalog. Production `main` remains unchanged.
- Auth state now distinguishes unresolved startup from confirmed logout, preventing cold-launch local-data deletion. The resolved Clerk-subject/app-user pair is cached for offline launches, revalidated online, and removed on invalidation.
- Staging Worker version `527852d7-8ec8-48c4-b4d0-c521a3308558` reaches the disposable PlanetScale branch through Hyperdrive and passes `select 1` readiness. This is connectivity evidence only; production and the authenticated route matrix remain pending.
- Match-event team/team-member references now round-trip through Core, iOS adapters, and Worker ingest/read contracts. Validation batches ownership lookups, normalizes UUID case, bounds events to 500 (source maximum observed: 23), and restricts references to participating teams; final source reconciliation and database-backed transport tests remain gates.
- The 30 disciplinary codes, three disciplinary rules, and 20 creator-free workout presets were imported into the isolated rehearsal branch with exact ordered-row hashes matching Supabase. The seeded 5/54 competition/team business columns also hash-match. This is not the final repeatable-read import.
- A repository validator now rejects any cutover bundle without explicit arrays/counts/table-specific dispositions for all 39 source tables, a read-only repeatable-read boundary, the exact source Auth ID set, collision-safe reviewed Clerk/app-user contracts, a dependency-complete plan for every currently verified import table, and owner/foreign-key integrity. Any previously empty table without a verified import contract hard-blocks cutover if it becomes non-empty; it cannot be accepted for archival. Mixed global/user workout presets require exact, non-overlapping seed/import row partitions. It is validation-only; the final bundle and import remain gated.
- Rollback control preparation now has an executable write gate and bounded packet validator. A provider-probed `WRITE_MODE=disabled` Worker version can halt API/webhook mutations and auth-side identity creation while preserving health and mapped-user reads. Packet validation checks strict UTC/bounds, declared provider receipts, distinct version IDs, an external restricted-ledger contract, and an already distributable recovery client; it does not prove those provider resources exist. The production environment, actual ledger/probe, populated packet, and guard-version upload/readback remain gated.
- Full RefWatchCore verification is green after correcting two stale test fixtures without changing runtime behavior: 111 XCTest tests executed with 110 passed and 1 explicit skip, and 5 Swift Testing tests passed.
- Executable Apple verification is available. The iOS unit target passes 89/89 on iPhone 15 Pro Max/iOS 17.0.1 and the full UI target passes 19/19 non-skipped cases on iPhone 15 Pro Max/iOS 18.5. The watch scheme on a Series 9 (45mm)/watchOS 11.5 simulator passes all 11 UI cases and executes 111 unit cases with 107 passed, 0 failed, and 4 explicit simulator-host skips. The Apple runs corrected async identity invalidation, authenticated UI-test persistence composition, deterministic reference/history fixtures, end-period confirmation, the shootout early-decision condition, manual halftime routing, and penalty-panel accessibility containment. Watch/widget version alignment is verified at `0.8.2 (1)`. Two iOS UI cases remain explicitly skipped for unavailable product surfaces; physical iPhone/watch acceptance remains pending because both devices were offline during the final audit.

## Decision Log
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
- Decision: Fail closed when a verified Clerk subject has no reviewed internal-user mapping; the `ALLOW_UNMAPPED_CLERK_USERS` escape hatch is development-only and must be absent or false in production.
  Rationale: Creating random internal UUIDs would disconnect users from their preserved records and violate the migration identity contract.
  Date/Author: 2026-07-14 / Codex

## Testing Approach
- API: install, typecheck, Vitest, Wrangler type generation and deploy dry-run; cover malformed auth, `/api/me`, tenant isolation, owner spoofing, ingest idempotency/transactions, OpenAI proxy behavior, parser fixtures, and webhook signatures.
- Swift: targeted auth/backend/repository tests, then repository-mandated iOS build and test commands.
- Shared/watch regression: `swift test --package-path RefWatchCore` plus full watchOS unit/UI execution where destinations are available. Timer/haptics/match lifecycle behavior must remain unchanged unless an executable regression proves a product defect; any such fix requires focused coverage and full scheme reruns.
- Security: search source/config/project products and built artifacts for removed Supabase config and forbidden server secrets.
- Provider cutover: disposable PlanetScale branch apply/readback, export/import counts and referential checks, staging Worker health/auth/CRUD/stream proof, and documented rollback before production cutover.

## Constraints & Considerations
- Preserve user-owned dirty files and never inspect or hand-edit `.projects` or generated `.env` files.
- No PlanetScale, Clerk secret/JWT private key, webhook secret, or OpenAI key may enter the iOS target.
- Do not trust client `owner_id`, parse Clerk subjects as UUIDs, remove SwiftData offline/backlog behavior, or change watch match lifecycle behavior.
- Hard deletes and timestamp-only incremental cursors are insufficient for multi-device deletion propagation; use tombstones or explicitly documented reconciliation semantics.
- Provider provisioning/deployment and live data/account cutover require readback evidence; missing provider access or physical-device proof must be reported as a gap.

## Outcomes & Retrospective
- Repository foundations, active iOS backend routing, API review remediation, a preliminary source snapshot, disposable PlanetScale schema/reference-data rehearsal, staging infrastructure connectivity, focused database integration, and simulator iOS/watch acceptance are in progress. No production deployment/import/cutover is claimed. Final outcomes remain pending identity decisions/mapping, final import and reconciliation, production Hyperdrive/Worker plus authenticated staging route proof, broader database/deployed tests, physical iPhone/watch acceptance, compatibility cleanup, and end-to-end provider evidence.

## Collaboration Review Log
- Planning code-risk reviewer: recommended Postgres/Hyperdrive, explicit identity readiness, owner-safe mutations, webhook signing, contract-first routes, and delayed Supabase dependency removal. Applied to the plan.
- Planning docs/evidence reviewer: required exec-plan artifacts, broader architecture/security docs, detailed schema/cutover evidence, and honest partial-acceptance language. Applied to the plan.
- API implementation reviewer: reported findings in assessment ownership, schedule references, JSONB serialization, idempotency, parser contract, tests, deletion sync/webhook ordering, OpenAI abuse controls, and deployment typing/bindings. The API remediation batch applied findings 1-4 and 7-9; the legacy parser normalization contract was subsequently ported and locally tested. The later real-Postgres match suite supersedes the earlier missing-database-proof status; broader CRUD plus Clerk/Hyperdrive authenticated deployed proof, production provider deployment, and data import remain explicit pre-cutover gates.
- Documentation/governance batch: incorporated the live Supabase MCP identity/count/RLS readback, server/client secret boundary, provider cutover/rollback runbook, and truthful partial status across canonical docs. Applied on 2026-07-14.
- Documentation reviewer: found two stale path/terminology issues and one pre-existing toolchain-version inconsistency. All were applied in the documentation batch.
- Reference-catalog batch: added authenticated, season-bounded Worker reads, target Drizzle tables/migration with a portable idempotent 5-competition/54-team seed, and a vendor-neutral Swift service. Unit/route coverage verifies bearer protection, seed cardinality, and contract decoding; provider migration application/readback remains a cutover gate.
- Reference-catalog reviewer: found missing source validation checks, possible team/competition season drift, and low-risk mutable registry debt. Database checks plus a composite season foreign key were added in migration `0003`; the registry pattern remains compatibility debt for later composition cleanup.
- Cutover code-risk reviewer `/root/code_risk_plan_review`: found cold-launch false logout/data deletion, unsafe just-in-time UUID creation, venue cast risk, missing persisted offline identity, event-reference parity, webhook ordering, and database-test gaps. The false logout, fail-closed mapping, safe cast, migration ordering, persisted cache, and event-reference transport are applied. The latest review also found UUID-case, query-amplification, and unrelated-team event-reference gaps; batching, bounds, normalization, and participating-team enforcement resolved them. The real-Postgres match suite supersedes the focused database gap; webhook ledger/ordering, populated event-reference transport, broader CRUD, and authenticated deployed proof remain explicit gates.
- Cutover docs/evidence reviewer `/root/docs_evidence_plan_review`: found stale source counts/table coverage, missing identity disposition/evidence artifacts, stale assistant architecture, insecurely underspecified secret ingestion, and incomplete rollback. Canonical counts, schema/product/runbook docs, secure secret handling, and timestamped artifacts are applied; production domain/identity decisions and the final operational rollback packet remain gated.
- Staging/evidence re-reviews: the docs reviewer required the preliminary/final snapshot split, five-table rehearsal correction, Clerk verification fallback wording, reproducible staging/global-data evidence, and narrower secret-audit claims. All were applied. The stronger audit found legacy migration/config resources in the app bundle; synchronized-group exclusions—including the future local `Secrets.xcconfig` and migrations directory—now prevent packaging while preserving repository evidence.
- Final code-risk re-review: event-reference implementation findings are resolved and focused helper tests cover validation/batching behavior. Query-aware SQL assertions and the later 3/3 real-Postgres match suite supersede the earlier mock-only tenant/concurrency gap; populated event-reference transport plus broader CRUD and deployed proof remain.
- Final docs/evidence re-review: adjacent status docs, JWT-key comment, reviewer trail, scan scope, and bundle-enumeration evidence were synchronized. Production identity/import/authenticated routes/database tests/devices/rollback remain open.
- Parser/validator re-review: the three validator relation/disposition gaps were resolved with regression tests. Local match-sheet contract/normalizer parity is complete; authenticated deployed fixture and end-to-end proof remain open.
