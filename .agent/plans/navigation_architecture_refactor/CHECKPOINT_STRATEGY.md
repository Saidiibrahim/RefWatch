---
plan_id: navigation_architecture_refactor
document_type: checkpoint_strategy
created: 2025-10-10
status: Active
priority: High
tags: [navigation, checkpoints, incremental-migration, risk-management]
---

# Checkpoint Strategy - Navigation Refactor

## Overview

This document defines the 3-checkpoint incremental migration strategy for the navigation architecture refactor (Phase A). Each checkpoint represents a **shippable, production-ready state**, reducing risk and providing flexibility during execution.

## Strategy Principles

1. **Incremental Value**: Each checkpoint delivers tangible improvements
2. **Shippable States**: Can ship after any checkpoint if needed
3. **Rollback Safety**: Git tags enable quick rollback to previous checkpoints
4. **Testing Per Checkpoint**: Validate before proceeding to next checkpoint
5. **Never Broken**: App remains functional throughout refactor

---

## Checkpoint 1: Remove Nested NavigationStack

### Timeline
**Estimated Effort:** 2-3 hours

### Goal
Fix the immediate anti-pattern: nested `NavigationStack` in `StartMatchScreen.swift`.

### Status After Completion
✅ **SHIPPABLE** - App works, architecture improved

### Changes

#### Files Modified
1. `RefZoneWatchOS/Features/Match/Views/StartMatchScreen.swift`
   - Remove `NavigationStack(path: $path)` wrapper (line 29)
   - Remove `@State private var path: [Route] = []` (line 21)
   - Remove `private enum Route: Hashable` (lines 23-26)
   - Add `let onNavigate: (DestinationType) -> Void` callback parameter
   - Update button actions to use callbacks instead of path manipulation

