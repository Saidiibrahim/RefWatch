---
task_id: 02
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Add NavigationPath State to MatchRootView
phase: Phase A
created: 2025-10-10
status: Completed
priority: High
estimated_minutes: 20
dependencies: [TASK_01_create_navigation_model.md]
tags: [navigation, state, swiftui, matchrootview]
---

# Task 02: Add NavigationPath State to MatchRootView

## Objective

Add a `@State private var navigationPath: [MatchRoute] = []` property to `MatchRootView` that will become the single source of truth for navigation state. This replaces the fragmented navigation state currently spread across multiple components.

## Context

**Current State:**
- `@State private var isStartMatchActive = false` (line 21) - binary navigation flag
- Nested `path` in `StartMatchScreen` (separate navigation stack)
- No centralized navigation state

**After This Task:**
- Single `navigationPath` array tracks entire navigation stack
- Foundation for flattening navigation in Task 03
- Prepares for lifecycle → navigation mapping in Task 04

## Implementation

### 1. Import MatchRoute

**File:** `RefZoneWatchOS/App/MatchRootView.swift`

Add import at top of file:
```swift
import SwiftUI
import RefWatchCore
// Add this:
import Foundation // If not already imported
```

### 2. Add NavigationPath State

Add after existing `@State` properties (around line 21):

```swift
@State private var latestSummary: CompletedMatchSummary?
@State private var isStartMatchActive = false // Keep for now, will remove in Task 03
// Add this:
@State private var navigationPath: [MatchRoute] = []
```

### 3. Add Helper Method (Placeholder)

Add in the private extension at the bottom of the file:

```swift
private extension MatchRootView {
    // ... existing methods ...

    /// Maps lifecycle state transitions to navigation path changes.
    /// This will be fully implemented in Task 04.
    func handleLifecycleNavigation(from oldState: MatchPhase, to newState: MatchPhase) {
        // TODO: Implement in Task 04
        // For now, this is a placeholder to show where the logic will live
    }
}
```

## Acceptance Criteria

- [ ] `navigationPath` state variable added to `MatchRootView`
- [ ] Initialized as empty array: `[]`
- [ ] Type is explicitly `[MatchRoute]`
- [ ] `isStartMatchActive` is NOT removed yet (will be removed in Task 03)
- [ ] Placeholder `handleLifecycleNavigation` method added
- [ ] File builds without errors
- [ ] No behavioral changes (navigation still works as before)

## Testing

### Build Verification
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

### Runtime Verification
- Launch watch app in simulator
- Verify navigation still works exactly as before
- No regressions introduced

## Migration Notes

### Why Keep isStartMatchActive?

We keep `isStartMatchActive` temporarily because:
1. Current `heroSection` still uses it via `navigationDestination(isPresented:)`
2. Task 03 will migrate to path-based navigation
3. Allows incremental migration (safer)

### Deprecation Timeline

- Task 02: Add `navigationPath` (this task)
- Task 03: Switch `heroSection` to use `navigationPath`
- Task 03: Remove `isStartMatchActive`

## Next Steps

After completion:
- Task 03 will update `NavigationStack` to use `navigationPath`
- Task 03 will replace `isStartMatchActive` with path-based navigation
- Task 04 will implement `handleLifecycleNavigation` method

## Notes

- `navigationPath` is an array because SwiftUI's `NavigationPath` works with homogeneous types
- Empty array represents "at root" (idle state)
- Each route in the array represents a navigation layer
- Example: `[.startFlow, .createMatch]` = Start screen → Create Match screen
