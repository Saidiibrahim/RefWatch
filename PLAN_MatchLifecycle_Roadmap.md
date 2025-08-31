## RefWatch Match Lifecycle Roadmap and Implementation Plan

### Purpose
This document captures the shared plan to modernize the match flow for professional referees on watchOS, summarizes what has been implemented so far, and outlines the next PRs with clear scope, acceptance criteria, and validation steps. Use this as the hand-off guide for ongoing work.

---

## Current Status (PR v1)

Branch and PR
- Branch: `chore/standardize-time-and-clean-events`
- PR: https://github.com/Saidiibrahim/RefWatch/pull/4

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
  - `RefWatch Watch App/Features/Match/Models/Match.swift`
  - `RefWatch Watch App/Features/Match/ViewModels/MatchViewModel.swift`
- Events (canonical types, flows):
  - `RefWatch Watch App/Features/Events/Models/MatchEventRecord.swift` (already present; used)
  - `RefWatch Watch App/Features/Events/Views/GoalTypeSelectionView.swift`
  - `RefWatch Watch App/Features/Events/Views/PlayerNumberInputView.swift`
  - `RefWatch Watch App/Features/Events/Views/CardEventFlow.swift`
  - `RefWatch Watch App/Features/Events/Views/CardRecipientSelectionView.swift`
  - `RefWatch Watch App/Features/Events/Views/CardReasonSelectionView.swift`
  - `RefWatch Watch App/Features/Events/ViewModels/CardEventCoordinator.swift`
- UI polish and routing:
  - `RefWatch Watch App/Features/Match/Views/MatchKickOffView.swift`
  - `RefWatch Watch App/Features/Timer/Views/FullTimeView.swift`
  - `RefWatch Watch App/Features/Match/Views/StartMatchScreen.swift`
- Deleted legacy/unused:
  - `RefWatch Watch App/Features/Events/Models/MatchEvent.swift` (deleted)
  - `RefWatch Watch App/Core/Services/TimerService/TimerService.swift` (deleted)
  - `RefWatch Watch App/Core/Services/MatchStateService/MatchStateService.swift` (deleted)
  - `RefWatch Watch App/Features/MatchSetup/Views/StartMatchDetailsView.swift` (deleted)

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

PR v1 (Completed) — Standardize, Consolidate, Polish
- Goals: Fix time unit bugs, consolidate event model, improve watch performance, and polish kickoff/full‑time.
- Status: Implemented and updated with follow‑up fixes.

PR v2 — Tests + Defensive Hardening
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
  - `RefWatch Watch AppTests/*` (new tests)
  - `RefWatch Watch App/Features/Match/ViewModels/MatchViewModel.swift` (small guards only)

PR v3 — Extract TimerManager (SRP)
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

PR v4 — Extra Time + Penalties
- Goals:
  - Lifecycle states for ET halves and penalties (`kickoffET1`, `kickoffET2`, `penalties`).
  - Kickoff screens for ET; penalty shootout flow with attempts and tallies.
- Deliverables:
  - Coordinator routes + views for ET/penalties.
  - Events for ET start/end and penalty attempts.
- Acceptance Criteria:
  - Configurations with `hasExtraTime`/`hasPenalties` present correct screens and state transitions.
  - Tests for transitions and event recording.

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

