# Live Activities Roadmap (watchOS)

Status: Working plan to add a Live Activity–style, always-current timer surface on Apple Watch via WidgetKit (Smart Stack) with optional ActivityKit bridging on supported platforms.

## Context & Goals
- Provide a continuously updating timer surface on Apple Watch that remains glanceable in the Smart Stack and resilient to app foreground/background transitions.
- Keep timing logic centralized in `TimerManager` and routing in `MatchLifecycleCoordinator`; avoid duplicating logic in widget code.
- Prefer WidgetKit on watchOS for Smart Stack presentation; conditionally support ActivityKit behind `#if canImport(ActivityKit)` (for iOS mirroring or future watchOS support) without creating a hard dependency in watch targets.
- Ensure the surface is up-to-date using dynamic timer rendering (`Text(timerInterval:)`) and minimal shared state persisted via an App Group.

## Current Status
- No existing `ActivityKit` or `WidgetKit` integration in the repo.
- Core pieces to leverage:
  - `RefWatchCore/Sources/RefWatchCore/Services/TimerManager.swift` (tick snapshots and period boundaries)
  - `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift` (authoritative match state and transitions)
  - `RefZoneWatchOS/Features/Timer/Views/TimerView.swift` (host screen)
  - `RefZoneWatchOS/Core/Platform/Connectivity/WatchConnectivitySyncClient.swift` (paired-device messaging, extendable later)
- No App Group configured yet for sharing state to a widget extension on watchOS.

## PR Breakdown

### PR1 — Foundations: Shared Model + App Group State
- Branch: `feature/watchos-live-activities-foundation`
- Base: `main`
- Commits: ~4–6
- Scope:
  - Add a small shared model for the widget/live surface, e.g., `LiveActivityState` (period label, match start/end timestamps, paused flag, stoppage active, home/away abbreviations and scores).
  - Add a protocol in watchOS core: `Core/Protocols/LiveActivity/LiveActivityPublishing.swift`:
    - `start(state:)`, `update(state:)`, `end()`; platform-specific implementations later.
  - Add a watch implementation to persist the latest state to App Group UserDefaults (suite name placeholder: `group.refwatch.shared`). File: `RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityStateStore.swift`.
    - API: `write(_:)`, `read()`, `clear()`; serialization via `Codable` JSON under a single key.
  - Integrate minimal state publishing hooks in a non-invasive way:
    - On match start/pause/resume/period change/end, derive `LiveActivityState` from `MatchViewModel` and write it to the store.
    - Keep this as a focused helper used by `TimerView` or a light adaptor that observes VM changes (no logic duplication).
- Acceptance:
  - Writing/reading the state store works on-device and simulator.
  - No user-visible UI changes; compilation remains green on all targets.
- Tests:
  - Unit tests for `LiveActivityState` encoding/decoding and store round-trip.
- Risk: Low (additive, no UI).

### PR2 — Smart Stack Widget Extension (watchOS)
- Branch: `feature/watchos-live-activities-widget`
- Base: `main`
- Commits: ~6–8
- Scope:
  - Create a new watchOS Widget Extension target: `RefWatchWidgets`.
  - Families: `.accessoryRectangular` (primary) and `.accessoryCircular`.
  - Provider uses `LiveActivityStateStore.read()` to build a `Timeline` with minimal entries:
    - While running: one entry with a `DateInterval` (period start → expected period end) rendered via `Text(timerInterval: ...)` so it animates without per-second reloads.
    - Paused: render static label with clear PAUSED affordance and last-known time.
  - Layouts:
    - Rectangular: period label top-left, running timer large; bottom strip shows `HOM 1 • 0 AWA` and stoppage indicator when active.
    - Circular: large timer only, small status glyph when paused/stoppage.
  - Deep link: `widgetURL` into `TimerView` (match in progress) to resume interaction quickly.
  - Performance: prefer `TimelineReloadPolicy.after(periodEnd)`; when paused or finished, use `.never` or a distant future.
- Acceptance:
  - Widget appears in Smart Stack and reflects the current match within 1–2s of state change when bringing up the stack.
  - Timer counts smoothly while the match runs; no visible per-second timeline updates.
- Tests:
  - Snapshot-style previews for both families; provider fallback when no state.
- Risk: Medium (new target + entitlements/config). Keep extension code small and self-contained.

