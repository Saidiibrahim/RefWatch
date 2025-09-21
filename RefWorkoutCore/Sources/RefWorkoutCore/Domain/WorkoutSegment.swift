import Foundation

public struct WorkoutSegment: Identifiable, Hashable, Codable, Sendable {
  public enum Purpose: String, Codable, CaseIterable, Sendable {
    case warmup
    case work
    case recovery
    case cooldown
    case free
  }

  public struct Target: Hashable, Codable, Sendable {
    public var metric: WorkoutMetric.Kind?
    public var value: Double?
    public var unit: WorkoutMetric.Unit?
    public var intensityZone: WorkoutIntensityZone?

    public init(
      metric: WorkoutMetric.Kind? = nil,
      value: Double? = nil,
      unit: WorkoutMetric.Unit? = nil,
      intensityZone: WorkoutIntensityZone? = nil
    ) {
      self.metric = metric
      self.value = value
      self.unit = unit
      self.intensityZone = intensityZone
    }
  }

  public let id: UUID
  public var name: String
  public var purpose: Purpose
  public var plannedDuration: TimeInterval?
  public var plannedDistance: Double?
  public var target: Target?
  public var notes: String?

  public init(
    id: UUID = UUID(),
    name: String,
    purpose: Purpose,
    plannedDuration: TimeInterval? = nil,
    plannedDistance: Double? = nil,
    target: Target? = nil,
    notes: String? = nil
  ) {
    self.id = id
    self.name = name
    self.purpose = purpose
    self.plannedDuration = plannedDuration
    self.plannedDistance = plannedDistance
    self.target = target
    self.notes = notes
  }
}
