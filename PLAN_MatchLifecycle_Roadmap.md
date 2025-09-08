## RefWatch Match Lifecycle Roadmap and Implementation Plan

### Purpose
This document captures the shared plan to modernize the match flow for professional referees on watchOS, summarizes what has been implemented so far, and outlines the next PRs with clear scope, acceptance criteria, and validation steps. Use this as the hand-off guide for ongoing work.

---

## Current Status (PR v1) ✅

Branch and PR
- Branch: `chore/standardize-time-and-clean-events`
- PR: https://github.com/Saidiibrahim/RefWatch/pull/4
 - Status: Completed ✅ (review passed)

Delivered in v1
- Time Units (seconds):
  - `Match.duration` and `Match.halfTimeLength` now modeled in seconds with correct defaults (90*60, 15*60).
  - Per‑period countdown initialized from model at match start/reset (no hard-coded 45:00).
- Logging/Timers:
  - Removed per‑tick debug logging; wrapped remaining logs with `#if DEBUG`.
  - Halftime timer updates on the main thread and is scheduled in `.common` run loop mode.
- Event Model Consolidation:
  - Removed legacy `MatchEvent` enum and dead navigation flows.
  - End-to-end use of canonical types: `GoalDetails.GoalType`, `CardDetails.CardType`, and `MatchEventRecord`.
  - Card flow driven by `CardEventFlow` + `CardEventCoordinator` only.
- UI Polish:
  - Kickoff and Full-time views display actual team names from `Match`.
  - Kickoff period duration label derived from match configuration (MM:SS ▼).
- Routing:
  - Selecting a saved match routes to kickoff if unstarted. `startMatch()` stamps `startTime`.
- Cleanup:
  - Deleted unused `TimerService`, `MatchStateService`, and orphaned `StartMatchDetailsView`.

Follow-up commit addressing review feedback
- Stoppage timer nil safety: guard `RunLoop.current.add` with `if let`.
- Added `deinit` to invalidate timers (prevent leaks/retain cycles).
- Clarifying comment on own‑goal mapping (opposite team scores) and verified logic.

Key files changed/added/deleted (v1)
- Model/VM:
  - `RefWatchWatchOS/Features/Match/Models/Match.swift`
  - `RefWatchWatchOS/Features/Match/ViewModels/MatchViewModel.swift`
- Events (canonical types, flows):
  - `RefWatchWatchOS/Features/Events/Models/MatchEventRecord.swift` (already present; used)
  - `RefWatchWatchOS/Features/Events/Views/GoalTypeSelectionView.swift`
  - `RefWatchWatchOS/Features/Events/Views/PlayerNumberInputView.swift`
  - `RefWatchWatchOS/Features/Events/Views/CardEventFlow.swift`
  - `RefWatchWatchOS/Features/Events/Views/CardRecipientSelectionView.swift`
  - `RefWatchWatchOS/Features/Events/Views/CardReasonSelectionView.swift`
  - `RefWatchWatchOS/Features/Events/ViewModels/CardEventCoordinator.swift`
- UI polish and routing:
  - `RefWatchWatchOS/Features/Match/Views/MatchKickOffView.swift`
  - `RefWatchWatchOS/Features/Timer/Views/FullTimeView.swift`
  - `RefWatchWatchOS/Features/Match/Views/StartMatchScreen.swift`
- Deleted legacy/unused:
  - `RefWatchWatchOS/Features/Events/Models/MatchEvent.swift` (deleted)
  - `RefWatchWatchOS/Core/Services/TimerService/TimerService.swift` (deleted)
  - `RefWatchWatchOS/Core/Services/MatchStateService/MatchStateService.swift` (deleted)
  - `RefWatchWatchOS/Features/MatchSetup/Views/StartMatchDetailsView.swift` (deleted)

Manual QA done for v1 (high level)
- Kickoff shows correct per‑period durations for 40/45/50‑minute setups.
- Pause/resume works; stoppage accumulates and displays `+mm:ss`.
- Half‑time elapsed updates continuously (including during UI interactions/scrolls).
- Second‑half kickoff auto‑selects opposite team; confirm starts second half.
- Regular goal and own‑goal update correct side scores; `MatchEventRecord` entries created.
- Long‑press actions → End Half/Match; Full Time shows correct team names and scores.
- Selecting a saved match routes to kickoff.

Build & Test commands
- Build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- Test: `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`

---

## Current Status (PR v2) ✅

Branch and PR
- Branch: `test/defensive-guards-and-swift-tests-v2`
- PR: https://github.com/Saidiibrahim/RefWatch/pull/5
 - Status: Completed ✅ (review passed)

