import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct AppRootView: View {
  @EnvironmentObject private var appModeController: AppModeController
  @EnvironmentObject private var aggregateEnvironment: AggregateSyncEnvironment
  @Environment(\.workoutServices) private var workoutServices
  @State private var workoutViewID = UUID()
  @State private var showModeSwitcher = false
  @State private var didPresentInitialSwitcher = false
  @State private var modeSwitcherBlockReason: ModeSwitcherBlockReason?
  @State private var blockHintMessage: String?
  @State private var showBlockHint = false
  @State private var confirmationMode: AppMode?
  @State private var showConfirmation = false

  private let haptics = WatchHaptics()

  var body: some View {
    Group {
      switch appModeController.currentMode {
      case .match:
        MatchRootView(connectivity: aggregateEnvironment.connectivity)
      case .workout:
        WorkoutRootView(
          services: workoutServices,
          appModeController: appModeController
        )
        .id(workoutViewID)
      }
    }
    .environment(\.modeSwitcherPresentation, guardedModeSwitcherBinding)
    .environment(\.modeSwitcherBlockReason, $modeSwitcherBlockReason)
    .onChange(of: appModeController.currentMode) { _, mode in
      if mode == .workout {
        workoutViewID = UUID()
      }
    }
    .onAppear(perform: presentSwitcherIfNeeded)
    .fullScreenCover(isPresented: $showModeSwitcher) {
      ModeSwitcherView(
        currentMode: appModeController.currentMode,
        lastSelectedMode: appModeController.hasPersistedSelection ? appModeController.currentMode : nil,
        activeMode: modeSwitcherBlockReason?.activeMode,
        allowDismiss: appModeController.hasPersistedSelection,
        onSelect: { mode in
          appModeController.select(mode)
          if mode == .workout {
            workoutViewID = UUID()
          }
          showModeSwitcher = false
          confirmationMode = mode
          withAnimation(.easeOut) { showConfirmation = true }
          haptics.play(.tap)
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn) { showConfirmation = false }
          }
        },
        onDismiss: {
          // If the user hasn't picked a mode yet, keep prompting until they do
          showModeSwitcher = appModeController.hasPersistedSelection ? false : true
        }
      )
      .environmentObject(appModeController)
    }
    .alert(blockHintMessage ?? "", isPresented: $showBlockHint) {
      Button("OK", role: .cancel) {
        showBlockHint = false
        blockHintMessage = nil
      }
    }
    .overlay(alignment: .top) {
      if showConfirmation, let confirmationMode {
        ModeSwitchConfirmationToast(mode: confirmationMode)
          .transition(.move(edge: .top).combined(with: .opacity))
          .padding(.top, 6)
      }
    }
  }
}

private extension AppRootView {
  var guardedModeSwitcherBinding: Binding<Bool> {
    Binding {
      showModeSwitcher
    } set: { shouldShow in
      guard shouldShow else {
        showModeSwitcher = false
        return
      }

      if let reason = modeSwitcherBlockReason {
        blockHintMessage = reason.message
        showBlockHint = true
        return
      }

      showModeSwitcher = true
    }
  }

  func presentSwitcherIfNeeded() {
    guard !didPresentInitialSwitcher else { return }
    didPresentInitialSwitcher = true

    if !appModeController.hasPersistedSelection {
      showModeSwitcher = true
    }
  }
}

private struct ModeSwitchConfirmationToast: View {
  let mode: AppMode

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
      Text("Switched to \(mode.displayName)")
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
  let container = try! WatchAggregateContainerFactory.makeContainer(inMemory: true)
  let library = WatchAggregateLibraryStore(container: container)
  let chunk = WatchAggregateSnapshotChunkStore(container: container)
  let delta = WatchAggregateDeltaOutboxStore(container: container)
  let coordinator = WatchAggregateSyncCoordinator(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta
  )
  let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)
  return AggregateSyncEnvironment(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta,
    coordinator: coordinator,
    connectivity: connectivity
  )
}
