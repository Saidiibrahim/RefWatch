import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutRootView: View {
  private let appModeController: AppModeController
  @StateObject private var viewModel: WorkoutModeViewModel
  @State private var presentError = false
  @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
  @Environment(\.modeSwitcherBlockReason) private var modeSwitcherBlockReason
  @Environment(\.theme) private var theme

  init(services: WorkoutServices, appModeController: AppModeController) {
    self.appModeController = appModeController
    _viewModel = StateObject(wrappedValue: WorkoutModeViewModel(services: services, appModeController: appModeController))
  }

  var body: some View {
    NavigationStack {
      content
      .navigationTitle("Workout")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            modeSwitcherPresentation.wrappedValue = true
          } label: {
            Label("Back", systemImage: "chevron.backward")
              .labelStyle(.iconOnly)
          }
          .opacity(isModeSwitcherBlocked ? 0.55 : 1)
          .accessibilityIdentifier("workoutModeSwitcherButton")
        }

        if case .list = viewModel.presentationState {
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
    .onAppear {
      updateModeSwitcherBlock()
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
    .onChange(of: viewModel.presentationState) { _, _ in
      updateModeSwitcherBlock()
    }
    .onChange(of: viewModel.isPerformingAction) { _, _ in
      updateModeSwitcherBlock()
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

private extension WorkoutPresentationState {
  var isActiveSession: Bool {
    switch self {
    case .session, .starting:
      return true
    default:
      return false
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

  var isModeSwitcherBlocked: Bool {
    viewModel.presentationState.isActiveSession || viewModel.isPerformingAction
  }

  func updateModeSwitcherBlock() {
    if isModeSwitcherBlocked {
      modeSwitcherBlockReason.wrappedValue = .activeWorkout
      appModeControllerOverrideIfNeeded()
    } else if modeSwitcherBlockReason.wrappedValue == .activeWorkout {
      modeSwitcherBlockReason.wrappedValue = nil
    }
  }

  func appModeControllerOverrideIfNeeded() {
    // Keep mode in sync if the app resumes during an active workout session
    if case .session = viewModel.presentationState {
      appModeController.overrideForActiveSession(.workout)
    }
  }
}
