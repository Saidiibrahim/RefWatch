# PLAN_match-lifecycle-haptics

## Purpose / Big Picture
Refactor match lifecycle haptics so period-boundary and halftime-expiry cues are expressed semantically in shared code, while playback sequencing and cancellation remain platform-adapter responsibilities.

## Context and Orientation
- Shared protocol surface: `RefWatchCore/Sources/RefWatchCore/Protocols/MatchLifecycleHapticsProviding.swift`
- Shared timer service: `RefWatchCore/Sources/RefWatchCore/Services/TimerManager.swift`
- Shared lifecycle view model: `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift`
- watchOS adapter: `RefWatchWatchOS/Core/Platform/Haptics/WatchMatchLifecycleHaptics.swift`
- iOS adapter: `RefWatchiOS/Core/Platform/Haptics/IOSMatchLifecycleHaptics.swift`
- Product and architecture docs: `docs/product-specs/match-timer.md`, `docs/design-docs/architecture/*.md`
- Release verification guidance: `docs/references/process/release-checklist.md`

## Plan of Work
1. Add a dedicated lifecycle-haptics protocol in `RefWatchCore` and keep it separate from generic `HapticsProviding`.
2. Inject lifecycle haptics into `TimerManager` and `MatchViewModel`, replacing direct watch playback in shared timer code.
3. Persist halftime-expiry cue dedupe state across unfinished-session restore.
4. Implement watch-owned repeated sequencing (`3 x 0.4s`) and iOS-owned conservative one-shot playback.
5. Add deterministic tests for lifecycle cue requests, repeated scheduling, and cancellation.
6. Update docs and release guidance so they match the new ownership split and validation expectations.

## Concrete Steps
- (TASK_01_match-lifecycle-haptics.md) Implement lifecycle-haptics protocol/adapters, add tests, and synchronize docs/release evidence.

## Progress
- [x] TASK_01_match-lifecycle-haptics.md

## Surprises & Discoveries
- The old natural-boundary regression test was stale: it expected `isHalfTime == true` after manual period end even though the current product flow transitions to `waitingForHalfTimeStart`.
- `TimerManager` could replay halftime-expiry haptics after restore because the old in-memory dedupe flag was not persisted.
- Repeated lifecycle haptics need cancellation semantics that generic UI haptics do not, so overloading `HapticsProviding` would have leaked watch-specific behavior into iOS.
- `MatchRootView`'s internal injected-`MatchViewModel` seam was unsafe on watchOS because it could bypass lifecycle-haptics, runtime-session, and persisted-session wiring that the production-owned constructor guarantees.

## Decision Log
- Decision: Introduce `MatchLifecycleHapticsProviding` instead of extending `HapticsProviding`.
- Rationale: lifecycle cues require repeated-sequence/cancellation semantics and different cross-platform policies, while generic UI haptics must remain simple.
- Date/Author: 2026-03-23 / Codex

- Decision: Persist halftime-expiry cue dedupe in `TimerManager.PersistenceState`.
- Rationale: unfinished-session restore must not replay the cue after relaunch once halftime expiry has already been acknowledged.
- Date/Author: 2026-03-23 / Codex

- Decision: Keep repeated sequence policy watch-local (`3 x 0.4s`) and internal-only for v1.
- Rationale: this preserves semantic shared call sites, avoids user-facing configuration scope, and prevents iOS behavior drift.
- Date/Author: 2026-03-23 / Codex

- Decision: Remove the internal injected-`MatchViewModel` `MatchRootView` branch on watchOS.
- Rationale: the seam was only a latent test/helper path, but it could construct a root view without lifecycle-haptics, runtime-session, or persisted-session ownership, weakening the watch app's invariants.
- Date/Author: 2026-03-23 / Codex

## Testing Approach
- Core unit tests:
  - `swift test --package-path RefWatchCore --filter MatchViewModel_EventsAndStoppageTests`
  - `swift test --package-path RefWatchCore --filter TimerManagerTests`
- watchOS unit tests:
  - `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:'RefWatch Watch AppTests/WatchMatchLifecycleHapticsTests'`
  - `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:'RefWatch Watch AppTests/PersistedActiveMatchSessionStoreTests'`
- Required watch compilation gate:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- Optional broader core regression sweep:
  - `swift test --package-path RefWatchCore`
