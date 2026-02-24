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

## Testing Focus
- Validate period transitions (start → halftime → next period).
- Ensure pause/resume retains elapsed time correctly.
- Cover penalty edge cases (stacked penalties, clearing after halftime).
