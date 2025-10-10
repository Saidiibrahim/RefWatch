---
task_id: 04
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Implement Lifecycle → Navigation Mapping
phase: Phase A
created: 2025-10-10
status: Ready
priority: High
estimated_minutes: 60
dependencies: [TASK_03_flatten_navigation.md]
tags: [navigation, lifecycle, state-management, coordination]
---

# Task 04: Lifecycle → Navigation Mapping

## Objective

Implement the `handleLifecycleNavigation` method that maps lifecycle state transitions to navigation path changes. This creates a clear separation of concerns: lifecycle manages match domain state, navigation path manages presentation.

## Context

After Task 03, we have:
- ✅ Single NavigationStack with path-based navigation
- ✅ Lifecycle state still controls which view to show (via switch statement)
- ❌ Navigation path not yet synchronized with lifecycle transitions

**Current Problem:**
When lifecycle changes from `.idle` → `.kickoffFirstHalf`, the switch statement shows `MatchKickOffView`, but the navigation path still contains the start flow stack. That leaves `StartMatchScreen` sitting underneath the kickoff screen, causing back navigation to jump to the wrong place.

**Goal:**
Let lifecycle transitions collapse the navigation path back to root whenever match play begins (or ends), while keeping the path intact during the idle start flow. This keeps push-style navigation (start flow) and phase-based routing (kickoff/setup/etc.) from fighting each other.

## Implementation

### 0. Promote Navigation Reducer to Shared Helper

To keep tests and production code in sync, extract the path-reset logic into a small helper that both `MatchRootView` and the unit tests (Task 06) can exercise.

- **File:** `RefZoneWatchOS/Core/Navigation/MatchNavigationReducer.swift`
- **Contents:** A `struct MatchNavigationReducer` with a `func reduce(path:inout [MatchRoute], from: MatchPhase, to: MatchPhase)` method that encapsulates the logic currently living in `handleLifecycleNavigation`.
- Instantiate this reducer inside `MatchRootView` (e.g. `private let navigationReducer = MatchNavigationReducer()`) and delegate to it when mapping lifecycle transitions.

> This step ensures Task 06 can import the production reducer via `@testable import` without duplicating code in the test target.

### 1. Implement handleLifecycleNavigation Method

**File:** `RefZoneWatchOS/App/MatchRootView.swift`

Replace the placeholder from Task 02:

```swift
private extension MatchRootView {
    /// Maps lifecycle phases to navigation stack resets.
    /// Any time we leave the idle state we clear the path so start flow screens
    /// are popped. When we return to idle we also clear to guarantee a clean slate.
    func handleLifecycleNavigation(from oldState: MatchPhase, to newState: MatchPhase) {
        navigationReducer.reduce(path: &navigationPath, from: oldState, to: newState)
    }
}
```

### 2. Wire Up onChange Handler

Update the existing `onChange(of: lifecycle.state)` in `MatchRootView` body:

**Before:**
```swift
.onChange(of: lifecycle.state) { newState in
    #if DEBUG
    print("DEBUG: MatchRootView.onChange lifecycle.state=\(newState)")
    #endif
    if newState != .idle {
        appModeController.overrideForActiveSession(.match)
    }
}
```

**After:**
```swift
.onChange(of: lifecycle.state) { oldState, newState in
    #if DEBUG
    print("DEBUG: MatchRootView lifecycle transition: \(oldState) → \(newState)")
    print("DEBUG: Navigation path before: \(navigationPath)")
    #endif

    // Map lifecycle transitions to navigation changes
    handleLifecycleNavigation(from: oldState, to: newState)

    #if DEBUG
    print("DEBUG: Navigation path after: \(navigationPath)")
    #endif

    // Override app mode when match is active
    if newState != .idle {
        appModeController.overrideForActiveSession(.match)
    }
}
```

> ℹ️ The two-parameter `onChange(of:)` overload landed in watchOS 10.0. If the deployment target stays below that, keep the single-value overload and derive `oldState` manually.

### 3. Lifecycle-Friendly Callbacks

