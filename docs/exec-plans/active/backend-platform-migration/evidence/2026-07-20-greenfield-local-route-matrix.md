# Greenfield Local Mounted-Route, Cursor, and Inactive-Ledger Evidence

Date: 2026-07-20 (Australia/Adelaide)

## Scope and boundary

This append-only artifact supersedes the local-test status of
`2026-07-17-local-route-matrix.md` without changing that historical artifact.
It records the completed local greenfield route/cursor batch after migrations
`0000` through `0016`.

The batch used only disposable loopback PostgreSQL and local simulator/test
processes. It did not call Clerk, PlanetScale, Cloudflare, Supabase, OpenAI, or
another provider; deploy a Worker; use a credential for provider
authentication/traffic or application runtime; activate production onboarding,
writes, traffic, or ledger capture; or perform physical-device acceptance. The
sole bounded credential handling was the audit script loading one locally
available value from `.env` in memory as a comparison fingerprint. No secret
value was printed, persisted, placed in evidence, or sent to a provider. The
OpenAI-backed route tests used strict local fetch stubs and failed on any
unexpected upstream URL.

This is hermetic implementation evidence, not production acceptance. The later
provider matrix must still prove real Clerk token and webhook verification,
PlanetScale/Hyperdrive mutation access, deployed routing, authenticated tenant
isolation and CRUD, bounded OpenAI behavior, iOS/watch behavior, writes, traffic,
and observation.

## Mounted-route coverage

`api/integration/routes.local.database.test.ts` now has 19 mounted Hono cases on
a fresh loopback-only PostgreSQL cluster:

1. missing `WRITE_MODE` fails closed before session verification;
2. eight concurrent `/api/me` requests bootstrap one exact-production,
   zero-legacy subject idempotently, while a deletion-tombstoned subject remains
   rejected;
3. missing/invalid bearer behavior and the authenticated deterministic 2026
   reference catalog;
4. team replacement bounds of 100 members, 25 officials, and 50 tags;
5. forced same-clock competition update/update ordering;
6. forced same-clock venue delete/resurrection ordering;
7. server-derived team/competition/venue ownership, ignored owner spoofing, and
   foreign-owner replacement rejection;
8. owner-scoped team/competition/venue tombstone synchronization;
9. scheduled-match active-reference validation, owner spoof rejection,
   isolation, and tombstone synchronization;
10. rejection of every foreign or soft-deleted match reference, including
    event team/member references;
11. full match bundle round-trip for periods, events, metrics, ownership, and
    tenant isolation;
12. preservation of historical match-event-to-team-member links across
    identical retries and retained-member updates, with nulling only after
    explicit member removal;
13. match-ingest idempotency and concurrent retry behavior, including
    owner-scoped idempotency keys;
14. owner-scoped match deletion and full soft-deleted bundle synchronization;
15. assessment create/update/isolation/conflict/tombstone behavior;
16. concurrent different-ID assessment creation for the same owner/match,
    returning one success and one documented conflict rather than a generic
    failure;
17. assistant SSE through a strict stub, without sending the server key in the
    upstream body;
18. match-sheet parsing through a strict stub with non-streaming,
    non-persisting upstream behavior; and
19. normal mounted writes with no ledger key, Queue, D1, cron, consumer,
    mutation-outbox, or delivery dependency.

The accompanying unit suite proves handler wiring and fail-closed behavior
against a mocked official `@clerk/backend/webhooks.verifyWebhook` boundary. The
18-case hermetic database suite enters below that cryptographic boundary and
proves real-Postgres lifecycle/idempotency/tombstone processing, including
exact-instance provenance checks, retries, delete-wins ordering, durable
delivery receipts, subject locks, and tombstones. Neither suite proves real
valid/invalid Clerk signature acceptance; that remains part of deployed
provider acceptance.

## Mutation and ownership contract

- Every protected route derives its internal owner from verified auth context;
  client owner fields are non-authoritative.
- Team child UUIDs are normalized before duplicate and ownership checks.
  Retained members/officials are bulk-upserted, only explicitly removed
  children are deleted, and oversized replacement arrays fail before mutation.
  This prevents an idempotent team retry from erasing historical
  `match_events.team_member_id` references through `ON DELETE SET NULL`.
- Scheduled matches, matches, assessments, teams, competitions, and venues
  reject foreign-owner references. Match and assessment creation also reject
  soft-deleted referenced rows.
- Assessment uniqueness for one owner/match is serialized with a sorted
  owner/match advisory-lock key. Lock order is the shared ledger barrier,
  entity ID, then sorted old/new owner/match keys. Concurrent different
  assessment IDs resolve to one success and one `409 assessment_conflict`.
