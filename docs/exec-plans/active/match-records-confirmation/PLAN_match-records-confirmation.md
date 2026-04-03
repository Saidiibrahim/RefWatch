# PLAN_match-records-confirmation

## Purpose / Big Picture
Replace the post-match watch timeline with a referee-friendly records confirmation flow and add an iOS `Records` / `Timeline` toggle that defaults to `Records`, while preserving sparse synced summaries and existing journal behavior.

## Context and Orientation
- watch history detail: `RefWatchWatchOS/Features/Match/Views/MatchHistoryView.swift`
- iOS history detail: `RefWatchiOS/Features/Match/MatchHistory/MatchHistoryDetailView.swift`
- shared event/domain formatting: `RefWatchCore/Sources/RefWatchCore/Domain/MatchEventRecord.swift`
- watch layout/theme anchors: `RefWatchWatchOS/Features/MatchSetup/Views/MatchSetupView.swift`, `RefWatchWatchOS/App/MatchRootView.swift`, `RefWatchWatchOS/Preview Content/PreviewSupport.swift`

## Plan of Work
1. Add dedicated watch records views for overview and per-team pages using the existing swipe pattern and watch theme/layout helpers.
2. Replace the watch completed-match detail timeline with the records-first 3-page experience while leaving the in-match log unchanged.
3. Add iOS records pages plus a segmented `Records` / `Timeline` toggle that preserves the score and self-assessment sections.
4. Extend preview coverage for records-first and empty/sparse data states on both platforms.
5. Verify watch and iOS builds and record any pre-existing warnings separately from new regressions.

## Concrete Steps
- (TASK_01_match-records-confirmation.md) Implement the records confirmation surfaces, previews, and build verification.

## Progress
- [x] TASK_01_match-records-confirmation.md

## Surprises & Discoveries
- Observation: The cleanest way to keep watchOS and iOS incident ordering aligned was a tiny shared `CompletedMatch.matchRecordsSections(for:)` helper plus focused `RefWatchCore` tests, instead of duplicating grouping logic in each UI target.
- Evidence: `swift test --package-path RefWatchCore --filter CompletedMatchRecordsTests` passed with 4/4 tests; both platform view stacks now call the same helper.
- Observation: The requested `iPhone 15 Pro Max` simulator destination was unavailable in this environment, so iOS verification needed the documented generic simulator fallback.
- Evidence: `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' build` failed with destination lookup error; retrying `-destination 'generic/platform=iOS Simulator'` succeeded.

## Decision Log
- Decision: Add a small shared `CompletedMatch.matchRecordsSections(for:)` helper plus targeted `RefWatchCore` tests, while leaving existing `RefWatchCore` models untouched.
- Rationale: The records grouping contract is shared by watchOS and iOS, and extracting that pure logic once avoids drift while staying within the user’s constraint against changing the underlying models.
- Date/Author: 2026-04-02 / Codex

## Testing Approach
- Build watch target:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' CODE_SIGNING_ALLOWED=NO build`
- Build iOS target:
  - `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' build`
  - fallback: `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'generic/platform=iOS Simulator' build`
- Preview validation:
  - compile watch and iOS preview code paths for populated and empty-event snapshots
  - note explicitly that Xcode canvas inspection is unavailable in this environment

## Constraints & Considerations
- Do not change `RefWatchCore` models.
- Keep `RefWatchWatchOS/Features/Timer/Views/MatchLogsView.swift` unchanged.
- Preserve original event order after filtering, except for yellow-before-red card grouping within the cards section.
- Sparse synced summaries may have `events == []`; overview must still render safely without invented incidents.

## Outcomes & Retrospective
- Outcome: Completed-match detail on watchOS is now a 3-page records confirmation flow with overview/home/away pages, while `MatchLogsView` remains the in-match timeline.
- Outcome: iOS detail keeps the existing score and self-assessment sections, then defaults to a `Records` segmented mode with a preserved `Timeline` fallback.
- Outcome: Preview coverage was expanded for overview, empty/sparse states, team pages, and detail-screen mode selection on both platforms.
- Verification:
  - `swift test --package-path RefWatchCore --filter CompletedMatchRecordsTests`
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' CODE_SIGNING_ALLOWED=NO build`
  - `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'generic/platform=iOS Simulator' build`
- Pre-existing / environment notes:
  - watch build reported the existing app-extension bundle-version warning: `CFBundleVersion of an app extension ('4') must match that of its containing parent app ('1')`
  - iOS build reported `Metadata extraction skipped. No AppIntents.framework dependency found.`
  - Xcode canvas previews were compiled through builds, but not visually inspected in this environment.