### PR3 — Live Activity Manager (conditional ActivityKit, optional)
- Branch: `feature/live-activities-manager`
- Base: `main`
- Commits: ~4–6
- Scope:
  - Add a `LiveActivityManager` service that conforms to `LiveActivityPublishing` and wraps `ActivityKit` behind `#if canImport(ActivityKit)`.
    - Files (platform-gated, shared in a new group `SharedLiveActivities`):
      - `MatchTimerAttributes.swift` (ActivityAttributes with `ContentState` mapping to `LiveActivityState`).
      - `LiveActivityManager.swift` (start/update/end using ActivityKit where available; no-op otherwise).
  - For watchOS today, this likely compiles as a no-op; on iOS it enables a future iPhone Live Activity (Lock Screen/Dynamic Island) that can mirror state.
  - Wire the existing state publishing helper to call both the App Group store and the manager (it will no-op on watch). Keep all calls resilient.
- Acceptance:
  - On platforms with ActivityKit, a developer can start/update/end without UI regressions in watch targets.
  - On watchOS, build remains green and behavior unchanged beyond the widget.
- Tests:
  - Mapping tests from `LiveActivityState` → `MatchTimerAttributes.ContentState`.
- Risk: Low/Medium due to conditional compilation. Keep API surface tiny and additive.

### PR4 — App Intents: Quick Controls + Widget Interactivity
- Branch: `feature/watchos-live-activities-intents`
- Base: `main`
- Commits: ~4–6
- Scope:
  - Add App Intents for `PauseMatch`, `ResumeMatch`, `StartHalfTime`, `StartSecondHalf` (best-effort, surface as available actions within the rectangular widget when space allows; otherwise use deep link only).
  - Add `WidgetCenter.shared.reloadTimelines(ofKind:)` calls after intent execution to speed up Smart Stack updates.
  - Ensure intents route correctly into `MatchViewModel` actions without duplicating logic.
- Acceptance:
  - From the Smart Stack, tapping the widget deep links to `TimerView`; when interactive buttons are present, actions work and widget refreshes quickly.
- Tests:
  - Intent invocation unit tests (where feasible) to verify state methods are called.
- Risk: Medium (background entry points). Keep intents idempotent and fast.

### PR5 — Paired iPhone Mirroring (Optional Sync)
- Branch: `feature/live-activities-watch-iphone-sync`
- Base: `main`
- Commits: ~3–5
- Scope:
  - Extend `WatchConnectivitySyncClient` with a lightweight live state envelope (e.g., `{ type: "liveState", data: <LiveActivityState JSON> }`).
  - iOS side (future PR, not in this file): accept and optionally trigger an iPhone Live Activity update using the same shared `LiveActivityManager` and attributes.
  - On watch, keep Smart Stack rooted in the App Group state; connectivity is additive for cross-device coherence only.
- Acceptance:
  - When within Bluetooth range, state changes propagate to iPhone within seconds (when the iOS app/extension is able to receive).
- Tests:
  - Extend existing connectivity tests with a simple round-trip for `liveState` payload.
- Risk: Medium (involves both targets). Keep schema versioned/namespaced (e.g., `live.v1`).

### PR6 — Polish: Tests, Docs, Resilience
- Branch: `feature/watchos-live-activities-tests-docs`
- Base: `main`
- Commits: ~2–3
- Scope:
  - Add unit tests for `LiveActivityState` derivation from `MatchViewModel` (paused/run/stoppage/halftime/ET/finished cases).
  - Add a short docs page: “Keeping the Smart Stack Live” covering state derivation, timers, and pitfalls.
  - Guard rails: when no active match, widget renders a neutral “No Active Match” with a deep link into kickoff.
- Acceptance:
  - Tests pass; docs clarify how to evolve the surface without touching timing logic.
- Risk: Low.

## Sequencing & Stacking
- Implement in order: PR1 → PR2 → PR3 (optional) → PR4 → PR5 (optional) → PR6.
- PR2 depends on PR1’s App Group store. PR3/PR5 are optional extensions and can be deferred.
- Branch creation example:
  - `git checkout -b feature/watchos-live-activities-foundation`
  - push and open PR with base set to `main`.

## Acceptance Criteria (Global)
- Smart Stack shows a continuously updating, glanceable timer while a match runs; paused and stoppage states are obvious.
- No duplication of timing logic outside `TimerManager`/`MatchViewModel`.
- Widget rendering remains performant (uses `Text(timerInterval:)`, minimal timeline entries).
- ActivityKit usage remains optional and never breaks watchOS builds.

