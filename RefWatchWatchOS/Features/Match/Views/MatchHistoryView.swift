//
//  MatchHistoryView.swift
//  RefWatchWatchOS
//
//  Description: Simple history list of completed matches with navigation to details.
//

import RefWatchCore
import SwiftUI

private let matchHistoryDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short
  return formatter
}()

// Simplified date formatter for history cards (date only, no time)
private let matchHistoryShortDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .none
  return formatter
}()

struct MatchHistoryView: View {
  let matchViewModel: MatchViewModel
  @State private var items: [CompletedMatch] = []
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.theme) private var theme
  @EnvironmentObject private var aggregateEnvironment: AggregateSyncEnvironment

  var body: some View {
    List {
      if self.items.isEmpty {
        self.emptyState
      } else {
        ForEach(self.items) { item in
          NavigationLink(destination: MatchHistoryDetailView(snapshot: item)) {
            MatchHistoryRow(snapshot: item)
          }
          .buttonStyle(.plain)
          .listRowInsets(self.rowInsets)
          .listRowBackground(Color.clear)
        }
        .onDelete(perform: self.delete)
      }
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .padding(.vertical, self.theme.components.listRowVerticalInset)
    .background(self.theme.colors.backgroundPrimary)
    .navigationTitle("History")
    .onAppear(perform: self.reload)
    .onChange(of: self.scenePhase) { phase, _ in
      if phase == .active { self.reload() }
    }
  }

  private func reload() {
    // Merge local JSON history with inbound iPhone summaries persisted via aggregate store
    let local = self.matchViewModel.loadRecentCompletedMatches(limit: 100)
    let inbound: [CompletedMatch] = {
      let records = (try? self.aggregateEnvironment.libraryStore.fetchInboundHistory(limit: 100, cutoffDays: 90)) ?? []
      return records.map { rec in
        var match = Match(
          id: rec.id,
          homeTeam: rec.homeName,
          awayTeam: rec.awayName)
        match.homeScore = rec.homeScore
        match.awayScore = rec.awayScore
        match.competitionName = rec.competitionName
        match.venueName = rec.venueName
        return CompletedMatch(id: rec.id, completedAt: rec.completedAt, match: match, events: [])
      }
    }()
    // Deduplicate by id with smart conflict resolution:
    // Prefer local if it has full event data OR if it's newer
    var byId: [UUID: CompletedMatch] = [:]
    for item in inbound {
      byId[item.id] = item
    }
    for item in local {
      if let existing = byId[item.id] {
        // Prefer local if it has events (richer data) OR if it's newer
        if item.events.isEmpty == false || item.completedAt > existing.completedAt {
          byId[item.id] = item
        }
        // Otherwise keep the iPhone version
      } else {
        byId[item.id] = item
      }
    }
    let merged = Array(byId.values)
      .sorted { $0.completedAt > $1.completedAt }
    self.items = Array(merged.prefix(100))
  }

  private func delete(at offsets: IndexSet) {
    for index in offsets {
      let id = self.items[index].id
      self.matchViewModel.deleteCompletedMatch(id: id)
    }
    self.reload()
  }

  private var emptyState: some View {
    VStack(spacing: self.theme.spacing.m) {
      Image(systemName: "clock")
        .font(self.theme.typography.iconAccent)
        .foregroundStyle(self.theme.colors.textSecondary)

      Text("No Completed Matches")
        .font(self.theme.typography.cardHeadline)
        .foregroundStyle(self.theme.colors.textPrimary)

      Text("Matches you finish will appear here")
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .listRowInsets(self.rowInsets)
    .listRowBackground(Color.clear)
  }

  private var rowInsets: EdgeInsets {
    EdgeInsets(
      top: self.theme.components.listRowVerticalInset,
      leading: self.theme.components.cardHorizontalPadding,
      bottom: self.theme.components.listRowVerticalInset,
      trailing: self.theme.components.cardHorizontalPadding)
  }
}

struct MatchHistoryDetailView: View {
  let snapshot: CompletedMatch

  @Environment(\.theme) private var theme

  var body: some View {
    ScrollView {
      VStack(spacing: self.theme.spacing.l) {
        ThemeCardContainer(role: .secondary) {
          HStack(spacing: self.theme.spacing.l) {
            self.teamScoreColumn(name: self.snapshot.match.homeTeam, score: self.snapshot.match.homeScore)
            Divider()
              .overlay(self.theme.colors.outlineMuted)
            self.teamScoreColumn(name: self.snapshot.match.awayTeam, score: self.snapshot.match.awayScore)
          }
          .padding(.vertical, self.theme.spacing.m)
        }

        ThemeCardContainer(role: .secondary) {
          VStack(alignment: .leading, spacing: self.theme.spacing.m) {
            Text("Timeline")
              .font(self.theme.typography.cardHeadline)
              .foregroundStyle(self.theme.colors.textPrimary)

            if self.snapshot.events.isEmpty {
              Text("Match completed on iPhone")
                .font(self.theme.typography.cardMeta)
                .foregroundStyle(self.theme.colors.textSecondary)
                .padding(.vertical, self.theme.spacing.s)
            } else {
              ForEach(self.snapshot.events.reversed()) { event in
                MatchEventDetailRow(event: event)
              }
            }
          }
          .padding(.vertical, self.theme.spacing.m)
        }
      }
      .padding(.horizontal, self.theme.components.cardHorizontalPadding)
      .padding(.vertical, self.theme.components.listRowVerticalInset)
    }
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .navigationTitle("Details")
  }

  private func teamScoreColumn(name: String, score: Int) -> some View {
    VStack(spacing: self.theme.spacing.xs) {
      Text(name)
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text("\(score)")
        .font(self.theme.typography.timerSecondary)
        .foregroundStyle(self.theme.colors.textPrimary)
    }
    .frame(maxWidth: .infinity)
  }
}

#Preview("Empty State") {
  let vm = MatchViewModel(haptics: WatchHaptics())
  let environment = makePreviewAggregateEnvironment()
  return NavigationStack { MatchHistoryView(matchViewModel: vm) }
    .theme(DefaultTheme())
    .environmentObject(environment)
}

