# PLAN_watch-match-runtime-continuity

## Purpose / Big Picture
Replace the prior best-effort extended-runtime model with a supported watchOS continuity architecture for unfinished matches, while keeping the product contract honest about what watchOS can and cannot guarantee.

## Context and Orientation
- Runtime controller: `RefWatchWatchOS/Core/Services/Runtime/BackgroundRuntimeSessionController.swift`
- Workout recovery hook: `RefWatchWatchOS/App/RefWatchApp.swift`
- Shared lifecycle logic: `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift`
- Persisted unfinished-match store: `RefWatchWatchOS/Core/Services/MatchLifecycle/PersistedActiveMatchSessionStore.swift`
- Watch root lifecycle hooks: `RefWatchWatchOS/App/MatchRootView.swift`
- Resume routing: `RefWatchWatchOS/Core/Services/MatchLifecycle/MatchLifecycleCoordinator.swift`
- Product/architecture docs: `docs/product-specs/match-timer.md`, `docs/design-docs/architecture/watchos.md`
- Release verification guidance: `docs/references/process/release-checklist.md`

## Plan of Work
1. Replace `WKExtendedRuntimeSession`-based Match Mode continuity with an `HKWorkoutSession`-backed runtime controller.
2. Persist every unfinished match state needed for relaunch recovery, including timer anchors, halftime waiting, and penalties.
3. Rehydrate persisted state on launch and centralize resume routing for every unfinished screen.
4. Fix halftime lifecycle so `waitingForHalfTimeStart` is a stable state instead of a transient hop.
5. Update docs/spec/release guidance so they match the implemented runtime and the remaining platform limits.

## Concrete Steps
- (TASK_01_watch-match-runtime-continuity.md) Implement workout-backed runtime, recovery, unfinished-match persistence, routing fixes, tests, and doc updates.

## Progress
- [x] TASK_01_watch-match-runtime-continuity.md
- 2026-03-12: Implemented an `HKWorkoutSession`-backed continuity controller, unfinished-match persistence/rehydration, centralized resume routing, and halftime waiting fixes; simulator validation landed, while physical-watch proof and release metadata verification remained pending.
- 2026-03-22: Updated current source so fresh build artifacts resolve to `WKBackgroundModes = [workout-processing]` only, removed watch Apple Music usage text, and narrowed the spec/architecture/release guidance to the corrected build configuration and current evidence limits.

## Surprises & Discoveries
- Apple’s current watchOS docs do not support an absolute “stay frontmost until completion” guarantee. They do document workout sessions as the supported way to keep an app onscreen while the session is active and to recover the active session on relaunch.
- `WKExtension.frontmostTimeoutExtended` is not a viable strategy on modern watchOS.
- Watch bundle validation fails when `WKBackgroundModes` goes beyond `workout-processing`.
- The exact product requirement therefore has to be interpreted as “supported continuity under workout-session semantics,” not as an unconditional foreground lock against explicit user action.

## Decision Log
- Decision: Replace Match Mode `WKExtendedRuntimeSession` continuity with `HKWorkoutSession`.
- Rationale: Apple documents workout sessions, not extended runtime sessions, as the supported mechanism for keeping the app onscreen during an active long-running watch session and for recovering that session after relaunch.
- Date/Author: 2026-03-12 / Codex

- Decision: Persist unfinished match state in App Group storage and route relaunch/deep-link recovery through a single coordinator mapping.
- Rationale: Runtime continuity is incomplete if process death or relaunch drops halftime, penalties, or pre-kickoff states onto the wrong surface.
- Date/Author: 2026-03-12 / Codex

- Decision: Treat `waitingForHalfTimeStart` as a first-class unfinished lifecycle state.
- Rationale: The halftime transition must survive relaunch and deep links without skipping directly into active halftime.
- Date/Author: 2026-03-12 / Codex

## Testing Approach
- Core unit tests:
  - `swift test --package-path RefWatchCore --filter 'MatchViewModel_BackgroundRuntimeTests|ActiveMatchSessionRestoreTests|PenaltiesStartFailureTests'`