- Mutable entities use namespace-qualified per-entity transaction advisory
  locks. The next `updated_at` is
  `max(request time, persisted updated_at + 1 millisecond)`. This
  preserves a strictly increasing version even when the request clock is
  forced to the same instant. Regressions cover same-clock update/update and
  delete/resurrection contention, including visibility of both changes.
- All five application writer files are classified and issue DML only through
  the reviewed mutation transaction wrapper. The two ledger control-plane
  writers remain classified separately.

## Incremental-sync contract

The Worker collection routes for teams, competitions, venues, schedules,
matches, and assessments use inclusive `updated_at >= updatedAfter` replay.
Inclusive replay prevents an equal-boundary row or tombstone from being lost.

The active Swift repositories for teams, competitions, venues, schedules, and
matches apply a shared collection policy:

- only a completed collection pull advances the in-memory high-water cursor;
  an individual push receipt never advances it;
- the first pull and every repository relaunch start at the Unix epoch, causing
  a full tombstone-inclusive reconciliation;
- later pulls subtract a 15-minute safety overlap from the last completed-pull
  cursor, clamped to the epoch;
- replayed active rows and tombstones apply only when strictly newer than the
  local remote version; and
- a remote replay never overwrites or deletes a locally dirty row.

The overlap addresses the reviewed late-commit race in which a request receives
its timestamp and blocks before commit while a later request commits first.
The implementation's bounded assumption is that application collection writes
are request-scoped, database-only transactions and settle within 15 minutes.
This is not an unbounded durable server cursor. A process relaunch deliberately
falls back to full epoch reconciliation, and future long-running/background
writers must either remain inside this bound or introduce a server-issued
monotonic cursor/revision contract.

The five focused `BackendCollectionCursorTests` prove:

- team, schedule, and match push acknowledgements cannot skip an earlier remote
  tombstone;
- a second schedule pull sends the actual 15-minute-overlapped query lower
  bound and retrieves a late-committing row; and
- equal/older replay and newer replay against dirty active/tombstone rows cause
  neither overwrite nor redundant publication.

## Inactive ledger

Normal `withMutation` work commits when there is no preparing, open, or
capture-enforced ledger epoch. The mounted fetch test provides no ledger key,
Queue, D1, cron, or consumer binding and observes no mutation-outbox or delivery
row. The separate hermetic database suite still opens an isolated epoch and
proves the historical strict capture behavior, then archives it. Production
ledger capture was not activated.

## Verification

| Check | Result |
| --- | --- |
| `npm run typecheck` | Passed |
| `npm test` | 193/193 passed |
| `npm run test:local:routes` | 19/19 passed after fresh migrations `0000`–`0016` |
| `npm run test:db` | 18/18 passed on disposable loopback PostgreSQL |
| `npm run mutation:coverage` | Passed: 36 schema tables; 23 capture-trigger tables; 13 explicit exclusions; 5 included application writer files; 2 control-plane writer files |
| `npm run dry-run -- --env production` | Passed with Wrangler 4.110.0; upload 1532.36 KiB, gzip 276.43 KiB; declared bindings were `HYPERDRIVE`, D1 `MUTATION_LEDGER`, Queue producer `MUTATION_LEDGER_QUEUE`, and `CF_VERSION_METADATA`; no cron or Queue consumer; production `WRITE_MODE` and onboarding remained disabled |
| Full `RefWatchiOSTests` | 76 XCTest + 18 Swift Testing = 94 passed, 0 failures, on iPhone 15 Pro Max/iOS 17.0.1; `** TEST SUCCEEDED **` |
| `BackendCollectionCursorTests` | 5/5 passed, 0 failures, 0.628 seconds, on simulator `RefWatch iPhone 15 Pro Max iOS 18.5`, iOS 18.5, with `CODE_SIGNING_ALLOWED=NO`; `** TEST SUCCEEDED **` |
| Generic iOS Release simulator build/readback | `** BUILD SUCCEEDED **`; readback was `CFBundleIdentifier=.RefWatch`, localhost backend, `pk_test_local_placeholder`, and no `CLERK_FRONTEND_API_HOST` plist entry. This is build proof, not production Release-configuration acceptance. |
| Repo-root available actual-value credential scan | Audit excluded `.git`, `.projects`, `node_modules`, `.env`, `.dev.vars`, and symlinks as implemented; 10,259 files checked against the one locally available fingerprint; 0 hits. Unavailable production secret values were not fingerprinted. |
| Fresh built-product/log available actual-value scan | The current Release-simulator `RefWatchiOS.app` plus three 2026-07-20 `RefWatchiOS` test-result bundles: 569 files checked against the one locally available fingerprint; 0 hits |
| Gitleaks 8.30.1 | Exact post-five-finding/pre-final-review-trail snapshot: no leaks in the 511,420-byte tracked diff or 337,624 bytes of explicitly enumerated untracked non-`.projects` files; `.projects` remained uninspected |
| `git diff --check` | Passed |

