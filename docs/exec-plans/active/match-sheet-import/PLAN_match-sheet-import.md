# PLAN_match-sheet-import

## Purpose / Big Picture
Implement the simplified optional match-sheet contract for upcoming matches:
- referees can save a fixture without any match sheets
- imported or manual sheets are per-side optional data
- iPhone no longer exposes `Draft` / `Ready` UI
- iPhone keeps home/away names as free-text schedule data, with optional Team Library autofill from already-saved library teams only, changing only the visible name string
- watch consumes saved side-specific participants when available and falls back side-by-side when they are not

## Context and Orientation
- Product spec: `docs/product-specs/scheduled-match-sheets.md`
- iOS architecture: `docs/design-docs/architecture/ios.md`
- watchOS architecture: `docs/design-docs/architecture/watchos.md`
- Match timer behavior: `docs/product-specs/match-timer.md`
- Historical implementation context: `docs/exec-plans/active/schedule-match-sheets/PLAN_schedule-match-sheets.md`

## Plan of Work
1. Supersede the old all-or-nothing readiness language across product, architecture, and plan artifacts.
2. Keep the existing storage shape (`draft | ready`, SwiftData blobs, Supabase JSON, aggregate sync) but move promotion to the save boundary.
3. Simplify iPhone upcoming-match and match-sheet editor UX so sides are optional and status labels disappear.
4. Change watch participant resolution from fixture-level gating to side-level consumption and fallback.
5. Extend previews and tests so optional/no-sheet, one-side-saved, and imported-side flows are represented explicitly.
6. Re-run targeted shared-core, iPhone persistence, import UI, and simulator build validation.

## Concrete Steps
- (TASK_01_match-sheet-import.md) Update product/design/plan artifacts for the simplified optional-sheet contract.
- (TASK_02_match-sheet-import-preview-matrix.md) Carry forward the preview harness and validation matrix, but refresh the fixtures and assertions for optional-sheet save semantics.

## Progress
- [x] Preview harness and seeded import fixtures already exist from the earlier preview wave.
- [x] Product/design docs are being superseded to remove the old two-sided watch-ready contract.
- [x] Shared-core resolver and save-boundary promotion work are in scope for this wave.
- [x] iPhone editor/save/import simplification is in scope for this wave.
- [x] Validation outcomes are recorded for shared-core, persistence DTOs, and simulator build.
- [x] `MatchSheetImportUITests` now completes cleanly after stabilizing the XCTest query/wait strategy.

## Surprises & Discoveries
- The schedule model already had the right persistence boundary: home/away JSON sheet blobs locally and remotely. No schema change was needed.
- The real issue was contract drift, not missing storage: the repo intentionally preserved imported sheets as `draft` after apply/save and still documented the old two-sided watch gate.
- Watch substitutions were already centralized behind a shared resolver, which made the per-side fallback refactor cheaper than changing multiple independent flows.
- Goal and card entry still had direct manual-only branches, so the per-side saved-sheet work had to include those paths rather than substitutions alone.
- Existing live Supabase rows still contain legacy `draft` sheet payloads. This wave intentionally does not backfill them.
- The remaining UI-suite blocker was not an app crash. Earlier failing xcresults exposed deterministic XCTest issues: an overlong exact-text query, parse-button wait fragility, and one `Activation point invalid ...` failure caused by the test's own `isHittable` query.

## Decision Log
- Decision: upcoming-match save remains available without match sheets.
- Rationale: referees must still be able to schedule and run a match even when sheets are missing.
- Date/Author: 2026-03-30 / Codex
- Decision: `draft | ready` remains the internal stored contract, but iPhone does not surface those words to users.
- Rationale: changing storage shape was unnecessary; the user asked for a simpler UI, not a new persistence schema.
- Date/Author: 2026-03-30 / Codex
- Decision: watch consumes saved participants per side instead of requiring both sides before any side can use a sheet.
- Rationale: the user explicitly wants one saved side to help immediately while the other side remains manual.
- Date/Author: 2026-03-30 / Codex
- Decision: no schema migration or data backfill is applied in this wave.
- Rationale: live DB inspection showed nullable `jsonb` columns already support the contract, and the user explicitly rejected backfill.
- Date/Author: 2026-03-30 / Codex
- Decision: `UpcomingMatchEditorView` may offer Team Library autofill for the visible home/away name fields, but that picker must use already-saved library teams only and must not materialize reference teams, bind `TeamRecord` to the scheduled match, or rewrite stored provenance.
- Rationale: the PM asked to restore library-assisted naming without re-coupling scheduled sheets to mutable library identities or adding new library-write side effects.
- Date/Author: 2026-03-31 / Codex

## Testing Approach
- Shared/core:
  - `swift test --package-path RefWatchCore --filter 'ScheduledMatchSheetTests|CardDetailsTests|MatchViewModel_LibraryIntegrationTests|MatchViewModel_EventsAndStoppageTests/test_substitutionDisplayDescription_usesNamesAndNumbersWhenAvailable|ActiveMatchSessionRestoreTests/test_restoreRoundTrip_preservesFrozenMatchSheets|AggregateSyncPayloadTests/testSnapshotRoundTrip'`
