//
//  VenuesListView.swift
//  RefWatchiOS
//
//  List view for browsing and managing venues in the library.
//

import SwiftUI

struct VenuesListView: View {
  let store: VenueLibraryStoring
  @State private var venues: [VenueRecord] = []
  @State private var searchText = ""
  @State private var showingEditor = false
  @State private var editingVenue: VenueRecord?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List {
      if self.filteredVenues.isEmpty {
        if self.searchText.isEmpty {
          ContentUnavailableView(
            "No Venues",
            systemImage: "building.2",
            description: Text("Add a venue to track where matches are played."))
        } else {
          ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No venues found for \"\(self.searchText)\"."))
        }
      } else {
        ForEach(self.filteredVenues) { venue in
          Button {
            self.editingVenue = venue
            self.showingEditor = true
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
        .onDelete(perform: self.deleteVenues)
      }
    }
    .navigationTitle("Venues")
    .searchable(
      text: self.$searchText,
      placement: .navigationBarDrawer(displayMode: .automatic),
      prompt: "Search venues")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          self.editingVenue = nil
          self.showingEditor = true
        } label: {
          Label("Add Venue", systemImage: "plus")
        }
      }
      ToolbarItem(placement: .topBarLeading) {
        EditButton()
      }
    }
    .sheet(isPresented: self.$showingEditor) {
      VenueEditorView(
        store: self.store,
        venue: self.editingVenue,
        onSave: {
          self.refreshVenues()
          self.showingEditor = false
        })
    }
    .onAppear {
      self.refreshVenues()
    }
    .onReceive(self.store.changesPublisher) { _ in
      self.refreshVenues()
    }
  }

  private var filteredVenues: [VenueRecord] {
    let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return self.venues }
    return self.venues.filter { venue in
      venue.name.localizedCaseInsensitiveContains(query) ||
        (venue.city?.localizedCaseInsensitiveContains(query) ?? false) ||
        (venue.country?.localizedCaseInsensitiveContains(query) ?? false)
    }
  }

  private func refreshVenues() {
    self.venues = (try? self.store.loadAll()) ?? []
  }

  private func deleteVenues(at offsets: IndexSet) {
    for index in offsets {
      let venue = self.filteredVenues[index]
      try? self.store.delete(venue)
    }
    self.refreshVenues()
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
        needsRemoteSync: false),
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
        needsRemoteSync: false),
    ]))
  }
}
#endif
