//
//  SwiftDataScheduleStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of ScheduleStoring with one-time JSON import.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class SwiftDataScheduleStore: ScheduleStoring, ScheduleMetadataPersisting {
    private let container: ModelContainer
    let context: ModelContext
    private let dateProvider: () -> Date
    private let changesSubject: CurrentValueSubject<[ScheduledMatch], Never>
    private let importFlagKey = "rw_schedule_imported_v1"

    init(
        container: ModelContainer,
        importJSONOnFirstRun: Bool = true,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.context = ModelContext(container)
        self.dateProvider = dateProvider
        self.changesSubject = CurrentValueSubject([])
        if importJSONOnFirstRun { importFromLegacyJSONIfNeeded() }
        publishSnapshot()
    }

    func loadAll() -> [ScheduledMatch] {
        snapshot()
    }

    func save(_ item: ScheduledMatch) {
        do {
            if let existing = try record(id: item.id) {
                existing.update(from: item, markModified: item.needsRemoteSync, dateProvider: dateProvider)
                existing.ownerSupabaseId = item.ownerSupabaseId ?? existing.ownerSupabaseId
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
                    ownerSupabaseId: item.ownerSupabaseId,
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
        } catch {
            // Best-effort; ignore for now
        }
    }

    func delete(id: UUID) {
        do {
            if let existing = try record(id: id) {
                context.delete(existing)
                try context.save()
                publishSnapshot()
            }
        } catch { }
    }

    func wipeAll() {
        do {
            let all = try context.fetch(FetchDescriptor<ScheduledMatchRecord>())
            for item in all { context.delete(item) }
            try context.save()
            publishSnapshot()
        } catch { }
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

    private func importFromLegacyJSONIfNeeded() {
        if UserDefaults.standard.bool(forKey: importFlagKey) { return }
        // Re-build the legacy JSON path used by ScheduleService
        let fileURL: URL
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            fileURL = docs.appendingPathComponent("scheduled_matches.json")
        } else {
            fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("appData", isDirectory: true)
                .appendingPathComponent("scheduled_matches.json")
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            UserDefaults.standard.set(true, forKey: importFlagKey)
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            let items = try dec.decode([ScheduledMatch].self, from: data)
            for it in items {
                save(it)
            }
            // Mark as imported. Keep the legacy file to be safe; future runs will skip.
            UserDefaults.standard.set(true, forKey: importFlagKey)
            publishSnapshot()
        } catch {
            // If import fails, still mark as imported to avoid repeated work
            UserDefaults.standard.set(true, forKey: importFlagKey)
        }
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
}
