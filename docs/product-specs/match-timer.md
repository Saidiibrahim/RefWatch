# Match Timer Feature Guide

## Purpose
Provides referees with precise match, period, and stoppage tracking, optimized for watchOS but shareable with iOS.

## Core Types
- `TimerView`: hosts controls, period labels, and renders the active face.
- `TimerFaceModel`: protocol defining the timer-facing API for views.
- `TimerManager`: executes timer updates, pause/resume logic, and halftime transitions.
- `PenaltyManager`: integrates foul timing and alerts.

## User Flow
1. Ref selects match parameters in Match Setup.
2. On start, `TimerManager` initializes match and period clocks.
3. `TimerFaceFactory` produces the configured watch face.
4. User interacts via actions sheet (pause, explicit halftime start, period transitions, penalties).
5. On completion, results sync to `MatchHistoryService`.

## Substitution Entry (watchOS)
- Tapping `Sub` from either team detail screen opens a hub flow instead of immediately asking for a single player-off or player-on entry.
- The hub exposes two spokes:
  - `Player(s) off`
  - `Player(s) on`
- Referees may enter either side first; watchOS no longer uses `substitutionOrderPlayerOffFirst` to control substitution navigation order.
- If the selected scheduled match is watch-ready, each spoke resolves from the scheduled match sheet frozen onto that fixture.
  - `Player(s) off` comes from the active on-field set derived from starters plus saved substitution history.
  - `Player(s) on` comes from unused substitutes on the frozen sheet.
  - Rows remain deterministic and selection order becomes the pairing order for saved substitutions.
- If the scheduled match has match-sheet data but either side is not ready, the spoke uses the numeric keypad/manual path instead of silently promoting live library rosters to official participants.
- Legacy schedules created before match-sheet support may still use synced library-roster lookup as a backward-compatibility fallback when no match-sheet fields exist at all.
- If the official frozen sheet is ready but a spoke has no eligible candidates left, the watch shows an unavailable state for that spoke instead of falling through to numeric/manual selection.
- The hub enables `Done` only when both sides contain the same non-zero count.
- If `Confirm Subs` is enabled, `Done` opens one confirmation surface summarizing the ordered pairs and the shared match time.
- Saving a batch records `N` normal substitution events, not a grouped event type.
  - Every event in the batch shares one captured `matchTime`, `period`, and `actualTime` snapshot.
  - Home/away substitution tallies increment by the batch size.
  - Undo remains at individual substitution granularity in v1.

## Lifecycle Haptics
- Natural period boundary emits the `periodBoundaryReached` lifecycle cue exactly once per boundary, after stale-callback guards pass and shared core has entered `PendingPeriodBoundaryDecision`.
- Natural period expiry enters the shared-core `PendingPeriodBoundaryDecision` waiting state first, keeps boundary-overrun timing running without generic paused semantics, then requests `.periodBoundaryReached`; the repeating alert must begin from that stable state instead of being coupled to immediate `pauseMatch()` side effects.
- The actual `.periodEnd(...)` event for a natural expiry is recorded only when the referee explicitly commits the transition through `endCurrentPeriod()`.
- Half-time elapsed crossing the configured length emits the `halftimeDurationReached` lifecycle cue exactly once, including across restore/relaunch.
- On watchOS both lifecycle cues use the same foreground-only repeating sequence policy: `3 x 0.4s` notification pulses, repeated every `3.0s` until the user explicitly acknowledges the alert while RefWatch remains active.
- The repeating alert is watch-owned UI layered above the timer surface. Acknowledgment silences haptics only; it does not advance match state, clear `PendingPeriodBoundaryDecision`, or replace Match Actions.
- If RefWatch becomes inactive or backgrounds, the repeating alert stops immediately and does not resume automatically on return or relaunch.
- Unfinished-session restore may rehydrate `PendingPeriodBoundaryDecision` and reopen the corresponding waiting surface, but it must not replay or resume a repeating alert automatically.
- Manual transition actions must not request a second lifecycle cue after the natural boundary cue has already fired.
- Reset, finalize, abandonment, and manual state transitions must cancel queued later pulses so they do not leak into the next lifecycle state.
- Manual progression remains referee-controlled: the user acknowledges the alert first, then explicitly commits the expired period through `endCurrentPeriod()`, which records `.periodEnd(...)` and moves into halftime waiting, the next kickoff waiting state, penalties waiting, or full-time as applicable.

