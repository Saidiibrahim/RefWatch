//
//  MatchRecordsTeamPage.swift
//  RefWatchWatchOS
//
//  Team-specific completed-match records page.
//

import RefWatchCore
import SwiftUI

struct MatchRecordsTeamPage: View {
  let snapshot: CompletedMatch
  let team: TeamSide

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    ScrollView {
      VStack(spacing: self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14)) {
        self.headerCard

        if self.hasIncidents {
          ForEach(self.sections, id: \.kind) { section in
            MatchRecordsTeamSection(
              title: section.kind.title,
              icon: self.sectionIcon(for: section.kind),
              accentColor: self.sectionColor(for: section.kind, events: section.events),
              rows: section.events.map { self.rowContent(for: $0) })
          }
        } else {
          self.emptyStateCard
        }
      }
      .padding(.horizontal, self.theme.components.cardHorizontalPadding)
      .padding(.vertical, self.theme.components.listRowVerticalInset)
    }
    .background(self.theme.colors.backgroundPrimary)
  }
}

extension MatchRecordsTeamPage {
  private var headerCard: some View {
    ThemeCardContainer(role: .secondary) {
      Text(self.teamName)
        .font(self.theme.typography.cardHeadline)
        .foregroundStyle(self.theme.colors.textPrimary)
        .lineLimit(2)
        .minimumScaleFactor(0.75)
    }
  }

  private var emptyStateCard: some View {
    ThemeCardContainer(role: .secondary, minHeight: 96) {
      Text("No incidents")
        .font(self.theme.typography.cardHeadline)
        .foregroundStyle(self.theme.colors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  private var teamName: String {
    switch self.team {
    case .home:
      self.snapshot.match.homeTeam
    case .away:
      self.snapshot.match.awayTeam
    }
  }

  private var sections: [MatchRecordsSection] {
    self.snapshot.matchRecordsSections(for: self.team)
  }

  private func sectionIcon(for kind: MatchRecordsSectionKind) -> String {
    switch kind {
    case .goals:
      "soccerball"
    case .cards:
      "square.fill"
    case .substitutions:
      "arrow.left.arrow.right"
    }
  }

  private func sectionColor(for kind: MatchRecordsSectionKind, events: [MatchEventRecord]) -> Color {
    switch kind {
    case .goals:
      self.theme.colors.matchPositive
    case .cards:
      self.completedMatchEventColor(for: events.first?.eventType ?? .kickOff)
    case .substitutions:
      self.theme.colors.accentSecondary
    }
  }

  private var hasIncidents: Bool {
    !self.sections.isEmpty
  }

  private func rowContent(for event: MatchEventRecord) -> MatchRecordsRowContent {
    switch event.eventType {
    case let .goal(details):
      return MatchRecordsRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .standard(
          title: self.watchParticipantLabel(number: details.playerNumber, name: details.playerName) ?? "Scorer not recorded",
          subtitle: details.goalType == .regular ? nil : details.goalType.rawValue),
        icon: "soccerball",
        color: self.completedMatchEventColor(for: event.eventType),
        accessibilityLabel: self.standardAccessibilityLabel(
          matchTime: event.matchTime,
          title: self.watchParticipantLabel(number: details.playerNumber, name: details.playerName) ?? "Scorer not recorded",
          subtitle: details.goalType == .regular ? nil : details.goalType.rawValue))

    case let .card(details):
      let title = self.watchCardSubject(details: details)
      let subtitle = self.cardReason(details: details)
      return MatchRecordsRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .standard(
          title: title,
          subtitle: subtitle),
        icon: "square.fill",
        color: self.completedMatchEventColor(for: event.eventType),
        accessibilityLabel: self.standardAccessibilityLabel(
          matchTime: event.matchTime,
          title: title,
          subtitle: subtitle))

    case let .substitution(details):
      let playerOff = self.watchParticipantLabel(number: details.playerOut, name: details.playerOutName) ?? "Out not recorded"
      let playerOn = self.watchParticipantLabel(number: details.playerIn, name: details.playerInName) ?? "In not recorded"
      return MatchRecordsRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .substitution(
          playerOff: playerOff,
          playerOn: playerOn),
        icon: nil,
        color: nil,
        accessibilityLabel: self.substitutionAccessibilityLabel(
          matchTime: event.matchTime,
          playerOff: playerOff,
          playerOn: playerOn))

    default:
      return MatchRecordsRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .standard(
          title: event.displayDescription,
          subtitle: nil),
        icon: "circle.fill",
        color: self.completedMatchEventColor(for: event.eventType),
        accessibilityLabel: self.standardAccessibilityLabel(
          matchTime: event.matchTime,
          title: event.displayDescription,
          subtitle: nil))
    }
  }

  private func watchParticipantLabel(number: Int?, name: String?) -> String? {
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedName = trimmedName?.isEmpty == false ? trimmedName : nil

    switch (number, resolvedName) {
    case let (number?, _):
      return "#\(number)"
    case let (nil, name?):
      return name
    case (nil, nil):
      return nil
    }
  }

  private func watchCardSubject(details: CardDetails) -> String {
    switch details.recipientType {
    case .player:
      return self.watchParticipantLabel(number: details.playerNumber, name: details.playerName) ?? "Player"
    case .teamOfficial:
      let trimmedName = details.officialName?.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolvedName = trimmedName?.isEmpty == false ? trimmedName : nil
      let role = self.officialRoleLabel(details: details)

      switch (resolvedName, role) {
      case let (name?, role?):
        return "\(name) · \(role)"
      case let (name?, nil):
        return name
      case let (nil, role?):
        return role
      case (nil, nil):
        return "Team Official"
      }
    }
  }

  private func officialRoleLabel(details: CardDetails) -> String? {
    let trimmedLabel = details.officialRoleLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmedLabel, !trimmedLabel.isEmpty {
      return trimmedLabel
    }
    return details.officialRole?.rawValue
  }

  private func cardReason(details: CardDetails) -> String {
    let cardText = "\(details.cardType.rawValue) Card"
    let trimmedReason = (details.reasonTitle ?? details.reason)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard trimmedReason.isEmpty == false else {
      return cardText
    }

    guard details.isSecondCautionDismissal else {
      return "\(cardText) · \(trimmedReason)"
    }

    let uppercasedReason = trimmedReason.uppercased()
    if uppercasedReason.contains("SECOND CAUTION") || uppercasedReason.contains("SECOND YELLOW") {
      return "\(cardText) · \(trimmedReason)"
    }
    return "\(cardText) · Second caution dismissal · \(trimmedReason)"
  }

  private func completedMatchEventColor(for eventType: MatchEventType) -> Color {
    if case let .card(details) = eventType, details.cardType == .yellow {
      return self.theme.colors.matchNeutral
    }
    return self.theme.colors.color(for: eventType)
  }

  private func standardAccessibilityLabel(matchTime: String, title: String, subtitle: String?) -> String {
    var parts = [matchTime, title]
    if let subtitle, !subtitle.isEmpty {
      parts.append(subtitle)
    }
    return parts.joined(separator: ", ")
  }

  private func substitutionAccessibilityLabel(matchTime: String, playerOff: String, playerOn: String) -> String {
    "\(matchTime), player on \(playerOn), player off \(playerOff)"
  }
}

