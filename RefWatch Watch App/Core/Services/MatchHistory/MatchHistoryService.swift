//
//  MatchHistoryService.swift
//  RefWatch Watch App
//
//  Description: Codable persistence for completed matches and logs.
//  Stores an array of CompletedMatch as JSON in the app Documents directory.
//

import Foundation

// MARK: - Protocol
protocol MatchHistoryStoring {
    func loadAll() throws -> [CompletedMatch]
    func save(_ match: CompletedMatch) throws
    func delete(id: UUID) throws
    func wipeAll() throws
}

// MARK: - Service
final class MatchHistoryService: MatchHistoryStoring {
    private let fileURL: URL
    private var cache: [CompletedMatch] = []

    // Inject base directory for tests; defaults to Documents directory in app container
    init(baseDirectory: URL? = nil) {
        if let base = baseDirectory {
            self.fileURL = base.appendingPathComponent("completed_matches.json")
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.fileURL = docs.appendingPathComponent("completed_matches.json")
        }
        // Best-effort initial load; ignore errors and start empty
        if let loaded = try? loadFromDisk() {
            self.cache = loaded
        } else {
            self.cache = []
        }
    }

    // MARK: - Public API
    func loadAll() throws -> [CompletedMatch] {
        // Ensure cache is synced with disk (best-effort)
        if let latest = try? loadFromDisk() { cache = latest }
        return cache.sorted(by: { $0.completedAt > $1.completedAt })
    }

    func save(_ match: CompletedMatch) throws {
        // Refresh cache from disk then append and write atomically
        if let latest = try? loadFromDisk() { cache = latest }
        cache.append(match)
        try saveToDisk(cache)
    }

    func delete(id: UUID) throws {
        if let latest = try? loadFromDisk() { cache = latest }
        cache.removeAll { $0.id == id }
        try saveToDisk(cache)
    }

    func wipeAll() throws {
        cache = []
        try saveToDisk(cache)
    }

    // MARK: - Disk Helpers
    private func loadFromDisk() throws -> [CompletedMatch] {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CompletedMatch].self, from: data)
    }

    private func saveToDisk(_ items: [CompletedMatch]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        // Atomic write
        try data.write(to: fileURL, options: .atomic)
        // Re-apply file protection and backup exclusion after atomic replace
        applyProtectionAndExclusion()
    }

    /// Applies data protection and excludes file from backup. Best-effort; logs in DEBUG on failure.
    private func applyProtectionAndExclusion() {
        // Set file protection: accessible after first unlock following boot
        do {
            try FileManager.default.setAttributes(
                [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            #if DEBUG
            print("DEBUG: Failed to set file protection on completed_matches.json: \(error)")
            #endif
        }

        // Exclude from backups (on-device only)
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try fileURL.setResourceValues(values)
        } catch {
            #if DEBUG
            print("DEBUG: Failed to exclude completed_matches.json from backup: \(error)")
            #endif
        }
    }
}
