//
//  SwiftDataScheduleStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of ScheduleStoring with one-time JSON import.
//

import Foundation
import Combine
import SwiftData
import RefWatchCore

@MainActor
final class SwiftDataScheduleStore: ScheduleStoring, ScheduleMetadataPersisting {
    private let container: ModelContainer
    let context: ModelContext
    private let dateProvider: () -> Date
    private let changesSubject: CurrentValueSubject<[ScheduledMatch], Never>
    private let auth: AuthenticationProviding

    init(
        container: ModelContainer,
        auth: AuthenticationProviding,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.context = ModelContext(container)
        self.dateProvider = dateProvider
        self.changesSubject = CurrentValueSubject([])
        self.auth = auth
        publishSnapshot()
    }

    func loadAll() -> [ScheduledMatch] {
        snapshot()
    }

    func save(_ item: ScheduledMatch) throws {
        let ownerId = try requireSignedIn(operation: "save scheduled match")
        if let existing = try record(id: item.id) {
            existing.update(from: item, markModified: item.needsRemoteSync, dateProvider: dateProvider)
            if existing.ownerSupabaseId != ownerId {
                existing.ownerSupabaseId = ownerId
            }
            existing.remoteUpdatedAt = item.remoteUpdatedAt
            existing.needsRemoteSync = item.needsRemoteSync
        } else {
            let row = ScheduledMatchRecord(
                id: item.id,
                kickoff: item.kickoff,
                homeName: item.homeTeam,
                awayName: item.awayTeam,
                competition: item.competition,
                notes: item.notes,
                status: item.status,
                ownerSupabaseId: ownerId,
                lastModifiedAt: dateProvider(),
                remoteUpdatedAt: item.remoteUpdatedAt,
                needsRemoteSync: item.needsRemoteSync,
                sourceDeviceId: item.sourceDeviceId
            )
            if item.needsRemoteSync == false {
                row.needsRemoteSync = false
            }
            context.insert(row)
        }
        try context.save()
        publishSnapshot()
    }

    func delete(id: UUID) throws {
        try requireSignedIn(operation: "delete scheduled match")
        if let existing = try record(id: id) {
            context.delete(existing)
            try context.save()
            publishSnapshot()
        }
    }

    func wipeAll() throws {
        try requireSignedIn(operation: "wipe scheduled matches")
        try performWipeAll()
    }

    func wipeAllForLogout() throws {
        try performWipeAll()
    }

    var changesPublisher: AnyPublisher<[ScheduledMatch], Never> {
        changesSubject.eraseToAnyPublisher()
    }

    // MARK: - Helpers
    func record(id: UUID) throws -> ScheduledMatchRecord? {
        var desc = FetchDescriptor<ScheduledMatchRecord>(predicate: #Predicate { $0.id == id })
        desc.fetchLimit = 1
        return try context.fetch(desc).first
    }

    func publishSnapshot() {
        changesSubject.send(snapshot())
    }

    private func snapshot() -> [ScheduledMatch] {
        let desc = FetchDescriptor<ScheduledMatchRecord>(sortBy: [SortDescriptor(\.kickoff, order: .forward)])
        let rows = (try? context.fetch(desc)) ?? []
        return rows.map { record in
            ScheduledMatch(
                id: record.id,
                homeTeam: record.homeName,
                awayTeam: record.awayName,
                kickoff: record.kickoff,
                competition: record.competition,
                notes: record.notes,
                status: record.status,
                ownerSupabaseId: record.ownerSupabaseId,
                remoteUpdatedAt: record.remoteUpdatedAt,
                needsRemoteSync: record.needsRemoteSync,
                sourceDeviceId: record.sourceDeviceId
            )
        }
    }

    private func requireSignedIn(operation: String) throws -> String {
        guard let userId = auth.currentUserId else {
            throw PersistenceAuthError.signedOut(operation: operation)
        }
        return userId
    }
}

private extension SwiftDataScheduleStore {
    func performWipeAll() throws {
        let all = try context.fetch(FetchDescriptor<ScheduledMatchRecord>())
        for item in all { context.delete(item) }
        if context.hasChanges {
            try context.save()
        }
        publishSnapshot()
    }
}
