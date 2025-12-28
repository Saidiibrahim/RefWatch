//
//  TeamsPickerView.swift
//  RefWatchiOS
//
//  Simple searchable picker for selecting a team from library.
//

import SwiftUI

struct TeamsPickerView: View {
    let teamStore: TeamLibraryStoring
    var onSelect: (TeamRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var teams: [TeamRecord] = []
    @State private var search: String = ""

    var body: some View {
        List {
            ForEach(teams, id: \.id) { team in
                Button {
                    onSelect(team)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                        if let div = team.division, !div.isEmpty { Text(div).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .navigationTitle("Select Team")
        .searchable(text: $search)
        .onChange(of: search) { _, _ in refresh() }
        .onAppear { refresh() }
    }

    private func refresh() {
        do { teams = try search.isEmpty ? teamStore.loadAllTeams() : teamStore.searchTeams(query: search) } catch { teams = [] }
    }
}

#Preview { NavigationStack { TeamsPickerView(teamStore: InMemoryTeamLibraryStore(), onSelect: { _ in }) } }
