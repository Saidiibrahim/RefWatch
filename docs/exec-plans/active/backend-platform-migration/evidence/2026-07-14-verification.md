# Verification — 2026-07-14

## API

Run from `api/`:

```sh
npm run typecheck
npm test -- --run
./node_modules/.bin/wrangler deploy --dry-run --env staging
```

Results:

- TypeScript typecheck: exit 0
- Vitest: 9 files passed, 47 tests passed. The later rollback batch added
  emergency API/webhook write-gate and operational-packet validation coverage.
- Real PlanetScale Postgres integration: 1 file passed, 3 tests passed. The
  match route rejected cross-tenant references and spoofed owners, serialized
  concurrent idempotency claims, rejected changed-body key reuse, and scoped
  reads/deletes to the resolved owner. See
  `2026-07-14-database-integration.md` for credential/cleanup boundaries.
- Match-sheet contract coverage includes 200-character team names, 255-character
  filenames, 8 MiB per image URL, 24 MiB aggregate image input, bounded output
  arrays/strings, and `max_output_tokens=8000`. Current official Structured
  Outputs guidance and the Responses OpenAPI schema were checked for the schema
  keywords and request parameter used.
- Wrangler: `4.110.0`, dry-run exit 0
- Final dry-run upload: 1469.25 KiB, gzip 263.12 KiB
- Staging bindings: Hyperdrive `HYPERDRIVE`,
  `REFWATCH_ENV="staging"`, and `ALLOW_UNMAPPED_CLERK_USERS="false"`
- Staging rollback binding: `WRITE_MODE="enabled"`
- Staging deployment/readiness evidence:
  `2026-07-14-staging-worker.md`

## RefWatchCore

Run with the full Xcode developer directory because Command Line Tools alone
cannot load the package macro plugin:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  swift test --package-path RefWatchCore --filter MatchEventReferenceTests

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  swift test --package-path RefWatchCore
```

Results:

- Targeted `MatchEventReferenceTests`: 2/2 passed. These prove Codable
  round-trip and backward compatibility when optional team references are
  absent; they are not database or end-to-end sync proof.
- Full Core verification: passed. XCTest executed 111 tests with 110 passed,
  0 failures, and 1 explicit skip; the separate Swift Testing runner passed
  5/5 tests.
- Two stale fixtures were corrected without changing runtime behavior. The
  aggregate round-trip now uses an instant exactly representable by the
  millisecond ISO-8601 wire contract. The penalty test now expects the existing
  lazy `penaltiesStart` event plus two attempts (`+3`, not `+2`).

## Apple Targets

Run from repository root with Xcode beta because the system default developer
directory contains only Command Line Tools:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'generic/platform=iOS Simulator' build

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'generic/platform=iOS Simulator' build-for-testing

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'platform=iOS Simulator,id=A14D4100-CCC5-4B05-AD82-39BA48742E49' \
  -parallel-testing-enabled NO -only-testing:RefWatchiOSTests test

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'platform=iOS Simulator,id=BA142766-1871-4873-80C4-5DE6BB7987CA' \
  -parallel-testing-enabled NO -only-testing:RefWatchiOSUITests test -quiet

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme 'RefWatch Watch App' \
  -destination 'platform=watchOS Simulator,id=348BD2BD-FA28-41F4-898E-37AA5882E242' \
  -parallel-testing-enabled NO -only-testing:'RefWatch Watch AppUITests' test

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme 'RefWatch Watch App' \
  -destination 'platform=watchOS Simulator,id=348BD2BD-FA28-41F4-898E-37AA5882E242' \
  -parallel-testing-enabled NO -only-testing:'RefWatch Watch AppTests' test
```

Results:

- Generic iOS simulator build, including embedded watch app: succeeded
- Generic build-for-testing, including unit and UI test bundles: succeeded
- iOS unit target on iPhone 15 Pro Max, iOS 17.0.1:
  89/89 passed after correcting `BackendIdentityProvider` invalidation to
  satisfy the async protocol requirement instead of selecting the no-op
  extension overload. A final explicit-result-path rerun also passed 89/89;
  its durable compact summary is in `2026-07-14-apple-test-receipts.md`.
- Full UI target on iPhone 15 Pro Max, iOS 18.5: 21 executed, 19 passed,
  0 failed, and 2 explicit skips. A final explicit-result-path rerun reproduced
  the same result; its durable compact summary is in
  `2026-07-14-apple-test-receipts.md`.
- The skips are bounded: the simulator attachment picker/fallback is not
  exposed by the current build, and theme selection is not exposed by the
  current Settings product surface.
- The first full run exposed an async identity-cache invalidation bug, missing
  deterministic Clerk/reference/history UI fixtures, an authenticated
  test-store composition error, a bypassed end-period confirmation, and stale
  UI element/navigation contracts. Those defects were corrected; the final
  full UI rerun is green.
