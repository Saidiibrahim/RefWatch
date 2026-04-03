//
//  MatchHistoryDetailView.swift
//  RefWatchiOS
//
//  Detail screen for a completed match with records-first review.
//

import Combine
import RefWatchCore
import SwiftUI

struct MatchHistoryDetailView: View {
  enum DetailMode: String, CaseIterable {
    case records = "Records"
    case timeline = "Timeline"
  }

  let snapshot: CompletedMatch
  @Environment(\.journalStore) private var journalStore
  @State private var latestJournal: JournalEntry?
  @State private var selectedMode: DetailMode

  init(snapshot: CompletedMatch, initialMode: DetailMode = .records) {
    self.snapshot = snapshot
    self._selectedMode = State(initialValue: initialMode)
  }

  var body: some View {
    List {
      Section("Self‑Assessment") {
        if let entry = self.latestJournal {
          NavigationLink(destination: JournalListView(snapshot: self.snapshot)) {
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                if let rating = entry.rating {
                  Text("⭐️ \(rating)/5")
                    .font(.subheadline)
                }
                Spacer()
                Text(Self.format(entry.updatedAt))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              if let text = entry.overall, !text.isEmpty {
                Text(text).lineLimit(2)
              } else if let text = entry.wentWell, !text.isEmpty {
                Text(text).lineLimit(2)
              } else if let text = entry.toImprove, !text.isEmpty {
                Text(text).lineLimit(2)
              } else {
                Text("(No text)")
                  .foregroundStyle(.secondary)
                  .font(.caption)
              }
            }
          }
          NavigationLink(destination: JournalEditorView(matchId: self.snapshot.id, onSaved: { self.loadLatest() })) {
            Label("Add Entry", systemImage: "plus")
          }
        } else {
          NavigationLink(destination: JournalEditorView(matchId: self.snapshot.id, onSaved: { self.loadLatest() })) {
            Label("Add Self‑Assessment", systemImage: "square.and.pencil")
          }
        }
      }

      Section {
        HStack {
          VStack(spacing: 4) {
            Text(self.snapshot.match.homeTeam)
              .font(.headline)
            Text("\(self.snapshot.match.homeScore)")
              .font(.largeTitle)
              .bold()
          }
          Spacer()
          VStack(spacing: 4) {
            Text(self.snapshot.match.awayTeam)
              .font(.headline)
            Text("\(self.snapshot.match.awayScore)")
              .font(.largeTitle)
              .bold()
          }
        }
        .padding(.vertical, 4)
      }

      Section {
        Picker("View", selection: self.$selectedMode) {
          ForEach(DetailMode.allCases, id: \.self) { mode in
            Text(mode.rawValue).tag(mode)
          }
        }
        .pickerStyle(.segmented)
      }

      switch self.selectedMode {
      case .records:
        Section {
          MatchRecordsView(snapshot: self.snapshot)
            .frame(height: MatchRecordsView.preferredHeight)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
      case .timeline:
        Section("Timeline") {
          MatchHistoryTimelineSection(snapshot: self.snapshot)
        }
      }
    }
    .navigationTitle("Details")
    .onAppear { self.loadLatest() }
    .onReceive(
      NotificationCenter.default.publisher(for: .journalDidChange)
        .receive(on: RunLoop.main))
    { _ in
      self.loadLatest()
    }
  }
}

extension MatchHistoryDetailView {
  fileprivate static func format(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func loadLatest() {
    Task { await self.loadLatestEntry() }
  }

  @MainActor
  private func loadLatestEntry() async {
    self.latestJournal = try? await self.journalStore.loadLatest(for: self.snapshot.id)
  }
}

private struct MatchHistoryTimelineSection: View {
  let snapshot: CompletedMatch

  @Environment(\.theme) private var theme

  var body: some View {
    ForEach(self.snapshot.events.reversed()) { event in
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: self.icon(for: event))
          .foregroundStyle(self.completedMatchEventColor(for: event.eventType))
          .frame(width: 18)

        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(event.matchTime)
              .font(.system(.footnote, design: .monospaced))
              .bold()
            Spacer()
            Text(event.periodDisplayName)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          if let team = event.teamDisplayName {
            Text(team)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(event.displayDescription)
            .font(.subheadline)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private func completedMatchEventColor(for eventType: MatchEventType) -> Color {
    if case let .card(details) = eventType, details.cardType == .yellow {
      return self.theme.colors.matchNeutral
    }
    return self.theme.colors.color(for: eventType)
  }

  private func icon(for event: MatchEventRecord) -> String {
    switch event.eventType {
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
}

#if DEBUG
#Preview("Detail - Records") {
  NavigationStack {
    MatchHistoryDetailView(
      snapshot: makeSampleCompletedMatch(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeScore: 2,
        awayScore: 1,
        hasEvents: true),
      initialMode: .records)
  }
}

#Preview("Detail - Timeline") {
  NavigationStack {
    MatchHistoryDetailView(
      snapshot: makeSampleCompletedMatch(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeScore: 2,
        awayScore: 1,
        hasEvents: true),
      initialMode: .timeline)
  }
}
#endif
