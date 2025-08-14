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

**Service Layer:**
- `MatchStateService`: Manages match state transitions and periods
- `TimerService`: Handles all timing-related functionality
- Services are injected into ViewModels, not used directly in Views

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
- `MatchViewModel` handles timing logic
- `TimerService` provides timer functionality
- Supports multiple periods, half-time, and extra time
- Real-time updates with proper state management

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