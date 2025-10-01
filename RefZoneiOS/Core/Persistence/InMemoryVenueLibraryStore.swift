//
//  InMemoryVenueLibraryStore.swift
//  RefZoneiOS
//
//  In-memory implementation of VenueLibraryStoring for testing and previews.
//

import Foundation
import Combine

/// In-memory implementation of venue storage for testing
final class InMemoryVenueLibraryStore: VenueLibraryStoring {
    private var venues: [VenueRecord] = []
    private let changesSubject = PassthroughSubject<[VenueRecord], Never>()

    var changesPublisher: AnyPublisher<[VenueRecord], Never> {
        changesSubject.eraseToAnyPublisher()
    }

    init(preloadedVenues: [VenueRecord] = []) {
        self.venues = preloadedVenues
    }

    func loadAll() throws -> [VenueRecord] {
        venues.sorted { $0.name < $1.name }
    }

    func search(query: String) throws -> [VenueRecord] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try loadAll()
        }

        let lowercased = query.lowercased()
        return venues
            .filter {
                $0.name.lowercased().contains(lowercased) ||
                ($0.city?.lowercased().contains(lowercased) ?? false) ||
                ($0.country?.lowercased().contains(lowercased) ?? false)
            }
            .sorted { $0.name < $1.name }
    }

    func create(name: String, city: String?, country: String?) throws -> VenueRecord {
        let record = VenueRecord(
            id: UUID(),
            name: name,
            city: city,
            country: country,
            latitude: nil,
            longitude: nil,
            ownerSupabaseId: "test-user",
            lastModifiedAt: Date(),
            remoteUpdatedAt: nil,
            needsRemoteSync: true
        )

        venues.append(record)
        notifyChanges()

        return record
    }

    func update(_ venue: VenueRecord) throws {
        guard let index = venues.firstIndex(where: { $0.id == venue.id }) else {
            throw NSError(domain: "InMemoryStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Venue not found"])
        }

        venue.lastModifiedAt = Date()
        venue.needsRemoteSync = true
        venues[index] = venue

        notifyChanges()
    }

    func delete(_ venue: VenueRecord) throws {
        venues.removeAll { $0.id == venue.id }
        notifyChanges()
    }

    func wipeAllForLogout() throws {
        venues.removeAll()
        notifyChanges()
    }

    // MARK: - Helpers

    private func notifyChanges() {
        let sorted = venues.sorted { $0.name < $1.name }
        changesSubject.send(sorted)
    }
}