Delivered in v2
- Tests (Swift Testing):
  - Duration conversions minutes→seconds and reset label derived from per‑period configuration.
  - Second‑half kickoff alternation (opposite team).
  - Event ordering at kickoff (`.kickOff` then `.periodStart(1)`), regular vs own‑goal mapping, and stoppage accumulation across pauses.
- Defensive Hardening:
  - Guard `RunLoop.current.add` for timers; remove force‑unwraps in debug prints.
  - Safe period math: `max(1, numberOfPeriods)` denominator; `max(0, …)` clamps for remaining/derived time.
  - No per‑tick logging in release; timer updates on main thread and scheduled in `.common`.

Manual QA done for v2 (high level)
- New tests pass locally on a watchOS simulator.
- Defensive guards prevent nil‑timer crashes and divide‑by‑zero in per‑period computations.

Key files changed/added (v2)
- Guards: `RefWatchWatchOS/Features/Match/ViewModels/MatchViewModel.swift`, `RefWatchWatchOS/Features/Match/Views/MatchKickOffView.swift`
- Tests: `RefWatchWatchOSTests/MatchViewModel_TimeConversionTests.swift`, `RefWatchWatchOSTests/MatchViewModel_KickoffAlternationTests.swift`, `RefWatchWatchOSTests/MatchViewModel_EventsAndStoppageTests.swift`

---

## Gaps and Improvements (Backlog)

Functional
- Extra Time and Penalties are not modeled in lifecycle/routes or UI; flags exist.
- “Undo last event” and “Quick +1 stoppage” actions would improve on‑pitch productivity.
- Persistence for finished matches and event logs; `finalizeMatch()` should snapshot before clearing state.

Architecture
- Timer logic still resides in `MatchViewModel`; extract to a dedicated `TimerManager` for SRP and testability.
- Lifecycle duplication: coordinator states vs ViewModel booleans (e.g., `waitingForHalfTimeStart`); keep coordinator authoritative and reduce duplication over time.

Reliability
- Add Swift Testing coverage for timings, transitions, events, and stoppage accumulation.
- Defensive checks for timers (nil guards everywhere) and period math (avoid divide‑by‑zero, negative values).

UX/Compatibility
- Verify `soccerball` symbol on the minimum watchOS target; add fallback icon if needed.
- Ensure labels remain readable and hit‑targets sufficient under all watch sizes.

Docs
- After service extraction, align docs (remove references to previously deleted services; document `TimerManager`).

---

## Multi‑PR Roadmap

PR v1 (Completed) ✅ — Standardize, Consolidate, Polish
- Goals: Fix time unit bugs, consolidate event model, improve watch performance, and polish kickoff/full‑time.
- Status: Implemented and updated with follow‑up fixes.

PR v2 (Completed) ✅ — Tests + Defensive Hardening
- Goals:
  - Add Swift Testing for duration conversions (create/saved), second‑half kickoff alternation, regular vs own‑goal scoring, stoppage accumulation across pauses, and event ordering.
  - Add defensive guards for timers and period math (e.g., `numberOfPeriods >= 1`, clamp negatives with `max(0, ...)`).
- Deliverables:
  - New test cases under `RefWatch Watch AppTests` using Swift Testing.
  - Small VM guard rails (nil checks for timers/run loop adds; bounds checks on period duration computations).
- Acceptance Criteria:
  - All tests pass locally and in CI.
  - No per‑tick logs in release; no timer crashes due to nil unwrapping.
- Suggested Files:
  - `RefWatchWatchOSTests/*` (new tests)
  - `RefWatchWatchOS/Features/Match/ViewModels/MatchViewModel.swift` (small guards only)

---

## Current Status (PR v3) ✅

Branch and PR
- Branch: `refactor/extract-timer-manager-v3`
- PR: https://github.com/Saidiibrahim/RefWatch/pull/6
 - Status: Completed ✅ (review passed)

Delivered in v3
- TimerManager Service:
- Added `RefWatchWatchOS/Core/Services/TimerManager/TimerManager.swift` (@Observable) managing:
    - Period tick (match elapsed, period elapsed, period countdown).
    - Stoppage accumulation across pauses with formatted `+mm:ss`.
    - Half-time elapsed tracking with haptic at configured threshold.
  - Defensive patterns: invalidate-before-recreate, `.common` run loop, main-thread dispatch, weak captures, idempotent `stopAll()`.
- MatchViewModel Integration:
  - Delegates timer/stoppage/halftime responsibilities to `TimerManager` while preserving public API and behavior.
  - Removed unused legacy start-time assignments and updated debug log.
- Tests:
- Added `RefWatchWatchOSTests/TimerManagerTests.swift` (per-period label calc, safety/idempotency cases).
- Added `RefWatchWatchOSTests/TestTimeHelpers.swift` (mm:ss parsing helper).
- Review Follow-ups:
  - Guard comment explaining single period timer; note about potential repeated halftime haptic (behavior unchanged by design).

