import Foundation

public enum WorkoutKind: String, Codable, CaseIterable, Sendable {
  case outdoorRun
  case outdoorWalk
  case indoorRun
  case indoorCycle
  case strength
  case mobility
  case refereeDrill
  case custom

  public var displayName: String {
    switch self {
    case .outdoorRun:
      return "Outdoor Run"
    case .outdoorWalk:
      return "Outdoor Walk"
    case .indoorRun:
      return "Indoor Run"
    case .indoorCycle:
      return "Indoor Cycle"
    case .strength:
      return "Strength"
    case .mobility:
      return "Mobility"
    case .refereeDrill:
      return "Referee Drill"
    case .custom:
      return "Custom"
    }
  }
}
