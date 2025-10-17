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
    .environment(\.modeSwitcherPresentation, $showModeSwitcher)
    .onChange(of: appModeController.currentMode) { mode in
      if mode == .workout {
        workoutViewID = UUID()
      }
    }
    .onAppear(perform: presentSwitcherIfNeeded)
    .fullScreenCover(isPresented: $showModeSwitcher) {
      ModeSwitcherView(
        lastSelectedMode: appModeController.hasPersistedSelection ? appModeController.currentMode : nil,
        allowDismiss: appModeController.hasPersistedSelection,
        onSelect: { mode in
          appModeController.select(mode)
          if mode == .workout {
            workoutViewID = UUID()
          }
          showModeSwitcher = false
        },
        onDismiss: {
          showModeSwitcher = false
        }
      )
      .environmentObject(appModeController)
    }
  }
}

private extension AppRootView {
  func presentSwitcherIfNeeded() {
    guard !didPresentInitialSwitcher else { return }
    didPresentInitialSwitcher = true

    if !appModeController.hasPersistedSelection {
      showModeSwitcher = true
    }
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
