//
//  LibrarySettingsView.swift
//  RefZoneiOS
//

import SwiftUI

struct LibrarySettingsView: View {
    let teamStore: TeamLibraryStoring
    let competitionStore: CompetitionLibraryStoring
    let venueStore: VenueLibraryStoring

    var body: some View {
        List {
            Section("Collections") {
                NavigationLink { TeamsListView(teamStore: teamStore) } label: {
                    Label("Teams", systemImage: "person.3")
                }
                NavigationLink { CompetitionsListView(store: competitionStore) } label: {
                    Label("Competitions", systemImage: "trophy")
                }
                NavigationLink { VenuesListView(store: venueStore) } label: {
                    Label("Venues", systemImage: "building.2")
                }
            }
        }
        .navigationTitle("Library")
    }
}

#Preview {
    NavigationStack {
        LibrarySettingsView(
            teamStore: InMemoryTeamLibraryStore(),
            competitionStore: InMemoryCompetitionLibraryStore(),
            venueStore: InMemoryVenueLibraryStore()
        )
    }
}
