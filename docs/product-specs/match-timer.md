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
4. User interacts via actions sheet (pause, halftime, penalties).
5. On completion, results sync to `MatchHistoryService`.

## Configuration
- Default face stored with `@AppStorage("timer_face_style")`.
- Additional faces register via `TimerFaceStyle` enumeration and the factory.

## Timer Readability Requirements
- Watch timer faces must clearly separate elapsed match time from remaining period time.
- Elapsed value is the primary, most prominent timer.
- Remaining value is visually distinct via secondary sizing and accent styling.
- The two values must remain legible on compact and standard watch sizes, with adaptive scaling.
- Accessibility output (VoiceOver) should announce elapsed and remaining values with distinct labels.

## Testing Focus
- Validate period transitions (start → halftime → next period).
- Ensure pause/resume retains elapsed time correctly.
- Cover penalty edge cases (stacked penalties, clearing after halftime).
- Validate elapsed vs remaining readability on Apple Watch Series 9 (45mm) and compact layout.
