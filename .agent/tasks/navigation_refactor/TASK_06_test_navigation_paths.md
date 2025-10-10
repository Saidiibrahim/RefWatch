---
task_id: 06
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Comprehensive Navigation Testing (Manual + Unit Tests)
phase: Phase A - Checkpoint 3
created: 2025-10-10
updated: 2025-10-10
status: Completed
priority: High
estimated_minutes: 120 (expanded with unit tests)
manual_testing_minutes: 60
unit_testing_minutes: 60
dependencies: [TASK_05_update_child_components.md]
tags: [testing, qa, navigation, regression, unit-tests, checkpoint-3]
---

# Task 06: Comprehensive Navigation Testing (Checkpoint 3)

## Objective

Perform thorough testing of the refactored navigation architecture through both manual testing and automated unit tests. This task validates Checkpoint 3 completion and ensures the app is production-ready.

**New in Updated Plan:**
- ✅ Unit test coverage for navigation logic (>70% target)
- ✅ Widget integration testing (moved from Phase B Task 10)
- ✅ Lifecycle state transition matrix tests
- ✅ Automated regression prevention

## Context

After Tasks 01-05:
- ✅ Single NavigationStack with path-based navigation
- ✅ Lifecycle → navigation mapping implemented
- ✅ All components updated

**This Task:**
- Comprehensive manual testing
- Regression testing of all flows
- Performance validation
- Documentation of any issues found

## Part 1: Unit Testing (NEW - 60 minutes)

### Overview

Create automated tests for navigation logic to prevent regressions and enable confident refactoring in the future.

> Prereq: Ensure the watchOS test target is building with Xcode 15+ so XCTest-on-watchOS works with the new navigation helper and canonical path helpers.

### Test Files to Create

#### 1. NavigationPathTests.swift

**Location:** `RefZoneWatchOSTests/Navigation/NavigationPathTests.swift`

**Test Suite (XCTest):**

> ⚠️ **Do not re-implement the reducer in the test target.** Task 04 should expose the production `MatchNavigationReducer` (either as a dedicated type in `Core/Navigation` or by making `handleLifecycleNavigation` internal). These tests must call that shared code so we catch regressions.

```swift
import XCTest
@testable import RefZone_Watch_App
@testable import RefWatchCore

final class NavigationPathTests: XCTestCase {
    private var reducer: MatchNavigationReducer!

    override func setUp() {
        super.setUp()
        reducer = MatchNavigationReducer()
    }

    func testCanonicalPathsRemainStable() {
        XCTAssertEqual(MatchRoute.startFlow.canonicalPath, [.startFlow])
        XCTAssertEqual(MatchRoute.savedMatches.canonicalPath, [.startFlow, .savedMatches])
        XCTAssertEqual(MatchRoute.createMatch.canonicalPath, [.startFlow, .createMatch])
    }

    func testIdleToActiveClearsPath() {
        var path: [MatchRoute] = [.startFlow, .createMatch]
        reducer.reduce(path: &path, from: .idle, to: .kickoffFirstHalf)
        XCTAssertTrue(path.isEmpty)
    }

    func testActiveToIdleClearsPath() {
        var path: [MatchRoute] = [.startFlow, .savedMatches]
        reducer.reduce(path: &path, from: .setup, to: .idle)
        XCTAssertTrue(path.isEmpty)
    }

    func testIdleToIdlePreservesPath() {
        var path: [MatchRoute] = [.startFlow]
        reducer.reduce(path: &path, from: .idle, to: .idle)
        XCTAssertEqual(path, [.startFlow])
    }

    func testCanonicalHelperIsIdempotent() {
        var path: [MatchRoute] = []
        for _ in 0..<3 {
            path = MatchRoute.createMatch.canonicalPath
        }
        XCTAssertEqual(path, [.startFlow, .createMatch])
    }
}
```

#### 2. LifecycleTransitionMatrixTests.swift

**Location:** `RefZoneWatchOSTests/Navigation/LifecycleTransitionMatrixTests.swift`

**Purpose:** Protect against regressions when new lifecycle states are added.

```swift
final class LifecycleTransitionMatrixTests: XCTestCase {
    private let allStates: [MatchPhase] = [
        .idle,
        .kickoffFirstHalf,
        .setup,
        .kickoffSecondHalf,
        .kickoffExtraTimeFirstHalf,
        .kickoffExtraTimeSecondHalf,
        .choosePenaltyFirstKicker,
        .penalties,
        .finished
    ]

    func testReducerNeverExpandsBeyondStartFlow() {
        let reducer = MatchNavigationReducer()

        for oldState in allStates {
            for newState in allStates {
                var path: [MatchRoute] = [.startFlow, .savedMatches]
                reducer.reduce(path: &path, from: oldState, to: newState)
                XCTAssertLessThanOrEqual(path.count, MatchRoute.savedMatches.canonicalPath.count)
            }
        }
    }
}
```

### Unit Test Acceptance Criteria

