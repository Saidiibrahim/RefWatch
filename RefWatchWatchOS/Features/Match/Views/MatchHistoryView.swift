//
//  MatchHistoryView.swift
//  RefWatchWatchOS
//
//  Description: Simple history list of completed matches with navigation to details.
//

import RefWatchCore
import SwiftUI

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

  var body: some View {
    MatchRecordsView(snapshot: self.snapshot)
      .navigationTitle("Details")
  }
}

#if DEBUG
#Preview("Empty State") {
  let vm = MatchViewModel(haptics: WatchHaptics())
  let environment = makePreviewAggregateEnvironment()
  NavigationStack { MatchHistoryView(matchViewModel: vm) }
    .watchPreviewChrome()
    .environmentObject(environment)
}

#Preview("With Matches") {
  let vm = makePreviewMatchViewModel()
  let environment = makePreviewAggregateEnvironment()
  NavigationStack { MatchHistoryView(matchViewModel: vm) }
    .watchPreviewChrome()
    .environmentObject(environment)
}

#Preview("Match History Row - Local Match") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Arsenal",
    awayTeam: "Chelsea",
    homeScore: 2,
    awayScore: 1,
    hasEvents: true)
  NavigationStack {
    List {
      MatchHistoryRow(snapshot: sampleMatch)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
  }
  .watchPreviewChrome()
}

#Preview("Match History Row - iPhone Match") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Manchester United",
    awayTeam: "Liverpool",
    homeScore: 3,
    awayScore: 2,
    hasEvents: false)
  NavigationStack {
    List {
      MatchHistoryRow(snapshot: sampleMatch)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
  }
  .watchPreviewChrome()
}

#Preview("Match History Row - Long Team Names") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Very Long Team Name That Might Overflow",
    awayTeam: "Another Extremely Long Team Name Here",
    homeScore: 5,
    awayScore: 4,
    hasEvents: true)
  NavigationStack {
    List {
      MatchHistoryRow(snapshot: sampleMatch)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
  }
  .watchPreviewChrome()
}

#Preview("Match History Detail - With Events") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Arsenal",
    awayTeam: "Chelsea",
    homeScore: 2,
    awayScore: 1,
    hasEvents: true)
  NavigationStack {
    MatchHistoryDetailView(snapshot: sampleMatch)
  }
  .watchPreviewChrome()
}

#Preview("Match History Detail - iPhone Match") {
  let sampleMatch = makeSampleCompletedMatch(
    homeTeam: "Manchester United",
    awayTeam: "Liverpool",
    homeScore: 3,
    awayScore: 2,
    hasEvents: false)
  NavigationStack {
    MatchHistoryDetailView(snapshot: sampleMatch)
  }
  .watchPreviewChrome()
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
#endif

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
