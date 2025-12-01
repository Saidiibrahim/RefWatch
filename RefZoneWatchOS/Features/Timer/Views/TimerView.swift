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
    @State private var confirmationDismissTask: Task<Void, Never>? = nil
    private let commandHandler = LiveActivityCommandHandler()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    // Persist selected timer face
    @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
    private var faceStyle: TimerFaceStyle { TimerFaceStyle.parse(raw: timerFaceStyleRaw) }
    
    private var periodLabel: String { PeriodLabelFormatter.label(for: model) }
    
    var body: some View {
        mainLayout
            .overlay { confirmationOverlay }
            .animation(.easeInOut(duration: 0.2), value: model.pendingConfirmation?.id)
            .erasedToAnyView()
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
        .onChange(of: model.pendingConfirmation?.id) { newValue in
            confirmationDismissTask?.cancel()
            guard let id = newValue else { return }
            confirmationDismissTask = Task { [model] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    model.clearPendingConfirmation(id: id)
                }
            }
        }
        .onDisappear {
            confirmationDismissTask?.cancel()
        }
    }
    
    // MARK: - Faces are rendered above; no state-specific views here.
}

// MARK: - LiveActivity Publishing

private extension TimerView {
    var mainLayout: some View {
        let verticalSpacing = layout.category == .compact ? theme.spacing.s : theme.spacing.m

        return VStack(spacing: verticalSpacing) {
            periodIndicator
            scoreDisplay
            timerFace
        }
        .accessibilityIdentifier("timerArea")
        .padding(.top, layout.timerTopPadding)
        .padding(.bottom, layout.timerBottomPadding + layout.safeAreaBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    }

    private var periodIndicator: some View {
        HStack {
            Text(periodLabel)
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
        .padding(.horizontal, theme.components.cardHorizontalPadding)
    }

    private var scoreDisplay: some View {
        ScoreDisplayView(
            homeTeam: model.homeTeamDisplayName,
            awayTeam: model.awayTeamDisplayName,
            homeScore: model.currentMatch?.homeScore ?? 0,
            awayScore: model.currentMatch?.awayScore ?? 0
        )
    }

    private var timerFace: some View {
        TimerFaceFactory.view(for: faceStyle, model: model)
            .hapticsProvider(WatchHaptics())
    }

    @ViewBuilder
    var confirmationOverlay: some View {
        if let confirmation = model.pendingConfirmation {
            EventConfirmationView(confirmation: confirmation, matchViewModel: model)
                .transition(.opacity)
        }
    }

    func publishLiveActivityState() {
        livePublisher.publish(for: model)
    }

    func processPendingWidgetCommand() {
        guard commandHandler.processPendingCommand(model: model) != nil else { return }
        publishLiveActivityState()
    }
}

// MARK: - Supporting Views

private extension View {
    func erasedToAnyView() -> AnyView {
        AnyView(self)
    }
}

#Preview {
    TimerView(model: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        .previewDevice("Apple Watch Series 9 (41mm)")
}

#Preview("Timer – Ultra") {
    TimerView(model: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .expanded))
        .previewDevice("Apple Watch Ultra 2 (49mm)")
}
