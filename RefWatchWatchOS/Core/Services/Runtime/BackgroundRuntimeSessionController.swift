//
//  BackgroundRuntimeSessionController.swift
//  RefWatchWatchOS
//
//  Description: Workout-backed Match Mode runtime protection for unfinished
//  matches, including active-session recovery after relaunch.
//

#if os(watchOS)
import Foundation
import HealthKit
import Observation
import WatchKit
@preconcurrency import RefWatchCore

/// Temporarily holds a recovered `HKWorkoutSession` handed off from the watch
/// application delegate so the main runtime controller can attach to it during
/// the next reconciliation pass.
@MainActor
final class MatchWorkoutRecoveryBroker {
  static let shared = MatchWorkoutRecoveryBroker()

  private var recoveredSession: HKWorkoutSession?

  private init() {}

  func storeRecoveredSession(_ session: HKWorkoutSession) {
    self.recoveredSession = session
  }

  func consumeRecoveredSession() -> HKWorkoutSession? {
    defer { self.recoveredSession = nil }
    return self.recoveredSession
  }
}

/// Errors surfaced while authorizing, starting, or recovering the workout-backed
/// runtime session used for Match Mode continuity.
enum MatchRuntimeSessionError: Error, Equatable {
  case healthDataUnavailable
  case authorizationDenied
  case authorizationRequestFailed
  case sessionStartFailed
  case sessionRecoveryFailed
}

/// Abstracts the runtime-session implementation that keeps Match Mode active
/// while an unfinished match is still being officiated.
@MainActor
protocol MatchRuntimeSessionProviding: AnyObject {
  var hasActiveSession: Bool { get }
  var startedAt: Date? { get }
  func recoverActiveSessionIfPossible() async throws -> Bool
  func requestAuthorizationIfNeeded() async throws -> Bool
  func start(title: String?, metadata: [String: String]) async throws
  func update(title: String?, metadata: [String: String])
  func stop(reason: BackgroundRuntimeEndReason) async throws
}

/// Test-only provider that simulates an active workout-backed runtime without
/// talking to HealthKit.
@MainActor
private final class UITestMatchRuntimeSessionProvider: MatchRuntimeSessionProviding {
  private(set) var hasActiveSession = false
  private(set) var startedAt: Date?

  func recoverActiveSessionIfPossible() async throws -> Bool {
    false
  }

  func requestAuthorizationIfNeeded() async throws -> Bool {
    true
  }

  func start(title: String?, metadata: [String: String]) async throws {
    self.hasActiveSession = true
    self.startedAt = Date()
  }

  func update(title: String?, metadata: [String: String]) {}

  func stop(reason: BackgroundRuntimeEndReason) async throws {
    self.hasActiveSession = false
    self.startedAt = nil
  }
}

/// HealthKit-backed provider that starts, updates, stops, and recovers the
/// `HKWorkoutSession` used for best-effort Match Mode continuity on watchOS.
@MainActor
private final class HealthKitMatchRuntimeSessionProvider: NSObject, MatchRuntimeSessionProviding {
  private let healthStore: HKHealthStore
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private(set) var startedAt: Date?

  init(healthStore: HKHealthStore = HKHealthStore()) {
    self.healthStore = healthStore
    super.init()
  }

  var hasActiveSession: Bool {
    self.session != nil
  }