## Configuration
- Default face stored with `@AppStorage("timer_face_style")`.
- Additional faces register via `TimerFaceStyle` enumeration and the factory.

## Runtime Continuity (watchOS Match Mode)
- Match Mode uses an `HKWorkoutSession`-backed runtime while a match is unfinished.
- Required watch bundle metadata is `WKBackgroundModes = [workout-processing]` only. Match Mode does not rely on background audio, Apple Music, or media playback.
- Runtime protection remains enabled during:
  - waiting to start the first half
  - in-play periods
  - paused states
  - `PendingPeriodBoundaryDecision`
  - waiting for halftime to start
  - halftime
  - waiting states between periods (second half, ET1, ET2)
  - penalty transition and active shootout
  - the full-time screen until the user finalizes completion, resets, or cancels
- Runtime protection ends when the match is completed, reset, or cancelled.
- Match Mode persists unfinished state and must rehydrate on relaunch, including:
  - timer anchors and pause state
  - `PendingPeriodBoundaryDecision`
  - halftime waiting
  - second-half / ET kickoff waiting
  - `waitingForPenaltiesStart`
  - active penalty shootout state
- Deep links and relaunch recovery are designed to route directly back to the correct unfinished surface instead of restarting at idle.
- Platform boundary:
  - watchOS documents active workout sessions as the supported continuity path while the session remains active
  - Match Mode is designed to reopen the last unfinished surface on relaunch when an active workout session can be recovered
  - Match Mode cannot guarantee absolute frontmost residency if the user explicitly presses the Digital Crown, opens another app, denies HealthKit authorization, or watchOS terminates the process
  - when those interruptions happen, RefWatch should recover the active workout session if available and restore the unfinished match snapshot on relaunch
- Match Mode does not rely on `WKExtension.frontmostTimeoutExtended`, which is unsupported on modern watchOS.
- Physical-watch validation and built-artifact metadata verification remain required before treating this continuity path as release-safe.

## Timer Readability Requirements
- Watch timer faces must clearly separate elapsed match time from remaining period time.
- Elapsed value is the primary, most prominent timer.
- Remaining value is visually distinct via secondary sizing and accent styling.
- The two values must remain legible on compact and standard watch sizes, with adaptive scaling.
- Accessibility output (VoiceOver) should announce elapsed and remaining values with distinct labels.
- On Always-On Display during halftime, the primary value must be halftime elapsed, not frozen match elapsed.

## Testing Focus
- Validate period transitions (start → halftime → next period).
- Ensure pause/resume retains elapsed time correctly.
- Cover penalty edge cases (stacked penalties, clearing after halftime).
- Validate natural period expiry sets `PendingPeriodBoundaryDecision`, requests `.periodBoundaryReached` from that calm state, and does not record `.periodEnd(...)` until explicit referee commit.
- Validate lifecycle haptic dedupe at natural period boundary and halftime expiry.
- Validate cancellation of queued lifecycle pulses after reset, abandonment, end/finalize, manual transition, app interruption, and backgrounding.
- Validate the acknowledgment overlay blocks timer taps and long-press actions until the user explicitly silences it.
- Validate acknowledgment does not clear `PendingPeriodBoundaryDecision`; only explicit referee progression consumes it.
- Validate unfinished-match persistence and rehydration across relaunch, including `PendingPeriodBoundaryDecision`, `waitingForHalfTimeStart`, and `waitingForPenaltiesStart`, without replaying a stopped repeating alert.
- Validate runtime continuity across kickoff waiting, in-play, halftime, ET, penalties, and full-time-pending-completion on Apple Watch Series 9 (45mm) physical hardware.
- Validate on physical Apple Watch hardware that natural period-boundary alerts start after the calm-state transition and do not coincide with extra pause/runtime churn.
- Validate elapsed vs remaining readability on Apple Watch Series 9 (45mm) and compact layout.
