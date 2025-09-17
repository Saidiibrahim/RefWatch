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
    Task {
      do {
        isPerformingAction = true
        let status = try await services.authorizationManager.requestAuthorization()
        authorization = status
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isPerformingAction = false
    }
  }

  func startPreset(_ preset: WorkoutPreset) {
    Task {
      do {
        isPerformingAction = true
        let configuration = WorkoutSessionConfiguration(
          kind: preset.kind,
          presetId: preset.id,
          title: preset.title,
          segments: preset.segments,
          metadata: ["source": "preset"]
        )
        let session = try await services.sessionTracker.startSession(configuration: configuration)
        activeSession = session
        isActiveSessionPaused = false
        appModeController.select(.workout)
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isPerformingAction = false
    }
  }

  func quickStart(kind: WorkoutKind) {
    Task {
      do {
        isPerformingAction = true
        let configuration = WorkoutSessionConfiguration(
          kind: kind,
          title: kind.displayName,
          metadata: ["source": "quick_start"]
        )
        let session = try await services.sessionTracker.startSession(configuration: configuration)
        activeSession = session
        isActiveSessionPaused = false
        appModeController.select(.workout)
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isPerformingAction = false
    }
  }

  func endActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task {
      do {
        isPerformingAction = true
        let finished = try await services.sessionTracker.endSession(id: sessionID, at: Date())
        try await services.historyStore.saveSession(finished)
        lastCompletedSession = finished
        activeSession = nil
        isActiveSessionPaused = false
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isPerformingAction = false
    }
  }

  func reloadPresets() {
    Task {
      await loadPresets()
    }
  }

  func reloadContent() {
    Task {
      await loadPresets()
      await loadHistory()
    }
  }

  func pauseActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task {
      do {
        isPerformingAction = true
        try await services.sessionTracker.pauseSession(id: sessionID)
        isActiveSessionPaused = true
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isPerformingAction = false
    }
  }

  func resumeActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task {
      do {
        isPerformingAction = true
        try await services.sessionTracker.resumeSession(id: sessionID)
        isActiveSessionPaused = false
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isPerformingAction = false
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
