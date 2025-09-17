import Foundation

public struct WorkoutSession: Identifiable, Codable, Hashable, Sendable {
  public struct Summary: Codable, Hashable, Sendable {
    public var averageHeartRate: Double?
    public var maximumHeartRate: Double?
    public var totalDistance: Double?
    public var activeEnergy: Double?
    public var duration: TimeInterval?

    public init(
      averageHeartRate: Double? = nil,
      maximumHeartRate: Double? = nil,
      totalDistance: Double? = nil,
      activeEnergy: Double? = nil,
      duration: TimeInterval? = nil
    ) {
      self.averageHeartRate = averageHeartRate
      self.maximumHeartRate = maximumHeartRate
      self.totalDistance = totalDistance
      self.activeEnergy = activeEnergy
      self.duration = duration
    }
  }

  public enum State: String, Codable, Sendable {
    case planned
    case active
    case ended
    case aborted
  }

  public let id: UUID
  public var state: State
  public var kind: WorkoutKind
  public var title: String
  public var startedAt: Date
  public var endedAt: Date?
  public var segments: [WorkoutSegment]
  public var metrics: [WorkoutMetric]
  public var intensityProfile: [WorkoutIntensityZone]
  public var summary: Summary
  public var perceivedExertion: Int?
  public var presetId: UUID?
  public var notes: String?
  public var metadata: [String: String]

  public init(
    id: UUID = UUID(),
    state: State? = nil,
    kind: WorkoutKind,
    title: String,
    startedAt: Date,
    endedAt: Date? = nil,
    segments: [WorkoutSegment] = [],
    metrics: [WorkoutMetric] = [],
    intensityProfile: [WorkoutIntensityZone] = [],
    summary: Summary = Summary(),
    perceivedExertion: Int? = nil,
    presetId: UUID? = nil,
    notes: String? = nil,
    metadata: [String: String] = [:]
  ) {
    self.id = id
    let resolvedState: State
    if let provided = state {
      resolvedState = provided
    } else if endedAt != nil {
      resolvedState = .ended
    } else {
      resolvedState = .planned
    }
    self.state = resolvedState
    self.kind = kind
    self.title = title
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.segments = segments
    self.metrics = metrics
    self.intensityProfile = intensityProfile
    self.summary = summary
    self.perceivedExertion = perceivedExertion
    self.presetId = presetId
    self.notes = notes
    self.metadata = metadata
  }

  public var isActive: Bool {
    state == .active
  }

  public var isCompleted: Bool {
    state == .ended
  }

  public var totalDuration: TimeInterval? {
    guard let endedAt else { return nil }
    return endedAt.timeIntervalSince(startedAt)
  }

  public func elapsedDuration(asOf date: Date = Date()) -> TimeInterval {
    switch state {
    case .planned:
      return 0
    case .active:
      return max(0, date.timeIntervalSince(startedAt))
    case .ended, .aborted:
      return totalDuration ?? 0
    }
  }

  @discardableResult
  public mutating func markActive(startedAt: Date? = nil) -> WorkoutSession {
    if let startedAt {
      self.startedAt = startedAt
    }
    self.state = .active
    self.endedAt = nil
    return self
  }

  @discardableResult
  public mutating func complete(at date: Date) -> WorkoutSession {
    self.endedAt = date
    self.state = .ended
    return self
  }

  @discardableResult
  public mutating func abort(at date: Date? = nil) -> WorkoutSession {
    if let date {
      self.endedAt = date
    }
    self.state = .aborted
    return self
  }
}
