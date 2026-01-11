import RefWatchCore
import RefWorkoutCore
import SwiftUI

struct WorkoutRootView: View {
  private let appModeController: AppModeController
  @StateObject private var viewModel: WorkoutModeViewModel
  @State private var presentError = false
  @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
  @Environment(\.modeSwitcherBlockReason) private var modeSwitcherBlockReason
  @Environment(\.theme) private var theme

  init(services: WorkoutServices, appModeController: AppModeController) {
    self.appModeController = appModeController
    _viewModel = StateObject(
      wrappedValue: WorkoutModeViewModel(
        services: services,
        appModeController: appModeController))
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Workout")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              self.modeSwitcherPresentation.wrappedValue = true
            } label: {
              Label("Back", systemImage: "chevron.backward")
                .labelStyle(.iconOnly)
            }
            .opacity(isModeSwitcherBlocked ? 0.55 : 1)
            .accessibilityIdentifier("workoutModeSwitcherButton")
          }

          if case .list = self.viewModel.presentationState {
            ToolbarItem(placement: .primaryAction) {
              Button {
                self.viewModel.reloadContent()
              } label: {
                Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                  .labelStyle(.iconOnly)
              }
              .disabled(self.viewModel.isPerformingAction)
            }
          }
        }
    }
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .task {
      await self.viewModel.bootstrap()
    }
    .onAppear {
      updateModeSwitcherBlock()
    }
    .onChange(of: self.viewModel.errorMessage) { _, message in
      let isSelectionError = if case .error = self.viewModel.presentationState {
        true
      } else {
        false
      }
      self.presentError = message != nil && !isSelectionError
    }
    .onChange(of: self.viewModel.presentationState) { _, _ in
      updateModeSwitcherBlock()
    }
    .onChange(of: self.viewModel.isPerformingAction) { _, _ in
      updateModeSwitcherBlock()
    }
    .alert("Workout Error", isPresented: self.$presentError) {
      Button("OK", role: .cancel) {
        self.presentError = false
        self.viewModel.errorMessage = nil
      }
    } message: {
      Text(self.viewModel.errorMessage ?? "An unknown error occurred.")
    }
  }
}

extension WorkoutPresentationState {
  fileprivate var isActiveSession: Bool {
    switch self {
    case .session, .starting:
      true
    default:
      false
    }
  }
}

extension WorkoutRootView {
  @ViewBuilder
  private var content: some View {
    switch self.viewModel.presentationState {
    case .list:
      WorkoutHomeView(
        items: self.viewModel.selectionItems,
        focusedSelectionID: self.viewModel.focusedSelectionID,
        dwellState: self.viewModel.dwellState,
        dwellConfiguration: self.viewModel.selectionDwellConfiguration,
        isBusy: self.viewModel.isPerformingAction,
        onFocusChange: self.viewModel.updateFocusedSelection,
        onSelect: self.viewModel.requestPreview,
        onRequestAccess: self.viewModel.requestAuthorization,
        onReloadPresets: self.viewModel.reloadPresets)

    case let .preview(item):
      WorkoutSessionPreviewView(
        item: item,
        isStarting: false,
        error: nil,
        onStart: { self.viewModel.startSelection(for: item) },
        onRetry: { self.viewModel.startSelection(for: item) },
        onReturnToList: self.viewModel.returnToList)

    case let .starting(item):
      WorkoutSessionPreviewView(
        item: item,
        isStarting: true,
        error: nil,
        onStart: {},
        onRetry: { self.viewModel.startSelection(for: item) },
        onReturnToList: self.viewModel.returnToList)

    case let .error(item, error):
      WorkoutSessionPreviewView(
        item: item,
        isStarting: false,
        error: error,
        onStart: { self.viewModel.startSelection(for: item) },
        onRetry: { self.viewModel.startSelection(for: item) },
        onReturnToList: self.viewModel.returnToList)

    case let .session(session):
      WorkoutSessionHostView(
        session: self.viewModel.activeSession ?? session,
        liveMetrics: self.viewModel.liveMetrics,
        isPaused: self.viewModel.isActiveSessionPaused,
        isEnding: self.viewModel.isPerformingAction,
        isRecordingSegment: self.viewModel.isRecordingSegment,
        lapCount: self.viewModel.lapCount,
        onPause: self.viewModel.pauseActiveSession,
        onResume: self.viewModel.resumeActiveSession,
        onEnd: self.viewModel.endActiveSession,
        onMarkSegment: self.viewModel.markSegment,
        onRequestNewSession: self.viewModel.abandonActiveSession)
        .workoutCrownReturnGesture(onReturn: self.viewModel.returnToList)
    }
  }

  private var isModeSwitcherBlocked: Bool {
    self.viewModel.presentationState.isActiveSession || self.viewModel.isPerformingAction
  }

  private func updateModeSwitcherBlock() {
    if self.isModeSwitcherBlocked {
      self.modeSwitcherBlockReason.wrappedValue = .activeWorkout
      self.appModeControllerOverrideIfNeeded()
    } else if self.modeSwitcherBlockReason.wrappedValue == .activeWorkout {
      self.modeSwitcherBlockReason.wrappedValue = nil
    }
  }

  private func appModeControllerOverrideIfNeeded() {
    // Keep mode in sync if the app resumes during an active workout session
    if case .session = self.viewModel.presentationState {
      self.appModeController.overrideForActiveSession(.workout)
    }
  }
}
