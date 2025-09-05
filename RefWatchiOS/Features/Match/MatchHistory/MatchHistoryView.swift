//
//  MatchHistoryView.swift
//  RefWatchiOS
//
//  Dedicated iOS history list for completed matches.
//

import SwiftUI
import RefWatchCore

struct MatchHistoryView: View {
    let matchViewModel: MatchViewModel
    @State private var items: [CompletedMatch] = []
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
                let data = filteredItems
                if data.isEmpty {
                    if searchText.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "No Completed Matches",
                                systemImage: "clock",
                                description: Text("Finish a match to see it here.")
                            )
                            Button {
                                dismiss()
                            } label: {
                                Label("Start Match", systemImage: "play.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                    } else {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("No matches found for \"\(searchText)\".")
                        )
                    }
                } else {
                    ForEach(data) { item in
                        NavigationLink(destination: MatchHistoryDetailView(snapshot: item)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.match.homeTeam) vs \(item.match.awayTeam)")
                                        .font(.body)
                                    Text(Self.format(item.completedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(item.match.homeScore) - \(item.match.awayScore)")
                                    .font(.headline)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("History")
        .toolbar { EditButton() }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search team")
        .refreshable { reload() }
        .onAppear { reload() }
    }

    private func delete(at offsets: IndexSet) {
        // Deletion operates on base items, not filtered view
        for i in offsets { matchViewModel.deleteCompletedMatch(id: filteredItems[i].id) }
        reload()
    }

    private func reload() { items = matchViewModel.loadRecentCompletedMatches() }

    private var filteredItems: [CompletedMatch] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            item.match.homeTeam.lowercased().contains(q) ||
            item.match.awayTeam.lowercased().contains(q)
        }
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    MatchHistoryView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}
