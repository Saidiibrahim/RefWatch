//
//  PenaltyFirstKickerView.swift
//  RefZoneWatchOS
//
//  Description: Dedicated screen to select the first kicker before entering penalties.
//

import SwiftUI
import WatchKit
import RefWatchCore

struct PenaltyFirstKickerView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var isRouting = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.l) {

            // Buttons
            HStack(spacing: theme.spacing.m) {
                firstKickerButton(title: matchViewModel.homeTeamDisplayName, side: .home, color: theme.colors.accentPrimary)
                firstKickerButton(title: matchViewModel.awayTeamDisplayName, side: .away, color: theme.colors.accentMuted)
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)

            Spacer()
        }
        .padding(.top, theme.spacing.l)
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("First Kicker")
    }

    private func firstKickerButton(title: String, side: TeamSide, color: Color) -> some View {
        Button(action: {
            // Haptic feedback and simple tap guard to avoid double navigation
            WKInterfaceDevice.current().play(.click)
            guard !isRouting else { return }
            isRouting = true

            // Coordinated penalty setup to prevent partial state corruption:
            // - startPenalties(withFirstKicker:) atomically begins the shootout and sets first kicker
            // - Only navigate if setup succeeds (returns true)
            // - On failure, we provide failure haptic feedback and keep the user on this screen
            // This replaces the previous multi-step beginPenaltiesIfNeeded() + setPenaltyFirstKicker() approach.
            let ok = matchViewModel.startPenalties(withFirstKicker: side)
            if ok {
                lifecycle.goToPenalties()
            } else {
                // If coordination failed (defensive), reset guard and notify via haptic
                isRouting = false
                WKInterfaceDevice.current().play(.failure)
            }
        }) {
            Text(title)
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textInverted)
                .frame(maxWidth: .infinity)
                .frame(height: theme.components.buttonHeight / 1.6)
                .background(RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous).fill(color))
        }
        .buttonStyle(.plain)
        .disabled(isRouting)
        .accessibilityIdentifier(side == .home ? "firstKickerHomeBtn" : "firstKickerAwayBtn")
    }

    
}

#Preview {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
}
