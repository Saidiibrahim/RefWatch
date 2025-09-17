import Foundation

public struct WorkoutAuthorizationStatus: Equatable, Sendable {
  public enum State: String, Sendable {
    case notDetermined
    case denied
    case limited
    case authorized
  }

  public var state: State
  public var lastPromptedAt: Date?

  public init(state: State, lastPromptedAt: Date? = nil) {
    self.state = state
    self.lastPromptedAt = lastPromptedAt
  }

  public var isAuthorized: Bool {
    state == .authorized
  }
}
