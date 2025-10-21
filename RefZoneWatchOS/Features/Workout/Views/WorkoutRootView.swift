import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutRootView: View {
  @StateObject private var viewModel: WorkoutModeViewModel
  @State private var presentError = false
  @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
  @Environment(\.theme) private var theme

  init(services: WorkoutServices, appModeController: AppModeController) {
    _viewModel = StateObject(wrappedValue: WorkoutModeViewModel(services: services, appModeController: appModeController))
  }

  var body: some View {
    NavigationStack {
      Group {
        if let session = viewModel.activeSession {
          WorkoutSessionHostView(
            session: session,
            liveMetrics: viewModel.liveMetrics,
            isPaused: viewModel.isActiveSessionPaused,
            isEnding: viewModel.isPerformingAction,
            isRecordingSegment: viewModel.isRecordingSegment,
            lapCount: viewModel.lapCount,
            onPause: viewModel.pauseActiveSession,
            onResume: viewModel.resumeActiveSession,
            onEnd: viewModel.endActiveSession,
            onMarkSegment: viewModel.markSegment,
            onRequestNewSession: viewModel.abandonActiveSession
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
        if viewModel.activeSession == nil {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              modeSwitcherPresentation.wrappedValue = true
            } label: {
              Label("Back", systemImage: "chevron.backward")
                .labelStyle(.iconOnly)
            }
            .disabled(viewModel.isPerformingAction)
          }

          ToolbarItem(placement: .primaryAction) {
            Button {
              viewModel.reloadContent()
            } label: {
              Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                .labelStyle(.iconOnly)
            }
            .disabled(viewModel.isPerformingAction)
          }
        }
      }
    }
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
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
