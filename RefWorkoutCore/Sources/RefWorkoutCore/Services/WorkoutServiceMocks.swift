import Foundation

public final class WorkoutAuthorizationManagerStub: WorkoutAuthorizationManaging {
  public var status: WorkoutAuthorizationStatus

  public init(status: WorkoutAuthorizationStatus = WorkoutAuthorizationStatus(state: .notDetermined)) {
    self.status = status
  }

  public func authorizationStatus() async -> WorkoutAuthorizationStatus {
    status
  }

  public func requestAuthorization() async throws -> WorkoutAuthorizationStatus {
    status
  }
}

public actor WorkoutSessionTrackerStub: WorkoutSessionTracking {
  public private(set) var sessions: [UUID: WorkoutSession] = [:]
  public private(set) var events: [UUID: [WorkoutEvent]] = [:]
  public private(set) var pausedSessions: Set<UUID> = []

  public init() {}

  public func startSession(configuration: WorkoutSessionConfiguration) async throws -> WorkoutSession {
    var model = WorkoutSession(
      state: .active,
      kind: configuration.kind,
      title: configuration.title,
      startedAt: Date(),
      segments: configuration.segments,
      presetId: configuration.presetId,
      metadata: configuration.metadata
    )
    sessions[model.id] = model
    return model
  }

  public func pauseSession(id: UUID) async throws {
    guard var session = sessions[id] else { return }
    session.state = .active
    sessions[id] = session
    pausedSessions.insert(id)
  }

  public func resumeSession(id: UUID) async throws {
    guard var session = sessions[id] else { return }
    session.state = .active
    sessions[id] = session
    pausedSessions.remove(id)
  }

  public func endSession(id: UUID, at date: Date) async throws -> WorkoutSession {
    guard var session = sessions[id] else {
      throw NSError(domain: "WorkoutSessionTrackerStub", code: 1)
    }
    session.complete(at: date)
    sessions[id] = session
    pausedSessions.remove(id)
    return session
  }

  public func recordEvent(_ event: WorkoutEvent, sessionId: UUID) async {
    var sessionEvents = events[sessionId, default: []]
    sessionEvents.append(event)
    events[sessionId] = sessionEvents
  }
}

public extension WorkoutServices {
  static func inMemoryStub(
    presets: [WorkoutPreset] = [],
    historySessions: [WorkoutSession] = []
  ) -> WorkoutServices {
    let history = InMemoryWorkoutHistoryStore(initialSessions: historySessions)
    let presetsStore = InMemoryWorkoutPresetStore(initialPresets: presets)
    let tracker = WorkoutSessionTrackerStub()
    let authorization = WorkoutAuthorizationManagerStub(status: WorkoutAuthorizationStatus(state: .authorized))
    return WorkoutServices(
      authorizationManager: authorization,
      sessionTracker: tracker,
      historyStore: history,
      presetStore: presetsStore
    )
  }
}