2. `RefZoneWatchOS/App/MatchRootView.swift`
   - Keep existing `@State private var isStartMatchActive = false`
   - Add callback handlers for StartMatchScreen navigation
   - **Do NOT** add `MatchRoute` enum yet (that's Checkpoint 2)

#### Example: StartMatchScreen Changes

**Before:**
```swift
struct StartMatchScreen: View {
    @State private var path: [Route] = []

    private enum Route: Hashable {
        case savedMatches
        case createMatch
    }

    var body: some View {
        NavigationStack(path: $path) {
            StartMatchOptionsView(
                onSelectMatch: { path.append(.savedMatches) },
                onCreateMatch: { path.append(.createMatch) }
            )
            .navigationDestination(for: Route.self) { route in
                // ...
            }
        }
    }
}
```

**After:**
```swift
struct StartMatchScreen: View {
    let onNavigateToSavedMatches: () -> Void
    let onNavigateToCreateMatch: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StartMatchOptionsView(
            onSelectMatch: onNavigateToSavedMatches,
            onCreateMatch: onNavigateToCreateMatch
        )
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Start Match")
        // No NavigationStack wrapper!
    }
}
```

### Acceptance Criteria

- [ ] `StartMatchScreen` has zero `NavigationStack` instances
- [ ] Navigation works via callbacks to parent
- [ ] "Start" button → StartMatchOptionsView → CreateMatch/SavedMatches flows work
- [ ] All navigation is single-click
- [ ] No compiler errors
- [ ] Manual test: Complete start flow end-to-end

### Testing Checklist

#### Functional Tests
- [ ] Tap "Start" → shows StartMatchOptionsView
- [ ] Tap "Create Match" → shows MatchSettingsListView
- [ ] Tap "Select Match" → shows SavedMatchesListView
- [ ] Configure match → proceeds to kickoff
- [ ] Select saved match → proceeds to kickoff
- [ ] Back navigation works correctly

#### Regression Tests
- [ ] History navigation still works
- [ ] Settings navigation still works
- [ ] Lifecycle transitions work
- [ ] Widget deep links still function

### Git Operations

```bash
# Before starting
git checkout -b feature/nav-refactor-checkpoint-1
git tag -a pre-checkpoint-1 -m "Before Checkpoint 1: Remove nested stack"

# After completion and testing
git add .
git commit -m "Checkpoint 1: Remove nested NavigationStack from StartMatchScreen

- Removed NavigationStack wrapper from StartMatchScreen
- Converted to callback-based navigation
- Parent (MatchRootView) handles routing via boolean flags
- All navigation paths tested and working
- Zero nested NavigationStacks in codebase

✅ Checkpoint 1 complete - app is shippable"

git tag -a checkpoint-1-complete -m "Checkpoint 1 complete: Nested stack removed"
```

### Rollback Procedure

If blocked:
```bash
git reset --hard pre-checkpoint-1
xcodebuild -scheme "RefZone Watch App" build
# Verify app works with nested stack (old way)
```

### Ship Decision

**Can ship after Checkpoint 1?** ✅ YES

**When to ship:**
- If Checkpoint 2 is delayed or blocked
- If sprint ends before Checkpoint 2 completion
- If higher-priority work interrupts refactor

**What you get:**
- No more nested NavigationStack anti-pattern
- Cleaner architecture
- Improved navigation reliability
- Foundation for path-based navigation (Checkpoint 2)

---

## Checkpoint 2: Path-Based Navigation

### Timeline
**Estimated Effort:** 3-4 hours

### Goal
Modernize navigation with path-based approach using `MatchRoute` enum.

### Status After Completion
✅ **SHIPPABLE** - Modern SwiftUI navigation architecture

### Changes

#### Files Created
1. `RefZoneWatchOS/Core/Navigation/MatchRoute.swift` (Task 01)
   - Define `MatchRoute` enum with all navigation destinations
   - Define `KickoffPhase` enum
   - Both conform to `Hashable`

#### Files Modified
2. `RefZoneWatchOS/App/MatchRootView.swift`
   - Add `@State private var navigationPath: [MatchRoute] = []`
   - Replace `NavigationStack` with `NavigationStack(path: $navigationPath)`
   - Add `.navigationDestination(for: MatchRoute.self) { route in destination(for: route) }`
   - Implement `destination(for:) -> some View` method
   - Add lifecycle → navigation mapping (Task 04)
   - Remove `isStartMatchActive` boolean flag
   - Update heroSection button to use `navigationPath.append(.startFlow)`

3. Update child component call sites to use new routing

#### Example: MatchRootView Changes

**Before (Checkpoint 1):**
```swift
@State private var isStartMatchActive = false

var body: some View {
    NavigationStack {
        // Root view
    }
    .navigationDestination(isPresented: $isStartMatchActive) {
        StartMatchScreen(
            onNavigateToSavedMatches: { /* boolean flag magic */ },
            onNavigateToCreateMatch: { /* boolean flag magic */ }
        )
    }
}
```

**After (Checkpoint 2):**
```swift
@State private var navigationPath: [MatchRoute] = []

var body: some View {
    NavigationStack(path: $navigationPath) {
        // Root view
    }
    .navigationDestination(for: MatchRoute.self) { route in
        destination(for: route)
    }
    .onChange(of: lifecycle.state) { old, new in
        handleLifecycleNavigation(from: old, to: new)
    }
}

@ViewBuilder
func destination(for route: MatchRoute) -> some View {
    switch route {
    case .startFlow:
        StartMatchScreen(...)
    case .savedMatches:
        SavedMatchesListView(...)
    case .createMatch:
        MatchSettingsListView(...)
    // ...
    }
}
```

### Tasks Completed in Checkpoint 2
- ✅ Task 01: Create MatchRoute enum (30 min)
- ✅ Task 02: Add navigationPath state (20 min)
- ✅ Task 03: Flatten navigation (remaining work from Checkpoint 1)
- ✅ Task 04: Lifecycle → navigation mapping (60 min)

### Acceptance Criteria

- [ ] `MatchRoute` enum defined and comprehensive
- [ ] `navigationPath` drives all navigation
- [ ] Boolean flags (`isStartMatchActive`) removed
- [ ] Lifecycle transitions update path correctly
- [ ] All navigation paths work with single clicks
- [ ] Deep link foundation in place
- [ ] No compiler errors
- [ ] Manual testing passes

### Testing Checklist

#### Navigation Path Tests
- [ ] Empty path `[]` = idle state
- [ ] `[.startFlow]` = StartMatchOptionsView
- [ ] `[.startFlow, .createMatch]` = MatchSettingsListView
- [ ] `[.startFlow, .savedMatches]` = SavedMatchesListView
- [ ] Lifecycle → path mapping works for all transitions

#### Functional Tests
- [ ] All Checkpoint 1 tests still pass
- [ ] Lifecycle transitions update path
- [ ] Back button updates path correctly
- [ ] Deep link sets path correctly

### Git Operations

```bash
# After completion and testing
git add .
git commit -m "Checkpoint 2: Implement path-based navigation

- Created MatchRoute and KickoffPhase enums
- Added navigationPath to MatchRootView
- Migrated from boolean flags to path-based routing
- Implemented lifecycle → navigation mapping
- Removed deprecated NavigationLink(isPresented:)

✅ Checkpoint 2 complete - modern navigation architecture"

git tag -a checkpoint-2-complete -m "Checkpoint 2 complete: Path-based navigation"
```

### Rollback Procedure

If blocked:
```bash
git reset --hard checkpoint-1-complete
xcodebuild -scheme "RefZone Watch App" build
# App works with callback-based navigation (Checkpoint 1)
```

### Ship Decision

**Can ship after Checkpoint 2?** ✅ YES

**When to ship:**
- If Checkpoint 3 (testing) is delayed
- If comprehensive testing can be done post-release
- If team needs to prioritize other work

**What you get:**
- Modern SwiftUI navigation architecture
- Deep link foundation
- Lifecycle cleanly separated from navigation
- Ready for widgets, Siri shortcuts, etc.

---

## Checkpoint 3: Testing & Production Polish

### Timeline
**Estimated Effort:** 2-3 hours

### Goal
Comprehensive testing, unit test coverage, and production readiness.

### Status After Completion
🚀 **PRODUCTION READY** - Fully tested, documented, ready to ship

### Changes

#### Files Created
1. `RefZoneWatchOSTests/Navigation/NavigationPathTests.swift` (NEW)
   - Unit tests for navigation path state
   - Lifecycle transition matrix tests
   - Idempotency tests
   - Path growth bounds tests

2. `RefZoneWatchOSTests/Navigation/WidgetDeepLinkTests.swift` (NEW)
   - Widget tap integration tests
   - Deep link URL scheme tests
   - Smart Stack vs Complication tests

#### Files Modified
3. Update documentation in modified files
4. Add inline comments for complex navigation logic

### Tasks Completed in Checkpoint 3
- ✅ Task 05: Update child components (45 min)
- ✅ Task 06: Comprehensive testing (90 min, expanded)
- ✅ Task 06b: Widget integration testing (45 min, NEW)
- ✅ Unit test creation (60 min, NEW)

### Acceptance Criteria

- [ ] All manual tests pass (Task 06 checklist)
- [ ] Unit tests added and passing (>70% coverage for navigation logic)
- [ ] Widget tap tests pass
- [ ] Deep link tests pass
- [ ] No navigation regressions
- [ ] Documentation complete
- [ ] Code review passed
- [ ] No compiler warnings

### Testing Checklist

#### Manual Testing
- [ ] Complete Task 06 full checklist (all scenarios)
- [ ] Test on multiple simulators (SE, Series 9, Ultra)
- [ ] Test lifecycle transitions end-to-end
- [ ] Test deep links from widgets

#### Unit Testing (NEW)
- [ ] `test_navigationPath_startsEmpty()`
- [ ] `test_lifecycleTransition_idleToKickoff_appendsKickoffToPath()`
- [ ] `test_lifecycleTransition_anyToIdle_clearsPath()`
- [ ] `test_multipleShowStartFlow_isIdempotent()`
- [ ] `test_pathDoesNotGrowInfinitely()`
- [ ] `test_allLifecycleTransitions_updatePathCorrectly()` (9×9 matrix)

#### Widget Testing (Moved from Phase B)
- [ ] Widget tap while idle → navigates to start flow
- [ ] Widget tap during match → navigates to match timer
- [ ] URL scheme `refzone://timer` works
- [ ] URL scheme `refzone://start` works
- [ ] Invalid URLs handled gracefully

### Git Operations

```bash
# After completion and testing
git add .
git commit -m "Checkpoint 3: Testing and production polish

- Added comprehensive unit tests for navigation logic
- Added widget deep link integration tests
- Completed manual testing on all simulators
- Updated documentation
- Verified no regressions

🚀 Phase A complete - production ready
✅ All checkpoints passed
✅ Test coverage >70%
✅ Zero navigation bugs detected"

git tag -a checkpoint-3-complete -m "Checkpoint 3 complete: Production ready"
git tag -a phase-a-complete -m "Phase A complete: Navigation refactor done"
```

### Rollback Procedure

If critical bugs found:
```bash
git reset --hard checkpoint-2-complete
# App has path-based navigation, just missing comprehensive tests
# Can ship and test in production if low-risk
```

### Ship Decision

**Must ship after Checkpoint 3?** 🚀 YES (Production Ready)

**What you get:**
- Fully tested navigation system
- Unit test coverage for regression prevention
- Widget deep links validated
- Production-ready architecture
- Complete documentation

---

## Execution Timeline

### Day 1 (4-5 hours)
- **Morning** (2-3 hours): Execute Checkpoint 1
  - Remove nested NavigationStack
  - Test thoroughly
  - Git tag
  - ✅ SHIP if needed

- **Afternoon** (2-3 hours): Start Checkpoint 2
  - Create MatchRoute enum
  - Begin path-based migration

### Day 2 (4-5 hours)
- **Morning** (1-2 hours): Complete Checkpoint 2
  - Finish lifecycle → navigation mapping
  - Test thoroughly
  - Git tag
  - ✅ SHIP if needed

- **Afternoon** (2-3 hours): Execute Checkpoint 3
  - Write unit tests
  - Widget integration testing
  - Final manual testing
  - Documentation
  - 🚀 PRODUCTION SHIP

---

## Success Criteria

### Per-Checkpoint Success

**Checkpoint 1:**
- ✅ Zero nested NavigationStacks
- ✅ All navigation works
- ✅ Can ship

**Checkpoint 2:**
- ✅ Path-based navigation implemented
- ✅ Lifecycle separated from navigation
- ✅ Can ship

**Checkpoint 3:**
- ✅ >70% test coverage
- ✅ Widget tests pass
- ✅ Production ready

### Overall Phase A Success

- ✅ All 3 checkpoints complete
- ✅ All acceptance criteria met
- ✅ No regressions detected
- ✅ Team sign-off
- ✅ Ready to deploy to production

---

## Monitoring & Metrics

### During Execution

Track time spent per checkpoint:
- Checkpoint 1: _____ hours (target: 2-3)
- Checkpoint 2: _____ hours (target: 3-4)
- Checkpoint 3: _____ hours (target: 2-3)
- **Total**: _____ hours (target: 8-10)

### Post-Execution

Track bugs found in production:
- Navigation-related bugs in Sprint 2: _____
- Navigation-related bugs in Sprint 3: _____
- Rollback required?: Yes/No
- Time to fix post-release bugs: _____ hours

**Success**: Zero critical navigation bugs in first 2 weeks post-deploy.

---

## Decision Tree

```
Start Phase A
    ↓
Tag: pre-checkpoint-1
    ↓
Execute Checkpoint 1 (2-3 hours)
    ↓
Test passes? ──No──> Rollback to pre-checkpoint-1
    ↓ Yes
Tag: checkpoint-1-complete
    ↓
Need to ship? ──Yes──> SHIP (nested stack removed)
    ↓ No
Execute Checkpoint 2 (3-4 hours)
    ↓
Test passes? ──No──> Rollback to checkpoint-1
    ↓ Yes
Tag: checkpoint-2-complete
    ↓
Need to ship? ──Yes──> SHIP (path-based navigation)
    ↓ No
Execute Checkpoint 3 (2-3 hours)
    ↓
Test passes? ──No──> Rollback to checkpoint-2
    ↓ Yes
Tag: checkpoint-3-complete, phase-a-complete
    ↓
🚀 PRODUCTION SHIP
```

---

## Notes

- Each checkpoint is independently valuable
- Rollback is quick and safe with git tags
- Can pause between checkpoints if needed
- Testing at each checkpoint prevents compound issues
- Documentation updated as you go
