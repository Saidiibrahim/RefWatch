//
//  VenueEditorView.swift
//  RefZoneiOS
//
//  Form for creating and editing venues.
//

import SwiftUI

struct VenueEditorView: View {
    let store: VenueLibraryStoring
    let venue: VenueRecord?
    let onSave: () -> Void

    @State private var name: String
    @State private var city: String
    @State private var country: String
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    init(store: VenueLibraryStoring, venue: VenueRecord?, onSave: @escaping () -> Void) {
        self.store = store
        self.venue = venue
        self.onSave = onSave

        _name = State(initialValue: venue?.name ?? "")
        _city = State(initialValue: venue?.city ?? "")
        _country = State(initialValue: venue?.country ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Venue Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                } footer: {
                    Text("Required. E.g., \"Wembley Stadium\", \"City Sports Complex\"")
                }

                Section {
                    TextField("City", text: $city)
                        .autocorrectionDisabled()
                    TextField("Country", text: $country)
                        .autocorrectionDisabled()
                } header: {
                    Text("Location")
                } footer: {
                    Text("Optional. E.g., \"London\", \"England\"")
                }

                Section {
                    if let venue, let latitude = venue.latitude, let longitude = venue.longitude {
                        HStack {
                            Text("Coordinates")
                            Spacer()
                            Text("\(latitude, specifier: "%.4f"), \(longitude, specifier: "%.4f")")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No coordinates set")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Coordinates")
                } footer: {
                    Text("Future: map picker for setting venue location")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(venue == nil ? "New Venue" : "Edit Venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVenue()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveVenue() {
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name is required"
            return
        }

        guard trimmedName.count <= 100 else {
            errorMessage = "Name must be 100 characters or less"
            return
        }

        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let cityToSave = trimmedCity.isEmpty ? nil : trimmedCity

        if let cityToSave, cityToSave.count > 100 {
            errorMessage = "City must be 100 characters or less"
            return
        }

        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryToSave = trimmedCountry.isEmpty ? nil : trimmedCountry

        if let countryToSave, countryToSave.count > 100 {
            errorMessage = "Country must be 100 characters or less"
            return
        }

        do {
            if let venue {
                // Update existing
                venue.name = trimmedName
                venue.city = cityToSave
                venue.country = countryToSave
                try store.update(venue)
            } else {
                // Create new
                _ = try store.create(name: trimmedName, city: cityToSave, country: countryToSave)
            }
            onSave()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
#Preview("New Venue") {
    VenueEditorView(
        store: InMemoryVenueLibraryStore(),
        venue: nil,
        onSave: {}
    )
}

#Preview("Edit Venue") {
    let record = VenueRecord(
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
    )
    VenueEditorView(
        store: InMemoryVenueLibraryStore(preloadedVenues: [record]),
        venue: record,
        onSave: {}
    )
}
#endif