Manual QA done for v3 (targeted)
- Smooth period transitions and unchanged event ordering at kickoff.
- Pause/resume displays accumulating `+mm:ss`; resets per period.
- Half-time elapsed updates; haptic at configured length.
- No regressions across timer UI states.

PR v3 (Completed) ✅ — Extract TimerManager (SRP)
- Goals:
  - Move timer responsibilities out of `MatchViewModel` into a focused `TimerManager` (@Observable) that manages:
    - Match running timer (elapsed, countdown per period).
    - Stoppage tracking across pauses.
    - Halftime elapsed tracking.
    - Lifecycle of internal `Timer`s with main‑thread updates and `.common` mode scheduling.
- Deliverables:
  - `Core/Services/TimerManager/TimerManager.swift` (new)
  - `MatchViewModel` integrating with `TimerManager` via a small API.
- Acceptance Criteria:
  - Behavior unchanged in the app; code is slimmer and easier to test.
  - Unit tests for `TimerManager` cover tick/pause/resume/stoppage.

## Current Status (PR v4) ✅

Branch and PR
- Branch: `feature/extra-time-penalties-v4`
- PR: https://github.com/Saidiibrahim/RefWatch/pull/7
 - Status: Completed ✅ (review passed)

Delivered in v4
- Lifecycle & Routing:
  - Added lifecycle states for Extra Time halves and Penalties; coordinator + ContentView route to ET1/ET2 kickoff and Penalty Shootout.
- UI:
  - Extended `MatchKickOffView` for ET1/ET2 with correct default second‑half kickers.
  - Added `PenaltyShootoutView` with per‑round dots, active team highlight, first‑kicker prompt, and “End Shootout” gating; fixed `.sheet` chaining.
  - `MatchLogsView` shows penalty attempts with round numbers and team context.
- Model & Services:
  - `Match`: added `extraTimeHalfLength` and `penaltyInitialRounds` (configurable).
  - `TimerManager`: supports ET per‑period durations and correct total elapsed accumulation across periods.
  - `PenaltyManager`: new @Observable service managing attempts, tallies, early decision, sudden death, first‑kicker, and decision haptic; integrated via VM bridging and event callbacks.
- ViewModel:
  - VM delegates penalty logic to `PenaltyManager`; exposes bridged properties used by UI; period routing unchanged; begin/end penalties record events.
- Configurability:
  - Match setup adds controls for ET half length (minutes) and shootout initial rounds; values flow into `Match`/VM and `PenaltyManager`.
- Tests:
  - `ExtraTimeAndPenaltiesTests.swift` covers ET transitions, tallies, early‑win detection, sudden death, round tracking, first‑kicker behavior, ET2 total elapsed accumulation, and configurable shootout rounds.

Manual QA done for v4 (targeted)
- Verified regulation → ET1 → ET2 → penalties routing, first‑kicker prompt flow, active‑team highlighting, and end gating; no regressions observed.

## Current Status (PR v6) ✅

Branch and PR
- Branch: `feature/v6-persist-completed-matches`
- PR: https://github.com/Saidiibrahim/RefWatch/pull/8
 - Status: Completed ✅ (review passed)

Delivered in v6
- Persistence snapshot: Added `CompletedMatch` model and `MatchHistoryService` (JSON, atomic writes, ISO8601 dates, in‑memory cache).
- VM integration: `finalizeMatch()` snapshots + persists before clearing state; graceful failure handling.
- History UI: Optional browser with details view (sorted recent‑first, delete support).
- Security & safety: File protection and backup exclusion applied after writes; documents guard with temp fallback in DEBUG; service made thread‑safe with concurrent queue + barrier.
- Performance: Avoids main‑thread I/O; cached date formatter; History auto‑refresh on activation; recent‑only loading via VM bridge.
- Tests: Service round‑trip, delete, concurrency + ordering, VM persistence and error surfacing.

PR v5 — In‑Match Productivity
- Goals:
  - Add “Undo last event” (revert score/card/sub counters and remove the record).
  - Add “Quick +1 stoppage” action (stoppage increment without pausing).
- Deliverables:
  - New actions in `MatchActionsSheet` and supporting VM methods.
- Acceptance Criteria:
  - Undo correctly reverses last event and updates UI/logs.
  - Quick stoppage increments cumulative stoppage time and displays in `TimerView`.

PR v6 — Persistence
- Goals:
  - Persist completed matches with full event logs.
  - Snapshot match before `finalizeMatch()` clears the VM state.
- Deliverables:
  - Codable persistence layer; optional “Match History” view on watch.
