---
task_id: 05
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Update Child Components for Path-Based Navigation
phase: Phase A
created: 2025-10-10
status: Ready
priority: Medium
estimated_minutes: 45
dependencies: [TASK_04_lifecycle_navigation_mapping.md]
tags: [components, refactor, callbacks, swiftui]
---

# Task 05: Update Child Components

## Objective

Update remaining child components (`SavedMatchesListView`, `MatchSettingsListView`, `StartMatchOptionsView`) to work seamlessly with the new path-based navigation architecture. Ensure callbacks trigger lifecycle transitions rather than direct navigation path manipulation.

## Context

After Tasks 03-04:
- ✅ Navigation path is managed by `MatchRootView`
- ✅ Lifecycle transitions automatically update navigation path
- ✅ `StartMatchScreen` uses callbacks

**Remaining Work:**
- Update callback signatures where needed
- Remove any direct path manipulation
- Ensure consistent callback patterns

## Implementation

### 1. SavedMatchesListView

**File:** `RefZoneWatchOS/Core/Components/MatchStart/SavedMatchesListView.swift`

**Current State:**
This component is already callback-based and doesn't manipulate navigation directly.

**Action: Verify Only**
```swift
// Current callback (should already be correct):
let onSelectMatch: (Match) -> Void

// Usage in MatchRootView.destination(for:) should be:
SavedMatchesListView(matches: matchViewModel.savedMatches) { match in
    matchViewModel.selectMatch(match)
    DispatchQueue.main.async {
        lifecycle.goToKickoffFirst()
    }
}
```

**No changes needed** - just verify the callback is wired correctly in `MatchRootView`.

### 2. MatchSettingsListView

**File:** `RefZoneWatchOS/Core/Components/MatchStart/MatchSettingsListView.swift`

**Current State:**
Already callback-based with `onStartMatch: (MatchViewModel) -> Void`.

**Action: Verify Only**

```swift
// Current signature (should already be correct):
let onStartMatch: (MatchViewModel) -> Void

// Usage in MatchRootView.destination(for:) should be:
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

**No changes needed** - verify the callback wiring in `MatchRootView`.

### 3. StartMatchOptionsView

**File:** `RefZoneWatchOS/Core/Components/MatchStart/StartMatchOptionsView.swift`

**Current State:**
Already callback-based with:
```swift
private let onReset: () -> Void
private let onSelectMatch: () -> Void
private let onCreateMatch: () -> Void
```

**Action: Verify Callback Usage**

In `StartMatchScreen` (updated in Task 03):
```swift
StartMatchOptionsView(
    onReset: handleReset,
    onSelectMatch: { onNavigate(.savedMatches) },
    onCreateMatch: { onNavigate(.createMatch) }
)
```

**No changes needed** - already using callbacks correctly.

### 4. MatchKickOffView

**File:** `RefZoneWatchOS/Features/Match/Views/MatchKickOffView.swift`

**Current State:**
Already uses lifecycle coordinator for transitions:

```swift
private func confirmKickOff() {
    guard let team = selectedTeam else { return }
    if let phase = etPhase {
        if phase == 1 {
            matchViewModel.setKickingTeamET1(team == .home)
            matchViewModel.startExtraTimeFirstHalfManually()
            lifecycle.goToSetup()  // ✅ Already correct
        }
        // ...
    } else if isSecondHalf {
        matchViewModel.setKickingTeam(team == .home)
        matchViewModel.startSecondHalfManually()
        lifecycle.goToSetup()  // ✅ Already correct
    } else {
        matchViewModel.setKickingTeam(team == .home)
        matchViewModel.startMatch()
        lifecycle.goToSetup()  // ✅ Already correct
    }
}
```

**Action: Verify Only**

This component already triggers lifecycle transitions, which will automatically update the navigation path via the `onChange` handler in `MatchRootView`.

**No changes needed** - already correct.

### 5. Deep Link Handler (Future-Proofing)

**File:** `RefZoneWatchOS/App/MatchRootView.swift`

Update the `onOpenURL` handler to use navigation path:

**Before:**
```swift
.onOpenURL { url in
    guard url.scheme == "refzone" else { return }
    if url.host == "timer" {
        if matchViewModel.isMatchInProgress || matchViewModel.isHalfTime || matchViewModel.penaltyShootoutActive {
            lifecycle.goToSetup()
        } else if matchViewModel.waitingForSecondHalfStart {
            lifecycle.goToKickoffSecond()
        }
        // ...
        consumeWidgetCommand()
    }
}
```

**After:**
```swift
.onOpenURL { url in
    guard url.scheme == "refzone" else { return }
    if url.host == "timer" {
        // Use lifecycle transitions, path will follow automatically
        if matchViewModel.isMatchInProgress || matchViewModel.isHalfTime || matchViewModel.penaltyShootoutActive {
            lifecycle.goToSetup()
        } else if matchViewModel.waitingForSecondHalfStart {
            lifecycle.goToKickoffSecond()
        } else if matchViewModel.waitingForET1Start {
            lifecycle.goToKickoffETFirst()
        } else if matchViewModel.waitingForET2Start {
            lifecycle.goToKickoffETSecond()
        } else {
            // Not in a match, navigate to start flow
            navigationPath = [.startFlow]
        }
        consumeWidgetCommand()
    }
}
```

## Acceptance Criteria

### Component Updates
- [ ] `SavedMatchesListView` - verified callback usage
- [ ] `MatchSettingsListView` - verified callback usage
- [ ] `StartMatchOptionsView` - verified callback usage
- [ ] `MatchKickOffView` - verified lifecycle usage
- [ ] Deep link handler updated to use path

### Code Quality
- [ ] No direct `navigationPath` manipulation in child components
- [ ] All navigation uses callbacks → lifecycle → path pattern
- [ ] `DispatchQueue.main.async` used for lifecycle transitions
- [ ] Comments explain callback → lifecycle flow

### Testing
- [ ] All child components still function correctly
- [ ] Callbacks trigger expected navigation
- [ ] No navigation regressions

## Testing

### Component-Level Tests

#### SavedMatchesListView
```
1. Tap a saved match
   Expected: Callback fires, lifecycle goes to kickoff, path resets to `[]` after transition
