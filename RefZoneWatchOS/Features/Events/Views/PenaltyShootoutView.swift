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

    var body: some View {
        VStack(spacing: theme.spacing.l) {

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
                    .padding(.horizontal, theme.components.cardHorizontalPadding)
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
                    .padding(.horizontal, theme.components.cardHorizontalPadding)
            }

            // Tallies
            HStack(spacing: theme.spacing.m) {
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
                    onMiss: { matchViewModel.recordPenaltyAttempt(team: .home, result: .missed) }
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
                    onMiss: { matchViewModel.recordPenaltyAttempt(team: .away, result: .missed) }
                )
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            // Ensure we mark penalties started once (idempotent)
            matchViewModel.beginPenaltiesIfNeeded()
        }
        // Bottom action
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                WKInterfaceDevice.current().play(.success)
                #if DEBUG
                print("DEBUG: PenaltyShootoutView: End Shootout tapped (decided=\(matchViewModel.isPenaltyShootoutDecided))")
                #endif
                matchViewModel.endPenaltiesAndProceed()
                #if DEBUG
                print("DEBUG: PenaltyShootoutView: endPenaltiesAndProceed -> isFullTime=\(matchViewModel.isFullTime)")
                #endif
                lifecycle.goToFinished()
            }) {
                Text("End Shootout")
                    .font(theme.typography.button)
                    .foregroundStyle(theme.colors.textInverted)
                    .frame(maxWidth: .infinity)
                    .frame(height: theme.components.buttonHeight / 1.6)
                    .background(
                        RoundedRectangle(cornerRadius: theme.components.controlCornerRadius, style: .continuous)
                            .fill(matchViewModel.isPenaltyShootoutDecided ? theme.colors.matchPositive : theme.colors.backgroundElevated)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("endShootoutButton")
            .disabled(!matchViewModel.isPenaltyShootoutDecided)
            .opacity(matchViewModel.isPenaltyShootoutDecided ? 1 : 0.5)
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .padding(.top, theme.spacing.s)
            .padding(.bottom, theme.spacing.xl)
        }
        // First-kicker prompt handled at MatchRootView level before routing
    }

    
}

private struct PenaltyTeamPanel: View {
    @Environment(\.theme) private var theme

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

    var body: some View {
        VStack(spacing: theme.spacing.s) {
            Text(title)
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textPrimary)

            Text("\(scored) / \(taken)")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.matchPositive)

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
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(theme.colors.matchPositive))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(side == .home ? "homeScorePenaltyBtn" : "awayScorePenaltyBtn")
                .disabled(!isActive || isDisabled)

                Button(action: onMiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colors.textInverted)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(theme.colors.matchCritical))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(side == .home ? "homeMissPenaltyBtn" : "awayMissPenaltyBtn")
                .disabled(!isActive || isDisabled)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                .fill(theme.colors.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                .stroke(isActive ? theme.colors.matchPositive : .clear, lineWidth: 2)
        )
    }
}

// FirstKickerPickerView removed; replaced by dedicated PenaltyFirstKickerView screen

#Preview {
    PenaltyShootoutView(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
}
