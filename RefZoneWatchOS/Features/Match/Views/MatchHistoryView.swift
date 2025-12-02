//
//  MatchHistoryView.swift
//  RefZoneWatchOS
//
//  Description: Simple history list of completed matches with navigation to details.
//

import SwiftUI
import RefWatchCore

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
      if items.isEmpty {
        emptyState
      } else {
        ForEach(items) { item in
          NavigationLink(destination: MatchHistoryDetailView(snapshot: item)) {
            MatchHistoryRow(snapshot: item)
          }
          .buttonStyle(.plain)
          .listRowInsets(rowInsets)
          .listRowBackground(Color.clear)
        }
        .onDelete(perform: delete)
      }
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .padding(.vertical, theme.components.listRowVerticalInset)
    .background(theme.colors.backgroundPrimary)
    .navigationTitle("History")
    .onAppear(perform: reload)
    .onChange(of: scenePhase) { phase, _ in
      if phase == .active { reload() }
    }
  }

  private func reload() {
    // Merge local JSON history with inbound iPhone summaries persisted via aggregate store
    let local = matchViewModel.loadRecentCompletedMatches(limit: 100)
    let inbound: [CompletedMatch] = {
      let records = (try? aggregateEnvironment.libraryStore.fetchInboundHistory(limit: 100, cutoffDays: 90)) ?? []
      return records.map { rec in
        var match = Match(
          id: rec.id,
          homeTeam: rec.homeName,
          awayTeam: rec.awayName
        )
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
    items = Array(merged.prefix(100))
  }

  private func delete(at offsets: IndexSet) {
    for index in offsets {
      let id = items[index].id
      matchViewModel.deleteCompletedMatch(id: id)
    }
    reload()
  }

  private var emptyState: some View {
    VStack(spacing: theme.spacing.m) {
      Image(systemName: "clock")
        .font(theme.typography.iconAccent)
        .foregroundStyle(theme.colors.textSecondary)

      Text("No Completed Matches")
        .font(theme.typography.cardHeadline)
        .foregroundStyle(theme.colors.textPrimary)

      Text("Matches you finish will appear here")
        .font(theme.typography.cardMeta)
        .foregroundStyle(theme.colors.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .listRowInsets(rowInsets)
    .listRowBackground(Color.clear)
  }

  private var rowInsets: EdgeInsets {
    EdgeInsets(
      top: theme.components.listRowVerticalInset,
      leading: theme.components.cardHorizontalPadding,
      bottom: theme.components.listRowVerticalInset,
      trailing: theme.components.cardHorizontalPadding
    )
  }

}

struct MatchHistoryDetailView: View {
    let snapshot: CompletedMatch

    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.l) {
                ThemeCardContainer(role: .secondary) {
                    HStack(spacing: theme.spacing.l) {
                        teamScoreColumn(name: snapshot.match.homeTeam, score: snapshot.match.homeScore)
                        Divider()
                            .overlay(theme.colors.outlineMuted)
                        teamScoreColumn(name: snapshot.match.awayTeam, score: snapshot.match.awayScore)
                    }
                    .padding(.vertical, theme.spacing.m)
                }

                ThemeCardContainer(role: .secondary) {
                    VStack(alignment: .leading, spacing: theme.spacing.m) {
                        Text("Timeline")
                            .font(theme.typography.cardHeadline)
                            .foregroundStyle(theme.colors.textPrimary)

                        if snapshot.events.isEmpty {
                            Text("Match completed on iPhone")
                                .font(theme.typography.cardMeta)
                                .foregroundStyle(theme.colors.textSecondary)
                                .padding(.vertical, theme.spacing.s)
                        } else {
                            ForEach(snapshot.events.reversed()) { event in
                                MatchEventDetailRow(event: event)
                            }
                        }
                    }
                    .padding(.vertical, theme.spacing.m)
                }
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .padding(.vertical, theme.components.listRowVerticalInset)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Details")
    }

    private func teamScoreColumn(name: String, score: Int) -> some View {
        VStack(spacing: theme.spacing.xs) {
            Text(name)
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(score)")
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textPrimary)
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
        hasEvents: true
    )
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
        hasEvents: false
    )
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
        hasEvents: true
    )
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
        hasEvents: true
    )
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
        hasEvents: false
    )
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
            completedAt: Date().addingTimeInterval(-3600)
        ),
        makeSampleCompletedMatch(
            homeTeam: "Manchester United",
            awayTeam: "Liverpool",
            homeScore: 3,
            awayScore: 2,
            hasEvents: false,
            completedAt: Date().addingTimeInterval(-7200)
        ),
        makeSampleCompletedMatch(
            homeTeam: "Tottenham",
            awayTeam: "Newcastle",
            homeScore: 1,
            awayScore: 0,
            hasEvents: true,
            completedAt: Date().addingTimeInterval(-10800)
        )
    ]
    
    for match in sampleMatches {
        try? mockHistory.save(match)
    }
    
    return vm
}

