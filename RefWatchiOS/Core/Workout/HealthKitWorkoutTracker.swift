#if os(iOS)
import Foundation
import HealthKit
import RefWorkoutCore

@available(iOS 17.0, *)
@MainActor
final class IOSHealthKitWorkoutTracker: NSObject, WorkoutSessionTracking {
  private let healthStore: HKHealthStore
  private var activeSessions: [UUID: ManagedSession] = [:]
  private var sessionLookup: [ObjectIdentifier: UUID] = [:]
  private var liveMetricsContinuations: [UUID: AsyncStream<WorkoutLiveMetrics>.Continuation] = [:]

  init(healthStore: HKHealthStore = HKHealthStore()) {
    self.healthStore = healthStore
    super.init()
  }

  func startSession(configuration: WorkoutSessionConfiguration) async throws -> WorkoutSession {
    guard HKHealthStore.isHealthDataAvailable() else {
      throw WorkoutSessionError.healthDataUnavailable
    }

    let hkConfiguration = try makeWorkoutConfiguration(for: configuration.kind)

    if #available(iOS 26.0, *) {
      // Use new HKLiveWorkoutBuilder API for iOS 26.0+
      let session = try HKWorkoutSession(healthStore: self.healthStore, configuration: hkConfiguration)
      let builder = session.associatedWorkoutBuilder()
      builder.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore, workoutConfiguration: hkConfiguration)
      builder.delegate = self
      session.delegate = self

      let startDate = Date()
      let workoutSession = WorkoutSession(
        state: .active,
        kind: configuration.kind,
        title: configuration.title,
        startedAt: startDate,
        segments: configuration.segments,
        presetId: configuration.presetId,
        metadata: configuration.metadata)

