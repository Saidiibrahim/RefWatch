# RefWatch Workout Mode Expansion Plan

## Purpose
- Extend RefZone to support referee off-field training with a cohesive experience spanning watchOS and iOS.
- Keep officiating workflows intact while layering workout tracking, analytics, and sync on top of existing services.

## Multi-PR Roadmap
1. **PR1 – Foundations & Package Skeleton**
   - Introduce a `RefWorkoutCore` local Swift package with shared workout domain models, protocol definitions, and adapter stubs.
   - Wire the package into both watchOS and iOS targets; establish health/workout permission handling interfaces.
   - Document architecture decisions in `docs/decisions` if the package boundary diverges from RefWatchCore conventions.
2. **PR2 – watchOS Workout Mode Entry & UX**
   - Add the mode switcher at `RefWatchApp` entry, enabling users to pick Match vs Workout, with persistence of last-used mode.
   - Build initial watch workout feature area (nav shell, preset list placeholder, session host view leveraging existing timer faces with workout-specific styling).
   - Implement workout session lifecycle hooks calling the shared services (simulated endpoints until backend decisions land).
3. **PR3 – iOS Command Center & Data Sync**
   - Create iOS workout hub for preset management, history review, and analytics dashboards powered by the shared package.
   - Extend sync services to handle workout records, integrate with HealthKit summaries, and surface combined timelines.
   - Add cross-platform tests (unit + basic UI smoke) to guard the critical flows.
4. **Follow-up PRs** (incremental)
   - Expand workout faces/interval logic, add advanced presets, integrate notifications/shortcuts, and refine analytics visualisations.

## PR1 Scope Decisions
- Ship domain primitives (`WorkoutSession`, `WorkoutSegment`, `WorkoutMetric`, `WorkoutPreset`, `WorkoutIntensityZone`) and serialization helpers in PR1 so features have a stable model contract.
- Keep `RefWorkoutCore` decoupled from `RefWatchCore`; defer a shared `RefFoundation` package until overlap justifies it.
- Define protocol surfaces for health/workout permissions (`WorkoutAuthorizationManaging`), live tracking (`WorkoutSessionTracking`), and history storage with simulator-friendly mocks; platform adapters will live in app targets.
- Provide persistence and sync protocols only in PR1, leaving concrete SwiftData/CloudKit implementations to later PRs.
- Defer advanced analytics/timer exports; expose only the metrics and interval definitions needed by near-term watch/iOS flows.
- Add focused XCTest coverage using fixtures under `RefWorkoutCoreTests` to validate encoding/derivation logic.
- Adopt the `Workout` prefix for types and camelCase properties to stay consistent across packages.

## High-Level Direction
- Treat workout sessions as first-class citizens parallel to match officiating while sharing relevant timer, haptics, and history systems.
- Lean on HealthKit/WorkoutKit for metrics capture; encapsulate platform APIs in adapters so both apps consume a unified abstraction.
- Preserve glanceable, distraction-free watch UX with ready-to-start presets, haptic/audio cues, and complication shortcuts.
- Position the iOS app as the command center for schedule planning, insights, and template authoring.

## iOS Command Center
- Add a `Features/Workout` module hosting preset builders, history views, and analytics (load vs intensity, heart-rate zones, compliance).
- Blend match and workout data into unified timelines and dashboards; surface recommendations (e.g., rest days, target mileage).
- Provide rich preset editing with drag-and-drop interval blocks, tagging, and sync to the watch via connectivity services.
- Manage permissions, reminders, and export/sharing options within Settings; support deep links/notifications to jump into sessions.

## Cross-Cutting Considerations
- Ensure data sync handles match/workout differentiation, conflict resolution, and offline caching gracefully.
- Update onboarding to present dual-mode capability, collect permissions, and optionally import historic workouts.
- Maintain accessibility, low battery impact, and configurability of displayed metrics for diverse workout types.
- Expand automated test coverage for shared services, timer logic variants, and onboarding flows.

## Modularity Ideas
- Create `RefWorkoutCore` with modules for domain (`WorkoutSession`, `WorkoutSegment`, `WorkoutMetric`), services (`WorkoutTrackingService`, `WorkoutHistoryStore`), and platform adapters (`HealthKitWorkoutAdapter`).
- Consider extracting common utilities into a light `RefFoundation` package if both RefWatchCore and RefWorkoutCore depend on shared helpers.
- Define protocols for timers, haptics, connectivity, and analytics so watchOS and iOS inject their implementations without circular dependencies.
- Keep RefWatchCore focused on officiating; share only truly common primitives to avoid bloated packages.

## Watch Entry Flow
- Introduce a root `ModeSwitcherView` presented by `RefWatchApp` that routes to `MatchFlow` or new `WorkoutFlow`, persisting the last selection via `@AppStorage`.
- Support quick-launch paths (complications, Siri, notifications) that bypass the picker with confirmation safeguards.
- Maintain separate navigation stacks/scene storage per mode to prevent state leakage between match and workout contexts.
- Provide onboarding guidance the first time workout mode is selected, including HealthKit permission prompts and preset suggestions.

## Workflow Sketch
- Landing selector → `MatchFlow` (current experience) or `WorkoutFlow`.
- `WorkoutFlow` home: recent presets, quick start tiles, access to session history, and warm-up/interval drill shortcuts.
- Session host: timer face tuned per workout type (interval cues, distance progression, heart-rate zones) with options to pause, skip intervals, log RPE, or end early.
- Wrap-up: summary screen capturing metrics, perceived effort, notes, and sync to iOS; allow immediate sharing or scheduling of next session.

## Open Questions
- How much of HealthKit data should we mirror vs reference (storage implications)?
- Do we extend existing backend or build a dedicated workout sync service? (impacts later PR scope.)
- What level of preset complexity is V1 vs future iterations? (determines watch UI depth.)
- Should we provide on-watch analytics summaries or keep them iOS-only initially?

