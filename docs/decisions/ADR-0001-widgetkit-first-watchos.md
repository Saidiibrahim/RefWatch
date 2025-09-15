# ADR-0001 — WidgetKit-first for watchOS, optional ActivityKit on iOS

- Status: Accepted
- Date: 2025-09-15
- Owner: RefZone watchOS

## Context
- Goal: Provide referees with glanceable, continuously updating match details when they intentionally leave the watch app during an ongoing match.
- Constraint: ActivityKit (Live Activities) is iOS/iPadOS-first and not directly available as a watchOS API; watch can display mirrored Live Activities from iPhone, but a watch-only app cannot own/manage them.
- UX needs: A surface that is reliable in the Smart Stack, updates smoothly for timers, and is battery-friendly. Deep link back into the in-progress timer.
- Architectural goals: Keep timing logic centralized in `TimerManager`/`MatchViewModel`; avoid duplicating business logic in any extension; use a tiny, versioned payload shared via an App Group.

## Options Considered
1) WidgetKit Smart Stack widgets on watchOS (accessory rectangular + circular)
   - Pros: Natively available on watchOS; smooth timer updates via `Text(timerInterval:)` without per-second timeline reloads; battery-friendly; supports deep link.
   - Cons: Limited interactivity and layout space; relies on shared state via App Group.

2) ActivityKit Live Activities–first (iPhone owns the live session; watch mirrors)
   - Pros: Rich iOS surfaces (Lock Screen/Dynamic Island); mirroring may appear on watch Smart Stack.
   - Cons: Watch cannot originate/manage ActivityKit sessions; adds complexity/dependency to iOS; not guaranteed as a primary watch surface.

3) Do nothing / rely solely on the foreground app
   - Pros: No additional targets/entitlements.
   - Cons: No glanceable surface when the user leaves the app; fails the core goal.

4) Classic complications (not the primary direction here)
   - Pros: Persistent watch face presence.
   - Cons: More constrained visuals than Smart Stack widgets for this use case; the plan targets Smart Stack first.

## Decision
- Adopt a WidgetKit-first approach on watchOS:
  - Build a Smart Stack widget extension with `.accessoryRectangular` and `.accessoryCircular` families.
  - Share a minimal `LiveActivityState` model via an App Group store so the widget renders the current match state without duplicating logic.
  - Use dynamic timer rendering (`Text(timerInterval:)`) to animate time without frequent timeline reloads.
  - Provide a deep link into `TimerView` to quickly resume in-app control.
- Keep ActivityKit optional and gated behind `#if canImport(ActivityKit)` for the iOS app only, enabling future mirroring but never making watchOS depend on ActivityKit.

## Rationale
- Availability: WidgetKit is supported directly on watchOS; ActivityKit is not a watch-owned API.
- Performance & battery: Dynamic timer rendering avoids per-second updates; Smart Stack is designed for glanceable, low-cost surfaces.
- Simplicity: A tiny, versioned shared payload + App Group avoids logic duplication and complexity.
- Future-proofing: Optional ActivityKit bridge on iOS enables richer iPhone experiences and potential watch mirroring later.

## Consequences
- Add a new watchOS Widget Extension target (e.g., `RefWatchWidgets`).
- Configure a shared App Group (e.g., `group.refzone.shared`) for state handoff to the widget.
- Add light hooks from `MatchViewModel`/`TimerManager` transitions to publish `LiveActivityState` on key events (start/pause/resume/period boundary/score change).
- Gate any ActivityKit code behind `#if canImport(ActivityKit)` so watchOS builds remain unaffected.
- Deep link into `TimerView` from the widget to resume control in-app.

## Scope and Non‑Goals
- In scope: Smart Stack widget for watchOS, deep link, App Group store, dynamic timer, optional iOS ActivityKit bridge.
- Out of scope for this decision: Full interactive widget controls; full iOS Live Activity UI scope; complications.

## Rollback Strategy
- The widget work is additive. If it causes issues, remove the widget extension target and App Group entries; the watch app continues to function.
- The ActivityKit bridge (iOS) is optional and compiled conditionally; it can be reverted independently.

## Build Impact
- This ADR lives at `docs/decisions/ADR-0001-widgetkit-first-watchos.md`. The `docs/` folder is not part of any Xcode target and does not affect build schemes.
- No changes to app schemes are implied by this document alone.

## Implementation Status
- WidgetKit-first path on watchOS has been implemented:
  - App Group store and versioned `LiveActivityState` payload
  - Smart Stack widget (accessory rectangular + circular) using `Text(timerInterval:)`
  - Deep link from widget into the app
- Remaining polish for this phase:
  - Adjust deep-link routing to land directly on the Timer surface when a match is active
  - Add a neutral “No Active Match” widget state
  - Expand tests around state derivation
- Optional future work (unchanged): ActivityKit bridge on iOS guarded by `#if canImport(ActivityKit)`.

## Verification & QA Notes
- While a match runs, the Smart Stack shows a smoothly updating timer; when paused, it shows a static time with a paused affordance.
- Period boundaries and stoppage indicators reflect promptly using minimal timeline reloads.
- Tapping the widget deep links into `TimerView` for immediate control.

## References
- Plan: `docs/PLAN_watchOS_LiveActivities_Roadmap.md`
- Touchpoints (when implemented):
  - `RefZoneWatchOS/Core/Protocols/LiveActivity/LiveActivityPublishing.swift`
  - `RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityState.swift`
  - `RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityStateStore.swift`
  - `RefZoneWatchOS/Features/Timer/Views/TimerView.swift`
  - Optional iOS bridge: `SharedLiveActivities/MatchTimerAttributes.swift`, `SharedLiveActivities/LiveActivityManager.swift` (conditional)
