---
task_id: 02
plan_id: PLAN_match-sheet-import
plan_file: ./PLAN_match-sheet-import.md
title: Add Xcode Canvas previews for the iPhone match-sheet import flow
phase: Implementation and validation
---

- [x] Add a preview-only signed-in auth helper and typed match-sheet import fixtures.
- [x] Add preview-only state seeding for upload, parse progress/error, and import-review states.
- [x] Add preview matrices to `MatchSheetImportPickerSheet`, `MatchSheetEditorView`, `UpcomingMatchEditorView`, and `MatchesTabView`.
- [x] Prove preview declarations with `rg`.
- [x] Build `RefWatchiOS` for the installed `iPhone 15 Pro Max (iOS 17.0.1)` simulator with isolated DerivedData and `CODE_SIGNING_ALLOWED=NO`.
- [x] Run the focused import regression slice.
- [x] Capture or explicitly defer visual Canvas proof for each major preview group.

## Validation Notes
- Preview declaration proof: `rg -n "#Preview|PreviewProvider" "RefWatchiOS/Preview Content/PreviewSupport.swift" RefWatchiOS/Features/Matches/Views/UpcomingMatchEditorView.swift RefWatchiOS/Features/Matches/Views/MatchSheetImportPickerSheet.swift RefWatchiOS/Features/Matches/Views/MatchSheetEditorView.swift RefWatchiOS/Features/Matches/Views/MatchesTabView.swift`
- Build: `xcodebuild -quiet -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' -derivedDataPath /tmp/refwatch-match-sheet-preview-build-quiet CODE_SIGNING_ALLOWED=NO build`
- Focused tests: `xcodebuild test -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.0.1' -derivedDataPath /tmp/refwatch-match-sheet-preview-tests CODE_SIGNING_ALLOWED=NO -only-testing:RefWatchiOSTests/MatchSheetImportViewModelTests -only-testing:RefWatchiOSTests/OpenAIMatchSheetImportServiceTests -only-testing:RefWatchiOSUITests/MatchSheetImportUITests`
- Result: build passed; focused test slice passed with 8 tests total across unit and UI suites.

## Gaps
- Manual Xcode Canvas screenshots were deferred. This shell environment can prove preview declarations, compile them, and rerun the import regressions, but it cannot render Canvas and capture preview screenshots directly.
- The original `OS=latest` simulator destination was unavailable locally. Validation used the installed `iPhone 15 Pro Max (iOS 17.0.1)` simulator instead.
