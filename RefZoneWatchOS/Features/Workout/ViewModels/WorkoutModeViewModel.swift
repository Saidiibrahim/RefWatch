import Foundation
import RefWatchCore
import RefWorkoutCore

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

  private let services: WorkoutServices
  private unowned let appModeController: AppModeController

  init(services: WorkoutServices, appModeController: AppModeController) {
    self.services = services
    self.appModeController = appModeController
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
      } catch {
        self.errorMessage = error.localizedDescription
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
      } catch {
        self.errorMessage = error.localizedDescription
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
      } catch {
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func endActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        let finished = try await self.services.sessionTracker.endSession(id: sessionID, at: Date())
        try await self.services.historyStore.saveSession(finished)
        self.lastCompletedSession = finished
        self.activeSession = nil
        self.isActiveSessionPaused = false
        self.lapCount = 0
        self.isRecordingSegment = false
        self.errorMessage = nil
      } catch {
        self.errorMessage = error.localizedDescription
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
      } catch {
        self.errorMessage = error.localizedDescription
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
      } catch {
        self.errorMessage = error.localizedDescription
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
      } catch {
        self.errorMessage = error.localizedDescription
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
      errorMessage = error.localizedDescription
    }
  }

  private func loadHistory() async {
    do {
      let sessions = try await services.historyStore.loadSessions(limit: 1)
      lastCompletedSession = sessions.first
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
