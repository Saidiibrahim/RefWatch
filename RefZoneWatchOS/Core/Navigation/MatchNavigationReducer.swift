import Foundation
import RefWatchCore

typealias MatchPhase = MatchLifecycleCoordinator.State

/// Reducer that keeps the navigation path in sync with lifecycle transitions.
/// Clearing the stacked start-flow screens when leaving idle avoids back-stack
/// ghosts once gameplay begins.
struct MatchNavigationReducer {
  /// Applies navigation updates for a lifecycle transition.
  /// - Parameters:
  ///   - path: The current navigation stack (mutated in place).
  ///   - oldState: Lifecycle state before the transition.
  ///   - newState: Lifecycle state after the transition.
  func reduce(path: inout [MatchRoute], from oldState: MatchPhase, to newState: MatchPhase) {
    if newState == .idle && oldState != .idle {
      path.removeAll(keepingCapacity: false)
      return
    }

    if oldState == .idle && newState != .idle {
      path.removeAll(keepingCapacity: false)
    }
  }
}