@MainActor
private func makePreviewAggregateEnvironment() -> AggregateSyncEnvironment {
    let container = try! WatchAggregateContainerFactory.makeContainer(inMemory: true)
    let library = WatchAggregateLibraryStore(container: container)
    let chunk = WatchAggregateSnapshotChunkStore(container: container)
    let delta = WatchAggregateDeltaOutboxStore(container: container)
    let coordinator = WatchAggregateSyncCoordinator(
        libraryStore: library,
        chunkStore: chunk,
        deltaStore: delta
    )
    let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)
    return AggregateSyncEnvironment(
        libraryStore: library,
        chunkStore: chunk,
        deltaStore: delta,
        coordinator: coordinator,
        connectivity: connectivity
    )
}

private func makeSampleCompletedMatch(
    homeTeam: String,
    awayTeam: String,
    homeScore: Int,
    awayScore: Int,
    hasEvents: Bool,
    completedAt: Date = Date()
) -> CompletedMatch {
    var match = Match(
        id: UUID(),
        homeTeam: homeTeam,
        awayTeam: awayTeam
    )
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
            details: .general
        ),
        MatchEventRecord(
            matchTime: "15:30",
            period: 1,
            eventType: .goal(.init(goalType: .regular, playerNumber: 9, playerName: "Player 9")),
            team: .home,
            details: .goal(.init(goalType: .regular, playerNumber: 9, playerName: "Player 9"))
        ),
        MatchEventRecord(
            matchTime: "45:00",
            period: 1,
            eventType: .halfTime,
            team: nil,
            details: .general
        ),
        MatchEventRecord(
            matchTime: "60:15",
            period: 2,
            eventType: .goal(.init(goalType: .regular, playerNumber: 7, playerName: "Player 7")),
            team: .home,
            details: .goal(.init(goalType: .regular, playerNumber: 7, playerName: "Player 7"))
        ),
        MatchEventRecord(
            matchTime: "75:20",
            period: 2,
            eventType: .card(.init(
                cardType: .yellow,
                recipientType: .player,
                playerNumber: 5,
                playerName: "Player 5",
                officialRole: nil,
                reason: "Unsporting behavior"
            )),
            team: .away,
            details: .card(.init(
                cardType: .yellow,
                recipientType: .player,
                playerNumber: 5,
                playerName: "Player 5",
                officialRole: nil,
                reason: "Unsporting behavior"
            ))
        ),
        MatchEventRecord(
            matchTime: "82:10",
            period: 2,
            eventType: .goal(.init(goalType: .regular, playerNumber: 11, playerName: "Player 11")),
            team: .away,
            details: .goal(.init(goalType: .regular, playerNumber: 11, playerName: "Player 11"))
        ),
        MatchEventRecord(
            matchTime: "90:00",
            period: 2,
            eventType: .matchEnd,
            team: nil,
            details: .general
        )
    ] : []
    
    return CompletedMatch(
        id: UUID(),
        completedAt: completedAt,
        match: match,
        events: events
    )
}

private class MockMatchHistoryService: MatchHistoryStoring {
    private var matches: [CompletedMatch] = []
    
