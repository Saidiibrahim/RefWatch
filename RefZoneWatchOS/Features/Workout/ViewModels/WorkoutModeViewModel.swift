import Foundation
import RefWatchCore
import RefWorkoutCore

/// Domain-specific errors for workout operations
enum WorkoutError: LocalizedError {
    case authorizationDenied
    case healthDataUnavailable
    case authorizationRequestFailed
    case sessionNotFound
    case sessionStartFailed(reason: String)
    case sessionEndFailed(reason: String)
    case collectionFailed(reason: String)
    case sessionFinishFailed(reason: String)
    case historyPersistenceFailed(reason: String)
    case presetLoadFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "HealthKit access denied. Please enable workout permissions in Settings."
        case .healthDataUnavailable:
            return "HealthKit is not available on this device."
        case .authorizationRequestFailed:
            return "Failed to request HealthKit authorization. Please try again."
        case .sessionNotFound:
            return "Workout session not found. Please try starting a new workout."
        case .sessionStartFailed(let reason):
            return "Failed to start workout: \(reason)"
        case .sessionEndFailed(let reason):
            return "Failed to end workout: \(reason)"
        case .collectionFailed(let reason):
            return "Failed to collect workout data: \(reason)"
        case .sessionFinishFailed(let reason):
            return "Failed to finish saving workout data: \(reason)"
        case .historyPersistenceFailed(let reason):
            return "Workout ended but couldn't save to history: \(reason)"
        case .presetLoadFailed(let reason):
            return "Failed to load workout presets: \(reason)"
        }
    }

    var recoveryAction: String? {
        switch self {
        case .authorizationDenied:
            return "Go to Settings > Privacy & Security > Health > RefWatch and enable workout permissions."
        case .healthDataUnavailable:
            return "HealthKit is not supported on this device. Workout features may be limited."
        case .authorizationRequestFailed:
            return "Try requesting permissions again or restart the app."
        case .sessionNotFound:
            return "Start a new workout session."
        case .sessionStartFailed:
            return "Try starting the workout again or restart the app."
        case .sessionEndFailed:
            return "The workout ended but may not have been saved properly."
        case .collectionFailed:
            return "Try ending the workout again or restart the app."
        case .sessionFinishFailed:
            return "Your workout data may be incomplete. Try syncing later."
        case .historyPersistenceFailed:
            return "Your workout data was recorded but couldn't be saved. Try syncing later."
        case .presetLoadFailed:
            return "Using default presets. Check your connection and try again."
        }
    }
}

@MainActor
final class WorkoutModeViewModel: ObservableObject {
  @Published private(set) var authorization: WorkoutAuthorizationStatus = WorkoutAuthorizationStatus(state: .notDetermined)
  @Published private(set) var presets: [WorkoutPreset] = []
  @Published private(set) var activeSession: WorkoutSession?
  @Published private(set) var lastCompletedSession: WorkoutSession?
  @Published private(set) var isActiveSessionPaused = false
  @Published private(set) var lapCount = 0
  @Published private(set) var isRecordingSegment = false
  @Published var errorMessage: String?
  @Published var isPerformingAction = false
  @Published var recoveryAction: String?

  private let services: WorkoutServices
  private unowned let appModeController: AppModeController

  init(services: WorkoutServices, appModeController: AppModeController) {
    self.services = services
    self.appModeController = appModeController
  }

  /// Clears all active session state to ensure UI consistency
  private func clearActiveSessionState() {
    self.activeSession = nil
    self.isActiveSessionPaused = false
    self.lapCount = 0
    self.isRecordingSegment = false
  }

  func bootstrap() async {
    await refreshAuthorization()
    await loadPresets()
    await loadHistory()
  }

  func refreshAuthorization() async {
    authorization = await services.authorizationManager.authorizationStatus()
  }

