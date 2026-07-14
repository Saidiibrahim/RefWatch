# Review Dispositions — 2026-07-14

Two independent read-only review lanes were used per the collaboration process
on 2026-07-14. Both reviewed the uncommitted backend-migration batch and active
plan; the docs lane then re-reviewed the synchronized evidence batch.

## Code-Risk Review

Reviewer task: `/root/code_risk_plan_review`.

- Applied: suppress unresolved Clerk startup state so cold launch cannot erase
  local user data as a false logout.
- Applied: fail closed for unmapped Clerk users; no random internal UUID is
  created in production.
- Applied: explicit safe casts for venue coordinates and corrected migration
  dependency ordering.
- Applied: persist the Clerk-subject-to-app-user mapping for offline launches,
  revalidate it online, and remove it on invalidation/logout.
- Applied after re-review: distinguish local token unavailability from a server
  401/403, allow only the former (or transport failure) to use a same-subject
  offline mapping, and make invalidation subject-specific to avoid an old
  logout clearing a newly resolved account.
- Final targeted re-review: both medium findings above were confirmed resolved;
  no new high- or medium-severity issue was found.
- Applied: match-event sync carries optional team and team-member references
  through Core Codable, iOS upload/read adapters, and Worker ingest/read.
  Targeted Core round-trip/backward-compatibility tests pass. Worker validation
  now batches owner lookups, normalizes UUID case, bounds events, and rejects
  references outside the match's participating teams.
- Applied after final re-review: focused helper tests exercise uppercase Swift
  UUIDs, missing/cross-tenant and non-participating teams, member/team mismatch,
  and the two-query batching ceiling. The API suite is 24/24 across six files.
- Deferred gate: final repeatable-read reconciliation must cover any newly
  non-null event references; the two targeted Core tests are not end-to-end
  sync proof. A later real-Postgres suite supersedes the mock-only match-route
  tenant/concurrency gap, while populated event-reference transport remains.
- Partially closed gate: 3/3 real-Postgres match-route tests now cover focused
  isolation and concurrency. Broader CRUD and Clerk-authenticated
  Worker/Hyperdrive coverage remain.
- Deferred gate: enable Clerk webhooks only after identity reconciliation, or
  add an event ledger, so a pre-mapping deletion cannot be lost.
- Deferred gate: strengthen timestamp cursor/reconciliation and OpenAI
  rate-limit evidence.
- Latest staging review: the secret/binding boundary and connection cleanup were
  sound. Three medium event-reference findings (UUID case, unbounded query
  amplification, and unrelated owned teams) were applied as described above.

## Documentation/Evidence Review

Reviewer task: `/root/docs_evidence_plan_review`.

- Applied: replaced stale sample counts with the complete live 39-table source
  snapshot and recorded the one auth-only identity.
- Applied: documented all source reference tables and the assessment mood/data
  shape needed by the target.
- Applied: separated disposable PlanetScale proof from production completion.
- Applied: added evidence artifacts and secure interactive OpenAI secret
  handling.
- Applied after staging re-review: corrected Clerk/preliminary-source/catalog
  lifecycle wording, made the global reference/preset rehearsal reproducible,
  and added an actual-value source/config/app+watch/build-log scanner. That
  scanner exposed legacy SQL/Markdown/xcconfig files being packaged; Xcode
  synchronized-group exclusions now keep those repository artifacts out of the
  clean app bundle.
- Deferred gate: production Clerk domain/configuration and full identity
  mapping require owner decisions/provider work.
- Deferred gate: rollback duration, write ledger, and operational owner must be
  fixed before cutover.

## Final Re-review Disposition

- Docs/evidence re-reviews required explicit staging-versus-production wording,
  preliminary-versus-final snapshot lifecycle, the corrected five-table
  rehearsal count, Clerk JWT/JWKS wording, and reproducible staging/global-data
  evidence. These are applied across the active plan and canonical docs.
- The reviewers rejected an over-broad bundle-audit claim. A reproducible
  actual-value scanner was added; it found no available secret value but exposed
  legacy SQL/Markdown/xcconfig resources in the app bundle. Xcode membership
  exclusions fixed the packaging issue and cover the real local secrets path
  plus the legacy migrations directory.
- Final code re-review found no remaining high/medium implementation defect.
  Its earlier disposable-database requirement is superseded by query-aware SQL
  assertions and the 3/3 real-Postgres match-route suite; populated references,
  broader CRUD, and deployed authentication remain required.
