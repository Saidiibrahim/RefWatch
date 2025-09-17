import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutRootView: View {
  @StateObject private var viewModel: WorkoutModeViewModel
  @State private var presentError = false

  init(services: WorkoutServices, appModeController: AppModeController) {
    _viewModel = StateObject(wrappedValue: WorkoutModeViewModel(services: services, appModeController: appModeController))
  }

  var body: some View {
    NavigationStack {
      Group {
        if let session = viewModel.activeSession {
          WorkoutSessionHostView(
            session: session,
            isEnding: viewModel.isPerformingAction,
            onEnd: viewModel.endActiveSession
          )
        } else {
          WorkoutHomeView(
            authorization: viewModel.authorization,
            presets: viewModel.presets,
            lastCompleted: viewModel.lastCompletedSession,
            isBusy: viewModel.isPerformingAction,
            onRequestAccess: viewModel.requestAuthorization,
            onStartPreset: viewModel.startPreset,
            onQuickStart: viewModel.quickStart,
            onReload: viewModel.reloadPresets
          )
        }
      }
      .navigationTitle("Workout")
      .toolbar { ToolbarItem(placement: .cancellationAction) { EmptyView() } }
    }
    .task {
      await viewModel.bootstrap()
    }
    .onChange(of: viewModel.errorMessage) { message in
      presentError = message != nil
    }
    .alert("Workout Error", isPresented: $presentError) {
      Button("OK", role: .cancel) {
        presentError = false
        viewModel.errorMessage = nil
      }
    } message: {
      Text(viewModel.errorMessage ?? "An unknown error occurred.")
    }
  }
}