The full iOS regression receipt was produced by:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' \
  -only-testing:RefWatchiOSTests CODE_SIGNING_ALLOWED=NO test
```

The focused cursor receipt was produced by:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'platform=iOS Simulator,name=RefWatch iPhone 15 Pro Max iOS 18.5,OS=18.5' \
  -only-testing:RefWatchiOSTests/BackendCollectionCursorTests \
  CODE_SIGNING_ALLOWED=NO test
```

The generic Release simulator build was:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The fresh built-product/log scan used the non-echoing local environment file
and these sanitized artifact classes:

```sh
node --env-file=.env scripts/audit-secret-values.mjs \
  '<Release-iphonesimulator RefWatchiOS.app>' \
  '<2026-07-20 RefWatchiOS xcresult 1>' \
  '<2026-07-20 RefWatchiOS xcresult 2>' \
  '<2026-07-20 RefWatchiOS xcresult 3>'
```

A broad Xcode 27 beta/iOS 18.5 run repeatedly aborted with an allocator
double-free while executing 15 unrelated legacy cases. The five affected
`BackendCollectionCursorTests` pass in that environment. This is a bounded
tool/runtime incompatibility, neither a product pass nor a product failure; the
94-case iOS 17.0.1 run is the fresh full-suite product receipt.

The production dry-run still references historical
`EXPECTED_DATABASE_ROLE_ID=vaqg84rqoedz`, which is documented read-only. Its
declared D1 and Queue-producer resources remain inert because modes are
disabled and no cron/Queue consumer is declared. The dry-run is therefore
build/configuration proof, not writable-runtime or inactive-resource absence
proof. This is distinct from the mounted local harness, which supplies no
ledger key, Queue, D1, cron, or consumer at all.

## Mandatory code-risk review

The first review found:

1. **HIGH** — wholesale team-child replacement could erase historical
   event/member links through foreign-key nulling;
2. **HIGH** — a collection cursor advanced by single-item push receipts, plus a
   first/relaunch pull that omitted tombstones;
3. **MEDIUM** — case-sensitive UUID duplicate/retention checks;
4. **MEDIUM** — inclusive replay that could overwrite dirty local rows or repeatedly rewrite
   equal/older rows; and
5. **MEDIUM** — a late-commit race that a simple inclusive boundary alone could
   not recover.

The team replacement became bounded, normalized, retained-ID bulk upsert plus
explicit removal. Cursor advancement became pull-only, first/relaunch sync uses
the epoch floor, subsequent pulls use the actual 15-minute overlap, and strict
local-version/dirty-row guards make replay idempotent.

The final **HIGH** finding was that concurrent same-clock mutations could publish
the same `updated_at`, allowing the strict-newer client rule to hide the later
mutation. Namespace-qualified per-entity locking and
`max(now, persisted + 1 millisecond)` versioning were applied across the
collection writers, with forced-clock update/update and delete/resurrection
regressions.

All findings were applied. The reviewer observed the 19/19 route suite pass on
four consecutive final runs. Final reviewer
`/root/route_matrix_code_risk_review` returned exactly `NO FINDINGS`.

## Mandatory docs/evidence review

The independent docs/evidence review reported six medium findings:

1. the route artifact recorded only the five focused cursor tests while current
   summaries still relied on the older 89/89 iOS receipt, and the generic
   Release build/configuration boundary was unstated;
2. the production dry-run omitted its declared bindings and read-only runtime
   role;
3. the credential-scan exclusions, exact corpora, tool version, and
   built-product/log scope were not reproducible; and
4. the webhook wording overstated mocked-verifier and below-crypto database
   coverage as independent signed-event verification; and
5. the scope denied all credential use even though the audit loaded one local
   value in memory as a comparison fingerprint; and
6. the Gitleaks corpus sizes drifted after applying the first five findings and
   were incorrectly described as a current-final receipt.

All six findings were applied through the exact full/focused/Release Apple
receipts and bounded Xcode 27 incompatibility, sanitized Wrangler
binding/role/mode inventory, reproducible source/diff scan scope, and precise
webhook crypto boundary above. The scope now classifies the sole bounded
in-memory fingerprint use and confirms that no value was printed or persisted.
Gitleaks was rerun after the first five findings; its exact
511,420/337,624-byte result is labeled as the post-five-finding,
pre-final-review-trail snapshot so this review-only append does not make a
self-referential current-corpus claim. After the review-only append, the
repo-root actual-value scan still reported one available fingerprint, 10,259
files, and zero hits, and `git diff --check` passed. Final reviewer
`/root/route_docs_consistency_review` returned exactly `NO FINDINGS`.
