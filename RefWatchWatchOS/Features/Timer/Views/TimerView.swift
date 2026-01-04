// TimerView.swift
// Description: Main match timing screen with swipeable layout for team events

import RefWatchCore
import SwiftUI
import WatchKit

struct TimerView: View {
  let model: MatchViewModel
  let lifecycle: MatchLifecycleCoordinator
  @State private var showingActionSheet = false
  @State private var pendingRouteToChooseFirstKicker = false
  @State private var livePublisher = LiveActivityStatePublisher(reloadKind: "RefWatchWidgets")
  @State private var confirmationDismissTask: Task<Void, Never>?
  private let commandHandler = LiveActivityCommandHandler()
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout
  // Persist selected timer face
  @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
  private var faceStyle: TimerFaceStyle { TimerFaceStyle.parse(raw: self.timerFaceStyleRaw) }

  private var periodLabel: String { PeriodLabelFormatter.label(for: self.model) }

  var body: some View {
    mainLayout
      .overlay { confirmationOverlay }
      .animation(.easeInOut(duration: 0.2), value: self.model.pendingConfirmation?.id)
      .erasedToAnyView()
      .onAppear {
        publishLiveActivityState()
        processPendingWidgetCommand()
      }
      .onLongPressGesture(minimumDuration: 0.8) {
        // Allow long press when match is running or during half-time
        if self.model.isMatchInProgress || self.model.isHalfTime {
          WKInterfaceDevice.current().play(.notification)
          self.showingActionSheet = true
        }
      }
      .sheet(
        isPresented: self.$showingActionSheet,
        onDismiss: {
          #if DEBUG
          print(
            "DEBUG: TimerView.sheet onDismiss showingActionSheet=false, " +
              "pendingRouteToChooseFirstKicker=\(self.pendingRouteToChooseFirstKicker), " +
              "waitingForPenaltiesStart=\(self.model.waitingForPenaltiesStart)")
          #endif
          // Modal presentation race prevention for watchOS:
          // When penalties should start while the actions sheet is visible, defer
          // navigation until after the sheet dismisses to avoid PUICAlertSheetController
          // overlap and the "already presenting" crash on watchOS.
          // We set `pendingRouteToChooseFirstKicker` while the sheet is open; on
          // dismissal we clear the flag and route exactly once.
          if self.pendingRouteToChooseFirstKicker || self.model.waitingForPenaltiesStart {
            self.pendingRouteToChooseFirstKicker = false
            self.lifecycle.goToChoosePenaltyFirstKicker()
          }
        },
        content: {
          MatchActionsSheet(matchViewModel: self.model, lifecycle: self.lifecycle)
        })
      // Lifecycle routing hooks
      .onChange(of: self.model.isFullTime) { _, isFT in
        #if DEBUG
        print(
          "DEBUG: TimerView.onChange isFullTime=\(isFT) state=\(self.lifecycle.state) " +
            "matchCompleted=\(self.model.matchCompleted)")
        #endif
        // Guard against re-entering finished after finalize/reset
        if isFT, !self.model.matchCompleted, self.lifecycle.state != .idle {
          self.lifecycle.goToFinished()
        }
        // Publish end state when full time
        if isFT { self.livePublisher.end() }
      }
      .onChange(of: self.model.waitingForSecondHalfStart) { _, waiting in
        if waiting { self.lifecycle.goToKickoffSecond() }
        publishLiveActivityState()
      }
      .onChange(of: self.model.waitingForET1Start) { _, waiting in
        if waiting { self.lifecycle.goToKickoffETFirst() }
        publishLiveActivityState()
      }
      .onChange(of: self.model.waitingForET2Start) { _, waiting in
        if waiting { self.lifecycle.goToKickoffETSecond() }
        publishLiveActivityState()
      }
      .onChange(of: self.model.waitingForPenaltiesStart) { _, waiting in
        #if DEBUG
        print("DEBUG: TimerView.onChange waitingForPenaltiesStart=\(waiting) sheetShown=\(self.showingActionSheet)")
        #endif
        if waiting {
          if self.showingActionSheet {
            self.pendingRouteToChooseFirstKicker = true
          } else {
            self.lifecycle.goToChoosePenaltyFirstKicker()
          }
        }
        publishLiveActivityState()
      }
      // Publishing hooks for key transitions
      .onChange(of: self.model.isMatchInProgress) { _, _ in publishLiveActivityState() }
      .onChange(of: self.model.isPaused) { _, _ in publishLiveActivityState() }
      .onChange(of: self.model.isHalfTime) { _, _ in publishLiveActivityState() }
      .onChange(of: self.model.isInStoppage) { _, _ in publishLiveActivityState() }
      .onChange(of: self.model.currentPeriod) { _, _ in publishLiveActivityState() }
      .onChange(of: self.model.penaltyShootoutActive) { _, _ in publishLiveActivityState() }
      .onChange(of: self.model.currentMatch?.homeScore ?? 0) { _, _ in publishLiveActivityState() }
      .onChange(of: self.model.currentMatch?.awayScore ?? 0) { _, _ in publishLiveActivityState() }
      .onChange(of: self.scenePhase) { _, newPhase in
        if newPhase == .active {
          processPendingWidgetCommand()
        }
      }
      .onChange(of: self.model.pendingConfirmation?.id) { _, newValue in
        self.confirmationDismissTask?.cancel()
        guard let id = newValue else { return }
        self.confirmationDismissTask = Task { [model] in
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          guard !Task.isCancelled else { return }
          await MainActor.run {
            model.clearPendingConfirmation(id: id)
          }
        }
      }
      .onDisappear {
        self.confirmationDismissTask?.cancel()
      }
  }

