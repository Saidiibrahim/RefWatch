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

            Text("\(score)")
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let vm = MatchViewModel(haptics: WatchHaptics())
    return NavigationStack { MatchHistoryView(matchViewModel: vm) }
      .theme(DefaultTheme())
}

private struct MatchHistoryRow: View {
  let snapshot: CompletedMatch
  @Environment(\.theme) private var theme

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: theme.spacing.m) {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text("\(snapshot.match.homeTeam) vs \(snapshot.match.awayTeam)")
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)

          HStack(spacing: theme.spacing.xs) {
            Text(dateText)
              .font(theme.typography.cardMeta)
              .foregroundStyle(theme.colors.textSecondary)

            if snapshot.events.isEmpty {
              Text("•")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
              Text("from iPhone")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.accentSecondary)
            }
          }
        }

        Spacer(minLength: theme.spacing.m)

        ScoreBadge(home: snapshot.match.homeScore, away: snapshot.match.awayScore)
      }
    }
  }

  private var dateText: String {
    matchHistoryDateFormatter.string(from: snapshot.completedAt)
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
    case .card(let details):
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
