import Foundation

public struct WorkoutPreset: Identifiable, Hashable, Codable, Sendable {
  public let id: UUID
  public var title: String
  public var kind: WorkoutKind
  public var description: String?
  public var segments: [WorkoutSegment]
  public var defaultIntensityZones: [WorkoutIntensityZone]
  public var createdAt: Date
  public var updatedAt: Date
  public var metadata: [String: String]

  public init(
    id: UUID = UUID(),
    title: String,
    kind: WorkoutKind,
    description: String? = nil,
    segments: [WorkoutSegment],
    defaultIntensityZones: [WorkoutIntensityZone] = [],
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    metadata: [String: String] = [:]
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.description = description
    self.segments = segments
    self.defaultIntensityZones = defaultIntensityZones
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.metadata = metadata
  }

  public var totalPlannedDuration: TimeInterval {
    segments.compactMap { $0.plannedDuration }.reduce(0, +)
  }

  public var totalPlannedDistance: Double {
    segments.compactMap { $0.plannedDistance }.reduce(0, +)
  }
}
