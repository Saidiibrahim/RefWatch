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
      content
      .navigationTitle("Workout")
      .toolbar {
        if case .list = viewModel.presentationState {
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
    .onChange(of: viewModel.errorMessage) { _, message in
      let isSelectionError: Bool
      if case .error = viewModel.presentationState {
        isSelectionError = true
      } else {
        isSelectionError = false
      }
      presentError = message != nil && !isSelectionError
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

private extension WorkoutRootView {
  @ViewBuilder
  var content: some View {
    switch viewModel.presentationState {
    case .list:
      WorkoutHomeView(
        items: viewModel.selectionItems,
        focusedSelectionID: viewModel.focusedSelectionID,
        dwellState: viewModel.dwellState,
        dwellConfiguration: viewModel.selectionDwellConfiguration,
        isBusy: viewModel.isPerformingAction,
        onFocusChange: viewModel.updateFocusedSelection,
        onSelect: viewModel.requestPreview,
        onRequestAccess: viewModel.requestAuthorization,
        onReloadPresets: viewModel.reloadPresets
      )

    case .preview(let item):
      WorkoutSessionPreviewView(
        item: item,
        isStarting: false,
        error: nil,
        onStart: { viewModel.startSelection(for: item) },
        onRetry: { viewModel.startSelection(for: item) },
        onReturnToList: viewModel.returnToList
      )

    case .starting(let item):
      WorkoutSessionPreviewView(
        item: item,
        isStarting: true,
        error: nil,
        onStart: {},
        onRetry: { viewModel.startSelection(for: item) },
        onReturnToList: viewModel.returnToList
      )

    case .error(let item, let error):
      WorkoutSessionPreviewView(
        item: item,
        isStarting: false,
        error: error,
        onStart: { viewModel.startSelection(for: item) },
        onRetry: { viewModel.startSelection(for: item) },
        onReturnToList: viewModel.returnToList
      )

    case .session(let session):
      WorkoutSessionHostView(
        session: viewModel.activeSession ?? session,
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
      .workoutCrownReturnGesture(onReturn: viewModel.returnToList)
    }
  }
}
