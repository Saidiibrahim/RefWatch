---
task_id: TASK_04_schedule-match-sheets
plan_id: PLAN_schedule-match-sheets
plan_file: ./PLAN_schedule-match-sheets.md
title: Validate match-sheet transport and watch precedence end to end
phase: Phase 4 - Validation
---

- [x] Add model, persistence, aggregate, and precedence tests.
- [x] Run shared-core tests.
- [x] Run iPhone and watch build validation on primary simulator targets.
- [x] Record final outcomes, reviewer findings, and any intentional deferrals in the plan.

## Validation Evidence
- 2026-03-31: `swift test --package-path RefWatchCore --filter ScheduledMatchSheetTests` passed for the Team Library name-autofill follow-up.
- 2026-03-31: `xcodebuild test -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' -derivedDataPath /tmp/refwatch-teamlibrary-name-autofill CODE_SIGNING_ALLOWED=NO -only-testing:RefWatchiOSTests/SwiftDataScheduleStoreTests -only-testing:RefWatchiOSTests/MatchSheetImportViewModelTests -only-testing:RefWatchiOSTests/OpenAIMatchSheetImportServiceTests` did not reach product assertions in this validation window:
  - one run stopped with `Early unexpected exit, operation never finished bootstrapping - no restart will be attempted. (Underlying Error: Test crashed with signal kill before establishing connection.)` in `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-52-41-+1030.xcresult`
  - a clean rerun later stopped during app launch with `FBSOpenApplicationServiceErrorDomain Code=1` / `RequestDenied` from `SBMainWorkspace`, with underlying `FBProcessExit Code=64 "The process failed to launch."`, in `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-56-01-+1030.xcresult`
- 2026-03-31: `xcodebuild test -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' -derivedDataPath /tmp/refwatch-teamlibrary-name-autofill CODE_SIGNING_ALLOWED=NO -only-testing:RefWatchiOSUITests/MatchSheetImportUITests` reached the updated upcoming-match editor and the new `team-name-autofill-home` control in the runner trace, but the class xcresult at `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-58-17-+1030.xcresult` ended with `Test crashed with signal kill.`
- 2026-03-31: `xcodebuild build -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' -derivedDataPath /tmp/refwatch-teamlibrary-name-autofill CODE_SIGNING_ALLOWED=NO` passed.
- 2026-03-30: `swift test --package-path RefWatchCore --filter ScheduledMatchSheetTests` passed after the follow-up pass, including the shared resolver fix that unblocked the broader simulator build.
- 2026-03-30: `xcodebuild test -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' -derivedDataPath /tmp/refwatch-teamrecord-decouple CODE_SIGNING_ALLOWED=NO -only-testing:RefWatchiOSTests/SwiftDataScheduleStoreTests -only-testing:RefWatchiOSTests/MatchSheetImportViewModelTests -only-testing:RefWatchiOSTests/OpenAIMatchSheetImportServiceTests` passed.
- 2026-03-30: Post-fix reruns of `RefWatchiOSUITests/MatchSheetImportUITests` on `iPhone 15 Pro Max (iOS 17.0.1)` stopped in the simulator/XCTest harness rather than at a product assertion:
  - a class rerun ended with `Failed to get matching snapshots: Error getting main window Unknown kAXError value -25218`
  - single-test reruns of `testHomeSideImportReviewApplyAndSave` then stopped in the simulator/XCTest harness before the assertion path completed
  - this was later superseded by the 2026-03-31 optional-sheet hardening pass, which reran `RefWatchiOSUITests/MatchSheetImportUITests` cleanly in `/tmp/refwatch-optional-sheet-ui-20260331g.xcresult`
- 2026-03-30: `xcodebuild build -quiet -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' -derivedDataPath /tmp/refwatch-teamrecord-decouple CODE_SIGNING_ALLOWED=NO` passed after fixing an unrelated shared `ScheduledMatchSheet` compile error exposed by the broader scheme build.
- 2026-03-30: `SwiftDataScheduleStoreTests` now includes follow-up coverage for `UpcomingMatchEditorView.scheduledMatchForSave(...)`, proving existing `homeTeamId` / `awayTeamId` pass through on edit, imported `sourceTeamId` / `sourceTeamName` survive save, and new schedules do not mint team IDs from editor state.
