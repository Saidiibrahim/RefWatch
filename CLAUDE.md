# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RefWatch is a multi-platform app (watchOS + iOS) designed for football/soccer referees to manage matches efficiently. The codebase uses SwiftUI and follows MVVM with a feature‑first architecture and modern Swift patterns. The watchOS app is production‑first; the iOS app complements it with match library, live mirror, and post‑match views.

## Build & Test Commands

### Building the Project
```bash
# Build the Watch app
xcodebuild -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build

# Build the iOS app
xcodebuild -project RefZone.xcodeproj -scheme "RefWatch iOS App" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build all targets (schemes must be shared)
xcodebuild -project RefZone.xcodeproj build
```

### Running Tests
```bash
# Run watchOS unit tests
xcodebuild -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' test

# (When present) Run iOS unit tests
xcodebuild -project RefZone.xcodeproj -scheme "RefWatch iOS App" -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### Development
- Open `RefZone.xcodeproj` in Xcode
- Select a scheme:
  - watchOS: "RefZone Watch App" → Apple Watch simulator
  - iOS: "RefWatch iOS App" → iPhone simulator
- Build and run with ⌘+R

## Architecture & Code Structure

### Module Organization
The repository follows a feature‑first architecture with clear separation of concerns. There are two app folders and a shared pool of sources compiled into both targets.

```
RefZoneWatchOS/
├── App/                    # Entry point and root configuration
├── Core/                   # Shared components and services
│   ├── Components/         # Reusable UI components
│   └── Services/          # Business logic services
└── Features/              # Feature-specific modules
    ├── Events/            # Match event recording (cards, goals)
    ├── Match/             # Core match management
    ├── MatchSetup/        # Pre-match configuration
    ├── Settings/          # App preferences
    ├── TeamManagement/    # Team and officials management
    └── Timer/             # Match timing functionality
RefZoneiOS/
├── App/                   # Entry, router, tabs (MainTabView)
├── Core/
│   ├── DesignSystem/      # Theme, palettes, shared modifiers
│   └── Platform/          # iOS platform adapters (e.g., IOSHaptics, Connectivity)
└── Features/
    ├── Matches/           # Matches list/detail
    ├── Live/              # Live mirror
    ├── Library/           # Teams/competitions/venues hub (placeholder)
    ├── Trends/            # Analytics (placeholder)
    └── Settings/          # App preferences
```

### Key Architectural Patterns

**MVVM with SwiftUI:**
- ViewModels use `@Observable` macro (Swift 5.9+)
- Views use `let model: MyModel` for observation (not @State)
- State management follows modern SwiftUI patterns

**Service/Coordinator Layer:**
- `MatchLifecycleCoordinator`: Controls lifecycle routing on watchOS (idle → setup → kickoff → running → halftime → second‑half/ET → finished).
- `TimerManager`: Focused service (SRP) for period tick, stoppage accumulation, half‑time elapsed; used by `MatchViewModel`.
- Coordinators encapsulate multi-step flows (e.g., `CardEventCoordinator`). Prefer coordinators over scattering navigation logic across views.

**Coordinator Pattern:**
- Used for complex flows like card event recording
- `CardEventCoordinator` manages the entire card recording flow
- Centralizes navigation and state management for multi-step processes

### State Management Rules

1. **ViewModels**: Annotate with `@Observable final class`
2. **View Observation**: Use `let model: MyModel` in views, not `@State`
3. **Reference Types**: Pass dependencies to child view constructors
4. **Value Types**: Use SwiftUI bindings only when child needs write access
5. **Local State**: Use `@State` only for view-managed local state
6. **App-wide State**: Use `Environment` for shared state across the app

## Code Style & Conventions

### Naming Conventions
- **Variables/Functions**: camelCase (`fetchMatchData`)
- **Types**: PascalCase (`MatchViewModel`)
- **Booleans**: Use `is/has/should` prefixes (`isMatchInProgress`)
- **Methods**: Use verbs (`startMatch`, `recordEvent`)

### Swift Best Practices
- Prefer `let` over `var`
- Use strong typing and proper optionals
- Implement async/await for concurrency
- Use Result type for error handling
- Leverage protocol-oriented programming
- Follow Apple's Human Interface Guidelines for WatchOS

### Required Comments
According to project rules, always add comments for debugging and understanding. Include:
- Function purpose and parameters
- Complex business logic explanations
- State transition explanations
- WatchOS-specific considerations

## Key Features Implementation

### Match Timer System
- `MatchViewModel` currently handles timing. PR v3 will extract a dedicated `TimerManager` for single-responsibility and easier testing.
- Timers schedule in `.common` mode; UI updates occur on the main thread; no per‑tick logging in release builds.
- Defensive guards: invalidate timers before recreating; guard `RunLoop.current.add` with `if let`; clamp period math to avoid divide‑by‑zero and negatives.
- Supports multiple periods and half‑time; extra time and penalties are planned in later PRs.

### Card Event Recording
Uses a sophisticated coordinator pattern:
1. Recipient selection (player/team official)
2. Detail collection (player number/official role)
3. Reason selection (context-aware card reasons)
4. Event recording in match state

**Flow:** `CardEventFlow` → `CardEventCoordinator` → Specific views
**Navigation:** Single NavigationStack for predictable UX

### Match Events
- Structured event system for goals, cards, substitutions
- Team-specific event tracking
- Integration with match timing for accurate timestamps

## Platform Considerations

- **watchOS**: target 11.2+, WatchKit haptics; avoid per‑tick logs; keep timer scheduling in `.common` and UI updates on main thread.
- **Development Team**: 6NV7X5BLU7
- **Bundle ID**: com.IbrahimSaidi.RefWatch.watchkitapp
- **Interface Orientations**: Portrait and Portrait Upside Down
- **Deployment**: Watch-only app (WKWatchOnly = YES)

- **iOS**: complementary app with tabs (Matches, Live, Trends, Library, Settings). Uses platform adapters (e.g., `IOSHaptics`) and compiles shared models/services/ViewModels via target membership. Avoid importing `WatchKit` in shared or iOS code.

## Development Workflow

1. **Feature Development**: Create new features in each app’s `Features/` directory following MVVM (Models/ViewModels/Views).
2. **Shared Code**: Prefer sharing via Target Membership first; keep shared sources UI‑agnostic (no WatchKit/UIKit). Use adapter protocols (`HapticsProviding`, `PersistenceProviding`, `ConnectivitySyncProviding`).
3. **Business Logic**: Implement services in `Core/Services/` (watch) and platform adapters under each app’s `Core/Platform/`.
4. **Testing**: Write unit tests under `RefWatchWatchOSTests/` (and future iOS tests). Keep package‑ready boundaries for a future `RefWatchCore` SPM.

## Important Notes

- The project uses Xcode 16.2 with Swift 5.0
- File System Synchronized Groups are used for project organization
- Build settings include automatic code signing
- SwiftUI previews are enabled for development
- Follow the established coordinator pattern for complex multi-step flows

## Defensive Coding & Testing Patterns

- Time Units: store durations in seconds (`TimeInterval`) in models; convert minutes at view‑model boundaries (e.g., `configureMatch`).
- Period Math: always use `max(1, numberOfPeriods)` when dividing by periods; clamp remaining/derived time with `max(0, …)`.
- Timers:
  - Invalidate before recreate; `RunLoop` `.common`; UI updates on main.
  - Guard `RunLoop.current.add` (`if let`); invalidate in `deinit` to avoid leaks.
- Optionals & Logging:
  - Avoid force‑unwraps, including in debug logs; prefer `if let` or `String(describing:)`.
  - Wrap debug logging within `#if DEBUG`; avoid per‑tick logging for performance.
