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
      ForEach(self.teams, id: \.id) { team in
        Button {
          self.onSelect(team)
          self.dismiss()
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(team.name)
            if let div = team.division, !div.isEmpty {
              Text(div)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle("Select Team")
    .searchable(text: self.$search)
    .onChange(of: self.search) { _, _ in self.refresh() }
    .onAppear { self.refresh() }
  }

  private func refresh() {
    do {
      self.teams = try self.search.isEmpty
        ? self.teamStore.loadAllTeams()
        : self.teamStore.searchTeams(query: self.search)
    } catch {
      self.teams = []
    }
  }
}

#Preview { NavigationStack { TeamsPickerView(teamStore: InMemoryTeamLibraryStore(), onSelect: { _ in }) } }
