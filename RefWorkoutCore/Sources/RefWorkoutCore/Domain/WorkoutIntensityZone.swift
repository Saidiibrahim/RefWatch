import Foundation

public enum WorkoutIntensityZone: String, Codable, CaseIterable, Sendable {
  case recovery
  case aerobic
  case tempo
  case threshold
  case anaerobic

  public var displayName: String {
    switch self {
    case .recovery:
      return "Recovery"
    case .aerobic:
      return "Aerobic"
    case .tempo:
      return "Tempo"
    case .threshold:
      return "Threshold"
    case .anaerobic:
      return "Anaerobic"
    }
  }
}