  func requestAuthorization() {
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        let status = try await self.services.authorizationManager.requestAuthorization()
        self.authorization = status
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let authError as WorkoutAuthorizationError {
        // Map specific authorization errors to appropriate user-facing messages
        let workoutError: WorkoutError = {
          switch authError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .requestFailed:
            return .authorizationRequestFailed
          }
        }()
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        // Fallback for any other authorization-related errors
        let workoutError = WorkoutError.authorizationDenied
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func startPreset(_ preset: WorkoutPreset) {
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        let configuration = WorkoutSessionConfiguration(
          kind: preset.kind,
          presetId: preset.id,
          title: preset.title,
          segments: preset.segments,
          metadata: ["source": "preset"]
        )
        let session = try await self.services.sessionTracker.startSession(configuration: configuration)
        self.activeSession = session
        self.isActiveSessionPaused = false
        self.lapCount = 0
        self.isRecordingSegment = false
        self.appModeController.select(.workout)
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionStartFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func quickStart(kind: WorkoutKind) {
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        let configuration = WorkoutSessionConfiguration(
          kind: kind,
          title: kind.displayName,
          metadata: ["source": "quick_start"]
        )
        let session = try await self.services.sessionTracker.startSession(configuration: configuration)
        self.activeSession = session
        self.isActiveSessionPaused = false
        self.lapCount = 0
        self.isRecordingSegment = false
        self.appModeController.select(.workout)
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionStartFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func endActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }

      do {
        // End the HealthKit session first
        let finished = try await self.services.sessionTracker.endSession(id: sessionID, at: Date())

        // Try to save to history - if this fails, we still want to clear the UI state
        do {
          try await self.services.historyStore.saveSession(finished)
          self.lastCompletedSession = finished
          self.clearActiveSessionState()
          self.errorMessage = nil
          self.recoveryAction = nil
        } catch let historyError {
          // History save failed but session ended successfully - clear UI state
          self.clearActiveSessionState()
          self.lastCompletedSession = nil // Don't show incomplete session
          let workoutError = WorkoutError.historyPersistenceFailed(reason: historyError.localizedDescription)
          self.errorMessage = workoutError.errorDescription
          self.recoveryAction = workoutError.recoveryAction
        }
      } catch let sessionError as WorkoutSessionError {
        // Session ending failed entirely
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch let sessionError {
        // Session ending failed entirely
        let workoutError = WorkoutError.sessionEndFailed(reason: sessionError.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  /// Ends the active session without persisting it so the user can immediately start a new workout type.
  func abandonActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        _ = try await self.services.sessionTracker.endSession(id: sessionID, at: Date())
        self.activeSession = nil
        self.isActiveSessionPaused = false
        self.lapCount = 0
        self.isRecordingSegment = false
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionEndFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func markSegment() {
    guard let sessionID = activeSession?.id else { return }
    guard !isRecordingSegment else { return }

    isRecordingSegment = true

    Task { @MainActor in
      defer { self.isRecordingSegment = false }

      let nextIndex = self.lapCount + 1
      await self.services.sessionTracker.recordEvent(
        .lap(index: nextIndex, timestamp: Date()),
        sessionId: sessionID
      )
      self.lapCount = nextIndex
      self.errorMessage = nil
    }
  }

  func reloadPresets() {
    Task { @MainActor in
      await self.loadPresets()
    }
  }

  func reloadContent() {
    Task { @MainActor in
      await self.loadPresets()
      await self.loadHistory()
    }
  }

  func pauseActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        try await self.services.sessionTracker.pauseSession(id: sessionID)
        self.isActiveSessionPaused = true
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionEndFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func resumeActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        try await self.services.sessionTracker.resumeSession(id: sessionID)
        self.isActiveSessionPaused = false
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionStartFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  private func loadPresets() async {
    do {
      presets = try await services.presetStore.loadPresets()
      if presets.isEmpty {
        presets = [WorkoutModeBootstrap.samplePreset]
        try await services.presetStore.savePreset(WorkoutModeBootstrap.samplePreset)
      }
    } catch {
      let workoutError = WorkoutError.presetLoadFailed(reason: error.localizedDescription)
      errorMessage = workoutError.errorDescription
      recoveryAction = workoutError.recoveryAction
    }
  }

  private func loadHistory() async {
    do {
      let sessions = try await services.historyStore.loadSessions(limit: 1)
      lastCompletedSession = sessions.first
    } catch {
      let workoutError = WorkoutError.historyPersistenceFailed(reason: error.localizedDescription)
      errorMessage = workoutError.errorDescription
      recoveryAction = workoutError.recoveryAction
    }
  }
}
