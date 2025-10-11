---
task_id: 08
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Integrate MatchFlowCoordinator in MatchRootView
phase: Phase B
created: 2025-10-10
status: ⏸️ DEFERRED
priority: Low (deferred until watchOS navigation complexity increases)
estimated_minutes: 60
dependencies: [TASK_07_create_flow_coordinator.md]
tags: [coordinator, integration, refactor, matchrootview, phase-b]
---

# Task 08: Integrate Coordinator in MatchRootView

## Objective

Refactor `MatchRootView` to use `MatchFlowCoordinator` instead of directly managing `navigationPath`. This completes the transition to a coordinator-based architecture where navigation logic is centralized.

## Context

**After Task 07:**
- ✅ `MatchFlowCoordinator` class created
- ✅ Intent-based navigation API available
- ✅ Deep link handling implemented

**This Task:**
- Replace `@State var navigationPath` with `@State var flowCoordinator`
- Update `NavigationStack` to bind to `coordinator.navigationPath`
- Update callbacks to use coordinator methods
- Migrate deep link handler to coordinator

## Implementation

### 1. Update State Properties

**File:** `RefZoneWatchOS/App/MatchRootView.swift`

#### 1.1 Replace navigationPath with flowCoordinator

**Before:**
```swift
@State private var matchViewModel: MatchViewModel
@State private var settingsViewModel: SettingsViewModel
@State private var lifecycle: MatchLifecycleCoordinator
@State private var showPersistenceError = false
@State private var latestSummary: CompletedMatchSummary?
@State private var navigationPath: [MatchRoute] = []
```

**After:**
```swift
@State private var matchViewModel: MatchViewModel
@State private var settingsViewModel: SettingsViewModel
@State private var lifecycle: MatchLifecycleCoordinator
@State private var showPersistenceError = false
@State private var latestSummary: CompletedMatchSummary?
@State private var flowCoordinator: MatchFlowCoordinator
```

#### 1.2 Initialize Coordinator in init()

**Before:**
```swift
@MainActor
init(matchViewModel: MatchViewModel? = nil) {
    let runtimeController = BackgroundRuntimeSessionController()
    _backgroundRuntimeController = State(initialValue: runtimeController)
    if let matchViewModel {
        _matchViewModel = State(initialValue: matchViewModel)
    } else {
        _matchViewModel = State(initialValue: MatchViewModel(
            haptics: WatchHaptics(),
            backgroundRuntime: runtimeController,
            connectivity: WatchConnectivitySyncClient()
        ))
    }
    _settingsViewModel = State(initialValue: SettingsViewModel())
    _lifecycle = State(initialValue: MatchLifecycleCoordinator())
}
```

**After:**
```swift
@MainActor
init(matchViewModel: MatchViewModel? = nil) {
    let runtimeController = BackgroundRuntimeSessionController()
    _backgroundRuntimeController = State(initialValue: runtimeController)

    let vm: MatchViewModel
    if let matchViewModel {
        vm = matchViewModel
        _matchViewModel = State(initialValue: matchViewModel)
    } else {
        vm = MatchViewModel(
            haptics: WatchHaptics(),
            backgroundRuntime: runtimeController,
            connectivity: WatchConnectivitySyncClient()
        )
        _matchViewModel = State(initialValue: vm)
    }

    _settingsViewModel = State(initialValue: SettingsViewModel())

    let lifecycleCoord = MatchLifecycleCoordinator()
    _lifecycle = State(initialValue: lifecycleCoord)

    // Initialize flow coordinator with lifecycle and view model
    _flowCoordinator = State(initialValue: MatchFlowCoordinator(
        lifecycle: lifecycleCoord,
        matchViewModel: vm
    ))
}
```

### 2. Update NavigationStack Binding

**Before:**
```swift
var body: some View {
    NavigationStack(path: $navigationPath) {
        Group {
            switch lifecycle.state {
            // ...
            }
        }
        .toolbar { ... }
        .navigationDestination(for: MatchRoute.self) { route in
            destination(for: route)
        }
    }
    // ...
}
```

**After:**
```swift
var body: some View {
    NavigationStack(path: $flowCoordinator.navigationPath) {
        Group {
            switch lifecycle.state {
            // ...
            }
        }
        .toolbar { ... }
        .navigationDestination(for: MatchRoute.self) { route in
            destination(for: route)
        }
    }
    // ...
}
```

### 3. Update heroSection Button

**Before:**
```swift
Button {
    navigationPath.append(.startFlow)
} label: {
    StartMatchHeroCard()
}
```

**After:**
```swift
Button {
    flowCoordinator.showStartFlow()
} label: {
    StartMatchHeroCard()
}
```

### 4. Update onChange Handler

**Before:**
```swift
.onChange(of: lifecycle.state) { oldState, newState in
    #if DEBUG
    print("DEBUG: MatchRootView lifecycle transition: \(oldState) → \(newState)")
    print("DEBUG: Navigation path before: \(navigationPath)")
    #endif

    handleLifecycleNavigation(from: oldState, to: newState)

    #if DEBUG
    print("DEBUG: Navigation path after: \(navigationPath)")
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
    print("DEBUG: Navigation path before: \(flowCoordinator.navigationPath)")
    #endif

    // Delegate to coordinator for lifecycle → navigation mapping
    flowCoordinator.handleLifecycleTransition(from: oldState, to: newState)

    #if DEBUG
    print("DEBUG: Navigation path after: \(flowCoordinator.navigationPath)")
    #endif

    if newState != .idle {
        appModeController.overrideForActiveSession(.match)
    }
}
```