#Preview("With Matches") {
  let vm = makePreviewMatchViewModel()
  let environment = makePreviewAggregateEnvironment()
  return NavigationStack { MatchHistoryView(matchViewModel: vm) }
    .theme(DefaultTheme())
    .environmentObject(environment)
}

#Preview("Match History Row - Local Match") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Arsenal",
    awayTeam: "Chelsea",
    homeScore: 2,
    awayScore: 1,
    hasEvents: true)
  return NavigationStack {
    List {
      MatchHistoryRow(snapshot: sampleMatch)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
  }
  .theme(DefaultTheme())
}

#Preview("Match History Row - iPhone Match") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Manchester United",
    awayTeam: "Liverpool",
    homeScore: 3,
    awayScore: 2,
    hasEvents: false)
  return NavigationStack {
    List {
      MatchHistoryRow(snapshot: sampleMatch)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
  }
  .theme(DefaultTheme())
}

#Preview("Match History Row - Long Team Names") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Very Long Team Name That Might Overflow",
    awayTeam: "Another Extremely Long Team Name Here",
    homeScore: 5,
    awayScore: 4,
    hasEvents: true)
  return NavigationStack {
    List {
      MatchHistoryRow(snapshot: sampleMatch)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
  }
  .theme(DefaultTheme())
}

#Preview("Match History Detail - With Events") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Arsenal",
    awayTeam: "Chelsea",
    homeScore: 2,
    awayScore: 1,
    hasEvents: true)
  return NavigationStack {
    MatchHistoryDetailView(snapshot: sampleMatch)
  }
  .theme(DefaultTheme())
}

#Preview("Match History Detail - iPhone Match") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Manchester United",
    awayTeam: "Liverpool",
    homeScore: 3,
    awayScore: 2,
    hasEvents: false)
  return NavigationStack {
    MatchHistoryDetailView(snapshot: sampleMatch)
  }
  .theme(DefaultTheme())
}

#Preview("Score Badge") {
  HStack(spacing: 20) {
    ScoreBadge(home: 2, away: 1)
    ScoreBadge(home: 0, away: 0)
    ScoreBadge(home: 5, away: 3)
  }
  .padding()
  .theme(DefaultTheme())
}

// MARK: - Preview Helpers

