import RefWatchCore
import RefWorkoutCore
import SwiftUI

struct AppRootView: View {
  @EnvironmentObject private var appModeController: AppModeController
  @EnvironmentObject private var aggregateEnvironment: AggregateSyncEnvironment
  @Environment(\.workoutServices) private var workoutServices
  @State private var workoutViewID = UUID()
  @State private var showModeSwitcher = false
  @State private var modeSwitcherBlockReason: ModeSwitcherBlockReason?
  @State private var blockHintMessage: String?
  @State private var showBlockHint = false
  @State private var confirmationMode: AppMode?
  @State private var showConfirmation = false

  private let haptics = WatchHaptics()

  var body: some View {
    ZStack {
      if self.appModeController.hasPersistedSelection {
        modeHostView
      } else {
        initialModeSelectionView
      }
    }
    .fullScreenCover(isPresented: self.$showModeSwitcher) {
      modeSwitcherSheet
    }
    .alert(self.blockHintMessage ?? "", isPresented: self.$showBlockHint) {
      Button("OK", role: .cancel) {
        self.showBlockHint = false
        self.blockHintMessage = nil
      }
    }
    .overlay(alignment: .top) {
      if self.showConfirmation, let confirmationMode {
        ModeSwitchConfirmationToast(mode: confirmationMode)
          .transition(.move(edge: .top).combined(with: .opacity))
          .padding(.top, 6)
      }
    }
  }
}

extension AppRootView {
  @ViewBuilder
  private var modeHostView: some View {
    Group {
      switch self.appModeController.currentMode {
      case .match:
        MatchRootView(connectivity: self.aggregateEnvironment.connectivity)
      case .workout:
        WorkoutRootView(
          services: self.workoutServices,
          appModeController: self.appModeController)
          .id(self.workoutViewID)
      }
    }
    .environment(\.modeSwitcherPresentation, self.guardedModeSwitcherBinding)
    .environment(\.modeSwitcherBlockReason, self.$modeSwitcherBlockReason)
    .onChange(of: self.appModeController.currentMode) { _, mode in
      if mode == .workout {
        self.workoutViewID = UUID()
      }
    }
  }

  private var initialModeSelectionView: some View {
    ModeSwitcherView(
      currentMode: self.appModeController.currentMode,
      lastSelectedMode: nil,
      activeMode: self.modeSwitcherBlockReason?.activeMode,
      allowDismiss: false,
      onSelect: self.handleModeSelection,
      onDismiss: {})
      .environmentObject(self.appModeController)
  }

  private var modeSwitcherSheet: some View {
    ModeSwitcherView(
      currentMode: self.appModeController.currentMode,
      lastSelectedMode: self.appModeController.hasPersistedSelection ? self.appModeController.currentMode : nil,
      activeMode: self.modeSwitcherBlockReason?.activeMode,
      allowDismiss: self.appModeController.hasPersistedSelection,
      onSelect: self.handleModeSelection,
      onDismiss: {
        // If the user hasn't picked a mode yet, keep prompting until they do
        self.showModeSwitcher = self.appModeController.hasPersistedSelection ? false : true
      })
      .environmentObject(self.appModeController)
  }

  private var guardedModeSwitcherBinding: Binding<Bool> {
    Binding {
      self.showModeSwitcher
    } set: { shouldShow in
      guard shouldShow else {
        self.showModeSwitcher = false
        return
      }

      if let reason = modeSwitcherBlockReason {
        self.blockHintMessage = reason.message
        self.showBlockHint = true
        return
      }

      self.showModeSwitcher = true
    }
  }

  private func handleModeSelection(_ mode: AppMode) {
    self.appModeController.select(mode)
    if mode == .workout {
      self.workoutViewID = UUID()
    }
    self.showModeSwitcher = false
    self.confirmationMode = mode
    withAnimation(.easeOut) { self.showConfirmation = true }
    self.haptics.play(.tap)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
      withAnimation(.easeIn) { self.showConfirmation = false }
    }
  }
}

private struct ModeSwitchConfirmationToast: View {
  let mode: AppMode

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
      Text("Switched to \(self.mode.displayName)")
        .font(.footnote)
        .lineLimit(1)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.ultraThinMaterial, in: Capsule())
    .accessibilityIdentifier("modeSwitchConfirmation")
  }
}

#Preview("Match Mode") {
  let controller = AppModeController()
  controller.select(.match, persist: false)
  let environment = makePreviewAggregateEnvironment()

  return AppRootView()
    .environmentObject(controller)
    .environmentObject(environment)
    .workoutServices(.inMemoryStub())
}

#Preview("Workout Mode") {
  let controller = AppModeController()
  controller.select(.workout, persist: false)
  let environment = makePreviewAggregateEnvironment()

  return AppRootView()
    .environmentObject(controller)
    .environmentObject(environment)
    .workoutServices(.inMemoryStub())
}

#Preview("No Selection (Shows Switcher)") {
  let controller = AppModeController()
  // Don't set a selection to trigger the switcher
  let environment = makePreviewAggregateEnvironment()

  return AppRootView()
    .environmentObject(controller)
    .environmentObject(environment)
    .workoutServices(.inMemoryStub())
}

@MainActor
private func makePreviewAggregateEnvironment() -> AggregateSyncEnvironment {
  guard let container = try? WatchAggregateContainerFactory.makeContainer(inMemory: true) else {
    fatalError("Failed to create preview aggregate container")
  }
  let library = WatchAggregateLibraryStore(container: container)
  let chunk = WatchAggregateSnapshotChunkStore(container: container)
  let delta = WatchAggregateDeltaOutboxStore(container: container)
  let coordinator = WatchAggregateSyncCoordinator(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta)
  let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)
  return AggregateSyncEnvironment(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta,
    coordinator: coordinator,
    connectivity: connectivity)
}
