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
  @State private var editingCompetition: CompetitionRecord?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List {
      if self.filteredCompetitions.isEmpty {
        if self.searchText.isEmpty {
          ContentUnavailableView(
            "No Competitions",
            systemImage: "trophy",
            description: Text("Add a competition to organize your matches."))
        } else {
          ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No competitions found for \"\(self.searchText)\"."))
        }
      } else {
        ForEach(self.filteredCompetitions) { competition in
          Button {
            self.editingCompetition = competition
            self.showingEditor = true
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
        .onDelete(perform: self.deleteCompetitions)
      }
    }
    .navigationTitle("Competitions")
    .searchable(
      text: self.$searchText,
      placement: .navigationBarDrawer(displayMode: .automatic),
      prompt: "Search competitions")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          self.editingCompetition = nil
          self.showingEditor = true
        } label: {
          Label("Add Competition", systemImage: "plus")
        }
      }
      ToolbarItem(placement: .topBarLeading) {
        EditButton()
      }
    }
    .sheet(isPresented: self.$showingEditor) {
      CompetitionEditorView(
        store: self.store,
        competition: self.editingCompetition,
        onSave: {
          self.refreshCompetitions()
          self.showingEditor = false
        })
    }
    .onAppear {
      self.refreshCompetitions()
    }
    .onReceive(self.store.changesPublisher) { _ in
      self.refreshCompetitions()
    }
  }

  private var filteredCompetitions: [CompetitionRecord] {
    let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return self.competitions }
    return self.competitions.filter { competition in
      competition.name.localizedCaseInsensitiveContains(query) ||
        (competition.level?.localizedCaseInsensitiveContains(query) ?? false)
    }
  }

  private func refreshCompetitions() {
    self.competitions = (try? self.store.loadAll()) ?? []
  }

  private func deleteCompetitions(at offsets: IndexSet) {
    for index in offsets {
      let competition = self.filteredCompetitions[index]
      try? self.store.delete(competition)
    }
    self.refreshCompetitions()
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
        needsRemoteSync: false),
      CompetitionRecord(
        id: UUID(),
        name: "Champions League",
        level: "Professional",
        ownerSupabaseId: "test-user",
        lastModifiedAt: Date(),
        remoteUpdatedAt: nil,
        needsRemoteSync: false),
    ]))
  }
}
#endif