## Risks & Mitigations
- Platform gaps: WatchOS ActivityKit availability may differ; use `#if canImport(ActivityKit)` and keep a robust WidgetKit-first path.
- Data freshness: Avoid per-second timeline reloads; rely on dynamic timer views and trigger reloads only on state boundaries (pause/resume/period end).
- Configuration drift: Introduce a tiny, versioned `LiveActivityState` payload and a single store key to reduce schema sprawl.
- Entitlements: App Group setup is required for the widget; add with a neutral placeholder and validate in CI.

## Rollback Strategy
- Each PR is additive. If the widget causes regressions, remove the extension target and App Group entries; app functionality remains intact.
- If ActivityKit bridging misbehaves, the manager is already a no-op on watchOS; revert the bridging PR without impacting widget.

## Decisions on Prior Open Questions
- Direct watch Live Activity vs. Widget: Choose WidgetKit-first for watchOS to guarantee Smart Stack presence and excellent battery profile; keep ActivityKit conditional for iOS and future-proofing.
- Control surface in the widget: Deep link is guaranteed; inline buttons via App Intents are best-effort and layout-gated.

## Suggested Files & Touchpoints (when implementing)
- `RefZoneWatchOS/Core/Protocols/LiveActivity/LiveActivityPublishing.swift`
- `RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityState.swift`
- `RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityStateStore.swift`
- `RefZoneWatchOS/App/RefZoneApp.swift` (App Group bootstrap if needed)
- `RefZoneWatchOS/Features/Timer/Views/TimerView.swift:1` (call publisher on start/pause/resume/period transitions)
- `SharedLiveActivities/MatchTimerAttributes.swift` (conditional ActivityKit)
- `SharedLiveActivities/LiveActivityManager.swift` (conditional ActivityKit)
- New target: `RefWatchWidgets` (WidgetKit extension for Smart Stack)

## Build, Test, and Verification
- Build (watchOS): `xcodebuild -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- Test (watchOS): `xcodebuild test -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`
- Manual QA
  - Start → pause → resume: Smart Stack reflects state; timer ticks while running.
  - Period boundary: rectangular widget shows time-to-end correctly, flips to halftime/ET/finished states appropriately.
  - No active match: neutral state with deep link to kickoff.
  - Optional: paired iPhone receives `liveState` envelope when in range (PR5).

---

## Appendix — Comment‑Only API Sketch

```swift
// LiveActivityState v1 — documentation-only sketch
// Purpose: Minimal, versioned payload written by the watch app to an App Group
// so the WidgetKit extension can render an always-current Smart Stack surface
// without duplicating timing logic.
//
// NOTE: Do not implement in code yet. This is a planning aid only.

/// Storage hints (when implemented):
/// - App Group suite: "group.refwatch.shared"
/// - Store key:      "liveActivity.state.v1"
struct LiveActivityState: Codable, Equatable {
    // MARK: - Schema & Identity
    /// Bump when adding/removing fields; provider should gracefully handle older versions.
    var version: Int = 1
    /// Optional correlation ID for future multi-match contexts (unused on watch for now).
    var matchIdentifier: String? = nil

    // MARK: - Scoreboard
    /// Three-letter abbreviations or short names (e.g., "HOM", "AWA").
    var homeAbbr: String
    var awayAbbr: String
    var homeScore: Int
    var awayScore: Int

    // MARK: - Period & Status
    /// UI-facing label (e.g., "First Half", "Half Time", "Second Half", "ET 1", "ET 2", "Penalties", "Full Time").
    var periodLabel: String
    /// True when the match clock is intentionally paused.
    var isPaused: Bool
    /// True when stoppage time is accumulating in the current period.
    var isInStoppage: Bool

    // MARK: - Timing
    /// Wall-clock start of the current period.
    var periodStart: Date
    /// Wall-clock expected end of the current period; nil when not applicable (e.g., penalties, finished).
    var expectedPeriodEnd: Date?
    /// Elapsed seconds at the time of last update when paused; nil while running.
    var elapsedAtPause: TimeInterval?

    // MARK: - Stoppage
    /// Accumulated stoppage seconds within the current period.
    var stoppageAccumulated: TimeInterval

    // MARK: - Meta
    /// Timestamp the state was last written; useful for staleness checks.
    var lastUpdated: Date
}

