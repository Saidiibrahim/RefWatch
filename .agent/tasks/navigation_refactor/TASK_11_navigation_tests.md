---
task_id: 11
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Add Unit Tests for MatchFlowCoordinator
phase: Phase B
created: 2025-10-10
status: ⏸️ DEFERRED
priority: Low (deferred until watchOS navigation complexity increases)
estimated_minutes: 90
dependencies: [TASK_10_deep_link_handling.md]
tags: [testing, unit-tests, coordinator, phase-b]
---

# Task 11: Unit Tests for MatchFlowCoordinator

## Objective

Create comprehensive unit tests for `MatchFlowCoordinator` to ensure navigation logic is correct, testable, and maintainable. This validates that the coordinator architecture is working as designed.

## Context

**After Task 10:**
- ✅ Coordinator implemented and integrated
- ✅ Deep links tested manually

**This Task:**
- Write unit tests for coordinator
- Test intent-based API
- Test lifecycle integration
- Test deep link handling

## Prerequisites

- [ ] Swift Testing framework available (Xcode 16+)
- [ ] Test target configured for watchOS
- [ ] Coordinator successfully integrated

## Implementation

### 1. Create Test File

**Location:** `RefZoneWatchOSTests/Navigation/MatchFlowCoordinatorTests.swift`

### 2. Test Structure

> Prereq: Coordinator tests require the Swift 5.9 toolchain (Xcode 15+) so the Observation-based coordinator compiles on watchOS. Confirm CI has the same baseline before landing these tests.

    @Test("non-idle transitions while match active do not grow path")
    @MainActor
    func test_activeTransitions_doNotGrowPath() {
        // Given
        let (coordinator, _, _) = makeCoordinator()
        coordinator.navigationPath = []

        // When
        coordinator.handleLifecycleTransition(from: .setup, to: .kickoffSecondHalf)

        // Then
        #expect(coordinator.navigationPath.isEmpty)
    }

    // MARK: - Deep Link Tests

    @Test("handleDeepLink timer when idle navigates to start flow")
    @MainActor
    func test_handleDeepLink_timerWhenIdle_navigatesToStartFlow() {
        // Given
        let (coordinator, _, _) = makeCoordinator()
        let url = URL(string: "refzone://timer")!

        // When
        coordinator.handleDeepLink(url)

        // Then
        #expect(coordinator.navigationPath == [.startFlow])
    }

    @Test("handleDeepLink start navigates to create match")
    @MainActor
    func test_handleDeepLink_start_navigatesToCreateMatch() {
        // Given
        let (coordinator, _, _) = makeCoordinator()
        let url = URL(string: "refzone://start")!

        // When
        coordinator.handleDeepLink(url)

        // Then
        #expect(coordinator.navigationPath == [.startFlow, .createMatch])
    }

    @Test("handleDeepLink history navigates to saved matches")
    @MainActor
    func test_handleDeepLink_history_navigatesToSavedMatches() {
        // Given
        let (coordinator, _, _) = makeCoordinator()
        let url = URL(string: "refzone://history")!

        // When
        coordinator.handleDeepLink(url)

        // Then
        #expect(coordinator.navigationPath == [.startFlow, .savedMatches])
    }

    @Test("handleDeepLink invalid host does nothing")
    @MainActor
    func test_handleDeepLink_invalidHost_doesNothing() {
        // Given
        let (coordinator, _, _) = makeCoordinator()
        let url = URL(string: "refzone://invalid")!

        // When
        coordinator.handleDeepLink(url)

        // Then
        #expect(coordinator.navigationPath.isEmpty)
    }

    @Test("handleDeepLink non-refzone scheme ignores URL")
    @MainActor
    func test_handleDeepLink_nonRefzoneScheme_ignoresURL() {
        // Given
        let (coordinator, _, _) = makeCoordinator()
        let url = URL(string: "https://example.com")!

        // When
        coordinator.handleDeepLink(url)

        // Then
        #expect(coordinator.navigationPath.isEmpty)
    }

    // MARK: - Match Resume Tests

    @Test("resumeSavedMatch selects match and proceeds to kickoff")
    @MainActor
    func test_resumeSavedMatch_selectsMatchAndProceedsToKickoff() async {
        // Given
        let (coordinator, lifecycle, viewModel) = makeCoordinator()
        let match = Match(homeTeam: "Team A", awayTeam: "Team B")

        // When
        coordinator.resumeSavedMatch(match)

        // Wait for async lifecycle transition
        try? await Task.sleep(for: .milliseconds(100))

        // Then
        #expect(viewModel.currentMatch?.homeTeam == "Team A")
        #expect(lifecycle.state == .kickoffFirstHalf)
    }

    // MARK: - Edge Cases

    @Test("multiple calls to showStartFlow are idempotent")
    @MainActor
    func test_multipleCallsToShowStartFlow_areIdempotent() {
        // Given
        let (coordinator, _, _) = makeCoordinator()

        // When
        coordinator.showStartFlow()
        coordinator.showStartFlow()
        coordinator.showStartFlow()

        // Then
        #expect(coordinator.navigationPath == [.startFlow])
    }

    @Test("navigation path does not grow infinitely")
    @MainActor
    func test_navigationPath_doesNotGrowInfinitely() {
        // Given
        let (coordinator, _, _) = makeCoordinator()

        // When
        for _ in 0..<100 {
            coordinator.showStartFlow()
        }

        // Then
        // Path should be reset each time, not append
        #expect(coordinator.navigationPath.count <= 2)
    }
}

// MARK: - Mock Haptics

