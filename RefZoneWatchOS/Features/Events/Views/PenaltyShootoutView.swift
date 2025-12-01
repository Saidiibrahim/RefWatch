//
//  PenaltyShootoutView.swift
//  RefZoneWatchOS
//
//  Description: Penalty shootout flow with attempts and tallies for each team.
//

import SwiftUI
import WatchKit
import RefWatchCore

struct PenaltyShootoutView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    @State private var showingPanelActions = false

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: adaptiveSpacing(for: proxy.size.height)) {
                if shouldShowStatusBanner {
                    statusBanner
                }

                HStack(spacing: theme.spacing.s) {
                    PenaltyTeamPanel(
                        side: .home,
                        title: matchViewModel.homeTeamDisplayName,
                        scored: matchViewModel.homePenaltiesScored,
                        taken: matchViewModel.homePenaltiesTaken,
                        rounds: matchViewModel.penaltyRoundsVisible,
                        results: matchViewModel.homePenaltyResults,
                        isActive: matchViewModel.nextPenaltyTeam == .home && !matchViewModel.isPenaltyShootoutDecided,
                        isDisabled: matchViewModel.isPenaltyShootoutDecided,
                        onScore: { matchViewModel.recordPenaltyAttempt(team: .home, result: .scored) },
                        onMiss: { matchViewModel.recordPenaltyAttempt(team: .home, result: .missed) },
                        onLongPress: presentPanelActions
                    )

                    PenaltyTeamPanel(
                        side: .away,
                        title: matchViewModel.awayTeamDisplayName,
                        scored: matchViewModel.awayPenaltiesScored,
                        taken: matchViewModel.awayPenaltiesTaken,
                        rounds: matchViewModel.penaltyRoundsVisible,
                        results: matchViewModel.awayPenaltyResults,
                        isActive: matchViewModel.nextPenaltyTeam == .away && !matchViewModel.isPenaltyShootoutDecided,
                        isDisabled: matchViewModel.isPenaltyShootoutDecided,
                        onScore: { matchViewModel.recordPenaltyAttempt(team: .away, result: .scored) },
                        onMiss: { matchViewModel.recordPenaltyAttempt(team: .away, result: .missed) },
                        onLongPress: presentPanelActions
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .padding(.top, theme.spacing.s)
            .padding(.bottom, layout.safeAreaBottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            // Ensure we mark penalties started once (idempotent)
            matchViewModel.beginPenaltiesIfNeeded()
        }
        .confirmationDialog(
            "Penalty Options",
            isPresented: $showingPanelActions,
            titleVisibility: .visible
        ) {
            if canUndoPenaltyAttempt {
                Button("Undo Last Kick") { handleUndo() }
            }

            if !matchViewModel.isPenaltyShootoutDecided {
                Button("Swap Kicking Order") { handleSwapOrder() }
            }

            if matchViewModel.isPenaltyShootoutDecided {
                Button("End Shootout", role: .destructive) { handleEndShootout() }
            }

            Button("Cancel", role: .cancel) { }
        }
        // First-kicker prompt handled at MatchRootView level before routing
    }

    private func adaptiveSpacing(for height: CGFloat) -> CGFloat {
        switch layout.category {
        case .compact where height < 350:
            return theme.spacing.xs
        case .compact:
            return theme.spacing.s
        case .standard:
            return theme.spacing.m
        case .expanded:
            return theme.spacing.l
        }
    }

    private var shouldShowStatusBanner: Bool {
        layout.category != .compact || matchViewModel.isPenaltyShootoutDecided
    }

    @ViewBuilder
    private var statusBanner: some View {
        if matchViewModel.isPenaltyShootoutDecided, let winner = matchViewModel.penaltyWinner {
            Text("\(winner == .home ? matchViewModel.homeTeamDisplayName : matchViewModel.awayTeamDisplayName) win")
                .font(theme.typography.cardHeadline)
                .padding(theme.spacing.s)
                .foregroundStyle(theme.colors.textInverted)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: theme.components.chipCornerRadius, style: .continuous)
                        .fill(theme.colors.matchPositive)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .simultaneousGesture(longPressGesture(trigger: presentPanelActions))
        } else if matchViewModel.isSuddenDeathActive {
            Text("Sudden Death")
                .font(theme.typography.cardMeta)
                .padding(theme.spacing.xs)
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: theme.components.chipCornerRadius, style: .continuous)
                        .fill(theme.colors.matchWarning)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .simultaneousGesture(longPressGesture(trigger: presentPanelActions))
        }
    }

    private func longPressGesture(trigger: @escaping () -> Void) -> some Gesture {
        LongPressGesture(minimumDuration: 0.7)
            .onEnded { finished in
                guard finished else { return }
                trigger()
            }
    }

    private func presentPanelActions() {
        WKInterfaceDevice.current().play(.click)
        showingPanelActions = true
    }

    private func handleEndShootout() {
        guard matchViewModel.isPenaltyShootoutDecided else { return }
        WKInterfaceDevice.current().play(.success)
        matchViewModel.endPenaltiesAndProceed()
        lifecycle.goToFinished()
    }

    private func handleUndo() {
        if !matchViewModel.undoLastPenaltyAttempt() {
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func handleSwapOrder() {
        matchViewModel.swapPenaltyOrder()
    }

    private var canUndoPenaltyAttempt: Bool {
        (matchViewModel.homePenaltiesTaken + matchViewModel.awayPenaltiesTaken) > 0
    }
}

private struct PenaltyTeamPanel: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    let side: TeamSide
    let title: String
    let scored: Int
    let taken: Int
    let rounds: Int
    let results: [PenaltyAttemptDetails.Result]
    let isActive: Bool
    let isDisabled: Bool
    let onScore: () -> Void
    let onMiss: () -> Void
    let onLongPress: (() -> Void)?

    var body: some View {
        VStack(spacing: theme.spacing.s) {
            Text(title)
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("\(scored) / \(taken)")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.matchPositive)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            // Per-round dots (first 5, then grow for sudden death)
            HStack(spacing: theme.spacing.xs) {
                ForEach(0..<rounds, id: \.self) { idx in
                    Group {
                        if idx < results.count {
                            if results[idx] == .scored {
                                Circle().fill(theme.colors.matchPositive)
                            } else {
                                Circle().fill(theme.colors.matchCritical)
                            }
                        } else {
                            Circle().stroke(theme.colors.outlineMuted, lineWidth: 1)
                        }
                    }
                    .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: theme.spacing.s) {
                Button(action: onScore) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.colors.textInverted)
                        .frame(width: controlDiameter, height: controlDiameter)
                        .background(Circle().fill(theme.colors.matchPositive))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(side == .home ? "homeScorePenaltyBtn" : "awayScorePenaltyBtn")
                .disabled(!isActive || isDisabled)
                
                Button(action: onMiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colors.textInverted)
                        .frame(width: controlDiameter, height: controlDiameter)
                        .background(Circle().fill(theme.colors.matchCritical))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(side == .home ? "homeMissPenaltyBtn" : "awayMissPenaltyBtn")
                .disabled(!isActive || isDisabled)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: layout.penaltyPanelMinHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                .fill(theme.colors.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                .stroke(isActive ? theme.colors.matchPositive : .clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous))
        .accessibilityIdentifier(side == .home ? "homePenaltyPanel" : "awayPenaltyPanel")
        .simultaneousGesture(longPressGesture)
    }

    private var controlDiameter: CGFloat {
        layout.dimension(36, minimum: 32, maximum: 44)
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.7)
            .onEnded { finished in
                guard finished, let onLongPress else { return }
                onLongPress()
            }
    }
}

// FirstKickerPickerView removed; replaced by dedicated PenaltyFirstKickerView screen

#Preview("Penalties – 41mm") {
    PenaltyShootoutView(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        
}

#Preview("Penalties – Ultra") {
    PenaltyShootoutView(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .expanded))
        
}
