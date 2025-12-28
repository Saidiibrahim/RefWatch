// ScoreDisplayView.swift
// Description: Component for displaying team names and scores in a horizontal layout

import SwiftUI
import RefWatchCore

struct ScoreDisplayView: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            teamColumn(title: homeTeam, score: homeScore)
            Divider()
                .overlay(theme.colors.outlineMuted)
            teamColumn(title: awayTeam, score: awayScore)
        }
        .padding(.horizontal, theme.components.cardHorizontalPadding)
        .padding(.vertical, verticalPadding)
    }

    private func teamColumn(title: String, score: Int) -> some View {
        VStack(spacing: theme.spacing.xs) {
            Text(title)
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(score)")
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

private extension ScoreDisplayView {
    var verticalPadding: CGFloat {
        layout.category == .compact ? theme.spacing.xs : theme.spacing.s
    }
}