      session.startActivity(with: startDate)

      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        builder.beginCollection(withStart: startDate) { [weak self] success, error in
          Task { @MainActor [weak self] in
            guard success, error == nil else {
              session.stopActivity(with: Date())
              session.end()
              builder.discardWorkout()
              continuation.resume(throwing: error ?? WorkoutSessionError.collectionBeginFailed)
              return
            }

            guard let self else {
              continuation.resume(throwing: WorkoutSessionError.collectionBeginFailed)
              return
            }

            let managed = ManagedSession(
              configuration: configuration,
              session: session,
              builder: builder,
              model: workoutSession)
            self.activeSessions[workoutSession.id] = managed
            self.sessionLookup[ObjectIdentifier(session)] = workoutSession.id
            continuation.resume(returning: ())
          }
        }
      }

      return workoutSession
    } else {
      // Use legacy approach for iOS 17.0-25.x
      let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: hkConfiguration, device: nil)
      // HKWorkoutBuilder on iOS doesn't expose delegate hooks, so we only keep a reference for summary data.

      let startDate = Date()
      let workoutSession = WorkoutSession(
        state: .active,
        kind: configuration.kind,
        title: configuration.title,
        startedAt: startDate,
        segments: configuration.segments,
        presetId: configuration.presetId,
        metadata: configuration.metadata)

      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        builder.beginCollection(withStart: startDate) { [weak self] success, error in
          Task { @MainActor [weak self] in
            guard success, error == nil else {
              continuation.resume(throwing: error ?? WorkoutSessionError.collectionBeginFailed)
              return
            }

            guard let self else {
              continuation.resume(throwing: WorkoutSessionError.collectionBeginFailed)
              return
            }

            let managed = ManagedSession(
              configuration: configuration,
              session: nil,
              builder: builder,
              model: workoutSession)
            self.activeSessions[workoutSession.id] = managed
            continuation.resume(returning: ())
          }
        }
      }

      return workoutSession
    }
  }

  func pauseSession(id: UUID) async throws {
    guard let managed = activeSessions[id] else {
      throw WorkoutSessionError.sessionNotFound
    }
    if let session = managed.session {
      session.pause()
    } else {
      // For legacy builder-only approach, we just mark the model as paused
      managed.model.pause()
    }
  }

  func resumeSession(id: UUID) async throws {
    guard let managed = activeSessions[id] else {
      throw WorkoutSessionError.sessionNotFound
    }
    if let session = managed.session {
      session.resume()
    } else {
      // For legacy builder-only approach, we just mark the model as active
      managed.model.markActive(startedAt: Date())
    }
  }

  func endSession(id: UUID, at date: Date) async throws -> WorkoutSession {
    guard let managed = activeSessions[id] else {
      throw WorkoutSessionError.sessionNotFound
    }

    if let session = managed.session {
      session.end()
    }

    // Handle both builder types for endCollection
    if #available(iOS 26.0, *), let liveBuilder = managed.builder as? HKLiveWorkoutBuilder {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        liveBuilder.endCollection(withEnd: date) { success, error in
          Task { @MainActor in
            guard success, error == nil else {
              continuation.resume(throwing: error ?? WorkoutSessionError.collectionEndFailed)
              return
            }
            continuation.resume(returning: ())
          }
        }
      }

      // Handle finishWorkout for live builder
      let workout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
        liveBuilder.finishWorkout { workout, error in
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
      self.updateSummary(&model, using: workout, builder: managed.builder)
      self.activeSessions.removeValue(forKey: id)
      if let session = managed.session {
        self.sessionLookup.removeValue(forKey: ObjectIdentifier(session))
      }
      return model
    } else if let legacyBuilder = managed.builder as? HKWorkoutBuilder {
      // Handle legacy HKWorkoutBuilder
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        legacyBuilder.endCollection(withEnd: date) { success, error in
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
        legacyBuilder.finishWorkout { workout, error in
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
      self.updateSummary(&model, using: workout, builder: managed.builder)
      self.activeSessions.removeValue(forKey: id)
      return model
    } else {
      // For sessions without any builder, create a simple workout manually
      var model = managed.model
      model.complete(at: date)

      // Create a basic workout for legacy sessions
      let workout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
        let workoutActivityType: HKWorkoutActivityType
        do {
          workoutActivityType = try self.makeWorkoutConfiguration(for: model.kind).activityType
        } catch {
          workoutActivityType = .other
        }
        let workout = HKWorkout(
          activityType: workoutActivityType,
          start: model.startedAt,
          end: date)
        continuation.resume(returning: workout)
      }

      self.updateSummaryLegacy(&model, using: workout)
      self.activeSessions.removeValue(forKey: id)
      if let session = managed.session {
        self.sessionLookup.removeValue(forKey: ObjectIdentifier(session))
      }
      return model
    }
  }

  func recordEvent(_ event: WorkoutEvent, sessionId: UUID) async {
    guard let managed = activeSessions[sessionId] else { return }
    managed.events.append(event)
  }

  func liveMetricsStream() -> AsyncStream<WorkoutLiveMetrics> {
    AsyncStream { continuation in
      let token = UUID()
      continuation.onTermination = { @Sendable [weak self] _ in
        Task { @MainActor [weak self] in
          self?.liveMetricsContinuations.removeValue(forKey: token)
        }
      }
      Task { @MainActor [weak self] in
        self?.liveMetricsContinuations[token] = continuation
      }
    }
  }

  private func updateSummary(_ session: inout WorkoutSession, using workout: HKWorkout, builder: Any?) {
    session.summary.duration = workout.endDate.timeIntervalSince(workout.startDate)
    if let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) {
      session.summary.totalDistance = distance
    }
    if let energy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) {
      session.summary.activeEnergy = energy
    }

    // Handle statistics from builder if available
    if let builder {
      var statistics: HKStatistics?
      if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
        if #available(iOS 26.0, *), let liveBuilder = builder as? HKLiveWorkoutBuilder {
          statistics = liveBuilder.statistics(for: heartRateType)
        } else if let legacyBuilder = builder as? HKWorkoutBuilder {
          statistics = legacyBuilder.statistics(for: heartRateType)
        }

        if let stats = statistics {
          let heartUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
          if let average = stats.averageQuantity()?.doubleValue(for: heartUnit) {
            session.summary.averageHeartRate = average
          }
          if let maximum = stats.maximumQuantity()?.doubleValue(for: heartUnit) {
            session.summary.maximumHeartRate = maximum
          }
        }
      }
    }
  }

  private func updateSummaryLegacy(_ session: inout WorkoutSession, using workout: HKWorkout) {
    session.summary.duration = workout.endDate.timeIntervalSince(workout.startDate)
    if let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) {
      session.summary.totalDistance = distance
    }
    if let energy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) {
      session.summary.activeEnergy = energy
    }
    // Note: Heart rate data would require separate HealthKit queries for legacy sessions
  }

  private func updateSummary(_ session: inout WorkoutSession, with metrics: WorkoutLiveMetrics) {
    if let elapsed = metrics.elapsedTime {
      session.summary.duration = elapsed
    }
    if let distance = metrics.totalDistance {
      session.summary.totalDistance = distance
    }
    if let energy = metrics.activeEnergy {
      session.summary.activeEnergy = energy
    }
  }

  private func broadcastLiveMetrics(_ metrics: WorkoutLiveMetrics) {
    for continuation in self.liveMetricsContinuations.values {
      continuation.yield(metrics)
    }
  }

  @available(iOS 26.0, *)
  private func metrics(
    for builder: HKLiveWorkoutBuilder,
    session: ManagedSession,
    collectedTypes: Set<HKSampleType>?) -> WorkoutLiveMetrics?
  {
    let timestamp = Date()
    var metrics = WorkoutLiveMetrics(sessionId: session.model.id, timestamp: timestamp)
    var didUpdate = false

    let elapsed = builder.elapsedTime
    if elapsed > 0 {
      metrics.elapsedTime = elapsed
      didUpdate = true
    }

    if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
      if collectedTypes == nil || collectedTypes?.contains(distanceType) == true {
        if let stats = builder.statistics(for: distanceType),
           let sum = stats.sumQuantity()?.doubleValue(for: HKUnit.meter())
        {
          metrics.totalDistance = sum
          didUpdate = true
        }
      }
    }

    if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
      if collectedTypes == nil || collectedTypes?.contains(energyType) == true {
        if let stats = builder.statistics(for: energyType),
           let sum = stats.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie())
        {
          metrics.activeEnergy = sum
          didUpdate = true
        }
      }
    }

    if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
      if collectedTypes == nil || collectedTypes?.contains(heartRateType) == true {
        if let stats = builder.statistics(for: heartRateType) {
          let heartUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
          if let recent = stats.mostRecentQuantity()?.doubleValue(for: heartUnit) {
            metrics.heartRate = recent
            didUpdate = true
          }
          if let average = stats.averageQuantity()?.doubleValue(for: heartUnit) {
            session.model.summary.averageHeartRate = average
          }
          if let maximum = stats.maximumQuantity()?.doubleValue(for: heartUnit) {
            session.model.summary.maximumHeartRate = maximum
          }
        }
      }
    }

    if let distance = metrics.totalDistance ?? session.model.summary.totalDistance,
       distance > 0,
       elapsed > 5
    {
      let kilometres = distance / 1000
      if kilometres > 0 {
        metrics.averagePace = elapsed / kilometres
        didUpdate = true
      }
    }

    if !didUpdate {
      return nil
    }

    self.updateSummary(&session.model, with: metrics)
    session.latestMetrics = metrics
    return metrics
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
    return self.activeSessions[modelId]
  }
}