- The pre-existing iOS 17.0.1 simulator can compile and run unit tests, but UI
  automation timed out under the installed Xcode beta. A same-model iPhone 15
  Pro Max simulator on iOS 18.5 completed the UI target without that harness
  stall.
- The full watch UI target passed 11/11 on an Apple Watch Series 9 (45mm),
  watchOS 11.5 simulator. It covers regular and extra-time/penalty lifecycles,
  restore states, first-kicker selection, score correction/undo, launch, and
  Settings. Authoritative bundle:
  `Test-RefWatch Watch App-2026.07.14_16-22-29-+0930.xcresult`.
- The full watch unit target executed 111 tests on the same simulator: 107
  passed, 0 failed, and 4 explicit `TimerFaceFactory` skips for the pre-existing
  simulator-host launch limitation. Authoritative bundle:
  `Test-RefWatch Watch App-2026.07.14_16-31-01-+0930.xcresult`.
- Combined watch scheme evidence is 122 executed, 118 passed, 0 failed, and 4
  explicit skips. The stable watchOS 11.5 runtime is authoritative; the
  available watchOS 26.2 beta runtime repeatedly lost the app/helper connection
  and was not used as acceptance evidence.
- Watch execution exposed and corrected three product defects: the shootout
  early-decision initial-round condition, manual halftime completion routing,
  and penalty-panel accessibility containment. UI-test fixtures, selectors,
  waits, scrolling, and lifecycle assertions were also aligned to the current
  product behavior.
- Physical iPhone 15 Pro Max and Apple Watch Series 9 verification: pending.
  Both devices are visible to Xcode but reported offline during the final audit.

Observed non-migration warnings include a missing `google-logo.pdf`, an
existing retroactive `CompletedMatch` conformance warning, deprecated iOS 17
`onChange` overloads, Xcode beta debugger-version lookup warnings, and a
diagnostics-only `simctl` lookup failure. The watch widget/parent version
mismatch found during test execution was corrected by aligning both targets to
marketing version `0.8.2`, build `1`. A subsequent Series 9 simulator build
exited 0 without the mismatch warning, and direct built-plist readback confirmed
`0.8.2 (1)` for both the watch app and widget extension. Physical-device
execution remains a release acceptance item.

## Dependency, Secret, and Built-Bundle Audit

The reproducible actual-value scanner loads forbidden credentials only in
process memory, never prints them, excludes credential source files
(`.env`, `.dev.vars`, `.projects`), and reports names/paths only on a match:

```sh
node --env-file=.env scripts/audit-secret-values.mjs .
node --env-file=.env scripts/audit-secret-values.mjs \
  ~/Library/Developer/Xcode/DerivedData/RefWatch-*/Build/Products/Debug-iphonesimulator/RefWatchiOS.app

find ~/Library/Developer/Xcode/DerivedData/RefWatch-*/Build/Products/Debug-iphonesimulator/RefWatchiOS.app \
  -type f | wc -l
find ~/Library/Developer/Xcode/DerivedData/RefWatch-*/Build/Products/Debug-iphonesimulator/RefWatchiOS.app \
  -maxdepth 1 -type f \( -name '*.sql' -o -name '*.md' -o -name '*.xcconfig' \) -print

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'generic/platform=iOS Simulator' build 2>&1 \
  | node --env-file=.env scripts/audit-secret-values.mjs --stdin xcodebuild-log

rg -n 'supabase-swift|github\.com/supabase' \
  RefWatch.xcodeproj/project.pbxproj \
  RefWatch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Results after a clean rebuild:

- Two available forbidden secret fingerprints were loaded (the local OpenAI
  key and managed development Clerk secret); repository source/config scan:
  3,858 files, zero actual-value hits.
- Full iOS `.app` after build-for-testing, including embedded watch app,
  Info.plists, binaries, test content, and dependency bundles: 86 files, zero
  actual-value hits. Bundle enumeration returned 86; the root legacy-resource
  `find` returned zero paths.
- Fresh Xcode build log: zero actual-value hits and `BUILD SUCCEEDED` detected.
- Supabase package URL scan in project and resolved package lock: zero hits.
- The audit cannot fingerprint credentials that are not available locally
  (production Clerk, database, webhook, or retired Supabase values). The
  Supabase package scan supplements that limitation; secret-name references in
  server code/docs are not credential values.

The stronger bundle audit initially found legacy SQL/Markdown and xcconfig
examples being copied as resources by Xcode's synchronized group. Those files
remain repository evidence but were excluded from target membership, including
the locally absent `Config/Secrets.xcconfig` and future files under the legacy
migrations directory; the clean
rebuild contains no `.sql`, `.md`, or `.xcconfig` at the app-bundle root.

Legacy SwiftData property names such as `ownerSupabaseId` and backend-adapter
source filenames under `Core/Platform/Supabase/` remain compatibility debt.
They do not link the Supabase SDK, but the source-name cleanup is still pending
and must preserve the existing SwiftData store schema.