- Historical optional-sheet baseline:
  - earlier validation in this initiative used booted iPhone 17 Pro simulator `3A595323-8860-4C9C-A56C-3DBE382E8B69` because the requested iPhone 15 Pro Max target stalled before booting in that environment
  - `xcodebuild test -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,id=3A595323-8860-4C9C-A56C-3DBE382E8B69' -derivedDataPath /tmp/refwatch-optional-sheet-tests-20260331c -resultBundlePath /tmp/refwatch-optional-sheet-tests-20260331c.xcresult CODE_SIGNING_ALLOWED=NO -only-testing:RefWatchiOSTests/SwiftDataScheduleStoreTests -only-testing:RefWatchiOSTests/SupabaseScheduleAPITests`
  - `xcodebuild test -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,id=3A595323-8860-4C9C-A56C-3DBE382E8B69' -derivedDataPath /tmp/refwatch-optional-sheet-ui-20260331g -resultBundlePath /tmp/refwatch-optional-sheet-ui-20260331g.xcresult CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -maximum-parallel-testing-workers 1 -only-testing:RefWatchiOSUITests/MatchSheetImportUITests`
- Current autofill-only follow-up expectation:
  - rerun the requested iPhone 15 Pro Max (iOS 17.0.1) regression slice and UI suite first
  - if the same simulator/XCTest harness failure recurs, record the exact error text and treat it as an environment blocker rather than proof of a product regression
  - 2026-03-31 follow-up reruns on `iPhone 15 Pro Max (iOS 17.0.1)` did recur in the harness rather than at a product assertion:
  - one targeted run stopped with `Early unexpected exit, operation never finished bootstrapping - no restart will be attempted. (Underlying Error: Test crashed with signal kill before establishing connection.)` in `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-52-41-+1030.xcresult`
  - a clean rerun later failed during app launch with `FBSOpenApplicationServiceErrorDomain Code=1` / `RequestDenied` from `SBMainWorkspace`, with underlying `FBProcessExit Code=64 \"The process failed to launch.\"`, in `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-56-01-+1030.xcresult`
- Full simulator build:
  - `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,id=9D882E4F-9064-42E5-A983-0FAFD75EB1D1' -derivedDataPath /tmp/refwatch-optional-sheet-build-20260331b CODE_SIGNING_ALLOWED=NO build`
- Database verification:
  - verify via `refwatch-database` that `scheduled_matches.home_match_sheet` / `away_match_sheet` remain nullable `jsonb` and no migration/backfill is applied

## Constraints & Considerations
- Do not break legacy schedules with both sheet fields absent.
- Do not add new persisted status values.
- Do not silently merge imported sides with existing entries.
- Keep player numbers visible in watch-side player selection rows whenever a side list exists.
- Keep the watch fallback rules concrete and side-specific instead of reintroducing fuzzy “watch-ready” wording.

## Outcomes & Retrospective
- Earlier preview-only work remains useful and stays in this initiative as implementation support, but it no longer defines the product contract.
- This plan now tracks the broader behavior change end to end: docs, iPhone UX, save semantics, watch consumption, persistence verification, and validation.
- Recorded optional-sheet baseline validation established:
  - targeted shared-core resolver/save tests passed locally, including `CardDetailsTests` and substitution display coverage
  - targeted watch support coverage passed in `SubstitutionFlowSupportTests`, including `#10 Name` / `#? Name` summary and confirmation formatting
  - targeted `SwiftDataScheduleStoreTests` and `SupabaseScheduleAPITests` passed in simulator validation
  - iOS simulator build passed
  - `MatchSheetImportUITests` passed cleanly on 2026-03-31 in `/tmp/refwatch-optional-sheet-ui-20260331g.xcresult`
- The current autofill-only follow-up adds UI coverage that should assert the new autofill buttons render distinctly from the removed source-team-binding controls and exercise local-team autofill using seeded saved-library teams in the signed-in UI-test shell once this wave is rerun.
  - 2026-03-31 rerun status: the requested iPhone 15 Pro Max regression slice did not reach product assertions in this wave; the two targeted reruns above stopped in simulator/XCTest harness failures instead of app-side test failures.
  - 2026-03-31 UI rerun status: `MatchSheetImportUITests` reached the updated upcoming-match editor and the new `team-name-autofill-home` control in the runner trace, but the class xcresult at `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-58-17-+1030.xcresult` ended with `Test crashed with signal kill.`
  - earlier failing UI xcresults did not show an app crash signature; they captured deterministic XCTest-side query/wait issues instead:
  - `/tmp/refwatch-optional-sheet-ui-20260331d.xcresult`: two parse-button wait failures
  - `/tmp/refwatch-optional-sheet-ui-20260331f.xcresult`: `Activation point invalid ...` triggered by the test's own `isHittable` query