struct MockHaptics: HapticsProviding {
    func playSuccess() {}
    func playWarning() {}
    func playError() {}
    func playSelection() {}
}
```

## Acceptance Criteria

### Test Coverage
- [ ] All intent methods tested (showStartFlow, startNewMatch, etc.)
- [ ] All lifecycle transitions tested
- [ ] All deep link scenarios tested
- [ ] Edge cases covered (invalid URLs, multiple calls, etc.)

### Test Quality
- [ ] Tests are isolated (no shared state)
- [ ] Tests use clear Given/When/Then structure
- [ ] Test names describe behavior
- [ ] Mock dependencies where appropriate
- [ ] XCTest is used (no reliance on the experimental `Testing` package)

### Build & Run
- [ ] All tests pass
- [ ] Tests run in < 5 seconds
- [ ] No flaky tests
- [ ] Tests work on CI (if configured)

## Testing

### Run Tests
```bash
xcodebuild test \
  -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)'
```

### Code Coverage
```bash
xcodebuild test \
  -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  -enableCodeCoverage YES
```

Target: >80% coverage for `MatchFlowCoordinator`

## Test Scenarios

### Intent API
- [ ] `showStartFlow()` sets path to `[.startFlow]`
- [ ] `startNewMatch()` sets path to `[.startFlow, .createMatch]`
- [ ] `showSavedMatches()` sets path to `[.startFlow, .savedMatches]`
- [ ] `reset()` clears path and resets lifecycle

### Lifecycle Integration
- [ ] `.idle` → `.kickoffFirstHalf` clears stacked start flow entries
- [ ] Any → `.idle` clears path
- [ ] Active-state transitions keep path empty (second half, ET, penalties)

### Deep Links
- [ ] `refzone://timer` (idle) → start flow canonical path
- [ ] `refzone://timer` (match active) → lifecycle updates, path cleared
- [ ] `refzone://start` → create match canonical path
- [ ] `refzone://history` → saved matches canonical path
- [ ] Invalid host → no navigation
- [ ] Non-refzone scheme → ignored

### Edge Cases
- [ ] Multiple calls are idempotent
- [ ] Path doesn't grow infinitely
- [ ] Empty host handled gracefully
- [ ] Nil URL components handled

## Next Steps

After completion:
- Phase B complete
- Consider CI/CD integration
- Evaluate coordinator pattern benefits for watchOS

## Notes

- Use Swift Testing framework (modern, better DX)
- Tests should be fast (< 100ms each)
- Mock external dependencies (haptics, networking)
- Test coordinator in isolation (unit tests, not integration)
- Consider property-based testing for state transitions
```swift
import XCTest
@testable import RefZone_Watch_App
@testable import RefWatchCore

@MainActor
final class MatchFlowCoordinatorTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeCoordinator() -> (
        coordinator: MatchFlowCoordinator,
        lifecycle: MatchLifecycleCoordinator,
        viewModel: MatchViewModel
    ) {
        let lifecycle = MatchLifecycleCoordinator()
        let viewModel = MatchViewModel(haptics: MockHaptics())
        let coordinator = MatchFlowCoordinator(
            lifecycle: lifecycle,
            matchViewModel: viewModel
        )
        return (coordinator, lifecycle, viewModel)
    }

    // MARK: - Intent-Based Navigation Tests

    func testShowStartFlowSetsCanonicalPath() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.showStartFlow()
        XCTAssertEqual(coordinator.navigationPath, MatchRoute.startFlow.canonicalPath)
    }

    func testStartNewMatchPushesCreateMatch() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.startNewMatch()
        XCTAssertEqual(coordinator.navigationPath, MatchRoute.createMatch.canonicalPath)
    }

    func testShowSavedMatchesPushesSavedMatches() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.showSavedMatches()
        XCTAssertEqual(coordinator.navigationPath, MatchRoute.savedMatches.canonicalPath)
    }

    func testResetClearsPathAndLifecycle() {
        let (coordinator, lifecycle, _) = makeCoordinator()
        coordinator.navigationPath = MatchRoute.createMatch.canonicalPath
        lifecycle.goToKickoffFirst()

        coordinator.reset()

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
        XCTAssertEqual(lifecycle.state, .idle)
    }

    // MARK: - Lifecycle Integration

    func testIdleToKickoffClearsStack() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.navigationPath = MatchRoute.createMatch.canonicalPath

        coordinator.handleLifecycleTransition(from: .idle, to: .kickoffFirstHalf)

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }

    func testAnyStateReturningToIdleClearsStack() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.navigationPath = MatchRoute.savedMatches.canonicalPath

        coordinator.handleLifecycleTransition(from: .penalties, to: .idle)

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }

    func testActiveStateTransitionsDoNotGrowPath() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.navigationPath.removeAll()

        coordinator.handleLifecycleTransition(from: .setup, to: .kickoffSecondHalf)

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }

    // MARK: - Deep Link Handling

    func testTimerDeepLinkDuringActiveMatchClearsPath() {
        let (coordinator, lifecycle, viewModel) = makeCoordinator()
        coordinator.navigationPath = MatchRoute.createMatch.canonicalPath
        viewModel.startMatch()
        lifecycle.goToSetup()

        coordinator.handleDeepLink(URL(string: "refzone://timer")!)

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }

    func testTimerDeepLinkWhileIdleShowsStartFlow() {
        let (coordinator, _, _) = makeCoordinator()

        coordinator.handleDeepLink(URL(string: "refzone://timer")!)

        XCTAssertEqual(coordinator.navigationPath, MatchRoute.startFlow.canonicalPath)
    }

    func testUnknownDeepLinkIsIgnored() {
        let (coordinator, _, _) = makeCoordinator()

        coordinator.handleDeepLink(URL(string: "refzone://unknown")!)

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }
}

// MARK: - Test Doubles

private struct MockHaptics: HapticsProviding {
    func playSuccess() {}
    func playWarning() {}
    func playError() {}
    func playSelection() {}
}
```
