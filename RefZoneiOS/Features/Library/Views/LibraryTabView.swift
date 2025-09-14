//
//  LibraryTabView.swift
//  RefZoneiOS
//
//  Placeholder Library hub for Teams/Competitions/Venues
//

import SwiftUI

struct LibraryTabView: View {
    let teamStore: TeamLibraryStoring

    var body: some View {
        NavigationStack {
            List {
                Section("Collections") {
                    NavigationLink { TeamsListView(teamStore: teamStore) } label: {
                        Label("Teams", systemImage: "person.3")
                    }
                    NavigationLink { Text("Competitions (coming soon)").navigationTitle("Competitions") } label: {
                        Label("Competitions", systemImage: "trophy")
                    }
                    NavigationLink { Text("Venues (coming soon)").navigationTitle("Venues") } label: {
                        Label("Venues", systemImage: "building.2")
                    }
                }
            }
            .navigationTitle("Library")
        }
    }
}

#Preview { NavigationStack { LibraryTabView(teamStore: InMemoryTeamLibraryStore()) } }
