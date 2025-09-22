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
    @Environment(\.watchLayoutScale) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                header

                HStack(spacing: theme.spacing.s) {
                    firstKickerButton(title: matchViewModel.homeTeamDisplayName, side: .home, color: theme.colors.accentPrimary)
                    firstKickerButton(title: matchViewModel.awayTeamDisplayName, side: .away, color: theme.colors.accentMuted)
                }

                Spacer(minLength: theme.spacing.s)
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.top, theme.spacing.s)
            .padding(.bottom, layout.safeAreaBottomPadding + theme.spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
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
                .font(theme.typography.heroSubtitle)
                .foregroundStyle(theme.colors.textInverted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: layout.dimension(theme.components.buttonHeight * 0.85, minimum: 40))
                .background(
                    RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                        .fill(color)
                )
        }
        .buttonStyle(.plain)
        .disabled(isRouting)
        .accessibilityIdentifier(side == .home ? "firstKickerHomeBtn" : "firstKickerAwayBtn")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text("First Kicker")
                .font(theme.typography.heroSubtitle)
                .foregroundStyle(theme.colors.textPrimary)

            Text("Choose which team begins the shootout")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

#Preview("First Kicker – 41mm") {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        .previewDevice("Apple Watch Series 9 (41mm)")
}

#Preview("First Kicker – Ultra") {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .expanded))
        .previewDevice("Apple Watch Ultra 2 (49mm)")
}
