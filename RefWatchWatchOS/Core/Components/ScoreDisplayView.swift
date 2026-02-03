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
    let emphasis: Bool

    init(
        homeTeam: String,
        awayTeam: String,
        homeScore: Int,
        awayScore: Int,
        emphasis: Bool = false
    ) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.emphasis = emphasis
    }

    var body: some View {
        HStack(spacing: emphasis ? theme.spacing.m : theme.spacing.s) {
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
                font: emphasis ? theme.typography.cardHeadline : theme.typography.cardMeta,
                color: theme.colors.textSecondary,
                alignment: .center
            )
            .minimumScaleFactor(0.6)

            Text("\(score)")
                .font(theme.typography.timerSecondary)
                .scaleEffect(emphasis ? 1.08 : 1.0, anchor: .center)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

private extension ScoreDisplayView {
    var verticalPadding: CGFloat {
        if emphasis {
            return layout.dimension(theme.spacing.s, minimum: theme.spacing.xs)
        }
        return layout.category == .compact ? theme.spacing.xs : theme.spacing.s
    }
}