// Derivation notes (not code):
// - While running:
//     - isPaused == false, elapsedAtPause == nil
//     - Widget renders a live timer using Text(timerInterval: DateInterval(start: periodStart, end: expectedPeriodEnd ?? Date()))
// - While paused:
//     - isPaused == true, elapsedAtPause set to period seconds
//     - Widget renders a static "mm:ss" from elapsedAtPause
// - Stoppage indicator uses isInStoppage and/or stoppageAccumulated to display a small badge and optional value.
// - periodLabel mirrors the host view label logic; avoid reproducing complex rules in the widget.
//
// Suggested mapping (pseudo) when implemented:
// LiveActivityState(
//   version: 1,
//   matchIdentifier: nil,
//   homeAbbr: vm.homeTeamDisplayName.getAbbrev(3) or vm.homeTeam,
//   awayAbbr: vm.awayTeamDisplayName.getAbbrev(3) or vm.awayTeam,
//   homeScore: vm.currentMatch?.homeScore ?? 0,
//   awayScore: vm.currentMatch?.awayScore ?? 0,
//   periodLabel: derived from vm flags (same as TimerView),
//   isPaused: vm.isPaused,
//   isInStoppage: vm.isInStoppage,
//   periodStart: compute from current period start reference in TimerManager,
//   expectedPeriodEnd: periodStart + perPeriodDurationSeconds(match, period),
//   elapsedAtPause: vm.isPaused ? secondsElapsedThisPeriod : nil,
//   stoppageAccumulated: secondsOfStoppageThisPeriod,
//   lastUpdated: now
// )
```

### Minimal Coding/Storage Keys (comment‑only)

```swift
// Storage (App Group)
// suite: "group.refwatch.shared"
// key:   "liveActivity.state.v1"

extension LiveActivityState {
    // Default (readable) keys — recommended during development
    enum CodingKeys: String, CodingKey {
        case version            // Int
        case matchIdentifier    // String?
        case homeAbbr           // String
        case awayAbbr           // String
        case homeScore          // Int
        case awayScore          // Int
        case periodLabel        // String
        case isPaused           // Bool
        case isInStoppage       // Bool
        case periodStart        // Date
        case expectedPeriodEnd  // Date?
        case elapsedAtPause     // TimeInterval?
        case stoppageAccumulated// TimeInterval
        case lastUpdated        // Date
    }

    // Optional compact keys — switch to these only if payload size matters
    // Keep both blocks consistent; migrating requires a one‑time read+rewrite.
    enum CompactCodingKeys: String, CodingKey {
        case version = "v"
        case matchIdentifier = "mid"
        case homeAbbr = "ha"
        case awayAbbr = "aa"
        case homeScore = "hs"
        case awayScore = "as"
        case periodLabel = "pl"
        case isPaused = "p"
        case isInStoppage = "si"
        case periodStart = "ps"
        case expectedPeriodEnd = "ee"
        case elapsedAtPause = "ep"
        case stoppageAccumulated = "sa"
        case lastUpdated = "lu"
    }
}
```

### Mapping Checklist — from TimerManager snapshots (comment‑only)

```text
Inputs
- MatchViewModel (vm): isPaused, isInStoppage, currentPeriod, flags for halftime/ET/penalties/finished,
  strings: periodTime, periodTimeRemaining, formattedStoppageTime, halfTimeElapsed,
  match: duration/periods/halfTimeLength/extraTimeHalfLength, currentMatch scores & team names.
- Now: current wall clock time.

Derivations
1) Determine phase/label
   - Prefer extracting the existing periodLabel logic from TimerView into a shared helper
     (e.g., PeriodLabelFormatter) or vm.periodLabel to avoid duplication.
   - Map states to labels: First Half, Half Time, Second Half, ET 1, ET 2, Penalties, Full Time.

2) Parse elapsed within current segment
   - Running or Paused (periods/ET): parse vm.periodTime ("MM:SS") → secondsElapsed.
   - Half Time: parse vm.halfTimeElapsed ("MM:SS") → secondsElapsed.
   - Penalties/Finished: no live timer; secondsElapsed optional.

3) Compute periodStart
   - periodStart = now - secondsElapsed (for periods/ET and halftime).
   - For penalties/finished, leave timers nil and render static UI in the widget.

4) Compute expectedPeriodEnd
   - If periods/ET: expectedEnd = periodStart + perPeriodDurationSeconds(match, vm.currentPeriod).
     Option A (preferred): expose a tiny public helper from TimerManager, e.g.,
       TimerManager.periodDuration(for:match,currentPeriod:)
     Option B (fallback): re-use the same formula inline (mirror TimerManager implementation).
   - If halftime: expectedEnd = periodStart + match.halfTimeLength.
   - If penalties/finished: expectedEnd = nil.

