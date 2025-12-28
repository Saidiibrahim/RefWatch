//
//  MatchHistoryView.swift
//  RefWatchiOS
//
//  Dedicated iOS history list for completed matches.
//

import SwiftUI
import Combine
import RefWatchCore

struct MatchHistoryView: View {
    let matchViewModel: MatchViewModel
    let historyStore: MatchHistoryStoring
    let matchSyncController: MatchHistorySyncControlling?
    @Environment(\.journalStore) private var journalStore
    @State private var items: [CompletedMatch] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var isSyncing: Bool = false
    @State private var hasMore: Bool = true
    @State private var nextCursor: Date? = nil
    private let pageSize: Int = 50
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
                // Show sync progress if syncing
                if isSyncing {
                    HStack {
                        Spacer()
                        ProgressView()
                        Text("Syncing...")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

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

                    // Paging footer: infinite scroll trigger and loading state
                    if hasMore || isLoading {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .padding(.vertical, 8)
                            } else {
                                Text("Load more…")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                    .onAppear {
                                        // Schedule to next runloop to avoid state writes during view update
                                        DispatchQueue.main.async { loadNextPage() }
                                    }
                            }
                            Spacer()
                        }
                    }
                }
            }
        .navigationTitle("History")
        .toolbar { EditButton() }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search team")
        .refreshable {
            await performSync()
            resetAndLoadFirstPage()
        }
        .onAppear {
            if items.isEmpty {
                // Schedule to next runloop to avoid mutations during initial layout
                DispatchQueue.main.async { resetAndLoadFirstPage() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .matchHistoryDidChange).receive(on: RunLoop.main)) { _ in
            DispatchQueue.main.async { resetAndLoadFirstPage() }
        }
        .onChange(of: matchViewModel.matchCompleted) { _, completed in
            if completed {
                DispatchQueue.main.async { resetAndLoadFirstPage() }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        Task { await deleteMatches(at: offsets) }
    }

    private func resetAndLoadFirstPage() {
        items = []
        nextCursor = nil
        hasMore = true
        loadNextPage()
    }

    private func loadNextPage() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        let limit = pageSize
        var page: [CompletedMatch] = []
        if let sd = historyStore as? SwiftDataMatchHistoryStore {
            page = (try? sd.loadBefore(completedAt: nextCursor, limit: limit)) ?? []
        } else {
            // Fallback for non-SwiftData stores: emulate cursor by filtering on completedAt
            let all = (try? historyStore.loadAll()) ?? []
            let source = nextCursor == nil ? all : all.filter { $0.completedAt < (nextCursor ?? Date.distantFuture) }
            page = Array(source.prefix(limit))
        }
        // Deduplicate by id and maintain order
        var existing = Set(items.map { $0.id })
        let uniques = page.filter { snap in
            let seen = existing.contains(snap.id)
            if !seen { existing.insert(snap.id) }
            return !seen
        }
        items.append(contentsOf: uniques)
        nextCursor = items.last?.completedAt
        hasMore = page.count == limit
        isLoading = false
    }

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

    /// Performs manual sync with remote database and waits for completion
    private func performSync() async {
        guard let controller = matchSyncController else { return }
        isSyncing = true
        _ = controller.requestManualSync()
        // Wait briefly for sync to complete (actual sync happens async)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        isSyncing = false
    }

    @MainActor
    private func deleteMatches(at offsets: IndexSet) async {
        // Deletion operates on base items, not filtered view
        for i in offsets {
            let id = filteredItems[i].id
            matchViewModel.deleteCompletedMatch(id: id)
            try? await journalStore.deleteAll(for: id)
        }
        resetAndLoadFirstPage()
    }
}

#Preview {
    MatchHistoryView(matchViewModel: MatchViewModel(haptics: NoopHaptics()), historyStore: MatchHistoryService(), matchSyncController: nil)
}