- Acceptance Criteria:
  - Completed matches retrievable; events accurate; no data loss after finalize.
 - Notes (post‑review adjustments):
   - `MatchHistoryService` uses a concurrent queue with barrier for thread‑safe cache + disk writes.
   - I/O executed on service queue (keeps main thread responsive).
   - File protection (`.completeUntilFirstUserAuthentication`) and backup exclusion applied after atomic writes.
   - `Documents` dir guarded; temp fallback in DEBUG if unavailable.
   - History list uses cached `DateFormatter` and refreshes on app activation.
  - Finalize surfaces non‑blocking persistence errors via small alert + haptic.

PR v6.1 — Data Security, Export, and History UX
- Goals:
  - Strengthen data handling and add quality‑of‑life tools around history.
  - Specifically: tighten file protection, monitor storage, export data, and add basic search/filter.
- Deliverables:
  - Security: Confirm and document optimal protection level for watchOS container (keep `.completeUntilFirstUserAuthentication` for usability; evaluate `.complete` feasibility, fallback if needed). Add a small integrity check when loading (schema version + JSON decode sanity log in DEBUG).
  - Storage monitoring: Service API to report on‑disk size and item count; lightweight warning threshold (e.g., 10MB) surfaced in History header for DEBUG builds.
  - Export: Service method to export all snapshots to a single JSON (or zipped JSON if size > 1MB) under `Documents/Exports/` and mark it excluded from backups; basic UI action to trigger export with a completion toast on watch.
  - Search/Filter: In‑memory filter on team names and date range for recent items; small UI on History to select team substring and quick date presets (Today/7d/30d/All).
- Acceptance Criteria:
  - Security: File remains protected; no regressions in load/save flows; integrity check logs appear in DEBUG.
  - Storage: Size and count reported; warning appears in DEBUG when threshold exceeded.
  - Export: Export file created successfully and visible via Files app when running a paired device; excluded from backups; success/failure feedback shown.
  - Search/Filter: Filtering works on team names and date presets without noticeable lag on a list of 500 items.
- Suggested Files:
  - `Core/Services/MatchHistory/MatchHistoryService.swift` (size reporting, export, optional integrity logging)
  - `Features/Match/ViewModels/MatchViewModel.swift` (bridges for export + filtering)
  - `Features/Match/Views/MatchHistoryView.swift` (search/filter controls in a compact watch‑friendly UI; export trigger in overflow menu)
- `RefWatchWatchOSTests/*` (export success test using temp dir; size reporting tests)

PR v7 — Docs + Cleanup
- Goals:
  - Update docs to reflect current services and flows (remove old references; document `TimerManager`).
  - Audit icon availability (fallbacks for watchOS versions).
- Deliverables:
  - Updated `CLAUDE.md`, `Core/README.md`, and any architecture docs.
- Acceptance Criteria:
  - New contributors can follow current architecture without confusion.

---

## Acceptance Criteria (Global)
- Performance: No per‑tick logging in release; timers use main‑thread updates and `.common` run loop mode.
- Correctness: Time units consistent (seconds in model). Own‑goal always credited to the opposite team. Period durations derived from config.
- UX: Kickoff and Full‑time show real team names; large, consistent controls for on‑pitch use.
- Reliability: Defensive guards prevent crashes on nil timers or bad math.
- Testability: Swift Testing covers core timer and event flows before shipping ET/penalties.

---

## Build, Test, and Verification

Commands
- Build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- Test: `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`

Manual QA Checklist (baseline)
- Kickoff per‑period duration matches configuration (40/45/50 minutes).
- Pause/resume; stoppage accumulates `+mm:ss` and resets per period.
- Half‑time elapsed updates even while interacting/scrolling.
- Second‑half kickoff defaults to opposite team; confirm starts period.
- Record regular and own goals; verify score side and logs.
- Long‑press → End Half/Match; verify Full‑time details.
- Saved match selection routes to kickoff if unstarted.

---

## Coding Conventions and Notes
- Swift + SwiftUI; 2‑space indentation; MVVM; one primary type per file.
- Names: Types `PascalCase`; functions/properties `camelCase`.
- Views end with `View`, view models with `ViewModel`, services with `Service`/`Manager`.
- Organize with `// MARK:` sections; avoid inline comments unless clarifying non‑obvious logic.

---

## Handoff Notes
- Merge PR v1 once checks pass and smoke tests look good (squash recommended). Then proceed with PR v2 (tests + defensive hardening) as the immediate next step.
- Keep lifecycle coordinator as the source of navigation truth as new states (ET/penalties) are added.
- Reintroduce a focused `TimerManager` in PR v3 to keep `MatchViewModel` lean and testable.