    func loadAll() throws -> [CompletedMatch] {
        return matches
    }
    
    func save(_ match: CompletedMatch) throws {
        matches.append(match)
    }
    
    func delete(id: UUID) throws {
        matches.removeAll { $0.id == id }
    }
    
    func wipeAll() throws {
        matches.removeAll()
    }
}

private struct MatchHistoryRow: View {
  let snapshot: CompletedMatch
  @Environment(\.theme) private var theme

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 88) {
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        // Show teams on separate lines for better readability
        VStack(alignment: .leading, spacing: 2) {
          Text(snapshot.match.homeTeam)
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
          
          Text(snapshot.match.awayTeam)
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }

        HStack(spacing: theme.spacing.xs) {
          Text(shortDateText)
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
            .lineLimit(1)

          if snapshot.events.isEmpty {
            Image(systemName: "iphone")
              .font(.system(size: 12))
              .foregroundStyle(theme.colors.accentSecondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // Simplified date format - date only, no time
  private var shortDateText: String {
    matchHistoryShortDateFormatter.string(from: snapshot.completedAt)
  }
}

private struct ScoreBadge: View {
  @Environment(\.theme) private var theme

  let home: Int
  let away: Int

  var body: some View {
    HStack(spacing: theme.spacing.xs) {
      Text("\(home)")
      Text("-")
      Text("\(away)")
    }
    .font(theme.typography.cardHeadline.monospacedDigit())
    .foregroundStyle(theme.colors.textPrimary)
    .padding(.horizontal, theme.spacing.s)
    .padding(.vertical, theme.spacing.xs)
    .background(
      Capsule(style: .continuous)
        .fill(theme.colors.surfaceOverlay)
    )
  }
}

private struct MatchEventDetailRow: View {
  let event: MatchEventRecord
  @Environment(\.theme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      HStack {
        Text(event.matchTime)
          .font(theme.typography.cardMeta.monospacedDigit())
          .foregroundStyle(theme.colors.textPrimary)

        Spacer()

        Text(event.periodDisplayName)
          .font(theme.typography.caption)
          .foregroundStyle(theme.colors.textSecondary)
      }

      HStack(alignment: .top, spacing: theme.spacing.s) {
        Image(systemName: icon)
          .font(theme.typography.iconAccent)
          .foregroundStyle(color)
          .frame(width: 22, height: 22)

        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          if let team = event.teamDisplayName {
            Text(team)
              .font(theme.typography.cardMeta)
              .foregroundStyle(theme.colors.textSecondary)
          }

          Text(event.displayDescription)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.vertical, theme.spacing.xs)
  }

  private var icon: String {
    switch event.eventType {
    case .goal:
      return "soccerball"
    case .card:
      return "square.fill"
    case .substitution:
      return "arrow.up.arrow.down"
    case .kickOff:
      return "play.circle"
    case .periodStart:
      return "play.circle.fill"
    case .halfTime:
      return "pause.circle"
    case .periodEnd:
      return "stop.circle"
    case .matchEnd:
      return "stop.circle.fill"
    case .penaltiesStart:
      return "flag"
    case .penaltyAttempt(let details):
      return details.result == .scored ? "checkmark.circle" : "xmark.circle"
    case .penaltiesEnd:
      return "flag.checkered"
    }
  }

  private var color: Color {
    switch event.eventType {
    case .goal:
      return theme.colors.matchPositive
    case .card(let details):
      return details.cardType == .yellow ? theme.colors.matchWarning : theme.colors.matchCritical
    case .substitution:
      return theme.colors.accentSecondary
    case .kickOff, .periodStart:
      return theme.colors.accentSecondary
    case .halfTime:
      return theme.colors.matchNeutral
    case .periodEnd, .matchEnd:
      return theme.colors.matchCritical
    case .penaltiesStart:
      return theme.colors.matchWarning
    case .penaltyAttempt(let details):
      return details.result == .scored ? theme.colors.matchPositive : theme.colors.matchCritical
    case .penaltiesEnd:
      return theme.colors.matchPositive
    }
  }
}
