---
task_id: 09
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Update Child Views to Emit Intents
phase: Phase B
created: 2025-10-10
status: ⏸️ DEFERRED
priority: Low (deferred until watchOS navigation complexity increases)
estimated_minutes: 30
dependencies: [TASK_08_refactor_match_root_view.md]
tags: [components, intents, refactor, phase-b]
---

# Task 09: Update Child Views to Emit Intents

## Objective

Update child views to use coordinator methods instead of direct callbacks where beneficial. This is an optional refinement that makes the intent-based architecture more explicit.

## Context

**After Task 08:**
- ✅ `MatchRootView` uses `MatchFlowCoordinator`
- ✅ Callbacks work via coordinator

**This Task (Optional Refinement):**
- Consider passing coordinator to child views
- Let child views call coordinator methods directly
- Evaluate trade-offs

## Analysis

### Current Approach (After Task 08)

**Child Views:**
```swift
// SavedMatchesListView
let onSelectMatch: (Match) -> Void

// MatchSettingsListView
let onStartMatch: (MatchViewModel) -> Void
```

**Parent (MatchRootView):**
```swift
SavedMatchesListView(matches: matches) { match in
    flowCoordinator.resumeSavedMatch(match)
}

MatchSettingsListView(matchViewModel: vm) { viewModel in
    viewModel.configureMatch(...)
    flowCoordinator.proceedToKickoff()
}
```

### Alternative Approach (Pass Coordinator)

**Child Views:**
```swift
// SavedMatchesListView
let flowCoordinator: MatchFlowCoordinator

// Usage inside:
Button {
    flowCoordinator.resumeSavedMatch(match)
} label: { ... }
```

**Parent:**
```swift
SavedMatchesListView(
    matches: matches,
    flowCoordinator: flowCoordinator
)
```

## Decision: Stick with Callbacks

**Recommendation:** Keep the callback-based approach from Task 08.

### Reasons

**✅ Pros of Callbacks:**
1. **Testability**: Easy to test child views in isolation with mock callbacks
2. **Reusability**: Child views don't depend on specific coordinator
3. **Separation**: Child views don't need to know about navigation logic
4. **Flexibility**: Parent decides how to handle intents

**❌ Cons of Passing Coordinator:**
1. **Coupling**: Child views coupled to `MatchFlowCoordinator`
2. **Testing**: Harder to test child views (need to mock coordinator)
3. **Reusability**: Child views can't be reused with different coordinators
4. **Imports**: Need to import coordinator in every child view

### When to Pass Coordinator

Pass coordinator only when:
- View has complex multi-step navigation logic
- View needs to coordinate multiple navigation actions
- View is tightly coupled to the coordinator already

**In this app:** None of the child views meet these criteria. They all have simple, single-intent actions.

## Implementation

### Action: Verify & Document

#### 1. Verify Current Callback Usage

**Files to check:**
- `SavedMatchesListView.swift` - uses `onSelectMatch` callback ✅
- `MatchSettingsListView.swift` - uses `onStartMatch` callback ✅
- `StartMatchOptionsView.swift` - uses `onSelectMatch` and `onCreateMatch` callbacks ✅

All child views already use callbacks correctly.

#### 2. Add Documentation Comments

Update doc comments in child views to clarify the callback pattern:

**Example for SavedMatchesListView:**
```swift
/// Displays a list of previously saved matches.
///
/// This component uses a callback-based approach for selection,
/// allowing the parent to decide how to handle navigation.
/// The parent (MatchRootView) delegates to MatchFlowCoordinator.
///
/// - Parameters:
///   - matches: The array of saved matches to display
///   - onSelectMatch: Callback invoked when a match is selected.
///                    The parent should handle navigation logic.
struct SavedMatchesListView: View {
    let matches: [Match]
    let onSelectMatch: (Match) -> Void
    // ...
}
```

#### 3. Document Pattern in CLAUDE.md

Add a section to `CLAUDE.md` explaining the navigation pattern:

```markdown
### Navigation Architecture

The app uses a coordinator pattern for navigation:

1. **MatchFlowCoordinator**: Owns navigation path, provides intent-based API
2. **MatchRootView**: Hosts coordinator, binds NavigationStack to coordinator path
3. **Child Views**: Emit intents via callbacks, parent delegates to coordinator

**Example Flow:**
```swift
// Child View (SavedMatchesListView)
Button { onSelectMatch(match) }

// Parent (MatchRootView)
SavedMatchesListView { match in
    flowCoordinator.resumeSavedMatch(match)  // Coordinator handles it
}

// Coordinator
func resumeSavedMatch(_ match: Match) {
    matchViewModel.selectMatch(match)
    proceedToKickoff()  // Triggers lifecycle + navigation
}
```

**Rationale**: Callbacks keep child views testable and reusable.
```

## Acceptance Criteria

- [ ] All child views still use callbacks (no coordinator dependencies)
- [ ] Doc comments updated in child views
- [ ] `CLAUDE.md` updated with navigation pattern
- [ ] Pattern documented for future contributors
- [ ] No code changes (verification only)

## Testing

### Verification

- [ ] `SavedMatchesListView` - callback-based ✅
- [ ] `MatchSettingsListView` - callback-based ✅
- [ ] `StartMatchOptionsView` - callback-based ✅
- [ ] No child views import `MatchFlowCoordinator` ✅

### Build Check
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

## Next Steps

After completion:
- Task 10 will implement deep link testing
- Task 11 will add coordinator unit tests

## Notes

- This task is mostly documentation and verification
- The callback approach is already in place from Phase A
- Future refactors should maintain this pattern
- If a child view needs complex navigation, consider extracting a sub-coordinator
