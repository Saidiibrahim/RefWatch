//
//  ScheduleService.swift
//  RefZoneiOS
//
//  Simple JSON-backed store for scheduled matches (iOS-only for now).
//

import Foundation
import OSLog
import RefWatchCore

@MainActor
protocol ScheduleStoring {
    func loadAll() -> [ScheduledMatch]
    func save(_ item: ScheduledMatch)
    func delete(id: UUID)
    func wipeAll()
}

@MainActor
final class ScheduleService: ScheduleStoring {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "ScheduleService", attributes: .concurrent)

    init(baseDirectory: URL? = nil) {
        if let base = baseDirectory {
            self.fileURL = base.appendingPathComponent("scheduled_matches.json")
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.fileURL = docs.appendingPathComponent("scheduled_matches.json")
        } else {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("appData", isDirectory: true)
            try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            self.fileURL = tmp.appendingPathComponent("scheduled_matches.json")
        }
    }

    func loadAll() -> [ScheduledMatch] {
        queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
            do {
                let data = try Data(contentsOf: fileURL)
                let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
                return try dec.decode([ScheduledMatch].self, from: data)
            } catch { return [] }
        }
    }

    func save(_ item: ScheduledMatch) {
        queue.sync(flags: .barrier) {
            var all = loadAll()
            if let idx = all.firstIndex(where: { $0.id == item.id }) { all[idx] = item } else { all.append(item) }
            persist(all)
        }
    }

    func delete(id: UUID) {
        queue.sync(flags: .barrier) {
            var all = loadAll()
            all.removeAll { $0.id == id }
            persist(all)
        }
    }

    func wipeAll() {
        queue.sync(flags: .barrier) { persist([]) }
    }

    private func persist(_ items: [ScheduledMatch]) {
        do {
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted]; enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLog.schedule.error("Failed to persist scheduled matches: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                    "error": "schedule persist failed",
                    "context": "ios.schedule.persist"
                ])
            }
        }
    }
}