- Physical-watch verification remains required for tactile feel and “no late pulses after transition/reset”.

## Validation Evidence
- `swift test --package-path RefWatchCore --filter MatchViewModel_EventsAndStoppageTests` passed in the closure batch after the watch-root seam removal, preserving the semantic lifecycle cue dedupe plus cancellation coverage through manual halftime, penalties flow, reset, and abandonment paths.
- `swift test --package-path RefWatchCore --filter TimerManagerTests` passed in the closure batch, preserving the halftime-expiry cue, restore, and cancellation coverage.
- `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:'RefWatch Watch AppTests/WatchMatchLifecycleHapticsTests'` passed in the closure batch, including the new replay/cancel proof that a replacement lifecycle cue cancels pending pulses from the older sequence before the new `3 x 0.4s` sequence completes.
- `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:'RefWatch Watch AppTests/PersistedActiveMatchSessionStoreTests'` passed in the closure batch, proving a persisted `didRequestHalftimeDurationCue == true` snapshot round-trips through `PersistedActiveMatchSessionStore` and does not replay `.halftimeDurationReached` after `MatchViewModel.restorePersistedActiveMatchSessionIfAvailable()`.
- `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build` succeeded in the closure batch, confirming the watch app still compiles after removing the injected `MatchRootView` seam.
- `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'generic/platform=iOS Simulator' build` had already succeeded in the initial implementation phase; the closure batch did not touch iOS wiring, so that companion-app compile proof was not rerun.
- `swift test --package-path RefWatchCore` still reports only the documented unrelated baseline failures in `AggregateSyncPayloadTests.testDeltaPayloadRoundTrip` and `ExtraTimeAndPenaltiesTests.test_penalty_attempt_logging_and_tallies`; lifecycle-haptics coverage in this initiative passed.
- `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'` built the watch targets but stalled at a simulator UI-test runner launch failure (`com.IbrahimSaidi.RefWatch-Watch-AppUITests.xctrunner` denied by the simulator workspace service), so full watch-simulator test proof remains blocked outside the refactor.
- Physical-watch validation still remains required for tactile feel and to confirm no late lifecycle pulses after transition/reset/abandon/end flows.

## Constraints & Considerations
- Scope excludes generic view-level haptics and the unrelated direct watch haptic in `PenaltyManager`.
- Shared services must remain free of direct WatchKit/UIKit haptic playback.
- Manual transitions must not double-fire lifecycle cues or allow queued pulses to leak into the next state.

## Outcomes & Retrospective
- Shared timer/lifecycle code now emits semantic cues through `MatchLifecycleHapticsProviding` instead of calling platform haptic APIs directly.
- Half-time expiry dedupe now persists across restore/relaunch, preventing replay after the cue has already been requested.
- watchOS owns the repeated `3 x 0.4s` lifecycle sequence and cancellation policy in one adapter, while iOS preserves the existing one-shot boundary behavior and no-op halftime expiry.

## Evidence Trail (Sub-Agents)
- Code-risk review (planning phase):
  - Finding: repeated-sequence semantics and cancellation should not be added to generic `HapticsProviding`; `TimerManager` needed injection plus persisted halftime dedupe.
  - Applied: introduced `MatchLifecycleHapticsProviding`, injected it through `MatchViewModel`/`TimerManager`, and persisted halftime cue state.
- Docs/evidence review (planning phase):
  - Finding: repo docs promised platform-agnostic shared services, but `TimerManager` still called WatchKit directly.
  - Applied: synchronized architecture/product/testing/process docs to the new semantic-cue + adapter-owned playback model.
- Docs/evidence review (implementation phase):
  - Finding: docs needed to keep `PenaltyManager` as an explicit out-of-scope exception and include abandonment in queued-pulse cancellation guidance.
  - Applied: narrowed the code-style rule to shared timer/lifecycle services, kept `PenaltyManager` as follow-up debt, and updated launch/release/product/watch architecture docs to mention abandonment cancellation.
- Code review (implementation phase):
  - Finding: no concrete regressions identified in lifecycle dedupe/cancellation, view-model/timer wiring, or platform adapter integration beyond the unsafe internal `MatchRootView` injection seam.
  - Applied: removed the seam, added focused watch replay/cancel coverage, and added persisted restore proof that the pre-requested halftime cue does not replay.
