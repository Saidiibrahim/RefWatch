---
task_id: 01
plan_id: PLAN_match-records-confirmation
plan_file: ./PLAN_match-records-confirmation.md
title: Implement records confirmation surfaces and verify platform builds
phase: Implementation
---

- [x] Add the watchOS records overview, team pages, and 3-page container using the existing page-swipe pattern.
- [x] Replace the watch completed-match detail timeline with the new records-first surface.
- [x] Add iOS records overview/team pages and the `Records` / `Timeline` segmented toggle while preserving journal loading behavior.
- [x] Add required previews for populated, sparse, and updated detail states on both platforms.
- [x] Run the required watchOS and iOS builds and record outcomes plus any pre-existing warnings.

## Evidence
- Shared grouping logic and edge-case coverage: `swift test --package-path RefWatchCore --filter CompletedMatchRecordsTests`
- watchOS build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' CODE_SIGNING_ALLOWED=NO build`
- iOS build fallback: `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'generic/platform=iOS Simulator' build`
