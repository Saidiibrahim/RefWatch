//
//  EventConfirmationView.swift
//  RefWatchWatchOS
//
//  Displays a transient confirmation for the most recently recorded match event.
//

import RefWatchCore
import SwiftUI

struct EventConfirmationView: View {
  let confirmation: MatchEventConfirmation
  let matchViewModel: MatchViewModel
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  private var event: MatchEventRecord { self.confirmation.event }

  var body: some View {
    ZStack {
      self.theme.colors.backgroundPrimary.opacity(0.92).ignoresSafeArea()

      VStack(spacing: self.theme.spacing.l) {
        self.iconView

        VStack(spacing: self.theme.spacing.xs) {
          Text(self.event.eventType.displayName)
            .font(self.theme.typography.heroTitle)
            .foregroundStyle(self.theme.colors.textPrimary)

          if let teamLine {
            Text(teamLine)
              .font(self.theme.typography.cardMeta)
              .foregroundStyle(self.theme.colors.textSecondary)
              .textCase(.uppercase)
          }

          if let detailLine {
            Text(detailLine)
              .font(self.theme.typography.caption)
              .foregroundStyle(self.theme.colors.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.top, self.theme.spacing.xs)
          }
        }
      }
      .padding(.vertical, self.theme.spacing.l)
      .padding(.horizontal, self.theme.spacing.xl)
      .background(
        RoundedRectangle(cornerRadius: self.layout.dimension(20, minimum: 16, maximum: 28))
          .fill(self.theme.colors.backgroundElevated)
          .overlay(
            RoundedRectangle(cornerRadius: self.layout.dimension(20, minimum: 16, maximum: 28))
              .stroke(self.theme.colors.surfaceOverlay, lineWidth: 1))
          .shadow(color: self.theme.colors.surfaceOverlay, radius: self.layout.dimension(18, minimum: 12, maximum: 24)))
      .padding(.horizontal, self.theme.spacing.l)
      .accessibilityElement(children: .combine)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var iconView: some View {
    ZStack {
      Circle()
        .fill(self.theme.colors.color(for: self.event.eventType))
        .frame(width: self.layout.eventIconSize * 1.6, height: self.layout.eventIconSize * 1.6)

      Image(systemName: self.iconName)
        .font(.system(size: self.layout.eventIconSize, weight: .semibold))
        .foregroundStyle(self.theme.colors.textInverted)
    }
  }

  private var iconName: String {
    switch self.event.eventType {
    case .goal:
      "soccerball"
    case let .card(details):
      details.cardType == .yellow ? "square.fill" : "square.fill"
    case .substitution:
      "arrow.up.arrow.down"
    case let .penaltyAttempt(attempt):
      attempt.result == .scored ? "checkmark.circle.fill" : "xmark.circle.fill"
    default:
      "checkmark.circle"
    }
  }

  private var teamLine: String? {
    guard let team = event.team else { return nil }
    let name = team == .home ? self.matchViewModel.homeTeamDisplayName : self.matchViewModel.awayTeamDisplayName
    return "\(team.rawValue) · \(name)"
  }

  private var detailLine: String? {
    switch self.event.eventType {
    case let .goal(details):
      if let number = details.playerNumber {
        return self.formattedPlayer(number: number, name: details.playerName)
      }
      return details.goalType == .regular ? nil : details.goalType.rawValue
    case let .card(details):
      if details.recipientType == .player, let number = details.playerNumber {
        return self.formattedPlayer(number: number, name: details.playerName)
      }
      if details.recipientType == .teamOfficial, let role = details.officialRole {
        return role.rawValue
      }
      return details.reason
    case let .substitution(details):
      if let playerOut = details.playerOut, let playerIn = details.playerIn {
        return "#\(playerOut) → #\(playerIn)"
      }
      return nil
    case let .penaltyAttempt(attempt):
      if let number = attempt.playerNumber {
        return self.formattedPlayer(number: number, name: nil)
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
  let record = MatchEventRecord(
    matchTime: "45:00",
    period: 1,
    eventType: .goal(details),
    team: .home,
    details: .goal(details))
  let confirmation = MatchEventConfirmation(event: record)

  return EventConfirmationView(confirmation: confirmation, matchViewModel: viewModel)
    .watchLayoutScale(WatchLayoutScale(category: .compact))
}
