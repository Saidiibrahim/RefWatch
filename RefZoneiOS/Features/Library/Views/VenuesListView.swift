//
//  VenuesListView.swift
//  RefZoneiOS
//
//  List view for browsing and managing venues in the library.
//

import SwiftUI

struct VenuesListView: View {
    let store: VenueLibraryStoring
    @State private var venues: [VenueRecord] = []
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editingVenue: VenueRecord? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if filteredVenues.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Venues",
                        systemImage: "building.2",
                        description: Text("Add a venue to track where matches are played.")
                    )
                } else {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No venues found for \"\(searchText)\".")
                    )
                }
            } else {
                ForEach(filteredVenues) { venue in
                    Button {
                        editingVenue = venue
                        showingEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(venue.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if let city = venue.city, let country = venue.country {
                                Text("\(city), \(country)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let city = venue.city {
                                Text(city)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let country = venue.country {
                                Text(country)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteVenues)
            }
        }
        .navigationTitle("Venues")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search venues")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingVenue = nil
                    showingEditor = true
                } label: {
                    Label("Add Venue", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingEditor) {
            VenueEditorView(
                store: store,
                venue: editingVenue,
                onSave: {
                    refreshVenues()
                    showingEditor = false
                }
            )
        }
        .onAppear {
            refreshVenues()
        }
        .onReceive(store.changesPublisher) { _ in
            refreshVenues()
        }
    }

    private var filteredVenues: [VenueRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return venues }
        return venues.filter { venue in
            venue.name.localizedCaseInsensitiveContains(query) ||
            (venue.city?.localizedCaseInsensitiveContains(query) ?? false) ||
            (venue.country?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func refreshVenues() {
        venues = (try? store.loadAll()) ?? []
    }

    private func deleteVenues(at offsets: IndexSet) {
        for index in offsets {
            let venue = filteredVenues[index]
            try? store.delete(venue)
        }
        refreshVenues()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        VenuesListView(store: InMemoryVenueLibraryStore(preloadedVenues: [
            VenueRecord(
                id: UUID(),
                name: "Wembley Stadium",
                city: "London",
                country: "England",
                latitude: 51.5560,
                longitude: -0.2795,
                ownerSupabaseId: "test-user",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            ),
            VenueRecord(
                id: UUID(),
                name: "Emirates Stadium",
                city: "London",
                country: "England",
                latitude: 51.5549,
                longitude: -0.1084,
                ownerSupabaseId: "test-user",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            )
        ]))
    }
}
#endif