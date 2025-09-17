#if os(watchOS)
import Foundation
import HealthKit
import RefWorkoutCore

@MainActor
final class HealthKitWorkoutTracker: NSObject, WorkoutSessionTracking, @unchecked Sendable {
  private let healthStore: HKHealthStore
  private var activeSessions: [UUID: ManagedSession] = [:]
  private var sessionLookup: [ObjectIdentifier: UUID] = [:]

  init(healthStore: HKHealthStore = HKHealthStore()) {
    self.healthStore = healthStore
    super.init()
  }

  func startSession(configuration: WorkoutSessionConfiguration) async throws -> WorkoutSession {
    guard HKHealthStore.isHealthDataAvailable() else {
      throw WorkoutSessionError.healthDataUnavailable
    }

    let hkConfiguration = try makeWorkoutConfiguration(for: configuration.kind)
    let session = try HKWorkoutSession(healthStore: healthStore, configuration: hkConfiguration)
    let builder = session.associatedWorkoutBuilder()
    builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: hkConfiguration)
    builder.delegate = self
    session.delegate = self

    let startDate = Date()
    var workoutSession = WorkoutSession(
      state: .active,
      kind: configuration.kind,
      title: configuration.title,
      startedAt: startDate,
      segments: configuration.segments,
      presetId: configuration.presetId,
      metadata: configuration.metadata
    )

    session.startActivity(with: startDate)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      builder.beginCollection(withStart: startDate) { [weak self] success, error in
        Task { @MainActor in
          guard success, error == nil else {
            session.end()
            continuation.resume(throwing: error ?? WorkoutSessionError.collectionBeginFailed)
            return
          }
          let managed = ManagedSession(configuration: configuration, session: session, builder: builder, model: workoutSession)
          self?.activeSessions[workoutSession.id] = managed
          self?.sessionLookup[ObjectIdentifier(session)] = workoutSession.id
          continuation.resume(returning: ())
        }
      }
    }

    return workoutSession
  }

  func pauseSession(id: UUID) async throws {
    guard let managed = activeSessions[id] else {
      throw WorkoutSessionError.sessionNotFound
    }
    managed.session.pause()
  }

  func resumeSession(id: UUID) async throws {
    guard let managed = activeSessions[id] else {
      throw WorkoutSessionError.sessionNotFound
    }
    managed.session.resume()
  }

  func endSession(id: UUID, at date: Date) async throws -> WorkoutSession {
    guard let managed = activeSessions[id] else {
      throw WorkoutSessionError.sessionNotFound
    }

    managed.session.end()

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      managed.builder.endCollection(withEnd: date) { success, error in
        Task { @MainActor in
          guard success, error == nil else {
            continuation.resume(throwing: error ?? WorkoutSessionError.collectionEndFailed)
            return
          }
          continuation.resume(returning: ())
        }
      }
    }

    let workout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
      managed.builder.finishWorkout { workout, error in
        Task { @MainActor in
          if let error {
            continuation.resume(throwing: error)
          } else if let workout {
            continuation.resume(returning: workout)
          } else {
            continuation.resume(throwing: WorkoutSessionError.finishFailed)
          }
        }
      }
    }

    var model = managed.model
    model.complete(at: date)
    updateSummary(&model, using: workout, builder: managed.builder)
    activeSessions.removeValue(forKey: id)
    sessionLookup.removeValue(forKey: ObjectIdentifier(managed.session))
    return model
  }

  func recordEvent(_ event: WorkoutEvent, sessionId: UUID) async {
    guard let managed = activeSessions[sessionId] else { return }
    managed.events.append(event)
  }

  private func updateSummary(_ session: inout WorkoutSession, using workout: HKWorkout, builder: HKLiveWorkoutBuilder) {
    session.summary.duration = workout.endDate.timeIntervalSince(workout.startDate)
    if let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) {
      session.summary.totalDistance = distance
    }
    if let energy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) {
      session.summary.activeEnergy = energy
    }

    if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
       let stats = builder.statistics(for: heartRateType) {
      let heartUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
      if let average = stats.averageQuantity()?.doubleValue(for: heartUnit) {
        session.summary.averageHeartRate = average
      }
      if let maximum = stats.maximumQuantity()?.doubleValue(for: heartUnit) {
        session.summary.maximumHeartRate = maximum
      }
    }
  }

  private func makeWorkoutConfiguration(for kind: WorkoutKind) throws -> HKWorkoutConfiguration {
    let configuration = HKWorkoutConfiguration()

    switch kind {
    case .outdoorRun:
      configuration.activityType = .running
      configuration.locationType = .outdoor
    case .outdoorWalk:
      configuration.activityType = .walking
      configuration.locationType = .outdoor
    case .indoorRun:
      configuration.activityType = .running
      configuration.locationType = .indoor
    case .indoorCycle:
      configuration.activityType = .cycling
      configuration.locationType = .indoor
    case .strength:
      configuration.activityType = .traditionalStrengthTraining
      configuration.locationType = .indoor
    case .mobility:
      configuration.activityType = .flexibility
      configuration.locationType = .indoor
    case .refereeDrill:
      configuration.activityType = .highIntensityIntervalTraining
      configuration.locationType = .outdoor
    case .custom:
      configuration.activityType = .other
      configuration.locationType = .unknown
    }

    return configuration
  }

  private func managedSession(for workoutSession: HKWorkoutSession) -> ManagedSession? {
    guard let modelId = sessionLookup[ObjectIdentifier(workoutSession)] else { return nil }
    return activeSessions[modelId]
  }
}