5) Stoppage fields
   - isInStoppage = vm.isInStoppage
   - stoppageAccumulated = parse vm.formattedStoppageTime ("MM:SS") → seconds.

6) Paused handling
   - isPaused = vm.isPaused
   - elapsedAtPause = isPaused ? secondsElapsed : nil
   - While paused, widget renders static time from elapsedAtPause and avoids DateInterval timers.

7) Scoreboard
   - homeAbbr/awayAbbr from vm.homeTeamDisplayName/vm.awayTeamDisplayName, truncate to 3 chars if needed.
   - homeScore/awayScore from vm.currentMatch.

8) Meta
   - version = 1, lastUpdated = now, matchIdentifier = nil (future‑proofing for multi‑match contexts).

Triggers (write + widget reload)
- Start match, pause, resume, begin/end stoppage, start next period, halftime start/end, ET1/ET2 start,
  begin penalties, penalties end, full time, score change.
- On each trigger: derive LiveActivityState, write to App Group store, request Widget timeline reload (PR4 adds intents).
```

### PeriodLabelFormatter Sketch (comment‑only)

```swift
// PeriodLabelFormatter — documentation-only sketch (no production code here)
// Purpose: Provide a single-source-of-truth period label for TimerView and
// LiveActivityState derivation to avoid duplicating branching logic.
// Proposed file (when implemented):
//   RefZoneWatchOS/Core/Services/Formatting/PeriodLabelFormatter.swift

struct PeriodLabelFormatter {
    struct Context {
        var currentPeriod: Int
        var isHalfTime: Bool
        var waitingForHalfTimeStart: Bool
        var waitingForSecondHalfStart: Bool
        var waitingForET1Start: Bool
        var waitingForET2Start: Bool
        var waitingForPenaltiesStart: Bool
        var isFullTime: Bool
    }

    /// Returns a user-facing label such as "First Half", "Half Time",
    /// "Second Half", "ET 1", "ET 2", "Penalties", or "Full Time".
    static func label(for ctx: Context) -> String {
        // PSEUDOCODE ONLY — mirror existing TimerView rules:
        // if ctx.isFullTime { return "Full Time" }
        // if ctx.isHalfTime || ctx.waitingForHalfTimeStart { return "Half Time" }
        // if ctx.waitingForSecondHalfStart { return "Second Half" }
        // if ctx.waitingForET1Start { return "ET 1" }
        // if ctx.waitingForET2Start { return "ET 2" }
        // switch ctx.currentPeriod {
        //   case 1: return "First Half"
        //   case 2: return "Second Half"
        //   case 3: return "ET 1"
        //   case 4: return "ET 2"
        //   default: return "Penalties"
        // }
        fatalError("planning stub")
    }
}

// Usage notes (when implemented):
// - TimerView: replace inline periodLabel with PeriodLabelFormatter.label(
//     for: .init(currentPeriod: vm.currentPeriod,
//                isHalfTime: vm.isHalfTime,
//                waitingForHalfTimeStart: vm.waitingForHalfTimeStart,
//                waitingForSecondHalfStart: vm.waitingForSecondHalfStart,
//                waitingForET1Start: vm.waitingForET1Start,
//                waitingForET2Start: vm.waitingForET2Start,
//                waitingForPenaltiesStart: vm.waitingForPenaltiesStart,
//                isFullTime: vm.isFullTime))
// - LiveActivityState derivation: call the same helper to populate `periodLabel`.

// Suggested test cases (documentation-only):
// 1) Initial state before kickoff → "First Half"
// 2) During first half running → "First Half"
// 3) End of first half, halftime running or waiting → "Half Time"
// 4) Waiting for second half start → "Second Half"
// 5) ET1/ET2 waiting → "ET 1" / "ET 2"
// 6) Active penalties → "Penalties"
// 7) Match finished (isFullTime) → "Full Time"
```

#### Callsite Note (TimerView)

- Replace the inline period label computation with `PeriodLabelFormatter`.
- File pointer for convenience:
  - `RefZoneWatchOS/Features/Timer/Views/TimerView.swift:18`
  - Replace the `private var periodLabel` computed property body with a call to `PeriodLabelFormatter.label(for:)` using VM flags, or deprecate the property and inline the formatter call where used.
