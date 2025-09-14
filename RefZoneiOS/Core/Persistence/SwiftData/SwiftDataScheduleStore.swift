//
//  SwiftDataScheduleStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of ScheduleStoring with one-time JSON import.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataScheduleStore: ScheduleStoring {
    private let container: ModelContainer
    private let context: ModelContext
    private let importFlagKey = "rw_schedule_imported_v1"

    init(container: ModelContainer, importJSONOnFirstRun: Bool = true) {
        self.container = container
        self.context = ModelContext(container)
        if importJSONOnFirstRun { importFromLegacyJSONIfNeeded() }
    }

    func loadAll() -> [ScheduledMatch] {
        let desc = FetchDescriptor<ScheduledMatchRecord>(sortBy: [SortDescriptor(\.kickoff, order: .forward)])
        let rows = (try? context.fetch(desc)) ?? []
        return rows.map { ScheduledMatch(id: $0.id, homeTeam: $0.homeName, awayTeam: $0.awayName, kickoff: $0.kickoff) }
    }

    func save(_ item: ScheduledMatch) {
        do {
            if let existing = try fetchRecord(id: item.id) {
                existing.homeName = item.homeTeam
                existing.awayName = item.awayTeam
                existing.kickoff = item.kickoff
            } else {
                let row = ScheduledMatchRecord(
                    id: item.id,
                    kickoff: item.kickoff,
                    homeName: item.homeTeam,
                    awayName: item.awayTeam
                )
                context.insert(row)
            }
            try context.save()
        } catch {
            // Best-effort; ignore for now
        }
    }

    func delete(id: UUID) {
        do {
            if let existing = try fetchRecord(id: id) {
                context.delete(existing)
                try context.save()
            }
        } catch { }
    }

    func wipeAll() {
        do {
            let all = try context.fetch(FetchDescriptor<ScheduledMatchRecord>())
            for item in all { context.delete(item) }
            try context.save()
        } catch { }
    }

    // MARK: - Helpers
    private func fetchRecord(id: UUID) throws -> ScheduledMatchRecord? {
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
        } catch {
            // If import fails, still mark as imported to avoid repeated work
            UserDefaults.standard.set(true, forKey: importFlagKey)
        }
    }
}