extension IOSHealthKitWorkoutTracker: HKWorkoutSessionDelegate {
  func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date)
  {
    guard let managed = managedSession(for: workoutSession) else { return }

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

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    guard let managed = managedSession(for: workoutSession) else { return }
    managed.model.abort(at: Date())
    self.activeSessions.removeValue(forKey: managed.model.id)
    self.sessionLookup.removeValue(forKey: ObjectIdentifier(workoutSession))
  }
}

// MARK: - HKLiveWorkoutBuilderDelegate (iOS 26.0+)

@available(iOS 26.0, *)
extension IOSHealthKitWorkoutTracker: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didCollectDataOf collectedTypes: Set<HKSampleType>)
  {
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard
        let session = workoutBuilder.workoutSession,
        let managed = self.managedSession(for: session),
        let metrics = self.metrics(for: workoutBuilder, session: managed, collectedTypes: collectedTypes)
      else {
        return
      }
      self.broadcastLiveMetrics(metrics)
    }
  }

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    Task { @MainActor [weak self] in
      guard let self else { return }
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

  nonisolated func workoutBuilderDidCollectData(_ workoutBuilder: HKLiveWorkoutBuilder) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard
        let session = workoutBuilder.workoutSession,
        let managed = self.managedSession(for: session),
        let metrics = self.metrics(for: workoutBuilder, session: managed, collectedTypes: nil)
      else {
        return
      }
      self.broadcastLiveMetrics(metrics)
    }
  }

  nonisolated func workoutBuilderDidCollectMetrics(_ workoutBuilder: HKLiveWorkoutBuilder) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard
        let session = workoutBuilder.workoutSession,
        let managed = self.managedSession(for: session),
        let metrics = self.metrics(for: workoutBuilder, session: managed, collectedTypes: nil)
      else {
        return
      }
      self.broadcastLiveMetrics(metrics)
    }
  }

  nonisolated func workoutBuilderDidFinishCollection(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

private final class ManagedSession {
  let configuration: WorkoutSessionConfiguration
  let session: HKWorkoutSession? // Can be nil for legacy HKWorkoutBuilder-only approach
  let builder: Any? // Can be HKLiveWorkoutBuilder or HKWorkoutBuilder for legacy sessions
  var model: WorkoutSession
  var events: [WorkoutEvent]
  var latestMetrics: WorkoutLiveMetrics?

  init(configuration: WorkoutSessionConfiguration, session: HKWorkoutSession?, builder: Any?, model: WorkoutSession) {
    self.configuration = configuration
    self.session = session
    self.builder = builder
    self.model = model
    self.events = []
    self.latestMetrics = nil
  }
}

extension HKWorkoutEventType {
  fileprivate var refIdentifier: String {
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
