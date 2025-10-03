//
//  MatchHistoryDetailView.swift
//  RefZoneiOS
//
//  Detail screen for a completed match. Ported from watch design, adapted for iOS.
//

import SwiftUI
import RefWatchCore
import Combine

struct MatchHistoryDetailView: View {
    let snapshot: CompletedMatch
    @Environment(\.journalStore) private var journalStore
    @State private var latestJournal: JournalEntry? = nil

    var body: some View {
        List {
            // Self-Assessment
            Section("Self‑Assessment") {
                if let entry = latestJournal {
                    NavigationLink(destination: JournalListView(snapshot: snapshot)) {
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
                    NavigationLink(destination: JournalEditorView(matchId: snapshot.id, onSaved: { loadLatest() })) {
                        Label("Add Entry", systemImage: "plus")
                    }
                } else {
                    NavigationLink(destination: JournalEditorView(matchId: snapshot.id, onSaved: { loadLatest() })) {
                        Label("Add Self‑Assessment", systemImage: "square.and.pencil")
                    }
                }
            }

            Section {
                HStack {
                    VStack(spacing: 4) {
                        Text(snapshot.match.homeTeam).font(.headline)
                        Text("\(snapshot.match.homeScore)").font(.largeTitle).bold()
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text(snapshot.match.awayTeam).font(.headline)
                        Text("\(snapshot.match.awayScore)").font(.largeTitle).bold()
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Events") {
                ForEach(snapshot.events.reversed()) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: event))
                            .foregroundStyle(color(for: event))
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
        .onReceive(NotificationCenter.default.publisher(for: .journalDidChange).receive(on: RunLoop.main)) { _ in loadLatest() }
    }

    private func icon(for event: MatchEventRecord) -> String {
        switch event.eventType {
        case .goal: return "soccerball"
        case .card(let details):
            return details.cardType == .yellow ? "square.fill" : "square.fill"
        case .substitution: return "arrow.up.arrow.down"
        case .kickOff: return "play.circle"
        case .periodStart: return "play.circle.fill"
        case .halfTime: return "pause.circle"
        case .periodEnd: return "stop.circle"
        case .matchEnd: return "stop.circle.fill"
        case .penaltiesStart: return "flag"
        case .penaltyAttempt(let details):
            return details.result == .scored ? "checkmark.circle" : "xmark.circle"
        case .penaltiesEnd: return "flag.checkered"
        }
    }

    private func color(for event: MatchEventRecord) -> Color {
        switch event.eventType {
        case .goal: return .green
        case .card(let details): return details.cardType == .yellow ? .yellow : .red
        case .substitution: return .blue
        case .kickOff, .periodStart: return .green
        case .halfTime: return .orange
        case .periodEnd, .matchEnd: return .red
        case .penaltiesStart: return .orange
        case .penaltyAttempt(let details): return details.result == .scored ? .green : .red
        case .penaltiesEnd: return .green
        }
    }
}

#Preview {
    // Minimal preview with an empty snapshot
    let match = Match(homeTeam: "Home", awayTeam: "Away")
    let snapshot = CompletedMatch(match: match, events: [])
    return NavigationStack { MatchHistoryDetailView(snapshot: snapshot) }
}

private extension MatchHistoryDetailView {
    static func format(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: date)
    }
    func loadLatest() {
        Task { await loadLatestEntry() }
    }

    @MainActor
    private func loadLatestEntry() async {
        latestJournal = try? await journalStore.loadLatest(for: snapshot.id)
    }
}
