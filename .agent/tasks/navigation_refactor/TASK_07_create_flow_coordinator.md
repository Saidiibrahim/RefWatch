---
task_id: 07
plan_id: navigation_architecture_refactor
plan_file: ../../plans/navigation_architecture_refactor/PLAN_navigation_architecture_refactor.md
title: Create MatchFlowCoordinator Class
phase: Phase B
created: 2025-10-10
updated: 2025-10-10
status: ⏸️ DEFERRED
priority: Low (deferred until watchOS navigation complexity increases)
estimated_minutes: 90
dependencies: [TASK_06_test_navigation_paths.md]
tags: [coordinator, architecture, navigation, phase-b, deferred]
revisit_criteria: [complex-flows-3+, deep-link-complexity, navigation-state-testing]
---

# ⏸️ DEFERRED - Task 07: Create MatchFlowCoordinator Class

## Deferral Notice

**Status:** This task is deferred until Phase B trigger criteria are met.

**Reason:** Phase B coordinator pattern is well-designed but premature for current simple watchOS navigation (6 routes, shallow flows).

**Revisit When:**
- 3+ complex multi-step navigation flows needed
- Deep link routing becomes complex and error-prone
- Navigation state testing becomes critical
- Navigation logic scattered across multiple views

See main plan document "When to Revisit Phase B" section for full criteria.

---

# Original Task Documentation (Preserved)

# Task 07: Create MatchFlowCoordinator

## Objective

Create a new `MatchFlowCoordinator` class that encapsulates navigation path management and provides an intent-based API for navigation. This coordinator will centralize navigation logic that's currently spread between `MatchRootView` and lifecycle handlers.

## Context

**Phase A** (Tasks 01-06) achieved:
- ✅ Single NavigationStack with path-based navigation
- ✅ Lifecycle → navigation mapping
- ✅ Separated domain state from presentation

**Phase B Goals:**
- Centralize navigation logic in a coordinator
- Provide intent-based API (`startNewMatch()` vs manual path manipulation)
- Enable comprehensive deep link handling
- Improve navigation testability

## Prerequisites

- [ ] Phase A tasks (01-06) complete and tested
- [ ] No outstanding navigation bugs
- [ ] Team approval to proceed with Phase B

## Implementation

### 1. Create New File

**Location:** `RefZoneWatchOS/Core/Navigation/MatchFlowCoordinator.swift`

### 2. Define MatchFlowCoordinator Class

```swift
import Foundation
import SwiftUI
import Observation
import RefWatchCore

/// Coordinates navigation flows for the match mode.
///
/// This coordinator provides an intent-based API for navigation, hiding the
/// complexity of path manipulation and lifecycle coordination. It serves as
/// the single source of truth for navigation state in the match mode.
///
/// Example usage:
/// ```swift
/// // Start a new match flow
/// coordinator.startNewMatch()
///
/// // Resume a saved match
/// coordinator.resumeSavedMatch(savedMatch)
///
/// // Handle a widget deep link
/// coordinator.handleDeepLink(url)
/// ```
@Observable
final class MatchFlowCoordinator {
    // MARK: - Public State

    /// The current navigation path. Observed by NavigationStack.
    var navigationPath: [MatchRoute] = []

    // MARK: - Private Dependencies

    private let lifecycle: MatchLifecycleCoordinator
    private let matchViewModel: MatchViewModel

    // MARK: - Initialization

    /// Creates a new flow coordinator.
    ///
    /// - Parameters:
    ///   - lifecycle: The lifecycle coordinator managing match state
    ///   - matchViewModel: The view model managing match data
    init(lifecycle: MatchLifecycleCoordinator, matchViewModel: MatchViewModel) {
        self.lifecycle = lifecycle
        self.matchViewModel = matchViewModel
    }

    // MARK: - Intent-Based Navigation API

    /// Navigates to the start flow (new or saved match selection).
    func showStartFlow() {
        navigationPath = MatchRoute.startFlow.canonicalPath
    }

    /// Starts a new match flow, navigating directly to match settings.
    func startNewMatch() {
        navigationPath = MatchRoute.createMatch.canonicalPath
    }

    /// Shows the saved matches list.
    func showSavedMatches() {
        navigationPath = MatchRoute.savedMatches.canonicalPath
    }