  // MARK: - Faces are rendered above; no state-specific views here.
}

// MARK: - LiveActivity Publishing

extension TimerView {
  private var mainLayout: some View {
    let verticalSpacing = self.layout.category == .compact ? self.theme.spacing.s : self.theme.spacing.m

    return VStack(spacing: verticalSpacing) {
      self.periodIndicator
      self.scoreDisplay
      self.timerFace
    }
    .accessibilityIdentifier("timerArea")
    .padding(.top, self.layout.timerTopPadding)
    .padding(.bottom, self.layout.timerBottomPadding + self.layout.safeAreaBottomPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private var periodIndicator: some View {
    HStack {
      Text(self.periodLabel)
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Spacer()
    }
    .padding(.horizontal, self.theme.components.cardHorizontalPadding)
  }

  private var scoreDisplay: some View {
    ScoreDisplayView(
      homeTeam: self.model.homeTeamDisplayName,
      awayTeam: self.model.awayTeamDisplayName,
      homeScore: self.model.currentMatch?.homeScore ?? 0,
      awayScore: self.model.currentMatch?.awayScore ?? 0)
  }

  private var timerFace: some View {
    TimerFaceFactory.view(for: self.faceStyle, model: self.model)
      .hapticsProvider(WatchHaptics())
  }

  @ViewBuilder
  private var confirmationOverlay: some View {
    if let confirmation = model.pendingConfirmation {
      EventConfirmationView(confirmation: confirmation, matchViewModel: self.model)
        .transition(.opacity)
    }
  }

  private func publishLiveActivityState() {
    self.livePublisher.publish(for: self.model)
  }

  private func processPendingWidgetCommand() {
    guard self.commandHandler.processPendingCommand(model: self.model) != nil else { return }
    self.publishLiveActivityState()
  }
}

// MARK: - Supporting Views

extension View {
  fileprivate func erasedToAnyView() -> AnyView {
    AnyView(self)
  }
}

#Preview {
  TimerView(model: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
    .watchLayoutScale(WatchLayoutScale(category: .compact))
}

#Preview("Timer – Ultra") {
  TimerView(model: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
    .watchLayoutScale(WatchLayoutScale(category: .expanded))
}
