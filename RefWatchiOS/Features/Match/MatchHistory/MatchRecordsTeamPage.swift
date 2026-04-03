//
//  MatchRecordsTeamPage.swift
//  RefWatchiOS
//
//  Team-specific completed-match records page.
//

import RefWatchCore
import SwiftUI

struct MatchRecordsTeamPage: View {
  let snapshot: CompletedMatch
  let team: TeamSide

  @Environment(\.theme) private var theme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(self.teamTitle)
          .font(.headline)
          .foregroundStyle(.primary)

        if self.hasIncidents {
          ForEach(self.sections, id: \.kind) { section in
            MatchRecordsTeamSection(
              title: section.kind.title,
              rows: section.events.map { self.rowContent(for: $0) })
          }
        } else {
          VStack {
            Text("No incidents")
              .font(.headline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
          .background(Color(uiColor: .secondarySystemGroupedBackground))
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollIndicators(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
  }
}

private extension MatchRecordsTeamPage {
  var teamTitle: String {
    switch self.team {
    case .home:
      return self.snapshot.match.homeTeam
    case .away:
      return self.snapshot.match.awayTeam
    }
  }

  var sections: [MatchRecordsSection] {
    self.snapshot.matchRecordsSections(for: self.team)
  }

  var hasIncidents: Bool {
    self.sections.isEmpty == false
  }

  func rowContent(for event: MatchEventRecord) -> MatchRecordsTimelineRowContent {
    switch event.eventType {
    case let .goal(details):
      let title = self.participantLabel(number: details.playerNumber, name: details.playerName) ?? "Scorer not recorded"
      let subtitle = details.goalType == .regular ? nil : details.goalType.rawValue
      return MatchRecordsTimelineRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .standard(title: title, subtitle: subtitle),
        icon: "soccerball",
        color: self.completedMatchEventColor(for: event.eventType),
        accessibilityLabel: self.standardAccessibilityLabel(
          matchTime: event.matchTime,
          title: title,
          subtitle: subtitle))

    case let .card(details):
      let title = self.cardSubject(details: details)
      let subtitle = self.cardReason(details: details)
      return MatchRecordsTimelineRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .standard(title: title, subtitle: subtitle),
        icon: "square.fill",
        color: self.completedMatchEventColor(for: event.eventType),
        accessibilityLabel: self.standardAccessibilityLabel(
          matchTime: event.matchTime,
          title: title,
          subtitle: subtitle))

    case let .substitution(details):
      let playerOff = self.participantLabel(number: details.playerOut, name: details.playerOutName) ?? "Out not recorded"
      let playerOn = self.participantLabel(number: details.playerIn, name: details.playerInName) ?? "In not recorded"
      return MatchRecordsTimelineRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .substitution(playerOff: playerOff, playerOn: playerOn),
        icon: nil,
        color: nil,
        accessibilityLabel: self.substitutionAccessibilityLabel(
          matchTime: event.matchTime,
          playerOff: playerOff,
          playerOn: playerOn))

    default:
      return MatchRecordsTimelineRowContent(
        id: event.id,
        matchTime: event.matchTime,
        content: .standard(title: event.displayDescription, subtitle: nil),
        icon: "circle.fill",
        color: self.completedMatchEventColor(for: event.eventType),
        accessibilityLabel: self.standardAccessibilityLabel(
          matchTime: event.matchTime,
          title: event.displayDescription,
          subtitle: nil))
    }
  }

  func participantLabel(number: Int?, name: String?) -> String? {
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedName = trimmedName?.isEmpty == false ? trimmedName : nil

    switch (number, resolvedName) {
    case let (number?, name?):
      return "#\(number) \(name)"
    case let (number?, nil):
      return "#\(number)"
    case let (nil, name?):
      return name
    case (nil, nil):
      return nil
    }
  }

  func cardSubject(details: CardDetails) -> String {
    switch details.recipientType {
    case .player:
      return self.participantLabel(number: details.playerNumber, name: details.playerName) ?? "Player"
    case .teamOfficial:
      let trimmedName = details.officialName?.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolvedName = trimmedName?.isEmpty == false ? trimmedName : nil
      let roleLabel = self.officialRoleLabel(details: details)

      switch (resolvedName, roleLabel) {
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

  func officialRoleLabel(details: CardDetails) -> String? {
    let trimmedLabel = details.officialRoleLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmedLabel, !trimmedLabel.isEmpty {
      return trimmedLabel
    }
    return details.officialRole?.rawValue
  }

  func cardReason(details: CardDetails) -> String {
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

  func completedMatchEventColor(for eventType: MatchEventType) -> Color {
    if case let .card(details) = eventType, details.cardType == .yellow {
      return self.theme.colors.matchNeutral
    }
    return self.theme.colors.color(for: eventType)
  }

  func standardAccessibilityLabel(matchTime: String, title: String, subtitle: String?) -> String {
    var parts = [matchTime, title]
    if let subtitle, !subtitle.isEmpty {
      parts.append(subtitle)
    }
    return parts.joined(separator: ", ")
  }

  func substitutionAccessibilityLabel(matchTime: String, playerOff: String, playerOn: String) -> String {
    "\(matchTime), player on \(playerOn), player off \(playerOff)"
  }
}

private struct MatchRecordsTeamSection: View {
  let title: String
  let rows: [MatchRecordsTimelineRowContent]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(self.title)
        .font(.headline)
        .foregroundStyle(.primary)

      ForEach(Array(self.rows.enumerated()), id: \.element.id) { index, row in
        MatchRecordsTeamRow(row: row)

        if index < self.rows.count - 1 {
          Divider()
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct MatchRecordsTeamRow: View {
  let row: MatchRecordsTimelineRowContent
  @Environment(\.theme) private var theme

  var body: some View {
    self.content
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(self.row.accessibilityLabel)
  }

  @ViewBuilder
  private var content: some View {
    switch self.row.content {
    case let .standard(title, subtitle):
      HStack(alignment: .top, spacing: 12) {
        self.timeLabel

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.subheadline.weight(.medium))

          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Spacer(minLength: 0)

        self.iconView
      }

    case let .substitution(playerOff, playerOn):
      HStack(alignment: .top, spacing: 12) {
        self.timeLabel

        VStack(alignment: .leading, spacing: 4) {
          self.substitutionLine(text: playerOn, arrow: "->", arrowColor: self.theme.colors.matchPositive)
          self.substitutionLine(text: playerOff, arrow: "<-", arrowColor: self.theme.colors.matchCritical)
        }
      }
    }
  }

  private var timeLabel: some View {
    Text(self.row.matchTime)
      .font(.system(.footnote, design: .monospaced))
      .bold()
      .frame(width: 52, alignment: .leading)
  }

  private func substitutionLine(text: String, arrow: String, arrowColor: Color) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(text)
        .font(.subheadline.weight(.medium))
        .fixedSize(horizontal: false, vertical: true)

      Text(arrow)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(arrowColor)
    }
  }

  @ViewBuilder
  private var iconView: some View {
    if let icon = self.row.icon, let color = self.row.color {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 18, alignment: .trailing)
    }
  }
}

private struct MatchRecordsTimelineRowContent: Identifiable {
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
}