    /// Resumes a saved match.
    ///
    /// - Parameter match: The saved match to resume
    func resumeSavedMatch(_ match: Match) {
        matchViewModel.selectMatch(match)
        proceedToKickoff()
    }

    /// Proceeds to the kickoff screen after match configuration.
    func proceedToKickoff() {
        // Trigger lifecycle transition
        DispatchQueue.main.async { [weak self] in
            self?.lifecycle.goToKickoffFirst()
        }
        // Path will be updated by handleLifecycleTransition
    }

    /// Resets navigation to the root (idle state).
    func reset() {
        navigationPath.removeAll()
        lifecycle.resetToStart()
    }

    // MARK: - Deep Link Handling

    /// Handles a deep link URL from widgets, Siri, or other external sources.
    ///
    /// Supported URL schemes:
    /// - `refzone://timer` - Navigate to active match or start flow
    /// - `refzone://start` - Start new match
    /// - `refzone://history` - Show saved matches
    ///
    /// - Parameter url: The deep link URL to handle
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "refzone" else {
            #if DEBUG
            print("DEBUG: MatchFlowCoordinator ignoring non-refzone URL: \(url)")
            #endif
            return
        }

        #if DEBUG
        print("DEBUG: MatchFlowCoordinator handling deep link: \(url)")
        #endif

        switch url.host {
        case "timer":
            handleTimerDeepLink()

        case "start":
            startNewMatch()

        case "history":
            showSavedMatches()

        default:
            #if DEBUG
            print("DEBUG: MatchFlowCoordinator unknown deep link host: \(url.host ?? "nil")")
            #endif
        }
    }

    private func handleTimerDeepLink() {
        if matchViewModel.isMatchInProgress || matchViewModel.isHalfTime || matchViewModel.penaltyShootoutActive {
            lifecycle.goToSetup()
            navigationPath.removeAll(keepingCapacity: false)
        } else if matchViewModel.waitingForSecondHalfStart {
            lifecycle.goToKickoffSecond()
            navigationPath.removeAll(keepingCapacity: false)
        } else if matchViewModel.waitingForET1Start {
            lifecycle.goToKickoffETFirst()
            navigationPath.removeAll(keepingCapacity: false)
        } else if matchViewModel.waitingForET2Start {
            lifecycle.goToKickoffETSecond()
            navigationPath.removeAll(keepingCapacity: false)
        } else {
            showStartFlow()
        }
    }

    // MARK: - Lifecycle Integration

    /// Maps lifecycle transitions to navigation path updates.
    ///
    /// Called by MatchRootView's onChange(of: lifecycle.state) handler.
    ///
    /// - Parameters:
    ///   - oldState: The previous lifecycle state
    ///   - newState: The new lifecycle state
    func handleLifecycleTransition(from oldState: MatchPhase, to newState: MatchPhase) {
        if newState == .idle {
            navigationPath.removeAll(keepingCapacity: false)
            return
        }

        if oldState == .idle && newState != .idle {
            navigationPath.removeAll(keepingCapacity: false)
        }
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
```

## Acceptance Criteria

- [ ] New file created at `RefZoneWatchOS/Core/Navigation/MatchFlowCoordinator.swift`
- [ ] Class conforms to `@Observable`
- [ ] `navigationPath: [MatchRoute]` property
- [ ] Intent-based API methods implemented
- [ ] Deep link handling implemented (match in progress clears path, idle shows start flow)
- [ ] Lifecycle integration method implemented (clears path when leaving/returning to idle)
- [ ] Comprehensive doc comments
- [ ] File builds without errors
- [ ] Class not yet used (foundation only)

## Testing

### Build Verification
```bash
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefZone Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch SE (44mm) (2nd generation)' \
  build
```

### Code Review
- [ ] Verify all navigation intents are covered
- [ ] Check deep link URL handling is comprehensive
- [ ] Confirm weak self in closures to avoid retain cycles
- [ ] Review debug logging

## Next Steps

After completion:
- Task 08 will integrate coordinator into `MatchRootView`
- Task 09 will update child views to call coordinator methods
- Task 10 will implement deep link end-to-end testing

## Notes

- This class is the core of Phase B
- Intent-based API makes navigation explicit and testable
- Deep link handling centralizes external navigation triggers
- `@Observable` enables SwiftUI binding to `navigationPath`
- Weak self in async closures prevents retain cycles
