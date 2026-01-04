//
//  MatchHistoryView.swift
//  RefWatchiOS
//
//  Dedicated iOS history list for completed matches.
//

import Combine
import RefWatchCore
import SwiftUI

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
  @State private var nextCursor: Date?
  private let pageSize: Int = 50
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List {
      // Show sync progress if syncing
      if self.isSyncing {
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

      let data = self.filteredItems
      if data.isEmpty {
        if self.searchText.isEmpty {
          VStack(spacing: 12) {
            ContentUnavailableView(
              "No Completed Matches",
              systemImage: "clock",
              description: Text("Finish a match to see it here."))
            Button {
              self.dismiss()
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
            description: Text("No matches found for \"\(self.searchText)\"."))
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
        .onDelete(perform: self.delete)

        // Paging footer: infinite scroll trigger and loading state
        if self.hasMore || self.isLoading {
          HStack {
            Spacer()
            if self.isLoading {
              ProgressView()
                .progressViewStyle(.circular)
                .padding(.vertical, 8)
            } else {
              Text("Load more…")
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .onAppear {
                  // Schedule to next runloop to avoid state writes during view update
                  DispatchQueue.main.async { self.loadNextPage() }
                }
            }
            Spacer()
          }
        }
      }
    }
    .navigationTitle("History")
    .toolbar { EditButton() }
    .searchable(text: self.$searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search team")
    .refreshable {
      await self.performSync()
      self.resetAndLoadFirstPage()
    }
    .onAppear {
      if self.items.isEmpty {
        // Schedule to next runloop to avoid mutations during initial layout
        DispatchQueue.main.async { self.resetAndLoadFirstPage() }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .matchHistoryDidChange).receive(on: RunLoop.main)) { _ in
      DispatchQueue.main.async { self.resetAndLoadFirstPage() }
    }
    .onChange(of: self.matchViewModel.matchCompleted) { _, completed in
      if completed {
        DispatchQueue.main.async { self.resetAndLoadFirstPage() }
      }
    }
  }

  private func delete(at offsets: IndexSet) {
    Task { await self.deleteMatches(at: offsets) }
  }

  private func resetAndLoadFirstPage() {
    self.items = []
    self.nextCursor = nil
    self.hasMore = true
    self.loadNextPage()
  }

  private func loadNextPage() {
    guard !self.isLoading, self.hasMore else { return }
    self.isLoading = true
    let limit = self.pageSize
    var page: [CompletedMatch] = []
    if let sd = historyStore as? SwiftDataMatchHistoryStore {
      page = (try? sd.loadBefore(completedAt: self.nextCursor, limit: limit)) ?? []
    } else {
      // Fallback for non-SwiftData stores: emulate cursor by filtering on completedAt
      let all = (try? self.historyStore.loadAll()) ?? []
      let source = self.nextCursor == nil ? all : all
        .filter { $0.completedAt < (self.nextCursor ?? Date.distantFuture) }
      page = Array(source.prefix(limit))
    }
    // Deduplicate by id and maintain order
    var existing = Set(items.map(\.id))
    let uniques = page.filter { snap in
      let seen = existing.contains(snap.id)
      if !seen { existing.insert(snap.id) }
      return !seen
    }
    self.items.append(contentsOf: uniques)
    self.nextCursor = self.items.last?.completedAt
    self.hasMore = page.count == limit
    self.isLoading = false
  }

  private var filteredItems: [CompletedMatch] {
    let q = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return self.items }
    return self.items.filter { item in
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
    self.isSyncing = true
    _ = controller.requestManualSync()
    // Wait briefly for sync to complete (actual sync happens async)
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    self.isSyncing = false
  }

  @MainActor
  private func deleteMatches(at offsets: IndexSet) async {
    // Deletion operates on base items, not filtered view
    for i in offsets {
      let id = self.filteredItems[i].id
      self.matchViewModel.deleteCompletedMatch(id: id)
      try? await self.journalStore.deleteAll(for: id)
    }
    self.resetAndLoadFirstPage()
  }
}

#Preview {
  MatchHistoryView(
    matchViewModel: MatchViewModel(haptics: NoopHaptics()),
    historyStore: MatchHistoryService(),
    matchSyncController: nil)
}
