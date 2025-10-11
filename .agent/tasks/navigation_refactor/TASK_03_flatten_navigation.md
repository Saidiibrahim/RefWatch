---
task_id: 03
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Flatten Navigation - Remove Nested NavigationStack (Checkpoints 1 & 2)
phase: Phase A
created: 2025-10-10
updated: 2025-10-10
status: Completed
priority: High
estimated_minutes: 150 (split across 2 checkpoints)
checkpoint_1_minutes: 90
checkpoint_2_minutes: 60
dependencies: [TASK_01_create_navigation_model.md, TASK_02_add_navigation_path.md]
tags: [navigation, refactor, swiftui, navigationstack, checkpoint-1, checkpoint-2]
---

# Task 03: Flatten Navigation Architecture (2 Checkpoints)

## Overview

This task is split into two checkpoints to enable incremental migration with shippable states:

- **Checkpoint 1** (90 min): Remove nested NavigationStack (Part A)
- **Checkpoint 2** (60 min): Complete path-based migration (Part B)

Each checkpoint is independently shippable and tested.

---

## Part A: Checkpoint 1 - Remove Nested Stack (90 min)

### Objective

Remove the nested `NavigationStack` from `StartMatchScreen` while keeping the app functional. This fixes the immediate anti-pattern without requiring full path-based navigation migration.

## Context

**Current Architecture (Problematic):**
```
MatchRootView
└─ NavigationStack
   ├─ switch lifecycle.state
   │  └─ .idle → List with NavigationLink
   │     └─ NavigationDestination → StartMatchScreen
   │        └─ NavigationStack (NESTED - BAD!)
   │           └─ path: [Route]
```

**Target Architecture:**
```
MatchRootView
└─ NavigationStack(path: $navigationPath)
   ├─ Root view (always visible)
   └─ .navigationDestination(for: MatchRoute.self)
      ├─ .startFlow → StartMatchScreen
      ├─ .savedMatches → SavedMatchesListView
      └─ .createMatch → MatchSettingsListView
```

## Implementation

### Part 1: Update MatchRootView NavigationStack

**File:** `RefZoneWatchOS/App/MatchRootView.swift`

#### 1.1 Change NavigationStack Declaration (line ~43)

**Before:**
```swift
NavigationStack {
    Group {
        switch lifecycle.state {
        case .idle:
            List { ... }
        case .kickoffFirstHalf:
            MatchKickOffView(...)
        // ...
        }
    }
    .toolbar { ... }
    .navigationDestination(isPresented: $isStartMatchActive) {
        StartMatchScreen(...)
    }
}
```

**After:**
```swift
NavigationStack(path: $navigationPath) {
    Group {
        switch lifecycle.state {
        case .idle:
            List { ... }
        case .kickoffFirstHalf:
            MatchKickOffView(...)
        // ...
        }
    }
    .toolbar { ... }
    .navigationDestination(for: MatchRoute.self) { route in
        destination(for: route)
    }
}
```

#### 1.2 Update heroSection Button (lines 187-195)

**Before:**
```swift
Button {
    isStartMatchActive = true
} label: {
    StartMatchHeroCard()
}
```

**After:**
```swift
Button {
    navigationPath = [.startFlow]
} label: {
    StartMatchHeroCard()
}
```

#### 1.3 Add Destination Builder Method

Add to private extension:

```swift
private extension MatchRootView {
    func setNavigationPath(for route: MatchRoute) {
        navigationPath = route.canonicalPath
    }

    @ViewBuilder
    func destination(for route: MatchRoute) -> some View {
        switch route {
        case .startFlow:
            StartMatchScreen(
                matchViewModel: matchViewModel,
                lifecycle: lifecycle,
                onNavigate: setNavigationPath
            )

        case .savedMatches:
            SavedMatchesListView(matches: matchViewModel.savedMatches) { match in
                matchViewModel.selectMatch(match)
                // Kickoff navigation handled by lifecycle in Task 04
            }

        case .createMatch:
            MatchSettingsListView(
                matchViewModel: matchViewModel,
                onStartMatch: { viewModel in
                    viewModel.configureMatch(
                        duration: viewModel.matchDuration,
                        periods: viewModel.numberOfPeriods,
                        halfTimeLength: viewModel.halfTimeLength,
                        hasExtraTime: viewModel.hasExtraTime,
                        hasPenalties: viewModel.hasPenalties
                    )
                    // Kickoff navigation handled by lifecycle in Task 04
                }
            )
    }
}

private extension MatchRoute {
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
}
```

#### 1.4 Remove isStartMatchActive