@MainActor
private func makePreviewMatchViewModel() -> MatchViewModel {
  let mockHistory = MockMatchHistoryService()
  let vm = MatchViewModel(history: mockHistory, haptics: WatchHaptics())

  // Add sample matches to the mock history
  let sampleMatches = [
    makeSampleCompletedMatch(
      homeTeam: "Arsenal",
      awayTeam: "Chelsea",
      homeScore: 2,
      awayScore: 1,
      hasEvents: true,
      completedAt: Date().addingTimeInterval(-3600)),
    makeSampleCompletedMatch(
      homeTeam: "Manchester United",
      awayTeam: "Liverpool",
      homeScore: 3,
      awayScore: 2,
      hasEvents: false,
      completedAt: Date().addingTimeInterval(-7200)),
    makeSampleCompletedMatch(
      homeTeam: "Tottenham",
      awayTeam: "Newcastle",
      homeScore: 1,
      awayScore: 0,
      hasEvents: true,
      completedAt: Date().addingTimeInterval(-10800)),
  ]

  for match in sampleMatches {
    try? mockHistory.save(match)
  }

  return vm
}

@MainActor
private func makePreviewAggregateEnvironment() -> AggregateSyncEnvironment {
  guard let container = try? WatchAggregateContainerFactory.makeContainer(inMemory: true) else {
    fatalError("Failed to create preview aggregate container")
  }
  let library = WatchAggregateLibraryStore(container: container)
  let chunk = WatchAggregateSnapshotChunkStore(container: container)
  let delta = WatchAggregateDeltaOutboxStore(container: container)
  let coordinator = WatchAggregateSyncCoordinator(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta)
  let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)
  return AggregateSyncEnvironment(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta,
    coordinator: coordinator,
    connectivity: connectivity)
}

private func makeSampleCompletedMatch(
  homeTeam: String,
  awayTeam: String,
  homeScore: Int,
  awayScore: Int,
  hasEvents: Bool,
  completedAt: Date = Date()) -> CompletedMatch
{
  var match = Match(
    id: UUID(),
    homeTeam: homeTeam,
    awayTeam: awayTeam)
  match.homeScore = homeScore
  match.awayScore = awayScore
  match.competitionName = "Premier League"
  match.venueName = "Stadium"

  let events: [MatchEventRecord] = hasEvents ? [
    MatchEventRecord(
      matchTime: "00:00",
      period: 1,
      eventType: .kickOff,
      team: nil,
      details: .general),
    MatchEventRecord(
      matchTime: "15:30",
      period: 1,
      eventType: .goal(.init(goalType: .regular, playerNumber: 9, playerName: "Player 9")),
      team: .home,
      details: .goal(.init(goalType: .regular, playerNumber: 9, playerName: "Player 9"))),
    MatchEventRecord(
      matchTime: "45:00",
      period: 1,
      eventType: .halfTime,
      team: nil,
      details: .general),
    MatchEventRecord(
      matchTime: "60:15",
      period: 2,
      eventType: .goal(.init(goalType: .regular, playerNumber: 7, playerName: "Player 7")),
      team: .home,
      details: .goal(.init(goalType: .regular, playerNumber: 7, playerName: "Player 7"))),
    MatchEventRecord(
      matchTime: "75:20",
      period: 2,
      eventType: .card(.init(
        cardType: .yellow,
        recipientType: .player,
        playerNumber: 5,
        playerName: "Player 5",
        officialRole: nil,
        reason: "Unsporting behavior")),
      team: .away,
      details: .card(.init(
        cardType: .yellow,
        recipientType: .player,
        playerNumber: 5,
        playerName: "Player 5",
        officialRole: nil,
        reason: "Unsporting behavior"))),
    MatchEventRecord(
      matchTime: "82:10",
      period: 2,
      eventType: .goal(.init(goalType: .regular, playerNumber: 11, playerName: "Player 11")),
      team: .away,
      details: .goal(.init(goalType: .regular, playerNumber: 11, playerName: "Player 11"))),
    MatchEventRecord(
      matchTime: "90:00",
      period: 2,
      eventType: .matchEnd,
      team: nil,
      details: .general)
  ] : []

  return CompletedMatch(
    id: UUID(),
    completedAt: completedAt,
    match: match,
    events: events)
}

private class MockMatchHistoryService: MatchHistoryStoring {
  private var matches: [CompletedMatch] = []

