//
//  VenueEditorView.swift
//  RefWatchiOS
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
  @State private var errorMessage: String?
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
          TextField("Venue Name", text: self.$name)
            .autocorrectionDisabled()
        } header: {
          Text("Name")
        } footer: {
          Text("Required. E.g., \"Wembley Stadium\", \"City Sports Complex\"")
        }

        Section {
          TextField("City", text: self.$city)
            .autocorrectionDisabled()
          TextField("Country", text: self.$country)
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
      .navigationTitle(self.venue == nil ? "New Venue" : "Edit Venue")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            self.saveVenue()
          }
          .disabled(!self.isValid)
        }
      }
    }
  }

  private var isValid: Bool {
    !self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func saveVenue() {
    self.errorMessage = nil

    let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      self.errorMessage = "Name is required"
      return
    }

    guard trimmedName.count <= 100 else {
      self.errorMessage = "Name must be 100 characters or less"
      return
    }

    let trimmedCity = self.city.trimmingCharacters(in: .whitespacesAndNewlines)
    let cityToSave = trimmedCity.isEmpty ? nil : trimmedCity

    if let cityToSave, cityToSave.count > 100 {
      self.errorMessage = "City must be 100 characters or less"
      return
    }

    let trimmedCountry = self.country.trimmingCharacters(in: .whitespacesAndNewlines)
    let countryToSave = trimmedCountry.isEmpty ? nil : trimmedCountry

    if let countryToSave, countryToSave.count > 100 {
      self.errorMessage = "Country must be 100 characters or less"
      return
    }

    do {
      if let venue {
        // Update existing
        venue.name = trimmedName
        venue.city = cityToSave
        venue.country = countryToSave
        try self.store.update(venue)
      } else {
        // Create new
        _ = try self.store.create(name: trimmedName, city: cityToSave, country: countryToSave)
      }
      self.onSave()
    } catch {
      self.errorMessage = "Failed to save: \(error.localizedDescription)"
    }
  }
}

#if DEBUG
#Preview("New Venue") {
  VenueEditorView(
    store: InMemoryVenueLibraryStore(),
    venue: nil,
    onSave: {})
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
    needsRemoteSync: false)
  VenueEditorView(
    store: InMemoryVenueLibraryStore(preloadedVenues: [record]),
    venue: record,
    onSave: {})
}
#endif
