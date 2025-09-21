import Foundation

public struct WorkoutServices: Sendable {
  public var authorizationManager: any WorkoutAuthorizationManaging
  public var sessionTracker: any WorkoutSessionTracking
  public var historyStore: any WorkoutHistoryStoring
  public var presetStore: any WorkoutPresetStoring

  public init(
    authorizationManager: any WorkoutAuthorizationManaging,
    sessionTracker: any WorkoutSessionTracking,
    historyStore: any WorkoutHistoryStoring,
    presetStore: any WorkoutPresetStoring
  ) {
    self.authorizationManager = authorizationManager
    self.sessionTracker = sessionTracker
    self.historyStore = historyStore
    self.presetStore = presetStore
  }
}
