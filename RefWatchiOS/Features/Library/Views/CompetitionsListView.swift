//
//  CompetitionsListView.swift
//  RefWatchiOS
//
//  List view for browsing and managing competitions in the library.
//  Shows reference catalog competitions from Supabase for authenticated users.
//

import SwiftUI

struct CompetitionsListView: View {
  let store: CompetitionLibraryStoring

  init(store: CompetitionLibraryStoring, previewReferenceCompetitions: [ReferenceCompetitionOption] = []) {
    self.store = store
    self._referenceCompetitions = State(initialValue: previewReferenceCompetitions)
    self._hasLoadedReferences = State(initialValue: !previewReferenceCompetitions.isEmpty)
  }

  @State private var competitions: [CompetitionRecord] = []
  @State private var referenceCompetitions: [ReferenceCompetitionOption] = []
  @State private var searchText = ""
  @State private var showingEditor = false
  @State private var editingCompetition: CompetitionRecord?
  @State private var isLoadingReferences = false
  @State private var hasLoadedReferences = false
  @State private var errorMessage: String?
  @Environment(\.dismiss) private var dismiss

  private var filteredCompetitions: [CompetitionRecord] {
    let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return self.competitions }
    return self.competitions.filter { competition in
      competition.name.localizedCaseInsensitiveContains(query) ||
        (competition.level?.localizedCaseInsensitiveContains(query) ?? false)
    }
  }

  private var unmaterializedReferences: [ReferenceCompetitionOption] {
    let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let filtered = self.referenceCompetitions
      .filter { ReferenceCatalogService.isReferenceCompetitionMaterialized($0, in: self.competitions) == false }
    guard !query.isEmpty else { return filtered }
    return filtered.filter { ref in
      ref.name.lowercased().contains(query) || ref.code.lowercased().contains(query)
    }
  }

  var body: some View {
    List {
      if self.filteredCompetitions.isEmpty && self.unmaterializedReferences.isEmpty && !self.isLoadingReferences {
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
        if !self.filteredCompetitions.isEmpty {
          Section("Your Competitions") {
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

        if !self.unmaterializedReferences.isEmpty {
          Section {
            ForEach(self.unmaterializedReferences) { ref in
              Button {
                self.materializeReference(ref)
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(ref.name)
                      .font(.body)
                      .foregroundStyle(.primary)
                    Text(ref.code.uppercased())
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "icloud.and.arrow.down")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                }
              }
              .buttonStyle(.plain)
            }
          } header: {
            Text("Reference Catalog")
          } footer: {
            Text("Tap to add a reference competition to your library.")
          }
        }

        if self.isLoadingReferences && self.referenceCompetitions.isEmpty {
          Section("Reference Catalog") {
            ProgressView("Loading reference competitions…")
              .frame(maxWidth: .infinity, alignment: .center)
              .listRowBackground(Color.clear)
          }
        }
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
      self.loadReferenceCatalog()
    }
    .onReceive(self.store.changesPublisher) { _ in
      self.refreshCompetitions()
    }
    .alert("Unable to Update Competitions", isPresented: self.alertBinding) {
      Button("OK", role: .cancel) { self.errorMessage = nil }
    } message: {
      Text(self.errorMessage ?? "We couldn't update your competitions.")
    }
  }

  private var alertBinding: Binding<Bool> {
    Binding(
      get: { self.errorMessage != nil },
      set: { newValue in
        if newValue == false { self.errorMessage = nil }
      })
  }

  private func refreshCompetitions() {
    self.competitions = (try? self.store.loadAll()) ?? []
  }

  private func loadReferenceCatalog() {
    guard !self.hasLoadedReferences else { return }
    self.isLoadingReferences = true
    Task { @MainActor in
      do {
        self.referenceCompetitions = try await ReferenceCatalogService.fetchReferenceCompetitions()
      } catch {
        // Silently fail — user still has local competitions.
      }
      self.isLoadingReferences = false
      self.hasLoadedReferences = true
    }
  }

  private func materializeReference(_ reference: ReferenceCompetitionOption) {
    do {
      _ = try ReferenceCatalogService.materializeReferenceCompetition(reference, into: self.store)
      self.refreshCompetitions()
    } catch {
      self.errorMessage = "Unable to add the reference competition."
    }
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
#Preview("With Local Competitions") {
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

#Preview("With Reference Catalog") {
  NavigationStack {
    CompetitionsListView(
      store: InMemoryCompetitionLibraryStore(),
      previewReferenceCompetitions: [
        ReferenceCompetitionOption(id: UUID(), code: "PSL", name: "Premier Soccer League"),
        ReferenceCompetitionOption(id: UUID(), code: "NFD", name: "National First Division"),
        ReferenceCompetitionOption(id: UUID(), code: "NED", name: "Nedbank Cup"),
      ]
    )
  }
}
#endif
