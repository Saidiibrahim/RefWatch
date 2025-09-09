//
//  MatchHistoryService.swift
//  RefWatchCore
//
//  Codable persistence for completed matches and logs.
//  Stores an array of CompletedMatch as JSON in the app Documents directory.
//

import Foundation

// MARK: - Protocol
@MainActor
public protocol MatchHistoryStoring {
    func loadAll() throws -> [CompletedMatch]
    func save(_ match: CompletedMatch) throws
    func delete(id: UUID) throws
    func wipeAll() throws
}

// Convenience pagination helper without breaking existing protocol call sites
public extension MatchHistoryStoring {
    func loadRecent(_ limit: Int = 50) -> [CompletedMatch] {
        let all = (try? loadAll()) ?? []
        return Array(all.prefix(limit))
    }
}

// MARK: - Service
@MainActor
public final class MatchHistoryService: MatchHistoryStoring {
    private let fileURL: URL
    private var cache: [CompletedMatch] = []
    private let queue = DispatchQueue(label: "MatchHistoryService", attributes: .concurrent)

    // Inject base directory for tests; defaults to Documents directory in app container
    public init(baseDirectory: URL? = nil) {
        if let base = baseDirectory {
            self.fileURL = base.appendingPathComponent("completed_matches.json")
        } else {
            // Guard documents directory discovery to avoid force-unwrap crashes
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                self.fileURL = docs.appendingPathComponent("completed_matches.json")
            } else {
                // Fall back to a temp-based appData folder (best-effort)
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("appData", isDirectory: true)
                try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
                self.fileURL = tmp.appendingPathComponent("completed_matches.json")
                #if DEBUG
                print("DEBUG: Documents directory not found. Falling back to temporary appData directory for persistence.")
                #endif
            }
        }
        // Best-effort initial load; ignore errors and start empty
        if let loaded = try? loadFromDisk() {
            self.cache = loaded
        } else {
            self.cache = []
        }
    }

    // MARK: - Public API
    public func loadAll() throws -> [CompletedMatch] {
        try queue.sync {
            // Ensure cache is synced with disk (best-effort)
            if let latest = try? loadFromDisk() { cache = latest }
            return cache.sorted(by: { $0.completedAt > $1.completedAt })
        }
    }

    public func save(_ match: CompletedMatch) throws {
        try queue.sync(flags: .barrier) {
            // Refresh cache from disk then append and write atomically
            if let latest = try? loadFromDisk() { cache = latest }
            cache.append(match)
            try saveToDisk(cache)
        }
    }

    public func delete(id: UUID) throws {
        try queue.sync(flags: .barrier) {
            if let latest = try? loadFromDisk() { cache = latest }
            cache.removeAll { $0.id == id }
            try saveToDisk(cache)
        }
    }

    public func wipeAll() throws {
        try queue.sync(flags: .barrier) {
            cache = []
            try saveToDisk(cache)
        }
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
            var url = fileURL // setResourceValues mutates
            try url.setResourceValues(values)
        } catch {
            #if DEBUG
            print("DEBUG: Failed to exclude completed_matches.json from backup: \(error)")
            #endif
        }
    }
}