private struct MatchRecordsTeamSection: View {
  let title: String
  let icon: String
  let accentColor: Color
  let rows: [MatchRecordsRowContent]

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(alignment: .leading, spacing: self.layout.dimension(self.theme.spacing.s, minimum: 8, maximum: 10)) {
        HStack(spacing: self.theme.spacing.s) {
          Image(systemName: self.icon)
            .foregroundStyle(self.accentColor)
            .font(self.theme.typography.iconAccent)

          Text(self.title)
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)
        }

        ForEach(Array(self.rows.enumerated()), id: \.element.id) { index, row in
          MatchRecordsTeamRow(row: row)

          if index < self.rows.count - 1 {
            Divider()
              .overlay(self.theme.colors.outlineMuted.opacity(0.7))
          }
        }
      }
    }
  }
}

private struct MatchRecordsTeamRow: View {
  let row: MatchRecordsRowContent

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    self.content
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(self.row.accessibilityLabel)
  }

  @ViewBuilder
  private var content: some View {
    switch self.row.content {
    case let .standard(title, subtitle):
      ViewThatFits {
        HStack(alignment: .top, spacing: self.theme.spacing.s) {
          self.timeLabel

          VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
            self.standardLine(text: title, isSubtitle: false)
            self.standardSubtitle(text: subtitle)
          }

          Spacer(minLength: 0)

          self.iconLabel
        }

        VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
          HStack(spacing: self.theme.spacing.s) {
            self.timeLabel
            self.iconLabel
            Spacer(minLength: 0)
          }

          self.standardLine(text: title, isSubtitle: false)
          self.standardSubtitle(text: subtitle)
        }
      }

    case let .substitution(playerOff, playerOn):
      HStack(alignment: .top, spacing: self.theme.spacing.s) {
        self.substitutionTimeLabel
          .frame(width: self.layout.dimension(42, minimum: 36, maximum: 46), alignment: .leading)

        VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
          self.substitutionLine(text: playerOn, arrow: "->", arrowColor: self.theme.colors.matchPositive)
          self.substitutionLine(text: playerOff, arrow: "<-", arrowColor: self.theme.colors.matchCritical)
        }
      }
    }
  }

  private var timeLabel: some View {
    Text(self.row.matchTime)
      .font(self.theme.typography.cardMeta.monospacedDigit())
      .foregroundStyle(self.theme.colors.textSecondary)
      .lineLimit(1)
  }

  private var substitutionTimeLabel: some View {
    Text(self.row.matchTimeMinute)
      .font(self.theme.typography.cardMeta.monospacedDigit())
      .foregroundStyle(self.theme.colors.textSecondary)
      .lineLimit(1)
  }

  private func standardLine(text: String, isSubtitle: Bool) -> some View {
    Text(text)
      .font(isSubtitle ? self.theme.typography.caption : self.theme.typography.cardMeta)
      .foregroundStyle(isSubtitle ? self.theme.colors.textSecondary : self.theme.colors.textPrimary)
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private func standardSubtitle(text: String?) -> some View {
    if let text {
      self.standardLine(text: text, isSubtitle: true)
    }
  }

  private func substitutionLine(text: String, arrow: String, arrowColor: Color) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: self.theme.spacing.xs) {
      Text(text)
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)

      Text(arrow)
        .font(self.theme.typography.cardMeta.weight(.semibold))
        .foregroundStyle(arrowColor)
    }
  }

  @ViewBuilder
  private var iconLabel: some View {
    if let icon = self.row.icon, let color = self.row.color {
      Image(systemName: icon)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: 18, height: 18)
    }
  }
}