Keep the callbacks from Task 03: they should continue triggering lifecycle transitions via `DispatchQueue.main.async { lifecycle.goToKickoffFirst() }`. With the mapper above, those transitions automatically clear the start flow stack after the state update completes. No additional changes are needed inside `StartMatchScreen`.

## Acceptance Criteria

### Functionality
- [ ] `MatchNavigationReducer` extracted to `RefZoneWatchOS/Core/Navigation` and reused by `MatchRootView`
- [ ] `handleLifecycleNavigation` method implemented
- [ ] Lifecycle transitions out of idle clear the navigation path
- [ ] Returning to idle clears any residual start flow path
- [ ] `onChange(of: lifecycle.state)` calls `handleLifecycleNavigation`
- [ ] Callbacks trigger lifecycle transitions (not direct path changes)
- [ ] `DispatchQueue.main.async` used for lifecycle transitions

### Testing
- [ ] Start new match → path collapses to `[]` when kickoff screen appears
- [ ] Select saved match → path collapses to `[]` when kickoff screen appears
- [ ] Half-time transition → path remains empty (no ghost start flow entries)
- [ ] Match completion → path stays empty (final screen shown by lifecycle)
- [ ] Deep link to active match → path reset works without leaving stray entries

### Debug
- [ ] Debug prints show lifecycle transitions (DEBUG builds only)
- [ ] Debug prints show path before/after changes
- [ ] Easy to diagnose navigation issues

## Testing

### Manual Test Cases

#### Test 1: New Match Flow
```
Actions:
1. Launch app (idle)
2. Tap "Start"
3. Tap "Create Match"
4. Configure settings
5. Tap "Start Match"

Expected navigationPath states:
1. []
2. [.startFlow]
3. [.startFlow, .createMatch]
4. [.startFlow, .createMatch] (no change)
5. [] (kickoff transition clears the stacked start flow path)
```

#### Test 2: Saved Match Flow
```
Actions:
1. Launch app (idle)
2. Tap "Start"
3. Tap "Select Match"
4. Select a match

Expected navigationPath states:
1. []
2. [.startFlow]
3. [.startFlow, .savedMatches]
4. [] (kickoff transition clears the stacked start flow path)
```

#### Test 3: Half-Time Transition
```
Actions:
1. Match in progress (first half)
2. Half-time whistle
3. Resume second half

Expected navigationPath states:
1. []
2. [] (no navigation during active play)
3. [] (path stays empty; lifecycle drives kickoff surface)
```

#### Test 4: Match Completion
```
Actions:
1. Match in progress
2. Full-time whistle

Expected navigationPath states:
1. []
2. [] (full-time handled by lifecycle without pushing onto the stack)
```

### Debug Inspection

Enable debug logging and verify:
```
DEBUG: MatchRootView lifecycle transition: .idle → .kickoffFirstHalf
DEBUG: Navigation path before: [.startFlow, .createMatch]
DEBUG: Navigation path after: []
```

### Build Verification
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

## Migration Notes

### Separation of Concerns Achieved

**Before:**
```swift
// Lifecycle AND navigation mixed
lifecycle.goToKickoffFirst()  // Changes state
path.append(.kickoff)         // Changes navigation
dismiss()                      // Changes presentation
```

**After:**
```swift
// Lifecycle only
lifecycle.goToKickoffFirst()  // Changes domain state
// Navigation automatically follows via onChange
```

### Future Benefits

This separation enables:
- **Deep linking**: `handleDeepLink()` can set path directly
- **Testing**: Mock lifecycle, assert path changes
- **History**: Track navigation path for analytics
- **State restoration**: Serialize/deserialize path

## Next Steps

After completion:
- Task 05 will update remaining child components
- Task 06 will run comprehensive tests
- Phase B will extract coordinator to encapsulate this logic

## Notes

- Use `DispatchQueue.main.async` when triggering lifecycle from callbacks to avoid state update races
- Debug prints are essential for diagnosing navigation issues
- Path should reflect user's navigation history, not just current screen
- Empty path `[]` means "at root", not "no navigation"
- Use `MatchRoute.canonicalPath` helpers to avoid duplicating array literals
