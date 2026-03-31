//
//  TeamsListView.swift
//  RefWatchiOS
//
//  Lists teams with search and create; navigates to TeamEditorView.
//  Shows reference catalog teams from Supabase for authenticated users.
//

import OSLog
import SwiftUI

struct TeamsListView: View {
  let teamStore: TeamLibraryStoring
  let loadReferenceCatalogOnAppear: Bool

  init(
    teamStore: TeamLibraryStoring,
    previewReferenceTeams: [ReferenceTeamOption] = [],
    loadReferenceCatalogOnAppear: Bool = true)
  {
    self.teamStore = teamStore
    self.loadReferenceCatalogOnAppear = loadReferenceCatalogOnAppear
    self._referenceTeams = State(initialValue: previewReferenceTeams)
    self._hasLoadedReferences = State(initialValue: !previewReferenceTeams.isEmpty || !loadReferenceCatalogOnAppear)
  }

  @State private var teams: [TeamRecord] = []
  @State private var referenceTeams: [ReferenceTeamOption] = []
  @State private var search: String = ""
  @State private var showingNewTeam = false
  @State private var newName: String = ""
  @State private var newShort: String = ""
  @State private var newDivision: String = ""
  @State private var errorMessage: String?
  @State private var isLoadingReferences = false
  @State private var hasLoadedReferences = false

  private var unmaterializedReferences: [ReferenceTeamOption] {
    let query = self.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let filtered = self.referenceTeams
      .filter { ReferenceCatalogService.isReferenceTeamMaterialized($0, in: self.teams) == false }
    guard !query.isEmpty else { return filtered }
    return filtered.filter { ref in
      ref.name.lowercased().contains(query)
        || (ref.shortName?.lowercased().contains(query) ?? false)
        || ref.competitionName.lowercased().contains(query)
    }
  }

