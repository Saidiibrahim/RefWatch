import Combine
import Foundation
import RefWorkoutCore

@MainActor
final class WorkoutDashboardViewModel: ObservableObject {
  @Published private(set) var authorization: WorkoutAuthorizationStatus =
    .init(state: .notDetermined)
  @Published private(set) var presets: [WorkoutPreset] = []
  @Published private(set) var recentSessions: [WorkoutSession] = []
  @Published var errorMessage: String?
  @Published var isLoading = false

  private let services: WorkoutServices
  private let fallbackPreset: WorkoutPreset = .init(
    title: "Tempo Intervals",
    kind: .outdoorRun,
    segments: [
      WorkoutSegment(name: "Warmup", purpose: .warmup, plannedDuration: 600),
      WorkoutSegment(name: "Main Set", purpose: .work, plannedDuration: 1200, plannedDistance: 3000),
      WorkoutSegment(name: "Cooldown", purpose: .cooldown, plannedDuration: 420),
    ])

  init(services: WorkoutServices) {
    self.services = services
  }

  func load() {
    Task { @MainActor in
      await self.refresh()
    }
  }

  func refresh() async {
    self.isLoading = true
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadAuthorization() }
      group.addTask { await self.loadPresets() }
      group.addTask { await self.loadHistory() }
      await group.waitForAll()
    }
    self.isLoading = false
  }

  func requestAuthorization() {
    Task { @MainActor in
      do {
        let status = try await self.services.authorizationManager.requestAuthorization()
        self.authorization = status
        self.errorMessage = nil
      } catch {
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func reloadPresets() {
    Task { @MainActor in
      await self.loadPresets(force: true)
    }
  }

  private func loadAuthorization() async {
    self.authorization = await self.services.authorizationManager.authorizationStatus()
  }

  private func loadPresets(force: Bool = false) async {
    do {
      let loaded = try await services.presetStore.loadPresets()
      if loaded.isEmpty, force {
        try await self.services.presetStore.savePreset(self.fallbackPreset)
        self.presets = [self.fallbackPreset]
      } else if loaded.isEmpty {
        self.presets = [self.fallbackPreset]
      } else {
        self.presets = loaded
      }
    } catch {
      self.errorMessage = error.localizedDescription
    }
  }

  private func loadHistory(limit: Int = 5) async {
    do {
      let sessions = try await services.historyStore.loadSessions(limit: limit)
      self.recentSessions = sessions
    } catch {
      self.errorMessage = error.localizedDescription
    }
  }
}
