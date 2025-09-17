import Foundation

public enum AppMode: String, CaseIterable, Codable, Identifiable, Sendable, Hashable {
  case match
  case workout

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .match:
      return "Match"
    case .workout:
      return "Workout"
    }
  }

  public var systemImageName: String {
    switch self {
    case .match:
      return "sportscourt"
    case .workout:
      return "figure.run"
    }
  }

  public var tagline: String {
    switch self {
    case .match:
      return "Officiate smarter"
    case .workout:
      return "Train like match day"
    }
  }
}
