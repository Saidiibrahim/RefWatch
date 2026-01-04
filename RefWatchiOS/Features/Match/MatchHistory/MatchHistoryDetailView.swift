//
//  MatchHistoryDetailView.swift
//  RefWatchiOS
//
//  Detail screen for a completed match. Ported from watch design, adapted for iOS.
//

import Combine
import RefWatchCore
import SwiftUI

struct MatchHistoryDetailView: View {
  let snapshot: CompletedMatch
  @Environment(\.journalStore) private var journalStore
  @State private var latestJournal: JournalEntry?

  var body: some View {
    List {
      // Self-Assessment
      Section("Self‑Assessment") {
        if let entry = latestJournal {
          NavigationLink(destination: JournalListView(snapshot: self.snapshot)) {
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                if let rating = entry.rating { Text("⭐️ \(rating)/5").font(.subheadline) }
                Spacer()
                Text(Self.format(entry.updatedAt)).font(.caption).foregroundStyle(.secondary)
              }
              if let txt = entry.overall, !txt.isEmpty {
                Text(txt).lineLimit(2)
              } else if let txt = entry.wentWell, !txt.isEmpty {
                Text(txt).lineLimit(2)
              } else if let txt = entry.toImprove, !txt.isEmpty {
                Text(txt).lineLimit(2)
              } else {
                Text("(No text)").foregroundStyle(.secondary).font(.caption)
              }
            }
          }
          NavigationLink(destination: JournalEditorView(matchId: self.snapshot.id, onSaved: { loadLatest() })) {
            Label("Add Entry", systemImage: "plus")
          }
        } else {
          NavigationLink(destination: JournalEditorView(matchId: self.snapshot.id, onSaved: { loadLatest() })) {
            Label("Add Self‑Assessment", systemImage: "square.and.pencil")
          }
        }
      }

      Section {
        HStack {
          VStack(spacing: 4) {
            Text(self.snapshot.match.homeTeam).font(.headline)
            Text("\(self.snapshot.match.homeScore)").font(.largeTitle).bold()
          }
          Spacer()
          VStack(spacing: 4) {
            Text(self.snapshot.match.awayTeam).font(.headline)
            Text("\(self.snapshot.match.awayScore)").font(.largeTitle).bold()
          }
        }
        .padding(.vertical, 4)
      }

      Section("Events") {
        ForEach(self.snapshot.events.reversed()) { event in
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: self.icon(for: event))
              .foregroundStyle(self.color(for: event))
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
    }
    .navigationTitle("Details")
    .onAppear { loadLatest() }
    .onReceive(
      NotificationCenter.default.publisher(for: .journalDidChange)
        .receive(on: RunLoop.main))
    { _ in
      loadLatest()
    }
  }

  private func icon(for event: MatchEventRecord) -> String {
    switch event.eventType {
    case .goal: "soccerball"
    case let .card(details):
      details.cardType == .yellow ? "square.fill" : "square.fill"
    case .substitution: "arrow.up.arrow.down"
    case .kickOff: "play.circle"
    case .periodStart: "play.circle.fill"
    case .halfTime: "pause.circle"
    case .periodEnd: "stop.circle"
    case .matchEnd: "stop.circle.fill"
    case .penaltiesStart: "flag"
    case let .penaltyAttempt(details):
      details.result == .scored ? "checkmark.circle" : "xmark.circle"
    case .penaltiesEnd: "flag.checkered"
    }
  }

  private func color(for event: MatchEventRecord) -> Color {
    switch event.eventType {
    case .goal: .green
    case let .card(details): details.cardType == .yellow ? .yellow : .red
    case .substitution: .blue
    case .kickOff, .periodStart: .green
    case .halfTime: .orange
    case .periodEnd, .matchEnd: .red
    case .penaltiesStart: .orange
    case let .penaltyAttempt(details): details.result == .scored ? .green : .red
    case .penaltiesEnd: .green
    }
  }
}

#Preview {
  // Minimal preview with an empty snapshot
  let match = Match(homeTeam: "Home", awayTeam: "Away")
  let snapshot = CompletedMatch(match: match, events: [])
  return NavigationStack { MatchHistoryDetailView(snapshot: snapshot) }
}

extension MatchHistoryDetailView {
  fileprivate static func format(_ date: Date) -> String {
    let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
    return f.string(from: date)
  }

  private func loadLatest() {
    Task { await self.loadLatestEntry() }
  }

  @MainActor
  private func loadLatestEntry() async {
    self.latestJournal = try? await self.journalStore.loadLatest(for: self.snapshot.id)
  }
}
