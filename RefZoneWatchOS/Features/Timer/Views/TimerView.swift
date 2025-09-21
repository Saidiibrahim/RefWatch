// TimerView.swift
// Description: Main match timing screen with swipeable layout for team events

import SwiftUI
import WatchKit
import RefWatchCore

struct TimerView: View {
    let model: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var showingActionSheet = false
    @State private var pendingRouteToChooseFirstKicker = false
    @State private var livePublisher = LiveActivityStatePublisher(reloadKind: "RefZoneWidgets")
    private let commandHandler = LiveActivityCommandHandler()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme
    // Persist selected timer face
    @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
    private var faceStyle: TimerFaceStyle { TimerFaceStyle.parse(raw: timerFaceStyleRaw) }
    
    private var periodLabel: String { PeriodLabelFormatter.label(for: model) }
    
    var body: some View {
        VStack(spacing: theme.spacing.m) {
            // Period indicator
            HStack {
                Text(periodLabel)
                    .font(theme.typography.cardMeta)
                    .foregroundStyle(theme.colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)

            // Score display
            ScoreDisplayView(
                homeTeam: model.homeTeam,
                awayTeam: model.awayTeam,
                homeScore: model.currentMatch?.homeScore ?? 0,
                awayScore: model.currentMatch?.awayScore ?? 0
            )

            // Main content: render selected timer face
            TimerFaceFactory.view(for: faceStyle, model: model)
                .hapticsProvider(WatchHaptics())
        }
        .accessibilityIdentifier("timerArea")
        .padding(.top, theme.spacing.l)
        .padding(.bottom, theme.spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            publishLiveActivityState()
            processPendingWidgetCommand()
        }
        .onLongPressGesture(minimumDuration: 0.8) {
            // Allow long press when match is running or during half-time
            if model.isMatchInProgress || model.isHalfTime {
                WKInterfaceDevice.current().play(.notification)
                showingActionSheet = true
            }
        }
        .sheet(isPresented: $showingActionSheet, onDismiss: {
            #if DEBUG
            print("DEBUG: TimerView.sheet onDismiss showingActionSheet=false, pendingRouteToChooseFirstKicker=\(pendingRouteToChooseFirstKicker), waitingForPenaltiesStart=\(model.waitingForPenaltiesStart)")
            #endif
            // Modal presentation race prevention for watchOS:
            // When penalties should start while the actions sheet is visible, defer
            // navigation until after the sheet dismisses to avoid PUICAlertSheetController
            // overlap and the "already presenting" crash on watchOS.
            // We set `pendingRouteToChooseFirstKicker` while the sheet is open; on
            // dismissal we clear the flag and route exactly once.
            if pendingRouteToChooseFirstKicker || model.waitingForPenaltiesStart {
                pendingRouteToChooseFirstKicker = false
                lifecycle.goToChoosePenaltyFirstKicker()
            }
        }) {
            MatchActionsSheet(matchViewModel: model, lifecycle: lifecycle)
        }
        // Lifecycle routing hooks
        .onChange(of: model.isFullTime) { isFT in
            #if DEBUG
            print("DEBUG: TimerView.onChange isFullTime=\(isFT) state=\(lifecycle.state) matchCompleted=\(model.matchCompleted)")
            #endif
            // Guard against re-entering finished after finalize/reset
            if isFT && !model.matchCompleted && lifecycle.state != .idle {
                lifecycle.goToFinished()
            }
            // Publish end state when full time
            if isFT { livePublisher.end() }
        }
        .onChange(of: model.waitingForSecondHalfStart) { waiting in
            if waiting { lifecycle.goToKickoffSecond() }
            publishLiveActivityState()
        }
        .onChange(of: model.waitingForET1Start) { waiting in
            if waiting { lifecycle.goToKickoffETFirst() }
            publishLiveActivityState()
        }
        .onChange(of: model.waitingForET2Start) { waiting in
            if waiting { lifecycle.goToKickoffETSecond() }
            publishLiveActivityState()
        }
        .onChange(of: model.waitingForPenaltiesStart) { waiting in
            #if DEBUG
            print("DEBUG: TimerView.onChange waitingForPenaltiesStart=\(waiting) sheetShown=\(showingActionSheet)")
            #endif
            if waiting {
                if showingActionSheet {
                    pendingRouteToChooseFirstKicker = true
                } else {
                    lifecycle.goToChoosePenaltyFirstKicker()
                }
            }
            publishLiveActivityState()
        }
        // Publishing hooks for key transitions
        .onChange(of: model.isMatchInProgress) { _ in publishLiveActivityState() }
        .onChange(of: model.isPaused) { _ in publishLiveActivityState() }
        .onChange(of: model.isHalfTime) { _ in publishLiveActivityState() }
        .onChange(of: model.isInStoppage) { _ in publishLiveActivityState() }
        .onChange(of: model.currentPeriod) { _ in publishLiveActivityState() }
        .onChange(of: model.penaltyShootoutActive) { _ in publishLiveActivityState() }
        .onChange(of: model.currentMatch?.homeScore ?? 0) { _ in publishLiveActivityState() }
        .onChange(of: model.currentMatch?.awayScore ?? 0) { _ in publishLiveActivityState() }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                processPendingWidgetCommand()
            }
        }
    }
    
    // MARK: - Faces are rendered above; no state-specific views here.
}

// MARK: - LiveActivity Publishing

private extension TimerView {
    func publishLiveActivityState() {
        livePublisher.publish(for: model)
    }

    func processPendingWidgetCommand() {
        guard commandHandler.processPendingCommand(model: model) != nil else { return }
        publishLiveActivityState()
    }
}

// MARK: - Supporting Views

#Preview {
    TimerView(model: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
} 