- [ ] `NavigationPathTests.swift` created
- [ ] `LifecycleTransitionMatrixTests.swift` created
- [ ] Tests exercise the production `MatchNavigationReducer` (no duplicated reducer code in test target)
- [ ] All tests pass
- [ ] Test coverage >70% for navigation logic
- [ ] Tests run in < 5 seconds total
- [ ] No flaky tests

---

## Part 2: Manual Testing Checklists (60 minutes)

### 1. Basic Navigation Flow Testing

#### Start Flow - New Match
- [ ] Launch app (should be at idle state)
- [ ] Verify `navigationPath == []`
- [ ] Tap "Start" button
  - [ ] Navigates to StartMatchOptionsView
  - [ ] Single tap works (not double-tap)
  - [ ] Verify `navigationPath == [.startFlow]`
- [ ] Tap "Create Match"
  - [ ] Navigates to MatchSettingsListView
  - [ ] Single tap works
  - [ ] Verify `navigationPath == [.startFlow, .createMatch]`
- [ ] Configure settings (change duration, periods, etc.)
  - [ ] Settings update correctly
  - [ ] No navigation changes
- [ ] Tap "Start Match"
  - [ ] Proceeds to MatchKickOffView
  - [ ] Single tap works
  - [ ] Verify path clears to `[]`
- [ ] Select kicking team
- [ ] Tap confirm
  - [ ] Enters match (MatchSetupView)
  - [ ] Verify `navigationPath == []` (cleared on entering active match)

#### Start Flow - Saved Match
- [ ] Launch app (idle)
- [ ] Tap "Start"
- [ ] Tap "Select Match"
  - [ ] Navigates to SavedMatchesListView
  - [ ] Verify `navigationPath == [.startFlow, .savedMatches]`
- [ ] Tap a saved match
  - [ ] Proceeds to kickoff
  - [ ] Match data loaded correctly
- [ ] Select team and confirm
  - [ ] Enters match
  - [ ] Path cleared

### 2. Back Navigation Testing

#### Back Button
- [ ] From StartMatchOptionsView → back → idle home
- [ ] From MatchSettingsListView → back → StartMatchOptionsView
- [ ] From SavedMatchesListView → back → StartMatchOptionsView
- [ ] From kickoff screen → back → settings/saved matches
- [ ] Verify path updates correctly on each back action

#### SwiftUI Gesture
- [ ] Swipe from left edge works for back navigation
- [ ] Path updates correctly
- [ ] No crashes or stuck states

### 3. Lifecycle Transition Testing

#### First Half → Second Half
- [ ] Start a match
- [ ] Play first half to completion
- [ ] Half-time whistle
  - [ ] Verify lifecycle state changes
  - [ ] Verify navigation path stays empty (start flow cleared)
- [ ] Second half kickoff screen appears
- [ ] Select team and confirm
- [ ] Second half begins

#### Full Time
- [ ] Complete second half
- [ ] Full-time whistle
  - [ ] FullTimeView appears
  - [ ] Verify `navigationPath.isEmpty`
- [ ] Verify match data is saved
- [ ] Return to idle from full-time

#### Extra Time (If Enabled)
- [ ] Enable extra time in settings
- [ ] Complete regular time as a draw
- [ ] Extra time first half kickoff
  - [ ] Verify kickoff screen for ET1
  - [ ] Verify `navigationPath.isEmpty` during ET kickoff
- [ ] Play ET1, transition to ET2
  - [ ] Verify kickoff screen for ET2
  - [ ] Verify navigation path stays empty
- [ ] Complete extra time

#### Penalties (If Enabled)
- [ ] Enable penalties
- [ ] Complete extra time as draw (or regular time if no ET)
- [ ] Penalty shootout begins
  - [ ] Verify penalty UI shows
  - [ ] Lifecycle state correct
- [ ] Complete shootout
- [ ] Return to idle

### 4. Deep Link Testing

#### Widget - Active Match
- [ ] Start a match
- [ ] Switch to watch face with widget
- [ ] Tap widget "View Timer"
  - [ ] Returns to match in progress
  - [ ] Verify navigation path is empty (match surfaces handled by lifecycle)
  - [ ] Timer visible and running

#### Widget - Idle
- [ ] Kill app or reset to idle
- [ ] Tap widget
  - [ ] Should navigate to start flow
  - [ ] Verify `navigationPath == [.startFlow]`

### 5. Edge Cases & Error Conditions

#### Rapid Navigation
- [ ] Rapidly tap "Start" multiple times
  - [ ] Should navigate only once
  - [ ] No duplicate screens pushed
- [ ] Rapidly tap back button
  - [ ] Smooth navigation
  - [ ] No crashes

#### Lifecycle While Navigating
- [ ] Start navigating to settings
- [ ] During navigation, trigger lifecycle change
  - [ ] Verify graceful handling
  - [ ] No stuck navigation

#### App Backgrounding
- [ ] Navigate mid-flow
- [ ] Background app (home button / digital crown)
- [ ] Return to app
  - [ ] Navigation state preserved
  - [ ] Path intact
  - [ ] Can continue navigation

