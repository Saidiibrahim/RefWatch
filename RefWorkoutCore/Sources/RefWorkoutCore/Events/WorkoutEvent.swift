import Foundation

public enum WorkoutEvent: Hashable, Codable, Sendable {
  case lap(index: Int, timestamp: Date)
  case intervalCompleted(segmentId: UUID, timestamp: Date)
  case heartRateSample(bpm: Double, timestamp: Date)
  case gpsPoint(latitude: Double, longitude: Double, altitude: Double?, timestamp: Date)
  case custom(name: String, payload: [String: String], timestamp: Date)
}
