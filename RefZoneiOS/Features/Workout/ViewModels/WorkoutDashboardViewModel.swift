import Foundation
import RefWorkoutCore

@MainActor
final class WorkoutDashboardViewModel: ObservableObject {
  @Published private(set) var authorization: WorkoutAuthorizationStatus = WorkoutAuthorizationStatus(state: .notDetermined)
  @Published private(set) var presets: [WorkoutPreset] = []
  @Published private(set) var recentSessions: [WorkoutSession] = []
  @Published var errorMessage: String?
  @Published var isLoading = false

  private let services: WorkoutServices
  private let fallbackPreset: WorkoutPreset = WorkoutPreset(
    title: "Tempo Intervals",
    kind: .outdoorRun,
    segments: [
      WorkoutSegment(name: "Warmup", purpose: .warmup, plannedDuration: 600),
      WorkoutSegment(name: "Main Set", purpose: .work, plannedDuration: 1200, plannedDistance: 3000),
      WorkoutSegment(name: "Cooldown", purpose: .cooldown, plannedDuration: 420)
    ]
  )

  init(services: WorkoutServices) {
    self.services = services
  }

  func load() {
    Task { await refresh() }
  }

  func refresh() async {
    isLoading = true
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadAuthorization() }
      group.addTask { await self.loadPresets() }
      group.addTask { await self.loadHistory() }
      await group.waitForAll()
    }
    isLoading = false
  }

  func requestAuthorization() {
    Task {
      do {
        let status = try await services.authorizationManager.requestAuthorization()
        authorization = status
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func reloadPresets() {
    Task { await loadPresets(force: true) }
  }

  private func loadAuthorization() async {
    authorization = await services.authorizationManager.authorizationStatus()
  }

  private func loadPresets(force: Bool = false) async {
    do {
      let loaded = try await services.presetStore.loadPresets()
      if loaded.isEmpty && force {
        try await services.presetStore.savePreset(fallbackPreset)
        presets = [fallbackPreset]
      } else if loaded.isEmpty {
        presets = [fallbackPreset]
      } else {
        presets = loaded
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadHistory(limit: Int = 5) async {
    do {
      let sessions = try await services.historyStore.loadSessions(limit: limit)
      recentSessions = sessions
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
