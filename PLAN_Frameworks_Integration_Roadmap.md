## RefWatch Frameworks Integration Roadmap and Implementation Plan

### Purpose
This document lays out a phased, multi‑PR plan to integrate modern watchOS capabilities tailored for elite football referees. It mirrors the style of the existing match lifecycle plan and focuses on: reliable long‑running runtime, at‑a‑glance controls, quick actions, privacy‑respectful data capture, robust persistence/analytics, and optional movement insights.

---

## Current Position Snapshot

- Architecture: `MatchLifecycleCoordinator` orchestrates phases; `MatchViewModel` delegates timing to `TimerManager` and penalties to `PenaltyManager`.
- Persistence: `MatchHistoryService` stores `CompletedMatch` snapshots as JSON with file protection and backup exclusion.
- Not yet integrated: HealthKit (workouts, heart rate, routes), WidgetKit complications, App Intents, WatchConnectivity, SwiftData, Swift Charts.
- Target outcome: Keep `TimerManager` as the UI tick/display source, but back it with a workout/extended runtime session to improve reliability when the app is backgrounded or screen is dimmed.

---

## Multi‑PR Roadmap

### PR W1 — Workout Sessions + Complications Foundations (Phase 1)

- Goals
  - Provide a robust long‑running runtime using `HKWorkoutSession` (+ `HKLiveWorkoutBuilder`) for match periods.
  - Surface match time/score via WidgetKit complications and deep link into active match.
  - Minimal App Intent for pause/resume from the complication.

- Deliverables
  - Service: `Core/Services/Workout/WorkoutSessionManager.swift`
    - Wrap start/stop/pause/resume of `HKWorkoutSession`.
    - Stream heart rate and active energy updates (optional UI display later).
    - Fallback to `WKExtendedRuntimeSession` when Health permission is denied.
  - Integration: Wire session lifecycle to `MatchViewModel`/`TimerManager` period boundaries.
  - Complications (WidgetKit): Small/rectangular showing match timer + score; deep link to `TimerView`.
  - App Intents: `PauseResumeMatchIntent` for quick control from the complication.

- Acceptance Criteria
  - Starting a match begins a workout session (or extended runtime fallback) and keeps time reliably while screen is off.
  - Complication updates when match is running and opens the correct screen state.
  - Denied Health permission gracefully degrades to extended runtime without crashes.

- Suggested Files
  - `Core/Services/Workout/WorkoutSessionManager.swift`
  - `App/Complications/*` (WidgetKit extensions, timelines, providers)
  - `App/AppIntents/PauseResumeMatchIntent.swift`
  - Light edits in `MatchViewModel.swift`, `TimerManager.swift`, `ContentView.swift`

- Manual QA (device recommended)
  - Start match → lock/dim screen → verify timer continuity and periodic heart‑rate samples (if enabled).
  - Complication shows timer/score; tap to open app in correct state.
  - Permission denied path works (no crash; session fallback active).

- Risks/Notes
  - Health permissions vary per device/user; ensure clear consent UI and minimal scopes.
  - Battery: prefer workout session over polling; avoid high‑frequency sampling.

---

### PR W2 — App Intents + Local Notifications + Haptics (Phase 2)

- Goals
  - Speed up on‑wrist operations with App Intents for common actions (goal/card/sub, start/stop/pause).
  - Local notifications for halftime complete, added‑time thresholds, and key checkpoints.
  - Introduce Core Haptics patterns for critical cues (fallback to `WKInterfaceDevice.play`).

- Deliverables
  - App Intents: `LogGoalIntent`, `LogCardIntent`, `LogSubIntent`, `StartMatchIntent`, `EndMatchIntent`.
  - Notifications: categories/actions for “Begin Halftime”, “Start Second Half”, “Proceed to ET/Penalties”.
  - Haptics: `Core/Services/Haptics/HapticsManager.swift` providing prepared patterns.

- Acceptance Criteria
  - Intents trigger correct state changes and event logging from complication or Siri/Shortcuts surface.
  - Halftime completion triggers a notification and appropriate haptic; actions navigate to the correct kickoff/halftime screen.
  - Works with or without W1 (no regressions if workouts disabled).

- Suggested Files
  - `App/AppIntents/*.swift`
  - `Core/Services/Haptics/HapticsManager.swift`
  - Notification plumbing in `RefWatchApp.swift`/app delegate equivalents.

- Manual QA
  - Trigger intents while app is foreground/background; verify navigation and logs.
  - Receive halftime/added‑time notifications; select actions and confirm routing.

