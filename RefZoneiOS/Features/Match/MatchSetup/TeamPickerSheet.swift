//
//  TeamPickerSheet.swift
//  RefZoneiOS
//
//  Select a saved team from the library with lightweight search support.
//

import SwiftUI

struct TeamPickerSheet: View {
    let teamStore: TeamLibraryStoring
    let onSelect: (TeamRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var teams: [TeamRecord] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var loadError: String?

    private var filteredTeams: [TeamRecord] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return teams }
        let lowercased = trimmed.lowercased()
        return teams.filter { team in
            team.name.lowercased().contains(lowercased) ||
            (team.division?.lowercased().contains(lowercased) ?? false) ||
            (team.shortName?.lowercased().contains(lowercased) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading teams…")
                } else if let error = loadError {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if teams.isEmpty {
                    ContentUnavailableView(
                        "No Teams Yet",
                        systemImage: "person.3",
                        description: Text("Create teams in Settings → Library → Teams")
                    )
                } else {
                    teamList
                }
            }
            .navigationTitle("Select Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search teams")
            .onAppear(perform: loadTeams)
        }
    }

    private var teamList: some View {
        List {
            let results = filteredTeams
            if results.isEmpty {
                ContentUnavailableView(
                    "No Teams Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ForEach(results, id: \.id) { team in
                    Button {
                        onSelect(team)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .font(.headline)
                            if let division = team.division, division.isEmpty == false {
                                Text(division)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func loadTeams() {
        isLoading = true
        loadError = nil
        do {
            teams = try teamStore.loadAllTeams()
        } catch {
            loadError = error.localizedDescription
            teams = []
        }
        isLoading = false
    }
}

#if DEBUG
struct TeamPickerSheet_Previews: PreviewProvider {
    @MainActor static func previewStore() -> TeamLibraryStoring {
        let store = InMemoryTeamLibraryStore()
        _ = try? store.createTeam(name: "Arsenal", shortName: "ARS", division: "Premier League")
        _ = try? store.createTeam(name: "Chelsea", shortName: "CHE", division: "Premier League")
        _ = try? store.createTeam(name: "Barcelona", shortName: "FCB", division: "La Liga")
        return store
    }

    static var previews: some View {
        TeamPickerSheet(teamStore: previewStore()) { _ in }
    }
}
#endif
