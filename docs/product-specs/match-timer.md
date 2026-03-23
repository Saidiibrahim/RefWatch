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
  - waiting for halftime to start
  - halftime
  - waiting states between periods (second half, ET1, ET2)
  - penalty transition and active shootout
  - the full-time screen until the user finalizes completion, resets, or cancels
- Runtime protection ends when the match is completed, reset, or cancelled.
- Match Mode persists unfinished state and must rehydrate on relaunch, including:
  - timer anchors and pause state
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
- Validate unfinished-match persistence and rehydration across relaunch, including `waitingForHalfTimeStart` and `waitingForPenaltiesStart`.
- Validate runtime continuity across kickoff waiting, in-play, halftime, ET, penalties, and full-time-pending-completion on Apple Watch Series 9 (45mm) physical hardware.
- Validate elapsed vs remaining readability on Apple Watch Series 9 (45mm) and compact layout.