- Risks/Notes
  - Keep intents fast and idempotent; ensure thread‑safe updates when invoked from background.

---

### PR W3 — Data, Analytics, and Sync (Phase 3)

- Goals
  - Migrate persistence to SwiftData models (matches, events) with a safe in‑place migration path from JSON.
  - Add Swift Charts to history/detail to visualize trends (e.g., heart rate vs. event timeline).
  - Provide WatchConnectivity export of completed matches to iPhone for optional deep analysis.

- Deliverables
  - Models: `CompletedMatchModel`, `MatchEventModel` (SwiftData) + lightweight migration from current JSON.
  - Charts: overlays for events and metrics in `MatchHistoryDetailView`.
  - Sync: `Core/Services/Sync/WatchConnectivitySyncService.swift` for snapshot export.

- Acceptance Criteria
  - Existing history remains visible; new matches persist via SwiftData.
  - Charts render without stutters; no noticeable battery impact on watch.
  - Manual export sends snapshots to iPhone app (or placeholder receiver) reliably.

- Suggested Files
  - `Core/Persistence/SwiftData/*`
  - `Core/Services/Sync/WatchConnectivitySyncService.swift`
  - `Features/Match/Views/MatchHistoryView.swift` (charts integration)

- Manual QA
  - Upgrade path from a build with JSON only → new build shows historical items and new items together.
  - Export several large snapshots; verify receipt on iPhone.

- Risks/Notes
  - SwiftData on watch is constrained; keep model simple and queries tight.
  - CloudKit sync can be considered later; start with explicit export for reliability.

---

### PR W4 — Optional Movement & Routes (Phase 4)

- Goals
  - Opt‑in route capture via `HKWorkoutRoute` during workouts for movement heatmaps (post‑match, on iPhone).
  - Add select Core Motion metrics (distance/steps/cadence bursts) to post‑match analytics.

- Deliverables
  - Route capture in `WorkoutSessionManager` (permission‑gated; off by default).
  - Minimal UI toggle in match setup to enable/disable movement capture.
  - Export routes alongside snapshots for iPhone processing/visualization.

- Acceptance Criteria
  - When enabled, route points are stored/exported; when disabled, no location usage.
  - No crashes on devices that deny location/route access.

- Suggested Files
  - `Core/Services/Workout/WorkoutSessionManager.swift` (route support)
  - `Features/MatchSetup/Views/MatchSetupView.swift` (movement capture toggle)

- Manual QA (device required)
  - Enable routes → complete short session → verify route exists; disable → no route.

- Risks/Notes
  - Location increases privacy and battery surface area; keep entirely opt‑in and clearly explained.

---

## Privacy, Permissions, and Data Handling

- HealthKit: Request minimal scopes (workout, heart rate, active energy). Clearly communicate use for officiating performance and timer reliability. Data stays on‑device unless user exports.
- Location/Routes: Disabled by default; obtain When‑In‑Use on watch only when user enables movement capture. No continuous background location outside a workout.
- Notifications: Local only for match events; actionable categories limited to officiating context.
- Storage: File protection remains enabled; consider SwiftData store location with the same protection level.

---

## Acceptance Criteria (Global)

- Timing reliability: Match time remains accurate with screen off and app transitions.
- UX continuity: Complications deep link correctly; intents/notifications route to the correct screen/state.
- Privacy‑first defaults: Movement capture opt‑in; Health scopes minimal; clear explanations.
- Performance: No per‑tick logging; UI stays responsive; battery impact remains acceptable for 90+ minutes.

---

## Build, Test, and Verification

- Build
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`

- Test
  - `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`

- Manual QA Checklist (baseline)
  - Start → Kickoff → Pause/Resume; stoppage accumulates and resets per period.
  - Halftime elapsed and notification/haptic behavior verified.
  - Regulation → ET1 → ET2 → Penalties → Full Time; finalize returns to start without intermediate screens.
  - Complication tap opens correct screen; quick actions work via intents.
  - Export of completed match succeeds; history shows accurate events and stats.

---

## Coding Conventions and Notes

- Swift + SwiftUI; MVVM; one primary type per file; 2‑space indentation.
- Names: Types `PascalCase`; functions/properties `camelCase`.
- Services should be focused (SRP) and testable; keep UI rendering logic in Views.

---

## Handoff Notes

- Proceed in order: W1 → W2 → W3 → W4. Each PR should include device‑based manual QA notes when Health/Routes are touched.
- Keep `MatchLifecycleCoordinator` authoritative for routing; avoid state duplication in VM where possible.
- If end‑of‑match navigation regresses, verify finalize flow and consider a NavigationPath fallback.


