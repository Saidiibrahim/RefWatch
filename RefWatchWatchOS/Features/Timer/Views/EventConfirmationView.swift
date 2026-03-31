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
      if let player = self.formattedParticipant(number: details.playerNumber, name: details.playerName) {
        return player
      }
      return details.goalType == .regular ? nil : details.goalType.rawValue
    case let .card(details):
      if details.recipientType == .player,
         let player = self.formattedParticipant(number: details.playerNumber, name: details.playerName)
      {
        return player
      }
      if details.recipientType == .teamOfficial {
        if let officialName = details.officialName?.trimmingCharacters(in: .whitespacesAndNewlines), officialName.isEmpty == false {
          if let roleLabel = self.officialRoleDisplayLabel(details) {
            return "\(officialName) · \(roleLabel)"
          }
          return officialName
        }
        if let roleLabel = self.officialRoleDisplayLabel(details) {
          return roleLabel
        }
      }
      return details.reason
    case let .substitution(details):
      let playerOut = self.formattedParticipant(number: details.playerOut, name: details.playerOutName)
      let playerIn = self.formattedParticipant(number: details.playerIn, name: details.playerInName)
      switch (playerOut, playerIn) {
      case let (playerOut?, playerIn?):
        return "\(playerOut) -> \(playerIn)"
      case let (playerOut?, nil):
        return playerOut
      case let (nil, playerIn?):
        return playerIn
      case (nil, nil):
        return nil
      }
    case let .penaltyAttempt(attempt):
      if let number = attempt.playerNumber {
        return self.formattedParticipant(number: number, name: nil)
      }
      return "Round \(attempt.round)"
    default:
      return nil
    }
  }

  private func formattedParticipant(number: Int?, name: String?) -> String? {
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedName = trimmedName?.isEmpty == false ? trimmedName : nil

    switch (number, resolvedName) {
    case let (number?, name?):
      return "#\(number) \(name)"
    case let (number?, nil):
      return "#\(number)"
    case let (nil, name?):
      return "#? \(name)"
    case (nil, nil):
      return nil
    }
  }

  private func officialRoleDisplayLabel(_ details: CardDetails) -> String? {
    let trimmedLabel = details.officialRoleLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmedLabel, trimmedLabel.isEmpty == false {
      return trimmedLabel
    }
    return details.officialRole?.rawValue
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