extension HealthKitWorkoutTracker: HKWorkoutSessionDelegate {
  nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    Task { @MainActor in
      guard let managed = self.managedSession(for: workoutSession) else { return }

      switch toState {
      case .running:
        managed.model.markActive(startedAt: date)
      case .paused:
        managed.model.pause()
      case .ended:
        managed.model.complete(at: date)
      case .stopped:
        managed.model.abort(at: date)
      case .notStarted, .prepared:
        break
      @unknown default:
        break
      }
    }
  }

  nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    Task { @MainActor in
      guard let managed = self.managedSession(for: workoutSession) else { return }
      managed.model.abort(at: Date())
      self.activeSessions.removeValue(forKey: managed.model.id)
      self.sessionLookup.removeValue(forKey: ObjectIdentifier(workoutSession))
    }
  }
}

extension HealthKitWorkoutTracker: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    Task { @MainActor in
      guard
        let session = workoutBuilder.workoutSession,
        let managed = self.managedSession(for: session),
        let hkEvent = workoutBuilder.workoutEvents.last
      else {
        return
      }

      let timestamp = hkEvent.dateInterval.start
      let payload = ["type": hkEvent.type.refIdentifier]
      let domainEvent = WorkoutEvent.custom(name: "healthKitEvent", payload: payload, timestamp: timestamp)
      managed.events.append(domainEvent)
    }
  }

  nonisolated func workoutBuilderDidCollectData(_ workoutBuilder: HKLiveWorkoutBuilder) {}
  nonisolated func workoutBuilderDidCollectMetrics(_ workoutBuilder: HKLiveWorkoutBuilder) {}
  nonisolated func workoutBuilderDidFinishCollection(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

private final class ManagedSession {
  let configuration: WorkoutSessionConfiguration
  let session: HKWorkoutSession
  let builder: HKLiveWorkoutBuilder
  var model: WorkoutSession
  var events: [WorkoutEvent]

  init(configuration: WorkoutSessionConfiguration, session: HKWorkoutSession, builder: HKLiveWorkoutBuilder, model: WorkoutSession) {
    self.configuration = configuration
    self.session = session
    self.builder = builder
    self.model = model
    self.events = []
  }
}

private extension HKWorkoutEventType {
  var refIdentifier: String {
    switch self {
    case .pause:
      return "pause"
    case .resume:
      return "resume"
    case .lap:
      return "lap"
    case .marker:
      return "marker"
    case .motionPaused:
      return "motionPaused"
    case .motionResumed:
      return "motionResumed"
    case .segment:
      return "segment"
    case .pauseOrResumeRequest:
      return "pauseOrResumeRequest"
    @unknown default:
      return "unknown"
    }
  }
}
#endif
