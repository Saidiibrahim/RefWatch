import Foundation

public enum WorkoutAuthorizationMetric: String, CaseIterable, Sendable {
  case distance
  case heartRate
  case activeEnergy
  case vo2Max

  public var isRequired: Bool {
    switch self {
    case .distance, .heartRate, .activeEnergy:
      return true
    case .vo2Max:
      return false
    }
  }

  public var isOptional: Bool {
    !isRequired
  }

  public var displayName: String {
    switch self {
    case .distance:
      return "Distance"
    case .heartRate:
      return "Heart Rate"
    case .activeEnergy:
      return "Active Energy"
    case .vo2Max:
      return "VO2 Max"
    }
  }
}

public struct WorkoutAuthorizationStatus: Equatable, Sendable {
  public enum State: String, Sendable {
    case notDetermined
    case denied
    case limited
    case authorized
  }

  public var state: State
  public var lastPromptedAt: Date?
  public var deniedMetrics: Set<WorkoutAuthorizationMetric>

  public init(
    state: State,
    lastPromptedAt: Date? = nil,
    deniedMetrics: Set<WorkoutAuthorizationMetric> = []
  ) {
    self.state = state
    self.lastPromptedAt = lastPromptedAt
    self.deniedMetrics = deniedMetrics
  }

  public var isAuthorized: Bool {
    state == .authorized
  }

  public var deniedRequiredMetrics: Set<WorkoutAuthorizationMetric> {
    Set(deniedMetrics.filter(\.isRequired))
  }

  public var deniedOptionalMetrics: Set<WorkoutAuthorizationMetric> {
    Set(deniedMetrics.filter(\.isOptional))
  }

  public var hasOptionalLimitations: Bool {
    !deniedOptionalMetrics.isEmpty
  }

  public var hasRequiredLimitations: Bool {
    !deniedRequiredMetrics.isEmpty
  }
}
