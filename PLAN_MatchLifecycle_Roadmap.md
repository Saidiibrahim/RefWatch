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
- Guards: `RefWatch Watch App/Features/Match/ViewModels/MatchViewModel.swift`, `RefWatch Watch App/Features/Match/Views/MatchKickOffView.swift`
- Tests: `RefWatch Watch AppTests/MatchViewModel_TimeConversionTests.swift`, `RefWatch Watch AppTests/MatchViewModel_KickoffAlternationTests.swift`, `RefWatch Watch AppTests/MatchViewModel_EventsAndStoppageTests.swift`

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
  - `RefWatch Watch AppTests/*` (new tests)
  - `RefWatch Watch App/Features/Match/ViewModels/MatchViewModel.swift` (small guards only)

---

## Current Status (PR v3) ✅

Branch and PR
- Branch: `refactor/extract-timer-manager-v3`
- PR: https://github.com/Saidiibrahim/RefWatch/pull/6
 - Status: Completed ✅ (review passed)

Delivered in v3
- TimerManager Service:
  - Added `RefWatch Watch App/Core/Services/TimerManager/TimerManager.swift` (@Observable) managing:
    - Period tick (match elapsed, period elapsed, period countdown).
    - Stoppage accumulation across pauses with formatted `+mm:ss`.
    - Half-time elapsed tracking with haptic at configured threshold.
  - Defensive patterns: invalidate-before-recreate, `.common` run loop, main-thread dispatch, weak captures, idempotent `stopAll()`.
- MatchViewModel Integration:
  - Delegates timer/stoppage/halftime responsibilities to `TimerManager` while preserving public API and behavior.
  - Removed unused legacy start-time assignments and updated debug log.
- Tests:
  - Added `RefWatch Watch AppTests/TimerManagerTests.swift` (per-period label calc, safety/idempotency cases).
  - Added `RefWatch Watch AppTests/TestTimeHelpers.swift` (mm:ss parsing helper).
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

PR v4.1 — Extract PenaltyManager (SRP)
- Goals:
  - Move all penalty shootout logic out of `MatchViewModel` into a focused `PenaltyManager` service while keeping public behavior and UI unchanged.
  - Improve testability (unit tests on manager) and maintainability (SRP akin to `TimerManager`).
- Deliverables:
  - `RefWatch Watch App/Core/Services/PenaltyManager/PenaltyManager.swift` (@Observable)
  - `MatchViewModel` integration with bridging properties/methods (non-breaking), event sink wiring.
  - New unit tests: `RefWatch Watch AppTests/PenaltyManagerTests.swift`.
- Acceptance Criteria:
  - No regressions in UI or flow: `PenaltyShootoutView` and routing behave the same.
  - All existing ET + penalties integration tests remain green.
  - New unit tests cover early decision, sudden death, round numbering, first-kicker, and next-team logic.

API Specification (PenaltyManager)
```swift
import Foundation
import Observation
import WatchKit

@Observable
final class PenaltyManager {
    // MARK: - Configuration
    let initialRounds: Int // default 5

    // MARK: - Lifecycle
    private(set) var isActive: Bool = false
    private(set) var isDecided: Bool = false
    private(set) var winner: TeamSide? = nil

    // MARK: - First Kicker
    private(set) var firstKicker: TeamSide = .home
    private(set) var hasChosenFirstKicker: Bool = false

    // MARK: - Tallies and Results
    private(set) var homeTaken: Int = 0
    private(set) var homeScored: Int = 0
    private(set) var homeResults: [PenaltyAttemptDetails.Result] = []

    private(set) var awayTaken: Int = 0
    private(set) var awayScored: Int = 0
    private(set) var awayResults: [PenaltyAttemptDetails.Result] = []

    // MARK: - Callbacks (wired by VM)
    var onStart: (() -> Void)?
    var onAttempt: ((TeamSide, PenaltyAttemptDetails) -> Void)?
    var onDecided: ((TeamSide) -> Void)?
    var onEnd: (() -> Void)?

    // MARK: - Init
    init(initialRounds: Int = 5) {
        self.initialRounds = max(1, initialRounds)
    }

    // MARK: - Computed
    var roundsVisible: Int {
        max(initialRounds, max(homeResults.count, awayResults.count))
    }

    var nextTeam: TeamSide {
        if homeTaken == awayTaken { return firstKicker }
        return homeTaken < awayTaken ? .home : .away
    }

    var isSuddenDeathActive: Bool {
        homeTaken >= initialRounds && awayTaken >= initialRounds
    }

    // MARK: - Commands
    func begin() {
        guard !isActive else { return }
        resetInternal()
        isActive = true
        onStart?()
    }

    func setFirstKicker(_ team: TeamSide) {
        firstKicker = team
        hasChosenFirstKicker = true
    }

    func recordAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int? = nil) {
        guard isActive else { return }
        // Round number is 1-based per-team attempt count
        let round = (team == .home ? homeTaken : awayTaken) + 1
        let details = PenaltyAttemptDetails(result: result, playerNumber: playerNumber, round: round)
        onAttempt?(team, details)

        if team == .home {
            homeTaken += 1
            if result == .scored { homeScored += 1 }
            homeResults.append(result)
        } else {
            awayTaken += 1
            if result == .scored { awayScored += 1 }
            awayResults.append(result)
        }

        computeDecisionIfNeeded()
    }

    func end() {
        guard isActive else { return }
        onEnd?()
        isActive = false
    }

    // MARK: - Internal
    private var didPlayDecisionHaptic: Bool = false

    private func resetInternal() {
        isDecided = false
        winner = nil
        didPlayDecisionHaptic = false
        hasChosenFirstKicker = false
        firstKicker = .home
        homeTaken = 0; homeScored = 0; homeResults.removeAll()
        awayTaken = 0; awayScored = 0; awayResults.removeAll()
    }

    private func computeDecisionIfNeeded() {
        // Early decision before completing initial rounds
        let homeRem = max(0, initialRounds - homeTaken)
        let awayRem = max(0, initialRounds - awayTaken)

        if homeTaken <= initialRounds || awayTaken <= initialRounds {
            if homeScored > awayScored + awayRem { decide(.home); return }
            if awayScored > homeScored + homeRem { decide(.away); return }
        }

        // Sudden death: after both reached initialRounds and attempts are equal
        if homeTaken >= initialRounds && awayTaken >= initialRounds && homeTaken == awayTaken {
            if homeScored != awayScored { decide(homeScored > awayScored ? .home : .away); return }
        }

        isDecided = false
        winner = nil
    }

    private func decide(_ team: TeamSide) {
        isDecided = true
        winner = team
        if !didPlayDecisionHaptic {
            WKInterfaceDevice.current().play(.success)
            didPlayDecisionHaptic = true
        }
        onDecided?(team)
    }
}
```