Delete the `@State` property (it's now replaced by `navigationPath`):

```swift
// DELETE THIS LINE:
@State private var isStartMatchActive = false
```

Also remove the `onChange(of: lifecycle.state)` that resets it (around line 157):

```swift
// DELETE THIS BLOCK:
if newState != .idle {
    appModeController.overrideForActiveSession(.match)
    isStartMatchActive = false  // <-- DELETE
}
```

### Part 2: Refactor StartMatchScreen

**File:** `RefZoneWatchOS/Features/Match/Views/StartMatchScreen.swift`

#### 2.1 Update View Signature

**Before:**
```swift
struct StartMatchScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Route] = []

    private enum Route: Hashable {
        case savedMatches
        case createMatch
    }
```

**After:**
```swift
struct StartMatchScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    // Navigation is now handled by parent
    let onNavigate: (MatchRoute) -> Void
```

#### 2.2 Replace NavigationStack with Simple Container

**Before:**
```swift
var body: some View {
    NavigationStack(path: $path) {
        StartMatchOptionsView(
            onReset: handleReset,
            onSelectMatch: { path.append(.savedMatches) },
            onCreateMatch: { path.append(.createMatch) }
        )
        // ...
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .savedMatches: SavedMatchesListView(...)
            case .createMatch: MatchSettingsListView(...)
            }
        }
    }
    .onChange(of: lifecycle.state) { ... }
}
```

**After:**
```swift
var body: some View {
    StartMatchOptionsView(
        onReset: handleReset,
        onSelectMatch: { onNavigate(.savedMatches) },
        onCreateMatch: { onNavigate(.createMatch) }
    )
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    .navigationTitle("Start Match")
    .toolbar {
        ToolbarItem(placement: .topBarLeading) {
            if lifecycle.state == .idle {
                Button {
                    modeSwitcherPresentation.wrappedValue = true
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("Back")
            }
        }
    }
    .onChange(of: lifecycle.state) { newValue in
        // When lifecycle moves past idle, dismiss this screen
        if newValue != .idle {
            dismiss()
        }
    }
}
```

#### 2.3 Remove Private Route Enum

Delete the nested `Route` enum - no longer needed:

```swift
// DELETE THIS:
private enum Route: Hashable {
    case savedMatches
    case createMatch
}
```

## Acceptance Criteria

### MatchRootView
- [ ] `NavigationStack(path: $navigationPath)` used instead of `NavigationStack`
- [ ] `.navigationDestination(for: MatchRoute.self)` implemented
- [ ] `destination(for:)` method handles all routes
- [ ] `heroSection` button sets `navigationPath` to `[.startFlow]`
- [ ] `isStartMatchActive` property removed
- [ ] `onChange` that resets `isStartMatchActive` removed

### StartMatchScreen
- [ ] `NavigationStack` wrapper removed
- [ ] `path: [Route]` state removed
- [ ] `Route` enum removed
- [ ] `onNavigate: (MatchRoute) -> Void` callback added
- [ ] Callbacks use `onNavigate()` instead of `path.append()`
- [ ] `onChange(of: lifecycle.state)` still dismisses view

### Build & Runtime
- [ ] Project builds without errors
- [ ] No nested NavigationStacks in codebase
- [ ] Single click navigation works throughout
- [ ] Back navigation works correctly

## Testing

### Manual Testing Checklist

1. **Start Flow**
   - [ ] Tap "Start" button once → navigates to StartMatchOptionsView
   - [ ] Tap "Create Match" once → navigates to MatchSettingsListView
   - [ ] Tap "Select Match" once → navigates to SavedMatchesListView
   - [ ] Tap "Start" twice quickly → navigationPath stays `[.startFlow]` (no duplicate entries)

2. **Create Match Flow**
   - [ ] Configure settings in MatchSettingsListView
   - [ ] Tap "Start Match" once → proceeds to kickoff
   - [ ] Lifecycle state changes correctly

3. **Saved Match Flow**
   - [ ] Select a saved match
   - [ ] Proceeds to kickoff correctly

4. **Back Navigation**
   - [ ] Back button from MatchSettingsListView returns to StartMatchOptionsView
   - [ ] Back button from StartMatchOptionsView returns to idle home
   - [ ] SwiftUI back gesture works (swipe from left)

5. **Lifecycle Transitions**
   - [ ] Kickoff → Match In Progress works
   - [ ] Half-time transitions work
   - [ ] Match completion returns to idle

### Build Verification
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

### Regression Testing
- [ ] History navigation works
- [ ] Settings navigation works
- [ ] Widget deep links still function (if implemented)

## Migration Notes

### Breaking Changes

**StartMatchScreen Signature:**
- Old: `StartMatchScreen(matchViewModel:lifecycle:)`
- New: `StartMatchScreen(matchViewModel:lifecycle:onNavigate:)`

All call sites must be updated (handled in `MatchRootView.destination(for:)`).

### Rollback Plan

If issues arise:
1. Revert `MatchRootView.swift` to use `NavigationLink(isActive:)`
2. Revert `StartMatchScreen.swift` to use nested `NavigationStack`
3. File bug report with reproduction steps
4. Short-term fixes from Sprint 1 will still be in place

## Next Steps

After completion:
- Task 04 will implement lifecycle → navigation mapping
- Task 05 will update remaining child components
- Task 06 will run comprehensive navigation tests

## Notes

- This is the largest single change in Phase A
- Take time to test thoroughly before moving to Task 04
- Consider pairing or code review before merging
- Navigation path can be inspected for debugging: `print("Navigation path: \(navigationPath)")`
- Implement `MatchRoute.canonicalPath` (see snippet above) so every navigation intent replaces the stack with a known shape rather than appending blindly.
