# PLAN_match-timer-ux

## Purpose / Big Picture
Improve iOS match timer flow so referees can quickly record events, keep context on the main timer, and avoid duplicated/confusing period/finish controls. The result should: (a) return users to the timer after saving events, (b) keep the event log readable for long matches, and (c) present one clear path for pausing, period transitions, and finishing.

## Context and Orientation
- iOS timer screen: `RefWatchiOS/Features/Match/MatchTimer/MatchTimerView.swift` (score strip, timers, controls, event list, sheets).
- Actions sheet: `RefWatchiOS/Features/Match/Events/MatchActionsSheet.swift` (launches event flows, period/finish controls).
- Event flows: `GoalEventFlowView.swift`, `CardEventFlowView.swift`, `SubstitutionEventFlowView.swift`.
- Core logic: `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift` (start/end period, event recording, finalize, pendingConfirmation).
- Watch timer already prioritizes keeping users on the timer and logs confirmations; useful for parity.

## Plan of Work
1) **Event flow routing**: Launch event sheets from `MatchTimerView` and dismiss back there; add completion hooks to event flow views; remove nested sheet presentations inside `MatchActionsSheet`.
2) **Timeline UX**: Replace fixed-height `List` with scrollable/log-friendly layout (LazyVStack + ScrollViewReader), show empty state, auto-scroll to latest, and lift the 25-event cap.
3) **Period & pause controls**: Consolidate to a single period transition action; remove "Advance to Next Period" duplication; ensure natural period end logs `.periodEnd` and flows into waiting states. Keep primary pause/resume button; optional safe gesture shortcut if low risk.
4) **Finish flow**: Remove/soften the toolbar "Finish" button; direct finishing through the actions sheet -> full-time summary to avoid accidental finalize.
5) **Feedback & undo**: Surface `pendingConfirmation`/undo affordance on iOS timer; ensure goal/card/sub actions leave the user on timer with clear feedback.
6) **Tests**: Add/refine core tests for period end logging and undo; add minimal UI test to confirm event save returns to timer and scrolls to latest.

## Concrete Steps
- (TASK_01_match-timer-ux.md) Audit current timer/actions code paths and confirm gaps for event return, period transitions, finish flows.
- (TASK_02_match-timer-ux.md) Implement event flow routing + dismiss to timer; refactor actions sheet presentations.
- (TASK_03_match-timer-ux.md) Redesign timeline UI (scroll, empty state, latest focus) and adjust layout.
- (TASK_04_match-timer-ux.md) Simplify controls (pause/period/finish) and add period-end logging + undo surfacing.
- (TASK_05_match-timer-ux.md) Add/adjust tests covering period end log + UI event return behavior.

## Progress
- [x] TASK_01_match-timer-ux.md
- [x] TASK_02_match-timer-ux.md
- [x] TASK_03_match-timer-ux.md
- [x] TASK_04_match-timer-ux.md
- [ ] TASK_05_match-timer-ux.md

## Suprises & Discoveries
- Observation: _pending_
- Evidence: _pending_

## Decision Log
- Decision: _pending_
- Rationale: _pending_
- Date/Author: 2025-12-01 / Codex

## Testing Approach
- Core: extend RefWatchCore tests for `endPeriod()` to record `.periodEnd`, and for undo after goal/card/sub.
- UI: lightweight UI test to create/save a goal and verify timer view visible and auto-scroll to latest.
- Manual: sanity run through start -> event -> period end -> finish on simulator.

## Constraints & Considerations
- Avoid accidental pauses with single taps; prefer primary button and optional long/double tap gesture.
- Keep watch parity where sensible but maintain iOS off-field usability.
- Respect feature-first architecture; minimal churn outside timer/actions files.
