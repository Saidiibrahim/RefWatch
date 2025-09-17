import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutRootView: View {
  @StateObject private var viewModel: WorkoutModeViewModel
  @State private var presentError = false
  @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation

  init(services: WorkoutServices, appModeController: AppModeController) {
    _viewModel = StateObject(wrappedValue: WorkoutModeViewModel(services: services, appModeController: appModeController))
  }

  var body: some View {
    NavigationStack {
      Group {
        if let session = viewModel.activeSession {
          WorkoutSessionHostView(
            session: session,
            isPaused: viewModel.isActiveSessionPaused,
            isEnding: viewModel.isPerformingAction,
            onPause: viewModel.pauseActiveSession,
            onResume: viewModel.resumeActiveSession,
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
            onReload: viewModel.reloadContent
          )
        }
      }
      .navigationTitle("Workout")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if viewModel.activeSession == nil {
            Button {
              modeSwitcherPresentation.wrappedValue = true
            } label: {
              Label("Switch", systemImage: "arrow.triangle.2.circlepath")
                .labelStyle(.iconOnly)
            }
            .disabled(viewModel.isPerformingAction)
          }
        }
      }
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
