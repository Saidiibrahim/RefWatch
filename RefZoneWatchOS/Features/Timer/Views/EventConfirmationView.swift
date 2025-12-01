//
//  EventConfirmationView.swift
//  RefZoneWatchOS
//
//  Displays a transient confirmation for the most recently recorded match event.
//

import SwiftUI
import RefWatchCore

struct EventConfirmationView: View {
    let confirmation: MatchEventConfirmation
    let matchViewModel: MatchViewModel
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    private var event: MatchEventRecord { confirmation.event }

    var body: some View {
        ZStack {
            theme.colors.backgroundPrimary.opacity(0.92).ignoresSafeArea()

            VStack(spacing: theme.spacing.l) {
                iconView

                VStack(spacing: theme.spacing.xs) {
                    Text(event.eventType.displayName)
                        .font(theme.typography.heroTitle)
                        .foregroundStyle(theme.colors.textPrimary)

                    if let teamLine = teamLine {
                        Text(teamLine)
                            .font(theme.typography.cardMeta)
                            .foregroundStyle(theme.colors.textSecondary)
                            .textCase(.uppercase)
                    }

                    if let detailLine = detailLine {
                        Text(detailLine)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, theme.spacing.xs)
                    }
                }
            }
            .padding(.vertical, theme.spacing.l)
            .padding(.horizontal, theme.spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: layout.dimension(20, minimum: 16, maximum: 28))
                    .fill(theme.colors.backgroundElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.dimension(20, minimum: 16, maximum: 28))
                            .stroke(theme.colors.surfaceOverlay, lineWidth: 1)
                    )
                    .shadow(color: theme.colors.surfaceOverlay, radius: layout.dimension(18, minimum: 12, maximum: 24))
            )
            .padding(.horizontal, theme.spacing.l)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(theme.colors.color(for: event.eventType))
                .frame(width: layout.eventIconSize * 1.6, height: layout.eventIconSize * 1.6)

            Image(systemName: iconName)
                .font(.system(size: layout.eventIconSize, weight: .semibold))
                .foregroundStyle(theme.colors.textInverted)
        }
    }

    private var iconName: String {
        switch event.eventType {
        case .goal:
            return "soccerball"
        case .card(let details):
            return details.cardType == .yellow ? "square.fill" : "square.fill"
        case .substitution:
            return "arrow.up.arrow.down"
        case .penaltyAttempt(let attempt):
            return attempt.result == .scored ? "checkmark.circle.fill" : "xmark.circle.fill"
        default:
            return "checkmark.circle"
        }
    }

    private var teamLine: String? {
        guard let team = event.team else { return nil }
        let name = team == .home ? matchViewModel.homeTeamDisplayName : matchViewModel.awayTeamDisplayName
        return "\(team.rawValue) · \(name)"
    }

    private var detailLine: String? {
        switch event.eventType {
        case .goal(let details):
            if let number = details.playerNumber {
                return formattedPlayer(number: number, name: details.playerName)
            }
            return details.goalType == .regular ? nil : details.goalType.rawValue
        case .card(let details):
            if details.recipientType == .player, let number = details.playerNumber {
                return formattedPlayer(number: number, name: details.playerName)
            }
            if details.recipientType == .teamOfficial, let role = details.officialRole {
                return role.rawValue
            }
            return details.reason
        case .substitution(let details):
            if let playerOut = details.playerOut, let playerIn = details.playerIn {
                return "#\(playerOut) → #\(playerIn)"
            }
            return nil
        case .penaltyAttempt(let attempt):
            if let number = attempt.playerNumber {
                return formattedPlayer(number: number, name: nil)
            }
            return "Round \(attempt.round)"
        default:
            return nil
        }
    }

    private func formattedPlayer(number: Int, name: String?) -> String {
        if let name, !name.isEmpty {
            return "#\(number) · \(name)"
        }
        return "#\(number)"
    }
}

#Preview {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    let details = GoalDetails(goalType: .regular, playerNumber: 9, playerName: "Smith")
    let record = MatchEventRecord(matchTime: "45:00", period: 1, eventType: .goal(details), team: .home, details: .goal(details))
    let confirmation = MatchEventConfirmation(event: record)

    return EventConfirmationView(confirmation: confirmation, matchViewModel: viewModel)
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        
}