VM Bridging Signatures (non-breaking)
```swift
// MatchViewModel.swift
private let penaltyManager = PenaltyManager()

// Hook up events (e.g., in init or when entering penalties)
private func wirePenaltyCallbacks() {
    penaltyManager.onStart = { [weak self] in self?.recordMatchEvent(.penaltiesStart) }
    penaltyManager.onAttempt = { [weak self] team, details in
        self?.recordEvent(.penaltyAttempt(details), team: team, details: .penalty(details))
    }
    penaltyManager.onDecided = { [weak self] _ in /* no-op; UI reads isDecided */ }
    penaltyManager.onEnd = { [weak self] in self?.recordMatchEvent(.penaltiesEnd) }
}

// Bridged properties (preserve existing VM API used by UI)
var penaltyShootoutActive: Bool { penaltyManager.isActive }
var homePenaltiesScored: Int { penaltyManager.homeScored }
var homePenaltiesTaken: Int { penaltyManager.homeTaken }
var awayPenaltiesScored: Int { penaltyManager.awayScored }
var awayPenaltiesTaken: Int { penaltyManager.awayTaken }
var homePenaltyResults: [PenaltyAttemptDetails.Result] { penaltyManager.homeResults }
var awayPenaltyResults: [PenaltyAttemptDetails.Result] { penaltyManager.awayResults }
var penaltyRoundsVisible: Int { penaltyManager.roundsVisible }
var nextPenaltyTeam: TeamSide { penaltyManager.nextTeam }
var penaltyFirstKicker: TeamSide { penaltyManager.firstKicker }
var hasChosenPenaltyFirstKicker: Bool {
    get { penaltyManager.hasChosenFirstKicker }
    set { /* optional: ignore set; call setPenaltyFirstKicker instead */ }
}
var isPenaltyShootoutDecided: Bool { penaltyManager.isDecided }
var penaltyWinner: TeamSide? { penaltyManager.winner }
var isSuddenDeathActive: Bool { penaltyManager.isSuddenDeathActive }

// Bridged commands (replace VM internals with delegation)
func beginPenaltiesIfNeeded() {
    guard !penaltyManager.isActive else { return }
    // stop timers and set currentPeriod for penalties here
    wirePenaltyCallbacks()
    penaltyManager.begin()
}

func setPenaltyFirstKicker(_ team: TeamSide) {
    penaltyManager.setFirstKicker(team)
}

func recordPenaltyAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int? = nil) {
    penaltyManager.recordAttempt(team: team, result: result, playerNumber: playerNumber)
}

func endPenaltiesAndProceed() {
    if penaltyManager.isActive { penaltyManager.end() }
    // then drive routing: isFullTime = true, etc.
}
```

Migration Steps
- Step 1: Add `PenaltyManager` with full logic and callbacks; no VM/UI changes yet.
- Step 2: Wire callbacks in VM; introduce bridging properties/methods (keep old fields temporarily if needed).
- Step 3: Replace VM penalty methods to delegate to manager.
- Step 4: Remove duplicated VM penalty state after UI compiles against bridged API.
- Step 5: Add `PenaltyManagerTests.swift`; keep existing integration tests (`ExtraTimeAndPenaltiesTests.swift`) green.

Testing Plan
- Unit tests (new):
  - Early decision detection across sequences and round positions.
  - Sudden death: decision only when attempts equal and scores differ.
  - Round numbering per team; first-kicker impact on `nextTeam`.
  - Haptic gating flag changes (no actual vibration in tests).
- Integration tests (existing):
  - ET → Penalties transitions, event recording, total elapsed unaffected.

Notes
- Manager owns decision haptic (mirrors `TimerManager` owning halftime haptic), but VM owns routing/period index.
- Future configurability: `initialRounds` and `extraTimeHalfLength` can be surfaced via Match Setup/Settings in a later PR.

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