#### Memory Pressure
- [ ] Navigate through entire flow
- [ ] Simulate memory warning (if possible)
- [ ] Verify no navigation state loss

### 6. Regression Testing

#### History Navigation
- [ ] From idle, tap "History"
  - [ ] Navigates to MatchHistoryView
  - [ ] Works on single tap
- [ ] Select a completed match
  - [ ] Shows match details correctly

#### Settings Navigation
- [ ] From idle, tap "Settings"
  - [ ] Navigates to SettingsScreen
  - [ ] Single tap works
- [ ] Change settings
  - [ ] Settings persist correctly
- [ ] Back to idle
  - [ ] Works correctly

#### Mode Switcher
- [ ] Tap mode switcher chevron
  - [ ] Mode picker shows
  - [ ] Can switch modes
- [ ] Return to match mode
  - [ ] Navigation state correct

### 7. Performance Testing

#### Navigation Latency
- [ ] Time from button tap to screen appearing
  - [ ] Should be < 100ms
  - [ ] No perceptible lag
- [ ] Test on Series 9 (45mm)
- [ ] Test on Ultra (49mm)
- [ ] Test on older hardware if available

#### Memory Usage
- [ ] Navigate through full flow
- [ ] Check Xcode memory graph
  - [ ] No navigation-related memory leaks
  - [ ] Path array size reasonable
  - [ ] No retained cycles

#### Animation Smoothness
- [ ] All transitions smooth (60fps)
- [ ] No janky animations
- [ ] No visual glitches

### 8. Debug Inspection

#### Console Logging
- [ ] Enable debug mode
- [ ] Navigate through flow
- [ ] Verify debug logs show:
  ```
  DEBUG: MatchRootView lifecycle transition: .idle → .kickoffFirstHalf
  DEBUG: Navigation path before: [.startFlow, .createMatch]
  DEBUG: Navigation path after: []
  ```
- [ ] Logs are clear and helpful
- [ ] No excessive logging

#### Path State Inspection
- [ ] Add breakpoint in `handleLifecycleNavigation`
- [ ] Step through navigation transitions
- [ ] Verify path updates match expectations

## Acceptance Criteria

### Functionality
- [ ] All basic navigation flows work with single taps
- [ ] All back navigation works correctly
- [ ] All lifecycle transitions update navigation correctly
- [ ] Deep links work
- [ ] Edge cases handled gracefully

### Regression
- [ ] No regressions in History navigation
- [ ] No regressions in Settings navigation
- [ ] No regressions in mode switcher
- [ ] All previously working features still work

### Performance
- [ ] Navigation latency < 100ms
- [ ] No memory leaks
- [ ] Smooth animations
- [ ] Works on all supported devices

### Quality
- [ ] Debug logs are helpful
- [ ] No console warnings or errors
- [ ] Code passes review
- [ ] Documentation updated

## Testing Environment

### Devices/Simulators
- [ ] Apple Watch SE (40mm) - watchOS 11.2
- [ ] Apple Watch SE (44mm) - watchOS 11.2
- [ ] Apple Watch Ultra 2 (49mm) - watchOS 11.2
- [ ] Apple Watch Series 10 (42mm) - watchOS 11.2
- [ ] Physical device (if available)

### Build Configuration
```bash
# Debug build
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  -configuration Debug \
  build
```

## Bug Reporting Template

If issues are found, document using this template:

```markdown
### Bug: [Short Description]

**Severity:** Critical / High / Medium / Low

**Steps to Reproduce:**
1. Step one
2. Step two
3. ...

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Navigation Path State:**
navigationPath = [...]
lifecycle.state = ...

**Console Output:**
[Paste relevant logs]

**Screenshots/Video:**
[If applicable]

**Workaround:**
[If known]
```

## Success Criteria

### Phase A Complete When:
- [ ] All test checklists pass
- [ ] Zero critical or high severity bugs
- [ ] Medium/low bugs documented for future sprints
- [ ] Performance metrics met
- [ ] Team sign-off obtained

### Metrics
- **Navigation Success Rate:** 100% (all paths work)
- **Regression Rate:** 0% (no features broken)
- **Performance:** < 100ms tap-to-screen latency
- **Memory:** No leaks detected
- **Stability:** No crashes in 100+ navigation actions

## Next Steps

### If All Tests Pass:
- [ ] Mark Phase A as complete
- [ ] Update plan status
- [ ] Consider starting Phase B (Flow Coordinator)
- [ ] Celebrate! 🎉

### If Critical Bugs Found:
- [ ] File bugs with reproduction steps
- [ ] Prioritize fixes
- [ ] Re-run affected tests
- [ ] Do not proceed to Phase B until resolved

### If Medium Bugs Found:
- [ ] Document bugs
- [ ] Assess impact
- [ ] Create backlog tickets
- [ ] Proceed to Phase B if bugs are non-blocking

## Notes

- Testing is the most important task in Phase A
- Take time to be thorough - catching bugs now saves time later
- Involve team members for additional coverage
- Consider recording test sessions for documentation
- Update this checklist if new test cases are discovered
