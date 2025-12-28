//
//  CompetitionsListView.swift
//  RefWatchiOS
//
//  List view for browsing and managing competitions in the library.
//

import SwiftUI

struct CompetitionsListView: View {
    let store: CompetitionLibraryStoring
    @State private var competitions: [CompetitionRecord] = []
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editingCompetition: CompetitionRecord? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if filteredCompetitions.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Competitions",
                        systemImage: "trophy",
                        description: Text("Add a competition to organize your matches.")
                    )
                } else {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No competitions found for \"\(searchText)\".")
                    )
                }
            } else {
                ForEach(filteredCompetitions) { competition in
                    Button {
                        editingCompetition = competition
                        showingEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(competition.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if let level = competition.level {
                                Text(level)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteCompetitions)
            }
        }
        .navigationTitle("Competitions")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search competitions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCompetition = nil
                    showingEditor = true
                } label: {
                    Label("Add Competition", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingEditor) {
            CompetitionEditorView(
                store: store,
                competition: editingCompetition,
                onSave: {
                    refreshCompetitions()
                    showingEditor = false
                }
            )
        }
        .onAppear {
            refreshCompetitions()
        }
        .onReceive(store.changesPublisher) { _ in
            refreshCompetitions()
        }
    }

    private var filteredCompetitions: [CompetitionRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return competitions }
        return competitions.filter { competition in
            competition.name.localizedCaseInsensitiveContains(query) ||
            (competition.level?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func refreshCompetitions() {
        competitions = (try? store.loadAll()) ?? []
    }

    private func deleteCompetitions(at offsets: IndexSet) {
        for index in offsets {
            let competition = filteredCompetitions[index]
            try? store.delete(competition)
        }
        refreshCompetitions()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CompetitionsListView(store: InMemoryCompetitionLibraryStore(preloadedCompetitions: [
            CompetitionRecord(
                id: UUID(),
                name: "Premier League",
                level: "Professional",
                ownerSupabaseId: "test-user",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            ),
            CompetitionRecord(
                id: UUID(),
                name: "Champions League",
                level: "Professional",
                ownerSupabaseId: "test-user",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            )
        ]))
    }
}
#endif