- Final docs re-review found no high issue. Its remaining JWT comment, adjacent
  status wording, reviewer trail, scan-scope wording, and bundle-enumeration
  evidence were applied in this batch.
- Cutover-validator/parser re-review initially found composite reference-season,
  page-owner, preset-disposition, unsupported-table archival, mixed-partition,
  and match-sheet resource-bound gaps. The validator now hard-blocks any
  non-empty table without a verified import contract, requires duplicate-free
  exact mixed-preset partitions, and checks the reviewed relationships. The
  parser now uses a streaming 25 MiB request ceiling plus per-field, aggregate,
  output-array, and output-token bounds.
- Final code-risk and docs/evidence re-reviews found no remaining high- or
  medium-severity finding. Both independently reran the API verification at
  37/37 tests across seven files with typecheck passing; the docs reviewer also
  read back staging version `527852d7-8ec8-48c4-b4d0-c521a3308558` as the
  latest 100% deployment.
- The later Apple execution batch supersedes the earlier no-simulator status:
  89/89 iOS unit tests pass on iPhone 15 Pro Max/iOS 17.0.1. On iPhone 15 Pro
  Max/iOS 18.5, the full UI target executes 21 cases with 19 passed, zero
  failures, and two explicit product-surface skips. The stable Series 9
  (45mm)/watchOS 11.5 simulator then passed all 11
  watch UI cases; its unit target executed 111 cases with 107 passed, 0 failed,
  and 4 explicit simulator-host skips. The watch batch corrected the shootout
  early-decision condition, manual halftime routing, accessibility containment,
  and stale harness contracts. Physical iPhone/watch acceptance and the
  widget/parent build-number mismatch remain gates.
- Final Apple code-risk re-review found no high- or medium-severity issue. It
  independently confirmed the retained watch bundles and reported two low-risk
  harness/notification-consistency items: manual-sync fallback notification
  scoping and permissive optional UI helper behavior. These are recorded as
  follow-up debt because downstream assertions keep the current 11/11 UI run
  meaningful.
- Final Apple docs/evidence re-review found no high issue. Its three medium
  findings were applied: split iOS destination provenance, a durable final iOS
  unit/UI receipt with the missing unit command, and this explicit disposition.
  Its low finding corrected the plan's simulator-mandate wording.
- The subsequent release-metadata batch aligned the watch app and widget
  extension to marketing version `0.8.2`, build `1`. A Series 9 simulator build
  passed without the prior mismatch warning and built-plist readback confirmed
  both values. Physical iPhone and Apple Watch execution could not start because
  Xcode reported both connected devices offline.
- Mandatory release-metadata code-risk and docs/evidence reviews found no high-
  or medium-severity issue. Both independently confirmed the configuration
  scope and built-plist values; the docs review also confirmed that simulator
  evidence is not represented as physical or production acceptance.
- A later read-only PlanetScale provider recheck confirmed production `main`
  still has zero public tables while the rehearsal retains 26 public tables,
  six migration-ledger rows, and the expected 5/54/30/3/20 seeded or rehearsed
  reference/preset counts. Production remained untouched.
- A Stripe Projects CLI managed-service recheck confirmed Clerk linkage remains
  complete but its service configuration still has no production domain. All
  environment values remained redacted; production Clerk configuration still
  awaits the explicit domain decision.
- Rollback-batch docs/evidence review found no high issue and two medium
  bookkeeping gaps: the active-plan test count was stale and this reviewer
  disposition was absent. Both are corrected; current verification is 47/47
  tests across nine files plus a Wrangler `4.110.0` staging dry-run at
  1469.25 KiB (gzip 263.12 KiB).
- Rollback-batch code-risk review found no high issue and four medium risks.
  Write-stop now also suppresses auth-side unmapped-user creation, unknown
  explicit write-mode values fail closed, and tests cover both. Packet
  validation now requires strict unexpired UTC instants, percentage bounds, a
  restricted ledger namespace, and declared provider/guard/ledger probe
  receipts. Documentation no longer claims the syntactic validator proves
  provider resources: the absent production Wrangler environment and actual
  transactional mutation ledger/probe remain explicit pre-cutover blockers.
  Queued Clerk webhook retries must be reconciled before writes reopen.
