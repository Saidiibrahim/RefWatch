//
//  SwiftDataCompetitionLibraryStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of CompetitionLibraryStoring.
//  Persists competitions to disk and provides query capabilities.
//

import Foundation
import SwiftData
import Combine
import OSLog
import RefWatchCore

/// SwiftData implementation for competition library persistence
@MainActor
final class SwiftDataCompetitionLibraryStore: CompetitionLibraryStoring {
    private let container: ModelContainer
    private let auth: SupabaseAuthStateProviding
    private let log = AppLog.supabase
    private let changesSubject = PassthroughSubject<[CompetitionRecord], Never>()

    /// Computed property to access the main context
    var context: ModelContext {
        container.mainContext
    }

    var changesPublisher: AnyPublisher<[CompetitionRecord], Never> {
        changesSubject.eraseToAnyPublisher()
    }

    init(container: ModelContainer, auth: SupabaseAuthStateProviding) {
        self.container = container
        self.auth = auth
    }

    func loadAll() throws -> [CompetitionRecord] {
        let descriptor = FetchDescriptor<CompetitionRecord>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func search(query: String) throws -> [CompetitionRecord] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return try loadAll()
        }

        let descriptor = FetchDescriptor<CompetitionRecord>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let records = try context.fetch(descriptor)
        let lowercasedQuery = trimmedQuery.lowercased()
        return records.filter { record in
            record.name.lowercased().contains(lowercasedQuery)
        }
    }

    func create(name: String, level: String?) throws -> CompetitionRecord {
        guard let userId = auth.currentUserId else {
            throw PersistenceAuthError.signedOut(operation: "create competition")
        }

        let record = CompetitionRecord(
            id: UUID(),
            name: name,
            level: level,
            ownerSupabaseId: userId,
            lastModifiedAt: Date(),
            remoteUpdatedAt: nil,
            needsRemoteSync: true
        )

        context.insert(record)
        try context.save()

        log.info("Created competition: \(name, privacy: .public)")
        notifyChanges()

        return record
    }

    func update(_ competition: CompetitionRecord) throws {
        guard auth.currentUserId != nil else {
            throw PersistenceAuthError.signedOut(operation: "update competition")
        }

        competition.lastModifiedAt = Date()
        competition.needsRemoteSync = true

        try context.save()

        log.info("Updated competition: \(competition.name, privacy: .public)")
        notifyChanges()
    }

    func delete(_ competition: CompetitionRecord) throws {
        guard auth.currentUserId != nil else {
            throw PersistenceAuthError.signedOut(operation: "delete competition")
        }

        context.delete(competition)
        try context.save()

        log.info("Deleted competition: \(competition.name, privacy: .public)")
        notifyChanges()
    }

    func wipeAllForLogout() throws {
        let competitions = try loadAll()
        for competition in competitions {
            context.delete(competition)
        }
        try context.save()
        log.notice("Wiped all competitions on sign-out")
        notifyChanges()
    }

    func refreshFromRemote() async throws {
        // SwiftData store does not talk to remote directly; Supabase repository handles pulls.
    }

    // MARK: - Internal Helpers

    /// Notify observers that competitions changed
    private func notifyChanges() {
        do {
            let all = try loadAll()
            changesSubject.send(all)
        } catch {
            log.error("Failed to load competitions for change notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Aggregate Delta Support

    func fetchCompetition(id: UUID) throws -> CompetitionRecord? {
        var descriptor = FetchDescriptor<CompetitionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func upsertFromAggregate(_ aggregate: AggregateSnapshotPayload.Competition, ownerSupabaseId ownerId: String) throws -> CompetitionRecord {
        let record: CompetitionRecord
        if let existing = try fetchCompetition(id: aggregate.id) {
            record = existing
        } else {
            record = CompetitionRecord(
                id: aggregate.id,
                name: aggregate.name,
                level: aggregate.level,
                ownerSupabaseId: ownerId,
                lastModifiedAt: aggregate.lastModifiedAt,
                remoteUpdatedAt: aggregate.remoteUpdatedAt,
                needsRemoteSync: true
            )
            context.insert(record)
        }

        record.name = aggregate.name
        record.level = aggregate.level
        record.ownerSupabaseId = ownerId
        record.lastModifiedAt = aggregate.lastModifiedAt
        record.remoteUpdatedAt = aggregate.remoteUpdatedAt
        record.needsRemoteSync = true

        try context.save()
        notifyChanges()
        return record
    }

    func deleteCompetition(id: UUID) throws {
        guard let existing = try fetchCompetition(id: id) else { return }
        context.delete(existing)
        try context.save()
        notifyChanges()
    }
}
