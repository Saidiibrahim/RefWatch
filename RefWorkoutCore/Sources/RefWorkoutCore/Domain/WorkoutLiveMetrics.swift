import Foundation

public struct WorkoutLiveMetrics: Equatable, Sendable {
  public var sessionId: UUID
  public var timestamp: Date
  /// Seconds since the session started, if known.
  public var elapsedTime: TimeInterval?
  /// Total distance in meters.
  public var totalDistance: Double?
  /// Active energy in kilocalories.
  public var activeEnergy: Double?
  /// Instantaneous heart rate in beats per minute.
  public var heartRate: Double?
  /// Average pace in seconds per kilometre.
  public var averagePace: Double?

  public init(
    sessionId: UUID,
    timestamp: Date = Date(),
    elapsedTime: TimeInterval? = nil,
    totalDistance: Double? = nil,
    activeEnergy: Double? = nil,
    heartRate: Double? = nil,
    averagePace: Double? = nil
  ) {
    self.sessionId = sessionId
    self.timestamp = timestamp
    self.elapsedTime = elapsedTime
    self.totalDistance = totalDistance
    self.activeEnergy = activeEnergy
    self.heartRate = heartRate
    self.averagePace = averagePace
  }

  public var isEmpty: Bool {
    totalDistance == nil && activeEnergy == nil && heartRate == nil && averagePace == nil && elapsedTime == nil
  }
}