  func recoverActiveSessionIfPossible() async throws -> Bool {
    if let recoveredSession = MatchWorkoutRecoveryBroker.shared.consumeRecoveredSession() {
      try self.attachRecoveredSession(recoveredSession)
      return true
    }

    return try await withCheckedThrowingContinuation { continuation in
      self.healthStore.recoverActiveWorkoutSession { [weak self] recoveredSession, error in
        Task { @MainActor in
          if let error {
            let nsError = error as NSError
            if nsError.domain == HKError.errorDomain,
               nsError.code == HKError.Code.errorNoData.rawValue
            {
              continuation.resume(returning: false)
              return
            }
            continuation.resume(throwing: error)
            return
          }

          guard let self, let recoveredSession else {
            continuation.resume(returning: false)
            return
          }

          do {
            try self.attachRecoveredSession(recoveredSession)
            continuation.resume(returning: true)
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }

  func requestAuthorizationIfNeeded() async throws -> Bool {
    guard HKHealthStore.isHealthDataAvailable() else {
      throw MatchRuntimeSessionError.healthDataUnavailable
    }

    let workoutType = HKObjectType.workoutType()
    switch self.healthStore.authorizationStatus(for: workoutType) {
    case .sharingAuthorized:
      return true
    case .sharingDenied:
      return false
    case .notDetermined:
      return try await withCheckedThrowingContinuation { continuation in
        self.healthStore.requestAuthorization(toShare: Set([workoutType]), read: Set([workoutType])) { success, error in
          if let error {
            continuation.resume(throwing: error)
            return
          }
          continuation.resume(returning: success)
        }
      }
    @unknown default:
      return false
    }
  }

  func start(title: String?, metadata: [String: String]) async throws {
    guard self.session == nil else { return }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .other
    configuration.locationType = .unknown

    let session = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
    let builder = session.associatedWorkoutBuilder()
    builder.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore, workoutConfiguration: configuration)
    session.delegate = self
    builder.delegate = self

    let startDate = Date()
    session.startActivity(with: startDate)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      builder.beginCollection(withStart: startDate) { success, error in
        guard success, error == nil else {
          continuation.resume(throwing: error ?? MatchRuntimeSessionError.sessionStartFailed)
          return
        }
        continuation.resume(returning: ())
      }
    }

    self.session = session
    self.builder = builder
    self.startedAt = startDate
    self.update(title: title, metadata: metadata)
  }

  func update(title: String?, metadata: [String: String]) {
    guard let builder else { return }
    var updatedMetadata = metadata
    if let title {
      updatedMetadata[HKMetadataKeyWorkoutBrandName] = title
    }
    builder.addMetadata(updatedMetadata) { _, _ in }
  }

  func stop(reason: BackgroundRuntimeEndReason) async throws {
    guard let session, let builder else { return }

    self.session = nil
    self.builder = nil
    self.startedAt = nil

    session.end()

    switch reason {
    case .completed:
      let endDate = Date()
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        builder.endCollection(withEnd: endDate) { success, error in
          guard success, error == nil else {
            continuation.resume(throwing: error ?? MatchRuntimeSessionError.sessionStartFailed)
            return
          }
          continuation.resume(returning: ())
        }
      }

      _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
        builder.finishWorkout { workout, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let workout {
            continuation.resume(returning: workout)
          } else {
            continuation.resume(throwing: MatchRuntimeSessionError.sessionStartFailed)
          }
        }
      }
    case .cancelled, .reset, .failure:
      builder.discardWorkout()
    }
  }

  private func attachRecoveredSession(_ recoveredSession: HKWorkoutSession) throws {
    let configuration = recoveredSession.workoutConfiguration
    let builder = recoveredSession.associatedWorkoutBuilder()
    builder.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore, workoutConfiguration: configuration)
    recoveredSession.delegate = self
    builder.delegate = self

    self.session = recoveredSession
    self.builder = builder
    self.startedAt = recoveredSession.startDate
  }
}

extension HealthKitMatchRuntimeSessionProvider: HKWorkoutSessionDelegate {
  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date)
  {
    Task { @MainActor in
      guard self.session === workoutSession else { return }
      if toState == .running, self.startedAt == nil {
        self.startedAt = date
      }
    }
  }

  nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    Task { @MainActor in
      guard self.session === workoutSession else { return }
      self.session = nil
      self.builder = nil
      self.startedAt = nil
    }
  }
}

extension HealthKitMatchRuntimeSessionProvider: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
  nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}

/// Keeps Match mode alive with a workout-backed runtime session while an unfinished
/// match is active. The controller reconciles toward a desired state instead of
/// blindly starting or stopping sessions on every lifecycle callback.
///
/// Match Mode still operates within watchOS platform limits. The controller
/// targets the documented workout-session path for wrist-raise return and
/// relaunch recovery, but it does not guarantee absolute frontmost residency if
/// the user leaves the app, HealthKit authorization is denied, or watchOS
/// terminates the process.
@MainActor
@Observable
final class BackgroundRuntimeSessionController: NSObject {
  /// High-level reconciliation state for the workout-backed runtime controller.
  enum Status: Equatable {
    case idle
    case recovering
    case authorizing
    case starting
    case running(startedAt: Date)
    case stopping
    case failed
  }

  private struct DesiredRuntime: Equatable {
    let kind: BackgroundRuntimeActivityKind
    let title: String?
    var metadata: [String: String]
  }

  private(set) var status: Status = .idle
  private(set) var lastError: Error?

