import Foundation

public enum WorkoutAuthorizationError: Error, Sendable {
  case healthDataUnavailable
  case requestFailed
}

public enum WorkoutSessionError: Error, Sendable {
  case healthDataUnavailable
  case sessionNotFound
  case collectionBeginFailed
  case collectionEndFailed
  case finishFailed
}
