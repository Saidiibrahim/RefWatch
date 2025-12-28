import Foundation

/// Represents the push-style destinations that stack on top of the idle home.
/// Gameplay surfaces continue to be driven directly by the lifecycle state.
enum MatchRoute: Hashable {
  /// Entry point for the start flow hub (choose resume vs create).
  case startFlow

  /// Saved matches list presented from the start flow.
  case savedMatches

  /// Match configuration screen shown before kickoff.
  case createMatch
}

extension MatchRoute {
  /// Stable canonical stack shapes for each supported route. Routing code should
  /// rely on this helper instead of hand-writing array literals so stack shape
  /// stays consistent across the app and tests.
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