  private let provider: MatchRuntimeSessionProviding
  private var desiredRuntime: DesiredRuntime?
  private var pendingStopReason: BackgroundRuntimeEndReason = .cancelled
  private var reconcileTask: Task<Void, Never>?
  private var needsReconcile = false
  private var didAttemptRecoveryForCurrentDesiredState = false

  /// Returns the runtime controller appropriate for the current process.
  ///
  /// UI tests and explicitly disabled environments receive a no-op provider so
  /// test runs can exercise lifecycle logic without creating real workout
  /// sessions.
  static func makeForCurrentEnvironment() -> BackgroundRuntimeSessionController {
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      || ProcessInfo.processInfo.environment["REFWATCH_DISABLE_MATCH_RUNTIME"] == "1"
    {
      return BackgroundRuntimeSessionController(provider: UITestMatchRuntimeSessionProvider())
    }
    return BackgroundRuntimeSessionController()
  }

  init(provider: MatchRuntimeSessionProviding? = nil) {
    self.provider = provider ?? HealthKitMatchRuntimeSessionProvider()
    super.init()
  }

  /// Reconciles toward an active Match Mode runtime session for the supplied
  /// unfinished match metadata.
  func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String]) {
    self.pendingStopReason = .cancelled
    self.desiredRuntime = DesiredRuntime(kind: kind, title: title, metadata: metadata)
    self.requestReconcile()
  }

  func notifyPause() {
    guard var desiredRuntime else { return }
    desiredRuntime.metadata["isPaused"] = "true"
    self.desiredRuntime = desiredRuntime
    self.provider.update(title: desiredRuntime.title, metadata: desiredRuntime.metadata)
  }

  func notifyResume() {
    guard var desiredRuntime else { return }
    desiredRuntime.metadata["isPaused"] = "false"
    self.desiredRuntime = desiredRuntime
    self.provider.update(title: desiredRuntime.title, metadata: desiredRuntime.metadata)
  }

  /// Reconciles toward no active runtime session and records how the workout
  /// should be finished or discarded when shutdown completes.
  func end(reason: BackgroundRuntimeEndReason) {
    self.desiredRuntime = nil
    self.pendingStopReason = reason
    self.requestReconcile()
  }

  private func requestReconcile() {
    self.needsReconcile = true
    guard self.reconcileTask == nil else { return }

    self.reconcileTask = Task { @MainActor [weak self] in
      guard let self else { return }
      while self.needsReconcile {
        self.needsReconcile = false
        await self.reconcileNow()
      }
      self.reconcileTask = nil
    }
  }

  private func reconcileNow() async {
    do {
      if let desiredRuntime = self.desiredRuntime {
        if self.provider.hasActiveSession {
          self.provider.update(title: desiredRuntime.title, metadata: desiredRuntime.metadata)
          self.status = .running(startedAt: self.provider.startedAt ?? Date())
          return
        }

        if self.didAttemptRecoveryForCurrentDesiredState == false {
          self.status = .recovering
          self.didAttemptRecoveryForCurrentDesiredState = true
          if try await self.provider.recoverActiveSessionIfPossible() {
            self.provider.update(title: desiredRuntime.title, metadata: desiredRuntime.metadata)
            self.status = .running(startedAt: self.provider.startedAt ?? Date())
            return
          }
        }

        self.status = .authorizing
        let authorized = try await self.provider.requestAuthorizationIfNeeded()
        guard authorized else {
          self.status = .failed
          self.lastError = MatchRuntimeSessionError.authorizationDenied
          return
        }
        guard let desiredRuntime = self.desiredRuntime else { return }

        self.status = .starting
        try await self.provider.start(title: desiredRuntime.title, metadata: desiredRuntime.metadata)
        self.status = .running(startedAt: self.provider.startedAt ?? Date())
        self.lastError = nil
        return
      }

      self.didAttemptRecoveryForCurrentDesiredState = false
      guard self.provider.hasActiveSession else {
        self.status = .idle
        self.lastError = nil
        return
      }

      self.status = .stopping
      let stopReason = self.pendingStopReason
      self.pendingStopReason = .cancelled
      try await self.provider.stop(reason: stopReason)
      self.status = .idle
      self.lastError = nil
    } catch {
      self.status = .failed
      self.lastError = error
    }
  }
}

extension BackgroundRuntimeSessionController: @MainActor BackgroundRuntimeManaging {}
#endif
