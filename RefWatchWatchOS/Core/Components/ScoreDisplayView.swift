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
    let compact: Bool

    init(
        homeTeam: String,
        awayTeam: String,
        homeScore: Int,
        awayScore: Int,
        compact: Bool = false
    ) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? theme.spacing.s : theme.spacing.m) {
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
            TeamNameAbbreviationText(
                name: title,
                font: compact ? theme.typography.caption : theme.typography.cardMeta,
                color: theme.colors.textSecondary,
                alignment: .center
            )

            Text("\(score)")
                .font(compact ? theme.typography.timerTertiary : theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

private extension ScoreDisplayView {
    var verticalPadding: CGFloat {
        if compact {
            return layout.dimension(theme.spacing.xs, minimum: theme.spacing.xs * 0.6)
        }
        return layout.category == .compact ? theme.spacing.xs : theme.spacing.s
    }
}
