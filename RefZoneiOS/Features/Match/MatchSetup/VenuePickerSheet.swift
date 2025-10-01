//
//  VenuePickerSheet.swift
//  RefZoneiOS
//
//  Sheet interface for selecting a saved venue from the library.
//

import SwiftUI

struct VenuePickerSheet: View {
    let venueStore: VenueLibraryStoring
    let onSelect: (VenueRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var venues: [VenueRecord] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var loadError: String?

    private var filteredVenues: [VenueRecord] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return venues }
        let lowercased = trimmed.lowercased()
        return venues.filter { venue in
            venue.name.lowercased().contains(lowercased) ||
            (venue.city?.lowercased().contains(lowercased) ?? false) ||
            (venue.country?.lowercased().contains(lowercased) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading venues…")
                } else if let error = loadError {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if venues.isEmpty {
                    ContentUnavailableView(
                        "No Venues Yet",
                        systemImage: "building.2",
                        description: Text("Create venues in Settings → Library → Venues")
                    )
                } else {
                    venueList
                }
            }
            .navigationTitle("Select Venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search venues")
            .onAppear(perform: loadVenues)
        }
    }

    private var venueList: some View {
        List {
            let results = filteredVenues
            if results.isEmpty {
                ContentUnavailableView(
                    "No Venues Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ForEach(results, id: \.id) { venue in
                    Button {
                        onSelect(venue)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(venue.name)
                                .font(.headline)
                            if let subtitle = subtitle(for: venue) {
                                Text(subtitle)
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

    private func subtitle(for venue: VenueRecord) -> String? {
        switch (venue.city, venue.country) {
        case let (city?, country?) where !city.isEmpty && !country.isEmpty:
            return "\(city), \(country)"
        case let (city?, _) where !city.isEmpty:
            return city
        case let (_, country?) where !country.isEmpty:
            return country
        default:
            return nil
        }
    }

    private func loadVenues() {
        isLoading = true
        loadError = nil
        do {
            venues = try venueStore.loadAll()
        } catch {
            loadError = error.localizedDescription
            venues = []
        }
        isLoading = false
    }
}

#if DEBUG
struct VenuePickerSheet_Previews: PreviewProvider {
    static func previewStore() -> VenueLibraryStoring {
        let store = InMemoryVenueLibraryStore()
        _ = try? store.create(name: "Wembley Stadium", city: "London", country: "England")
        _ = try? store.create(name: "Emirates Stadium", city: "London", country: "England")
        _ = try? store.create(name: "Parc des Princes", city: "Paris", country: "France")
        return store
    }

    static var previews: some View {
        VenuePickerSheet(venueStore: previewStore()) { _ in }
    }
}
#endif