  private var groupedUnmaterializedReferences: [(String, [ReferenceTeamOption])] {
    let grouped = Dictionary(grouping: self.unmaterializedReferences, by: \.competitionName)
    return grouped
      .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
      .map { ($0.key, $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
  }

  var body: some View {
    List {
      if self.teams.isEmpty && self.groupedUnmaterializedReferences.isEmpty && !self.isLoadingReferences {
        ContentUnavailableView(
          "No Teams",
          systemImage: "person.3",
          description: Text("Add teams you frequently officiate."))
      } else {
        if !self.teams.isEmpty {
          Section("Your Teams") {
            ForEach(self.teams, id: \.id) { team in
              NavigationLink(destination: TeamEditorView(teamStore: self.teamStore, team: team)) {
                VStack(alignment: .leading, spacing: 4) {
                  Text(team.name).font(.headline)
                  HStack(spacing: 8) {
                    if let short = team.shortName, !short.isEmpty { Text(short) }
                    if let div = team.division, !div.isEmpty {
                      Text(div).foregroundStyle(.secondary)
                    }
                  }.font(.caption)
                }
              }
              .swipeActions(edge: .trailing) {
                Button(role: .destructive) { self.delete(team) } label: { Label("Delete", systemImage: "trash") }
              }
            }
          }
        }

        ForEach(self.groupedUnmaterializedReferences, id: \.0) { competitionName, refs in
          Section(competitionName) {
            ForEach(refs) { ref in
              Button {
                self.materializeReference(ref)
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(ref.name).font(.headline)
                    if let short = ref.shortName, !short.isEmpty {
                      Text(short).font(.caption)
                    }
                  }
                  Spacer()
                  Image(systemName: "icloud.and.arrow.down")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }

        if self.isLoadingReferences && self.referenceTeams.isEmpty {
          Section("Reference Catalog") {
            ProgressView("Loading reference teams…")
              .frame(maxWidth: .infinity, alignment: .center)
              .listRowBackground(Color.clear)
          }
        }
      }
    }
    .navigationTitle("Teams")
    .searchable(
      text: self.$search,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search teams")
    .onChange(of: self.search) { _, _ in self.refreshLocal() }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { self.showingNewTeam = true } label: { Label("New Team", systemImage: "plus") }
      }
    }
    .sheet(isPresented: self.$showingNewTeam) {
      NavigationStack {
        Form {
          Section("Team") {
            TextField("Name", text: self.$newName)
            TextField("Short Name", text: self.$newShort)
            TextField("Division", text: self.$newDivision)
          }
        }
        .navigationTitle("New Team")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            SheetDismissButton { self.showingNewTeam = false }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Create") { self.createTeam() }
              .disabled(self.newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
      .presentationDetents([.medium, .large])
    }
    // No nested NavigationStack here; LibraryTabView owns the NavigationStack.
    .onAppear {
      self.refreshLocal()
      if self.loadReferenceCatalogOnAppear {
        self.loadReferenceCatalog()
      }
    }
    .alert("Unable to Update Teams", isPresented: self.alertBinding) {
      Button("OK", role: .cancel) {
        self.errorMessage = nil
      }
    } message: {
      Text(self.errorMessage ?? "We couldn't update your teams.")
    }
  }

  private func refreshLocal() {
    do {
      self.teams = try self.search.isEmpty ? self.teamStore.loadAllTeams() : self.teamStore
        .searchTeams(query: self.search)
    } catch {
      AppLog.library.error("Failed to load teams: \(error.localizedDescription, privacy: .public)")
      self.teams = []
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "We couldn't load your teams.")
    }
  }

  private func loadReferenceCatalog() {
    guard !self.hasLoadedReferences else { return }
    self.isLoadingReferences = true
    Task { @MainActor in
      do {
        self.referenceTeams = try await ReferenceCatalogService.fetchReferenceTeams()
      } catch {
        AppLog.library.error("Failed to load reference teams: \(error.localizedDescription, privacy: .public)")
      }
      self.isLoadingReferences = false
      self.hasLoadedReferences = true
    }
  }

  private func materializeReference(_ reference: ReferenceTeamOption) {
    do {
      _ = try ReferenceCatalogService.materializeReferenceTeam(reference, into: self.teamStore)
      self.refreshLocal()
    } catch {
      AppLog.library.error("Failed to materialize reference team: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Unable to add the reference team.")
    }
  }

  private var alertBinding: Binding<Bool> {
    Binding(
      get: { self.errorMessage != nil },
      set: { newValue in
        if newValue == false {
          self.errorMessage = nil
        }
      })
  }

  private func createTeam() {
    do {
      _ = try self.teamStore.createTeam(
        name: self.newName.trimmingCharacters(in: .whitespacesAndNewlines),
        shortName: self.newShort.trimmingCharacters(in: .whitespacesAndNewlines),
        division: self.newDivision.trimmingCharacters(in: .whitespacesAndNewlines))
      self.newName = ""
      self.newShort = ""
      self.newDivision = ""
      self.showingNewTeam = false
      self.refreshLocal()
    } catch {
      AppLog.library.error("Failed to create team: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to create teams on iPhone.")
    }
  }

  private func delete(_ team: TeamRecord) {
    do {
      try self.teamStore.deleteTeam(team)
      self.refreshLocal()
    } catch {
      AppLog.library.error("Failed to delete team: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to delete teams from your library.")
    }
  }

  private func errorDisplayMessage(for error: Error, fallback: String) -> String {
    if let authError = error as? PersistenceAuthError {
      return authError.errorDescription ?? fallback
    }
    if let localized = (error as NSError).localizedFailureReason {
      return localized
    }
    return fallback
  }
}

#Preview("Empty Library") {
  NavigationStack {
    TeamsListView(
      teamStore: InMemoryTeamLibraryStore(),
      loadReferenceCatalogOnAppear: false)
  }
}

#Preview("With Reference Catalog") {
  NavigationStack {
    TeamsListView(teamStore: InMemoryTeamLibraryStore())
  }
}
