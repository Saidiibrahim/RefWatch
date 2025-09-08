//
//  MatchHistoryView.swift
//  RefWatch Watch App
//
//  Description: Simple history list of completed matches with navigation to details.
//

import SwiftUI
import RefWatchCore

struct MatchHistoryView: View {
    let matchViewModel: MatchViewModel
    @State private var items: [CompletedMatch] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                    Text("No Completed Matches")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    NavigationLink(destination: MatchHistoryDetailView(snapshot: item)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.match.homeTeam) vs \(item.match.awayTeam)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(format(date: item.completedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(item.match.homeScore) - \(item.match.awayScore)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .listStyle(.carousel)
        .navigationTitle("History")
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { phase, _ in
            if phase == .active { reload() }
        }
    }

    private func reload() {
        items = matchViewModel.loadRecentCompletedMatches()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let id = items[index].id
            matchViewModel.deleteCompletedMatch(id: id)
        }
        reload()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private func format(date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

struct MatchHistoryDetailView: View {
    let snapshot: CompletedMatch

    var body: some View {
        VStack(spacing: 8) {
            // Header scores
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(snapshot.match.homeTeam)
                        .font(.system(size: 14, weight: .bold))
                    Text("\(snapshot.match.homeScore)")
                        .font(.system(size: 22, weight: .bold))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(snapshot.match.awayTeam)
                        .font(.system(size: 14, weight: .bold))
                    Text("\(snapshot.match.awayScore)")
                        .font(.system(size: 22, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)

            // Events list
            List {
                ForEach(snapshot.events.reversed()) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon(for: event))
                            .foregroundColor(color(for: event))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(event.matchTime)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                Spacer()
                                Text(event.periodDisplayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if let team = event.teamDisplayName {
                                Text(team)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(event.displayDescription)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.carousel)
        }
        .navigationTitle("Details")
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
    let vm = MatchViewModel(haptics: WatchHaptics())
    return NavigationStack { MatchHistoryView(matchViewModel: vm) }
}