- Watch simulator tests:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,id=294CB8D5-EA1C-4945-B3E2-C0F0C291A6D9' -derivedDataPath /tmp/refwatch-watch-runtime test -only-testing:"RefWatch Watch AppTests/BackgroundRuntimeSessionControllerTests" -only-testing:"RefWatch Watch AppTests/MatchLifecycleCoordinatorTests" -only-testing:"RefWatch Watch AppTests/PenaltiesStartFailureTests"`
- Watch UI restoration tests:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,id=294CB8D5-EA1C-4945-B3E2-C0F0C291A6D9' -derivedDataPath /tmp/refwatch-watch-runtime-ui test -only-testing:"RefWatch Watch AppUITests/RefWatch_Watch_AppUITests/testLaunchWithWaitingPenaltiesSnapshotOpensFirstKickerScreen" -only-testing:"RefWatch Watch AppUITests/RefWatch_Watch_AppUITests/testLaunchWithWaitingHalfTimeSnapshotOpensTimerSurface"`
- Physical-device matrix (Apple Watch Series 9 45mm):
  - wrist-down / wrist-raise during first half
  - halftime waiting restore
  - ET and penalties restore
  - relaunch with active workout-session recovery
  - explicit user exit behavior

## Validation Evidence
- Automated pass:
  - `swift test --package-path RefWatchCore --filter 'MatchViewModel_BackgroundRuntimeTests|ActiveMatchSessionRestoreTests|PenaltiesStartFailureTests'`
- Automated pass:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,id=294CB8D5-EA1C-4945-B3E2-C0F0C291A6D9' -derivedDataPath /tmp/refwatch-watch-runtime test -only-testing:"RefWatch Watch AppTests/BackgroundRuntimeSessionControllerTests" -only-testing:"RefWatch Watch AppTests/MatchLifecycleCoordinatorTests" -only-testing:"RefWatch Watch AppTests/PenaltiesStartFailureTests"`
- Watch simulator and UI validation:
  - Automated pass:
    - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,id=294CB8D5-EA1C-4945-B3E2-C0F0C291A6D9' -derivedDataPath /tmp/refwatch-watch-runtime-ui test -only-testing:"RefWatch Watch AppUITests/RefWatch_Watch_AppUITests/testLaunchWithWaitingPenaltiesSnapshotOpensFirstKickerScreen"` showed the waiting-penalties restore route returning to first-kicker selection.
  - Manual simulator proof:
    - launched `com.IbrahimSaidi.RefWatch.watchkitapp` on watchOS Simulator with an injected halftime-waiting snapshot via `simctl`
    - captured a simulator screenshot showing the app restored on the `Half Time` setup surface instead of idle/kickoff
  - Known simulator limitation:
    - repeated `xcodebuild` UI-automation runs for the halftime-waiting assertion were unstable / slow under the watch UI runner, so the halftime restore path is backed by manual simulator evidence in this turn rather than a clean XCTest pass
- Physical-watch validation:
  - Not yet captured in this turn. Required for final proof of wrist-down return behavior and real-device recovery timing.

## Constraints & Considerations
- RefWatch targets the supported watchOS continuity path for unfinished matches only when HealthKit workout authorization is granted and the watch bundle ships with `WKBackgroundModes = [workout-processing]` only.
- RefWatch cannot honestly claim an unconditional foreground lock until match completion because watchOS still permits explicit user dismissal/app switching and can terminate the process under system policy.
- Simulator evidence is necessary for code correctness but not sufficient proof of frontmost behavior on hardware.

## Outcomes & Retrospective
- The runtime architecture now targets Apple’s documented long-running-session model instead of relying on best-effort extended runtime behavior.
- The repository contract is stricter: any future continuity claim must distinguish supported workout-session continuity from impossible absolute frontmost guarantees.
- Release-safe closure still depends on corrected watch bundle metadata verification and physical-watch continuity proof.

## Evidence Trail (Sub-Agents)
- Code-risk review (planning phase):
  - Finding: continuity would be incomplete without workout recovery, persisted timer/penalty state, deep-link routing fixes, and a stable halftime waiting state.
  - Applied: added workout recovery, unfinished-match snapshots, centralized resume routing, URL scheme correction, and halftime lifecycle stabilization.
- Docs/evidence review (planning phase):
  - Finding: product/spec/release docs were stale once Match Mode moved onto `HKWorkoutSession`.
  - Applied: updated architecture, product spec, and release guidance to state the workout-backed runtime and the remaining watchOS limits explicitly.