- Event Recording:
  - On match start, record `.kickOff` followed by `.periodStart(1)`; use `MatchEventRecord` as the logging source of truth.
  - Own‑goal: UI maps to the opposite `TeamSide`; the ViewModel respects the team parameter. Keep flows consistent with this contract.
- Swift Testing (Xcode 16+):
  - Use `@Test`, `#expect`, and `#require` (unwrap before comparing) from the `Testing` framework.
  - Compare like types (e.g., `TimeInterval(50 * 60)` rather than `50 * 60`).
  - For time‑based assertions, parse `mm:ss` and assert with tolerance (e.g., `>=` for accumulated stoppage).
  - Naming: files `MatchViewModel_<Topic>Tests.swift`; methods `test_<Action>_when<Context>_does<Outcome>()`.
- Simulator Tips:
  - Prefer concrete destinations: watchOS (Series 9 45mm), iOS (iPhone 15).

## Sync Error Handling & Retry Policy (I6)

- Transport Envelope:
  - Dictionary with keys: `type: "completedMatch"`, `data: Data` (JSON-encoded `CompletedMatch`).
  - Dates encoded/decoded with ISO8601 across platforms for consistency.
- Sender Policy (watchOS):
  - Encode JSON on a background queue to avoid UI stutters.
  - If `WCSession.default.isReachable` → call `sendMessage` with an `errorHandler`.
  - On `sendMessage` error or when not reachable → immediately fall back to `transferUserInfo` for durable delivery.
  - On watchOS, `isPaired` is unavailable; availability uses `WCSession.isSupported()`.
- Receiver Policy (iOS):
  - Decode JSON on a background queue.
  - Persist to SwiftData and post notifications on the main actor.
  - Attach `ownerId` if available and missing in the snapshot (idempotent).
- Diagnostics (DEBUG only):
  - `Notification.Name.syncFallbackOccurred` posted when falling back to durable transfer.
  - `Notification.Name.syncNonrecoverableError` posted for non-recoverable issues (e.g., encode/decode failure, session unavailable).
  - Diagnostics are non-intrusive and only posted on debug builds.

## Threading Invariants (Persistence & Sync)

- JSON encode/decode runs off the main thread.
- SwiftData operations run on the main actor in this app (store annotated `@MainActor`).
- NotificationCenter posts that drive UI updates occur on the main thread.
- Tests assert that connectivity-triggered saves occur on the main thread.

## History Loading & Pagination (I6)

- Default bounded loads: `SwiftDataMatchHistoryStore.loadAll()` applies a reasonable default fetch limit to protect memory.
- Pagination API: `loadPage(offset:limit:)` is available for “See All” or infinite scrolling screens.
- UI guidance:
  - Use `loadAll()` for “Recent/Past” summaries.
  - Use `loadPage(offset:limit:)` for full-history views.

## Lifecycle & WCSession Delegate (iOS)

- `IOSConnectivitySyncClient` is retained for app lifetime by the App root and activates the session once.
- `deinit` clears `WCSession.default.delegate` defensively to avoid dangling delegate references in case of lifecycle changes.
- If the client ever becomes observable, consider `@StateObject` in App and explicit `deactivate()` on scene phase changes.
