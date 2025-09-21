import Foundation

public struct WorkoutSessionConfiguration: Sendable, Hashable, Codable {
  public var kind: WorkoutKind
  public var presetId: UUID?
  public var title: String
  public var segments: [WorkoutSegment]
  public var metadata: [String: String]

  public init(
    kind: WorkoutKind,
    presetId: UUID? = nil,
    title: String,
    segments: [WorkoutSegment] = [],
    metadata: [String: String] = [:]
  ) {
    self.kind = kind
    self.presetId = presetId
    self.title = title
    self.segments = segments
    self.metadata = metadata
  }
}