```

#### MatchSettingsListView
```
1. Configure settings
2. Tap "Start Match"
   Expected: Settings applied, lifecycle goes to kickoff, path resets to `[]` after transition
```

#### StartMatchOptionsView
```
1. Tap "Select Match"
   Expected: onNavigate(.savedMatches) called, navigationPath becomes `[.startFlow, .savedMatches]`
2. Tap "Create Match"
   Expected: onNavigate(.createMatch) called, navigationPath becomes `[.startFlow, .createMatch]`
```

#### MatchKickOffView
```
1. Select team
2. Tap confirm
   Expected: lifecycle.goToSetup() called, path clears to []
```

#### Deep Link
```
1. Tap widget while match in progress
   Expected: lifecycle.goToSetup(), path clears to []
2. Tap widget when idle
   Expected: path becomes [.startFlow]
```

### Build Verification
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

## Migration Notes

### Callback Pattern

**Consistent Pattern Across All Components:**
```swift
// Child component
Button("Action") {
    onAction()  // Emit intent via callback
}

// Parent (MatchRootView)
ChildView {
    // Handle intent:
    // 1. Update domain state (if needed)
    // 2. Trigger lifecycle transition
    DispatchQueue.main.async {
        lifecycle.goToNextState()
    }
}

// Automatic:
// onChange(of: lifecycle.state) updates navigationPath
```

### Why DispatchQueue.main.async?

Prevents state update races when:
1. Button tap triggers callback
2. Callback triggers lifecycle change
3. onChange updates navigation path
4. SwiftUI re-renders

The async ensures each state update completes before the next begins.

## Next Steps

After completion:
- Task 06 will run comprehensive navigation tests
- All Phase A tasks complete
- Ready to consider Phase B (Flow Coordinator)

## Notes

- Most components were already callback-based (good design!)
- This task is mainly verification and documentation
- Focus on ensuring `DispatchQueue.main.async` is used consistently
- Deep link handler is the only new code in this task