### 5. Remove handleLifecycleNavigation Method

Delete the `handleLifecycleNavigation` and `handleTransitionFromIdle` methods from `MatchRootView`'s private extension - they're now in the coordinator.

```swift
// DELETE THESE METHODS:
// func handleLifecycleNavigation(from:to:)
// func handleTransitionFromIdle(to:)
```

### 6. Update Deep Link Handler

**Before:**
```swift
.onOpenURL { url in
    guard url.scheme == "refzone" else { return }
    if url.host == "timer" {
        if matchViewModel.isMatchInProgress || matchViewModel.isHalfTime || matchViewModel.penaltyShootoutActive {
            lifecycle.goToSetup()
        } else if matchViewModel.waitingForSecondHalfStart {
            lifecycle.goToKickoffSecond()
        } else if matchViewModel.waitingForET1Start {
            lifecycle.goToKickoffETFirst()
        } else if matchViewModel.waitingForET2Start {
            lifecycle.goToKickoffETSecond()
        } else {
            navigationPath = [.startFlow]
        }
        consumeWidgetCommand()
    }
}
```

**After:**
```swift
.onOpenURL { url in
    // Delegate all deep link handling to coordinator
    flowCoordinator.handleDeepLink(url)

    // Consume widget command if applicable
    if url.scheme == "refzone" && url.host == "timer" {
        consumeWidgetCommand()
    }
}
```

### 7. Update destination(for:) Callbacks

Update callbacks to use coordinator methods instead of direct lifecycle calls:

**Before:**
```swift
case .createMatch:
    MatchSettingsListView(
        matchViewModel: matchViewModel,
        onStartMatch: { viewModel in
            viewModel.configureMatch(...)
            DispatchQueue.main.async {
                lifecycle.goToKickoffFirst()
            }
        }
    )
```

**After:**
```swift
case .createMatch:
    MatchSettingsListView(
        matchViewModel: matchViewModel,
        onStartMatch: { viewModel in
            viewModel.configureMatch(...)
            // Coordinator handles lifecycle coordination
            flowCoordinator.proceedToKickoff()
        }
    )
```

**Similarly for savedMatches:**
```swift
case .savedMatches:
    SavedMatchesListView(matches: matchViewModel.savedMatches) { match in
        flowCoordinator.resumeSavedMatch(match)
    }
```

## Acceptance Criteria

### Code Changes
- [ ] `flowCoordinator` state property added
- [ ] Coordinator initialized in `init()`
- [ ] NavigationStack binds to `coordinator.navigationPath`
- [ ] `heroSection` button calls `coordinator.showStartFlow()`
- [ ] `onChange` delegates to `coordinator.handleLifecycleTransition`
- [ ] `onOpenURL` delegates to `coordinator.handleDeepLink`
- [ ] `destination(for:)` callbacks use coordinator methods
- [ ] `handleLifecycleNavigation` methods removed

### Build & Runtime
- [ ] Project builds without errors
- [ ] No compiler warnings
- [ ] Navigation works identically to Phase A
- [ ] No regressions

## Testing

### Manual Testing

#### Basic Navigation
- [ ] Tap "Start" → shows start flow (via coordinator)
- [ ] Create new match → proceeds to kickoff
- [ ] Select saved match → proceeds to kickoff
- [ ] All navigation identical to Phase A

#### Deep Links
- [ ] Widget tap while idle → start flow presented (path `[.startFlow]`)
- [ ] Widget tap during match → match resumes with empty path (screens driven by lifecycle)
- [ ] Deep link URLs work

#### Lifecycle Transitions
- [ ] First half → second half kickoff
- [ ] Match completion → full-time screen
- [ ] Extra time transitions

### Build Verification
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

### Regression Testing
- [ ] Run Phase A test checklist (Task 06)
- [ ] All previous tests still pass

## Migration Notes

### Before vs After

**Before (Phase A):**
```swift
// MatchRootView
@State private var navigationPath: [MatchRoute] = []

// Navigation
navigationPath.append(.startFlow)

// Lifecycle handling
handleLifecycleNavigation(from: old, to: new)
```

**After (Phase B):**
```swift
// MatchRootView
@State private var flowCoordinator: MatchFlowCoordinator

// Navigation
flowCoordinator.showStartFlow()

// Lifecycle handling
flowCoordinator.handleLifecycleTransition(from: old, to: new)
```

### Benefits

- Navigation logic centralized in coordinator
- Intent-based API more readable
- Easier to test (mock coordinator)
- Improved maintainability and scalability

## Next Steps

After completion:
- Task 09 will update child views to use coordinator
- Task 10 will implement deep link tests
- Task 11 will add unit tests for coordinator

## Notes

- This is a refactor, not a feature change - behavior should be identical
- If issues arise, coordinator can be bypassed temporarily
- Coordinator owns path but not lifecycle state (lifecycle still separate)
- `DispatchQueue.main.async` is now inside coordinator methods
