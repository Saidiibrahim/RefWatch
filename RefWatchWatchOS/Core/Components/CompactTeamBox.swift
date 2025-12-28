//
//  CompactTeamBox.swift
//  RefWatchWatchOS
//
//  Description: Compact team selection box component optimized for watch screen space
//

import SwiftUI
import RefWatchCore

/// Compact team box component optimized for watch screen space
struct CompactTeamBox: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    let teamName: String
    let score: Int
    let isSelected: Bool
    let action: () -> Void
    let accessibilityIdentifier: String?

    init(
        teamName: String,
        score: Int,
        isSelected: Bool,
        action: @escaping () -> Void,
        accessibilityIdentifier: String? = nil
    ) {
        self.teamName = teamName
        self.score = score
        self.isSelected = isSelected
        self.action = action
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacing.xs) {
                Text(teamName)
                    .font(theme.typography.cardMeta.weight(.semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Text("\(score)")
                    .font(theme.typography.timerSecondary)
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: layout.compactTeamTileHeight)
            .padding(.horizontal, theme.spacing.s)
            .background(background)
            .overlay(border)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous))
        .accessibilityIdentifier(accessibilityIdentifier ?? "teamBox_\(teamName)")
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
            .fill(isSelected ? theme.colors.matchPositive : theme.colors.backgroundElevated)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
            .stroke(isSelected ? theme.colors.matchPositive.opacity(0.9) : theme.colors.outlineMuted.opacity(0.6), lineWidth: 1)
    }

    private var textColor: Color {
        isSelected ? theme.colors.textInverted : theme.colors.textPrimary
    }
}

#Preview {
    HStack(spacing: 10) {
        CompactTeamBox(
            teamName: "HOM",
            score: 1,
            isSelected: true,
            action: { print("Home selected") },
            accessibilityIdentifier: "homeTeamButton"
        )
        
        CompactTeamBox(
            teamName: "AWA",
            score: 0,
            isSelected: false,
            action: { print("Away selected") },
            accessibilityIdentifier: "awayTeamButton"
        )
    }
    .padding()
}
