# PLAN_watch-match-runtime-continuity

## Purpose / Big Picture
Harden watchOS Match mode runtime continuity so active match flows (including halftime and penalties) remain resilient when watchOS drops foreground priority, while preserving the product boundary that Match mode is non-fitness and does not start `HKWorkoutSession`.

## Context and Orientation
- Runtime controller: `RefWatchWatchOS/Core/Services/Runtime/BackgroundRuntimeSessionController.swift`.
- Shared lifecycle logic: `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift`.
- Watch root lifecycle hooks: `RefWatchWatchOS/App/MatchRootView.swift`.
- Existing background-runtime tests: `RefWatchCore/Tests/RefWatchCoreTests/MatchViewModel_BackgroundRuntimeTests.swift`.
- Product/architecture docs: `docs/product-specs/match-timer.md`, `docs/design-docs/architecture/watchos.md`.
- App Review boundary reference: `docs/references/process/app-review-response.md`.

## Plan of Work
1. Refactor runtime session controller with a testable session-wrapper abstraction and reason-aware restart policy.
2. Centralize runtime eligibility in `MatchViewModel` so halftime, ET waiting states, and penalties stay protected.
3. Add root scene-phase reconciliation to re-arm runtime protection after returning active.
4. Expand automated tests for core transitions and watch runtime-controller restart/idempotency behavior.
5. Update docs/spec/process references to codify best-effort continuity and compliance boundaries.

## Concrete Steps
- (TASK_01_watch-match-runtime-continuity.md) Implement runtime hardening, transition-based sync, tests, and docs updates.

## Progress
- [x] TASK_01_watch-match-runtime-continuity.md
- 2026-02-28: Implemented runtime controller policy hardening, centralized MatchViewModel runtime sync, root scene-phase reconciliation, watch runtime-controller tests, and docs updates.

## Surprises & Discoveries
- `WKExtension.frontmostTimeoutExtended` is deprecated as "No longer supported" on modern watchOS SDKs, so continuity must rely on `WKExtendedRuntimeSession` plus robust resume behavior.

## Decision Log
- Decision: Keep Match mode on `WKExtendedRuntimeSession` only and do not introduce `HKWorkoutSession`.
- Rationale: Preserves existing product and App Review boundary between Match (non-fitness) and Workout (fitness).
- Date/Author: 2026-02-28 / Codex
- Decision: Use reason-aware restart behavior with bounded startup-failure retries instead of a fixed restart-attempt count.
- Rationale: Reduces restart thrash while improving resilience across valid invalidation scenarios.
- Date/Author: 2026-02-28 / Codex

## Testing Approach
- Core unit tests:
  - `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchCore -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' test`
- Watch tests:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' test`
- Physical-device matrix (Apple Watch Series 9 45mm):
  - first half wrist-down/raise
  - halftime wrist-down/raise
  - ET and penalties transitions
  - match end/reset stop behavior

## Validation Evidence
- Automated pass:
  - `swift test --package-path RefWatchCore --filter MatchViewModel_BackgroundRuntimeTests`
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:"RefWatch Watch AppTests/BackgroundRuntimeSessionControllerTests" test`
- Existing unrelated suite failures remain in broader test runs and are outside this runtime-continuity scope.
- Physical-device validation on Apple Watch Series 9 (45mm) remains required for final reliability sign-off.

## Constraints & Considerations
- Match mode remains non-fitness; no `HKWorkoutSession` in match runtime continuity path.
- Runtime continuity is best-effort under watchOS power/thermal/system constraints.
- Simulator runtime-session behavior can differ from physical hardware and must be interpreted separately.

## Outcomes & Retrospective
- Implemented controller hardening, state-centralized runtime sync, scene-phase reconciliation, tests, and docs updates in one pass.
- Final validation outcomes and physical-watch evidence should be attached to this plan as follow-up run artifacts.

## Evidence Trail (Sub-Agents)
- Code-risk review (planning phase):
  - Finding: `frontmostTimeoutExtended` is not a viable strategy and restart loops need reason-aware handling.
  - Applied: avoided frontmost-timeout API, implemented reason-aware restart policy with bounded startup-failure retries.
- Docs/evidence review (planning phase):
  - Finding: non-trivial reliability behavior requires active exec-plan artifacts and App Review boundary alignment.
  - Applied: created this active workstream and updated product/design/process docs accordingly.
