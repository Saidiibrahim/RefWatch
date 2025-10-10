---
task_id: 01
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Create Navigation Model (MatchRoute enum)
phase: Phase A
created: 2025-10-10
status: Ready
priority: High
estimated_minutes: 30
dependencies: []
tags: [navigation, model, enum, swiftui]
---

# Task 01: Create Navigation Model

## Objective

Create a new `MatchRoute` enum that represents all possible navigation destinations in the match flow. This enum will be the foundation for path-based navigation and will replace implicit navigation state scattered across multiple components.

## Context

Currently, navigation state is implicitly managed through:
- `isStartMatchActive` boolean in `MatchRootView`
- Nested `path: [Route]` in `StartMatchScreen`
- `lifecycle.state` transitions

This task creates an explicit navigation model that:
- Represents all destinations as enum cases
- Conforms to `Hashable` for SwiftUI NavigationPath
- Separates navigation concerns from domain logic

## Implementation

### 1. Create New File

**Location:** `RefZoneWatchOS/Core/Navigation/MatchRoute.swift`

### 2. Define MatchRoute Enum

```swift
import Foundation

/// Represents navigation destinations that are pushed on top of the idle root.
/// The lifecycle-driven phases (kickoff, halftime, in-progress) stay owned by
/// `MatchRootView` so we only enumerate the routes that truly require stacking.
enum MatchRoute: Hashable {
    /// Entry point for the start flow hub (create vs resume match)
    case startFlow

    /// Saved matches list presented from the start flow
    case savedMatches

    /// Match configuration screen prior to kickoff
    case createMatch
}

extension MatchRoute {
    /// Stable canonical stack shapes for each supported route. Later tasks call
    /// into this helper so navigation state changes stay consistent and we avoid
    /// duplicating array literals across the codebase.
    var canonicalPath: [MatchRoute] {
        switch self {
        case .startFlow:
            return [.startFlow]
        case .savedMatches:
            return [.startFlow, .savedMatches]
        case .createMatch:
            return [.startFlow, .createMatch]
        }
    }
}
```

### 3. Add Documentation

Each enum case should have clear documentation explaining:
- When it's used
- What screen it represents
- Any associated data

## Acceptance Criteria

- [ ] New file created at `RefZoneWatchOS/Core/Navigation/MatchRoute.swift`
- [ ] `MatchRoute` enum defined with all cases
- [ ] `canonicalPath` helper added on `MatchRoute`
- [ ] Enum conforms to `Hashable`
- [ ] All cases have doc comments
- [ ] File builds without errors
- [ ] Enums are used nowhere yet (foundation only)

## Testing

### Build Verification
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

### Code Review
- Verify all current navigation destinations are represented
- Check that enum is extensible for future routes
- Confirm `canonicalPath` covers every case and returns stable stacks

## Next Steps

After completion:
- Task 02 will add `navigationPath` state to `MatchRootView`
- The enum will be consumed by `NavigationStack(path:)` in Task 03

## Notes

- Keep this enum simple and focused on navigation only
- Avoid adding business logic or view logic
- Additional cases can be added later (Phase B) if we start stacking gameplay phases
- Future routes (tutorials, onboarding) can be added as new cases
