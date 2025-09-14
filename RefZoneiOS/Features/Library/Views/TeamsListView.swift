//
//  TeamsListView.swift
//  RefZoneiOS
//
//  Lists teams with search and create; navigates to TeamEditorView.
//

import SwiftUI
import OSLog

struct TeamsListView: View {
    let teamStore: TeamLibraryStoring

    @State private var teams: [TeamRecord] = []
    @State private var search: String = ""
    @State private var showingNewTeam = false
    @State private var newName: String = ""
    @State private var newShort: String = ""
    @State private var newDivision: String = ""

    var body: some View {
        List {
            if teams.isEmpty {
                ContentUnavailableView(
                    "No Teams",
                    systemImage: "person.3",
                    description: Text("Add teams you frequently officiate.")
                )
            } else {
                ForEach(teams, id: \.id) { team in
                    NavigationLink(destination: TeamEditorView(teamStore: teamStore, team: team)) {
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
                        Button(role: .destructive) { delete(team) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("Teams")
        .searchable(text: $search)
        .onChange(of: search) { _ in refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewTeam = true } label: { Label("New Team", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showingNewTeam) {
            NavigationStack {
                Form {
                    Section("Team") {
                        TextField("Name", text: $newName)
                        TextField("Short Name", text: $newShort)
                        TextField("Division", text: $newDivision)
                    }
                }
                .navigationTitle("New Team")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingNewTeam = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Create") { createTeam() }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
            }
            .presentationDetents([.medium, .large])
        }
        // No nested NavigationStack here; LibraryTabView owns the NavigationStack.
        .onAppear { refresh() }
    }

    private func refresh() {
        do {
            teams = try search.isEmpty ? teamStore.loadAllTeams() : teamStore.searchTeams(query: search)
        } catch {
            AppLog.library.error("Failed to load teams: \(error.localizedDescription, privacy: .public)")
            teams = []
        }
    }

    private func createTeam() {
        do {
            _ = try teamStore.createTeam(name: newName.trimmingCharacters(in: .whitespacesAndNewlines), shortName: newShort.trimmingCharacters(in: .whitespacesAndNewlines), division: newDivision.trimmingCharacters(in: .whitespacesAndNewlines))
            newName = ""; newShort = ""; newDivision = ""; showingNewTeam = false
            refresh()
        } catch {
            AppLog.library.error("Failed to create team: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func delete(_ team: TeamRecord) {
        do {
            try teamStore.deleteTeam(team)
            refresh()
        } catch {
            AppLog.library.error("Failed to delete team: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview { NavigationStack { TeamsListView(teamStore: InMemoryTeamLibraryStore()) } }
