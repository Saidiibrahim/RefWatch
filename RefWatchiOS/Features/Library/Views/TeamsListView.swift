//
//  TeamsListView.swift
//  RefWatchiOS
//
//  Lists teams with search and create; navigates to TeamEditorView.
//

import OSLog
import SwiftUI

struct TeamsListView: View {
  let teamStore: TeamLibraryStoring

  @State private var teams: [TeamRecord] = []
  @State private var search: String = ""
  @State private var showingNewTeam = false
  @State private var newName: String = ""
  @State private var newShort: String = ""
  @State private var newDivision: String = ""
  @State private var errorMessage: String?

  var body: some View {
    List {
      if self.teams.isEmpty {
        ContentUnavailableView(
          "No Teams",
          systemImage: "person.3",
          description: Text("Add teams you frequently officiate."))
      } else {
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
    .navigationTitle("Teams")
    .searchable(text: self.$search)
    .onChange(of: self.search) { _, _ in self.refresh() }
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
            Button("Cancel") { self.showingNewTeam = false }
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
    .onAppear { self.refresh() }
    .alert("Unable to Update Teams", isPresented: Binding(
      get: { self.errorMessage != nil },
      set: { if $0 == false { self.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) { self.errorMessage = nil }
    } message: {
      Text(self.errorMessage ?? "Sign in on your phone to manage teams.")
    }
  }

  private func refresh() {
    do {
      self.teams = try self.search.isEmpty ? self.teamStore.loadAllTeams() : self.teamStore
        .searchTeams(query: self.search)
    } catch {
      AppLog.library.error("Failed to load teams: \(error.localizedDescription, privacy: .public)")
      self.teams = []
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "We couldn't load your teams.")
    }
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
      self.refresh()
    } catch {
      AppLog.library.error("Failed to create team: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to create teams on iPhone.")
    }
  }

  private func delete(_ team: TeamRecord) {
    do {
      try self.teamStore.deleteTeam(team)
      self.refresh()
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

#Preview { NavigationStack { TeamsListView(teamStore: InMemoryTeamLibraryStore()) } }
