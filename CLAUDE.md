# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RefWatch is a WatchOS app designed for football/soccer referees to manage matches efficiently. The app uses SwiftUI and follows MVVM architecture with modern Swift concurrency patterns.

## Build & Test Commands

### Building the Project
```bash
# Build the Watch App target
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build

# Build all targets
xcodebuild -project RefWatch.xcodeproj build
```

### Running Tests
```bash
# Run unit tests
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' test

# Run UI tests
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch AppUITests" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' test
```

### Development
- Open `RefWatch.xcodeproj` in Xcode
- Select "RefWatch Watch App" scheme
- Choose a watchOS simulator target
- Build and run with ⌘+R

## Architecture & Code Structure

### Module Organization
The app follows a feature-based architecture with clear separation of concerns:

```
RefWatch Watch App/
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
```

### Key Architectural Patterns

**MVVM with SwiftUI:**
- ViewModels use `@Observable` macro (Swift 5.9+)
- Views use `let model: MyModel` for observation (not @State)
- State management follows modern SwiftUI patterns

**Service/Coordinator Layer:**
- `MatchLifecycleCoordinator`: Controls high-level lifecycle routing (idle → setup → kickoff → running → halftime → second-half kickoff → finished).
- Timer responsibilities currently live in `MatchViewModel`; a focused `TimerManager` service will be extracted in PR v3 for SRP and testability.
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

## WatchOS Considerations

- **Target Platform**: watchOS 11.2+
- **Development Team**: 6NV7X5BLU7
- **Bundle ID**: com.IbrahimSaidi.RefWatch.watchkitapp
- **Interface Orientations**: Portrait and Portrait Upside Down
- **Deployment**: Watch-only app (WKWatchOnly = YES)

## Development Workflow

1. **Feature Development**: Create new features in the `Features/` directory following the established pattern (Models/ViewModels/Views)
2. **Shared Components**: Add reusable components to `Core/Components/`
3. **Business Logic**: Implement services in `Core/Services/`
4. **Testing**: Write unit tests in `RefWatch Watch AppTests/` and UI tests in `RefWatch Watch AppUITests/`

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
  - Invalidate existing timers before creating new ones.
  - Schedule in `.common` run loop mode and perform UI updates on the main thread.
  - Guard `RunLoop.current.add` by unwrapping timers (`if let`).
  - In `deinit`, invalidate timers to prevent leaks and retain cycles.
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
  - When using `xcodebuild`, specify a concrete watch device and OS to avoid destination ambiguity (e.g., `Apple Watch Series 10 (46mm)`, OS 11.5).
