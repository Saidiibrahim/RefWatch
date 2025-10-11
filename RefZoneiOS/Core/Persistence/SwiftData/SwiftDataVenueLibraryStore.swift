//
//  SwiftDataVenueLibraryStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of VenueLibraryStoring.
//  Persists venues to disk and provides query capabilities.
//

import Foundation
import SwiftData
import Combine
import OSLog
import RefWatchCore

/// SwiftData implementation for venue library persistence
@MainActor
final class SwiftDataVenueLibraryStore: VenueLibraryStoring {
    private let container: ModelContainer
    private let auth: SupabaseAuthStateProviding
    private let log = AppLog.supabase
    private let changesSubject = PassthroughSubject<[VenueRecord], Never>()

    /// Computed property to access the main context
    var context: ModelContext {
        container.mainContext
    }

    var changesPublisher: AnyPublisher<[VenueRecord], Never> {
        changesSubject.eraseToAnyPublisher()
    }

    init(container: ModelContainer, auth: SupabaseAuthStateProviding) {
        self.container = container
        self.auth = auth
    }

    func loadAll() throws -> [VenueRecord] {
        let descriptor = FetchDescriptor<VenueRecord>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func search(query: String) throws -> [VenueRecord] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return try loadAll()
        }

        let descriptor = FetchDescriptor<VenueRecord>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let records = try context.fetch(descriptor)
        let lowercasedQuery = trimmedQuery.lowercased()
        return records.filter { venue in
            venue.name.lowercased().contains(lowercasedQuery) ||
            (venue.city?.lowercased().contains(lowercasedQuery) ?? false) ||
            (venue.country?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    func create(name: String, city: String?, country: String?) throws -> VenueRecord {
        guard let userId = auth.currentUserId else {
            throw PersistenceAuthError.signedOut(operation: "create venue")
        }

        let record = VenueRecord(
            id: UUID(),
            name: name,
            city: city,
            country: country,
            latitude: nil,
            longitude: nil,
            ownerSupabaseId: userId,
            lastModifiedAt: Date(),
            remoteUpdatedAt: nil,
            needsRemoteSync: true
        )

        context.insert(record)
        try context.save()

        log.info("Created venue: \(name, privacy: .public)")
        notifyChanges()

        return record
    }

    func update(_ venue: VenueRecord) throws {
        guard auth.currentUserId != nil else {
            throw PersistenceAuthError.signedOut(operation: "update venue")
        }

        venue.lastModifiedAt = Date()
        venue.needsRemoteSync = true

        try context.save()

        log.info("Updated venue: \(venue.name, privacy: .public)")
        notifyChanges()
    }

    func delete(_ venue: VenueRecord) throws {
        guard auth.currentUserId != nil else {
            throw PersistenceAuthError.signedOut(operation: "delete venue")
        }

        context.delete(venue)
        try context.save()

        log.info("Deleted venue: \(venue.name, privacy: .public)")
        notifyChanges()
    }

    func wipeAllForLogout() throws {
        let venues = try loadAll()
        for venue in venues {
            context.delete(venue)
        }
        try context.save()
        log.notice("Wiped all venues on sign-out")
        notifyChanges()
    }

    func refreshFromRemote() async throws {
        // SwiftData store relies on Supabase repository for remote pulls.
    }

    // MARK: - Internal Helpers

    /// Notify observers that venues changed
    private func notifyChanges() {
        do {
            let all = try loadAll()
            changesSubject.send(all)
        } catch {
            log.error("Failed to load venues for change notification: \(error.localizedDescription, privacy: .public)")
        }
    }
}
