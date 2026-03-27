# watchOS Architecture

WatchOS owns match/timer continuity and does not host the live assistant/OpenAI runtime. Keep AI assistant references in this repo iOS-only unless a future feature explicitly adds a watch handoff state.

## Entry Points
- `RefWatchApp.swift` configures the watch scene.
- `AppRootView` handles onboarding versus active match routing.
- `MatchRootView` hosts active match UI, timer face selection, actions sheets, and the watch-only lifecycle alert overlay.

## Core Services
- `TimerManager` controls match and period clocks, publishes state, and emits semantic lifecycle haptic cues through injected adapters rather than calling WatchKit directly.
- `MatchHistoryService` stores recent matches and supports restoration.
- `PenaltyManager` encapsulates foul tracking and notifications.
- `BackgroundRuntimeSessionController` manages an `HKWorkoutSession`-backed Match Mode runtime while a match is unfinished.
  - Required watch bundle metadata is `WKBackgroundModes = [workout-processing]` only. Match Mode does not depend on background audio, Apple Music, or media playback.
  - Scope includes kickoff waiting, in-play, paused, `PendingPeriodBoundaryDecision`, halftime waiting, halftime, second-half waiting, ET waiting, penalty waiting, active penalties, and the full-time screen before final completion/reset.
  - `MatchViewModel` persists a full `ActiveMatchSessionSnapshot` so unfinished matches can rehydrate timer anchors, penalty state, and lifecycle flags after process death or relaunch.
  - `PersistedActiveMatchSessionStore` writes the snapshot into the watch App Group so `MatchRootView` can restore it on launch before routing.
  - `RefWatchApp.swift` implements `WKApplicationDelegate.handleActiveWorkoutRecovery()` and hands recovered sessions back to the runtime controller through `MatchWorkoutRecoveryBroker`.
  - Natural period expiry is modeled in shared core as `PendingPeriodBoundaryDecision`: `MatchViewModel` transitions into that stable unfinished state, persists it, and only then emits `.periodBoundaryReached`. The actual `.periodEnd(...)` event is deferred until the referee explicitly commits the transition via `endCurrentPeriod()`.
  - `MatchLifecycleCoordinator` owns the canonical resume-route mapping for every unfinished state, including `PendingPeriodBoundaryDecision`, `waitingForHalfTimeStart`, and `waitingForPenaltiesStart`.
  - Reconciliation is triggered from `MatchRootView` on launch and on `.inactive` / `.active` scene-phase changes.
  - The repeating alert itself is not part of restore state. Rehydration returns to the stable waiting surface while watch-owned haptics remain foreground-only and non-resuming after interruption.
  - Platform boundary: an active workout session is the documented continuity path under watchOS workout-session semantics, but explicit user dismissal/app switching, revoked HealthKit permission, or system termination can still interrupt frontmost state.

## Timer Faces
- ``TimerFaceModel`` (protocol) defines read-only timer state and actions.
- ``TimerFaceStyle`` selects the active face via `@AppStorage("timer_face_style")`.
- ``TimerFaceFactory`` produces SwiftUI views (e.g., ``StandardTimerFace``) rendered inside `TimerView`.

## Feature Modules
- `MatchSetup`: handles team selections, rules, and kickoff routines.
- `Match`: renders live actions, score adjustments, and penalty logging.
- `Events`: displays chronological match events for quick review.
- `Settings`: hosts personalization and integration options.

## Substitution Entry Flow
- `MatchSetupView` launches watch event-entry destinations on the parent `NavigationStack`; substitution entry no longer owns a nested stack.
- `SubstitutionFlow` is a watch hub-and-spoke flow with local state ownership for:
  - ordered `player(s) off` selections
  - ordered `player(s) on` selections
  - destination routing to each spoke and optional confirmation
- The watch substitution hub allows either side to be entered first and keeps the hub as the state owner so selections survive navigation back from each spoke.
- The hub is intentionally stripped down for speed:
  - the top `Substitutions made` summary card is removed
  - `Player(s) off` and `Player(s) on` show shirt numbers only in the hub subtitle
  - if a selected player has no shirt number, the hub subtitle renders `?` for that slot
  - player names remain inside the roster/sheet selection spokes for disambiguation
- Participant resolution prefers frozen scheduled match sheets carried on the active match or schedule snapshot.
  - When both home and away sheets are `ready`, watch resolves `player(s) off` from the current on-field set and `player(s) on` from unused substitutes.
  - If a ready frozen sheet has no eligible candidates for a spoke, watch shows a blocked unavailable state instead of falling through to numeric/manual entry.
  - When a schedule has match-sheet fields but is not watch-ready, watch uses numeric/manual entry and does not silently mix live library roster members into the official participant path.
  - Legacy schedules with no match-sheet fields retain the old team-ID / exact-name library lookup only as backward compatibility.
- `Done` is enabled only when off/on counts match and are non-zero.
- If `Confirm Subs` is enabled, the hub still navigates to confirmation for single-pair substitutions.
- Multi-pair batches bypass confirmation and save directly from `Done`; this is the approved speed path for referees entering several substitutions at once.
- Manual numeric entry keeps entered numbers visible on the hub rows and uses keypad backspace as stack-style undo when the current buffer is empty.
- `MatchViewModel.recordSubstitutions(team:substitutions:)` performs the save boundary:
  - captures one timestamp / `matchTime` / `period` snapshot
  - emits one normal substitution event per ordered pair
  - increments team substitution tallies by batch size
  - suppresses stale single-substitution confirmation state after batch saves

## Watch-Specific Adapters
- `WatchHaptics` implements `HapticsProviding`.
- `WatchMatchLifecycleHaptics` implements `MatchLifecycleHapticsProviding` and owns the watch-only repeating lifecycle alert policy: `3 x 0.4s` pulses repeated every `3.0s` until explicit acknowledgment while the app is active.
- `WatchMatchLifecycleHaptics` starts natural period-boundary playback only after shared core has entered `PendingPeriodBoundaryDecision`; it does not own match-state progression or restore semantics.
- `LifecycleAlertOverlayView` is a watch-only blocking surface rendered by `MatchRootView`; it swallows background taps and keeps acknowledgment separate from timer-face interactions and from consuming `PendingPeriodBoundaryDecision`.
- Connectivity stubs exist for future watch-to-phone sync.

## Testing Notes
- Focus on ViewModel logic, persisted unfinished-match snapshots, and penalty/timer rehydration.
- Add watch-side coverage for the simplified substitution hub, number-only summaries, and manual keypad backspace undo behavior.
- Keep confirmation coverage explicit for the single-pair path while asserting multi-pair batches skip the confirmation surface.
- Lifecycle haptics must be validated at two levels:
  - shared/core tests assert `PendingPeriodBoundaryDecision` sequencing, semantic cue requests, dedupe, persisted restore behavior, and cancellation triggers
  - watch adapter tests assert repeating-cycle scheduling, acknowledgment, and queued-pulse cancellation
- Use watchOS simulator tests for routing/runtime-controller behavior and launch restoration.
- Release proof also requires verifying built watch bundle metadata, including `WKBackgroundModes = [workout-processing]` only.
- Treat simulator and physical-watch evidence separately:
  - simulator validates state restoration, routing, and compile-time HealthKit/workout integration
  - physical Apple Watch validation is still required for wrist-down return behavior, workout recovery timing, frontmost continuity under real watchOS power policy, tactile confirmation that lifecycle haptics do not arrive late after transition/reset, confirmation that natural period-boundary alerts start after the stable decision-state transition, and confirmation that foreground-only alerts do not resume after interruption/relaunch
