---
task_id: 02
plan_id: PLAN_match-sheet-import
plan_file: ./PLAN_match-sheet-import.md
title: Refresh previews and validation for optional per-side sheets
phase: Implementation and validation
---

- [x] Keep the signed-in preview harness and typed import fixtures from the earlier preview wave.
- [x] Refresh preview naming and seeded saved-result fixtures so they no longer describe persisted imported sheets as `draft` user-facing states.
- [x] Update the upcoming-match and import UI to use optional-sheet actions only (`Add Manually`, `Edit`, `Import/Replace Screenshots`, `Remove Sheet`).
- [x] Add or update targeted tests for:
  - saving with no sheets
  - saving with one populated side only
  - imported-side review/apply/save
  - absence of legacy status labels in iPhone UI
- [x] Re-run the focused persistence validation slice and record the result.
- [x] Re-run the full UI suite to a clean XCTest completion with stabilized XCTest queries and waits.

## Validation Notes
- Shared/core resolver coverage now needs to prove:
  - save-boundary promotion to internal `ready`
  - one-side-saved / other-side-empty fallback behavior
  - saved card-participant resolution per side
- iPhone persistence coverage now needs to prove:
  - prepared one-side-only schedules survive SwiftData and Supabase round-trips
  - empty opposite-side shells remain safe and non-blocking
- UI coverage now needs to prove:
  - `Save` works without sheets
  - legacy `Draft` / `Ready` / `Mark Ready` / `Mark Draft` copy is gone
  - import review is in-memory until the parent upcoming-match `Save`

## Recorded Outcomes
- `swift test --package-path RefWatchCore --filter 'ScheduledMatchSheetTests|CardDetailsTests|MatchViewModel_LibraryIntegrationTests|MatchViewModel_EventsAndStoppageTests/test_substitutionDisplayDescription_usesNamesAndNumbersWhenAvailable|ActiveMatchSessionRestoreTests/test_restoreRoundTrip_preservesFrozenMatchSheets|AggregateSyncPayloadTests/testSnapshotRoundTrip'`
  - passed locally on 2026-03-31 after the post-fix watch/display adjustments
- `RefWatchiOSTests/SwiftDataScheduleStoreTests`
  - passed in targeted simulator validation on 2026-03-31
- `RefWatchiOSTests/SupabaseScheduleAPITests`
  - passed in targeted simulator validation on 2026-03-31
- `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,id=9D882E4F-9064-42E5-A983-0FAFD75EB1D1' -derivedDataPath /tmp/refwatch-optional-sheet-build-20260331b CODE_SIGNING_ALLOWED=NO build`
  - passed on 2026-03-31
- `xcodebuild test -project RefWatch.xcodeproj -scheme 'RefWatch Watch App' -destination 'platform=watchOS Simulator,id=294CB8D5-EA1C-4945-B3E2-C0F0C291A6D9' -derivedDataPath /tmp/refwatch-optional-sheet-watch-20260331a -resultBundlePath /tmp/refwatch-optional-sheet-watch-20260331a.xcresult CODE_SIGNING_ALLOWED=NO -only-testing:'RefWatch Watch AppTests/SubstitutionFlowSupportTests'`
  - passed on 2026-03-31, covering watch-side selection and confirmation summaries for `#10 Name` and `#? Name`
- `RefWatchiOSUITests/MatchSheetImportUITests`
  - passed cleanly on 2026-03-31 in `/tmp/refwatch-optional-sheet-ui-20260331g.xcresult`
  - earlier investigation artifacts showed test-side failures, not app/runtime crashes:
  - `/tmp/refwatch-optional-sheet-ui-20260331d.xcresult`: two parse-button wait failures
  - `/tmp/refwatch-optional-sheet-ui-20260331f.xcresult`: `Activation point invalid ...` caused by the UI test's own `isHittable` query
  - none of the inspected xcresults showed an app crash signature
- Stable simulator evidence was captured on booted iPhone 17 Pro simulator `3A595323-8860-4C9C-A56C-3DBE382E8B69` after the requested iPhone 15 Pro Max simulator stalled in this environment before producing a usable xcresult.

## Gaps
- Manual Xcode Canvas screenshots remain a tooling gap in this shell environment.