private struct MatchRecordsRowContent: Identifiable {
  let id: UUID
  let matchTime: String
  let content: Content
  let icon: String?
  let color: Color?
  let accessibilityLabel: String

  enum Content {
    case standard(title: String, subtitle: String?)
    case substitution(playerOff: String, playerOn: String)
  }

  fileprivate var matchTimeMinute: String {
    self.matchTime.split(separator: ":", maxSplits: 1).first.map(String.init) ?? self.matchTime
  }
}

#if DEBUG
#Preview("Home Team Page") {
  MatchRecordsTeamPage(
    snapshot: makeSampleCompletedMatch(
      homeTeam: "Arsenal",
      awayTeam: "Chelsea",
      homeScore: 2,
      awayScore: 1,
      hasEvents: true),
    team: .home)
    .watchPreviewChrome()
}

#Preview("Home Team Page - Compact") {
  MatchRecordsTeamPage(
    snapshot: makeSampleCompletedMatch(
      homeTeam: "Arsenal",
      awayTeam: "Chelsea",
      homeScore: 2,
      awayScore: 1,
      hasEvents: true),
    team: .home)
    .watchPreviewChrome(layout: WatchPreviewSupport.compactLayout)
}

#Preview("Away Team Page") {
  MatchRecordsTeamPage(
    snapshot: makeSampleCompletedMatch(
      homeTeam: "Arsenal",
      awayTeam: "Chelsea",
      homeScore: 2,
      awayScore: 1,
      hasEvents: true),
    team: .away)
    .watchPreviewChrome()
}

#Preview("Team Page - No Incidents") {
  MatchRecordsTeamPage(
    snapshot: MatchRecordsTeamPagePreviewFixtures.noIncidentsSnapshot(),
    team: .home)
    .watchPreviewChrome()
}

@MainActor
private enum MatchRecordsTeamPagePreviewFixtures {
  static func noIncidentsSnapshot() -> CompletedMatch {
    var snapshot = makeSampleCompletedMatch(
      homeTeam: "Arsenal",
      awayTeam: "Chelsea",
      homeScore: 1,
      awayScore: 0,
      hasEvents: true,
      events: [
        MatchEventRecord(
          matchTime: "00:00",
          period: 1,
          eventType: .kickOff,
          team: nil,
          details: .general),
        MatchEventRecord(
          matchTime: "45:00",
          period: 1,
          eventType: .halfTime,
          team: nil,
          details: .general),
        MatchEventRecord(
          matchTime: "90:00",
          period: 2,
          eventType: .matchEnd,
          team: nil,
          details: .general),
      ])
    snapshot.match.homeYellowCards = 0
    snapshot.match.awayYellowCards = 0
    snapshot.match.homeRedCards = 0
    snapshot.match.awayRedCards = 0
    snapshot.match.homeSubs = 0
    snapshot.match.awaySubs = 0
    return snapshot
  }
}
#endif