  func loadAll() throws -> [CompletedMatch] {
    self.matches
  }

  func save(_ match: CompletedMatch) throws {
    self.matches.append(match)
  }

  func delete(id: UUID) throws {
    self.matches.removeAll { $0.id == id }
  }

  func wipeAll() throws {
    self.matches.removeAll()
  }
}

private struct MatchHistoryRow: View {
  let snapshot: CompletedMatch
  @Environment(\.theme) private var theme

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 88) {
      VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
        // Show teams on separate lines for better readability
        VStack(alignment: .leading, spacing: 2) {
          Text(self.snapshot.match.homeTeam)
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

          Text(self.snapshot.match.awayTeam)
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }

        HStack(spacing: self.theme.spacing.xs) {
          Text(self.shortDateText)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
            .lineLimit(1)

          if self.snapshot.events.isEmpty {
            Image(systemName: "iphone")
              .font(.system(size: 12))
              .foregroundStyle(self.theme.colors.accentSecondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // Simplified date format - date only, no time
  private var shortDateText: String {
    matchHistoryShortDateFormatter.string(from: self.snapshot.completedAt)
  }
}

private struct ScoreBadge: View {
  @Environment(\.theme) private var theme

  let home: Int
  let away: Int

  var body: some View {
    HStack(spacing: self.theme.spacing.xs) {
      Text("\(self.home)")
      Text("-")
      Text("\(self.away)")
    }
    .font(self.theme.typography.cardHeadline.monospacedDigit())
    .foregroundStyle(self.theme.colors.textPrimary)
    .padding(.horizontal, self.theme.spacing.s)
    .padding(.vertical, self.theme.spacing.xs)
    .background(
      Capsule(style: .continuous)
        .fill(self.theme.colors.surfaceOverlay))
  }
}

private struct MatchEventDetailRow: View {
  let event: MatchEventRecord
  @Environment(\.theme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
      HStack {
        Text(self.event.matchTime)
          .font(self.theme.typography.cardMeta.monospacedDigit())
          .foregroundStyle(self.theme.colors.textPrimary)

        Spacer()

        Text(self.event.periodDisplayName)
          .font(self.theme.typography.caption)
          .foregroundStyle(self.theme.colors.textSecondary)
      }

      HStack(alignment: .top, spacing: self.theme.spacing.s) {
        Image(systemName: self.icon)
          .font(self.theme.typography.iconAccent)
          .foregroundStyle(self.color)
          .frame(width: 22, height: 22)

        VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
          if let team = event.teamDisplayName {
            Text(team)
              .font(self.theme.typography.cardMeta)
              .foregroundStyle(self.theme.colors.textSecondary)
          }

          Text(self.event.displayDescription)
            .font(self.theme.typography.caption)
            .foregroundStyle(self.theme.colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.vertical, self.theme.spacing.xs)
  }

  private var icon: String {
    switch self.event.eventType {
    case .goal:
      "soccerball"
    case .card:
      "square.fill"
    case .substitution:
      "arrow.up.arrow.down"
    case .kickOff:
      "play.circle"
    case .periodStart:
      "play.circle.fill"
    case .halfTime:
      "pause.circle"
    case .periodEnd:
      "stop.circle"
    case .matchEnd:
      "stop.circle.fill"
    case .penaltiesStart:
      "flag"
    case let .penaltyAttempt(details):
      details.result == .scored ? "checkmark.circle" : "xmark.circle"
    case .penaltiesEnd:
      "flag.checkered"
    }
  }

  private var color: Color {
    switch self.event.eventType {
    case .goal:
      self.theme.colors.matchPositive
    case let .card(details):
      details.cardType == .yellow ? self.theme.colors.matchWarning : self.theme.colors.matchCritical
    case .substitution:
      self.theme.colors.accentSecondary
    case .kickOff, .periodStart:
      self.theme.colors.accentSecondary
    case .halfTime:
      self.theme.colors.matchNeutral
    case .periodEnd, .matchEnd:
      self.theme.colors.matchCritical
    case .penaltiesStart:
      self.theme.colors.matchWarning
    case let .penaltyAttempt(details):
      details.result == .scored ? self.theme.colors.matchPositive : self.theme.colors.matchCritical
    case .penaltiesEnd:
      self.theme.colors.matchPositive
    }
  }
}
