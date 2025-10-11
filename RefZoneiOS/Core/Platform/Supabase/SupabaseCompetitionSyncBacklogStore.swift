//
//  SupabaseCompetitionSyncBacklogStore.swift
//  RefZoneiOS
//
//  Persists pending competition deletion identifiers so the repository can retry
//  remote deletions when connectivity returns.
//

import Foundation

/// Protocol for persisting pending competition sync operations
protocol CompetitionLibrarySyncBacklogStoring: AnyObject {
    /// Load pending deletion IDs from persistent storage
    func loadPendingDeletionIDs() -> Set<UUID>

    /// Add a competition ID to the pending deletion queue
    func addPendingDeletion(id: UUID)

    /// Remove a competition ID from the pending deletion queue
    func removePendingDeletion(id: UUID)

    /// Clear all pending operations
    func clearAll()
}

/// UserDefaults-backed implementation of competition sync backlog storage
final class SupabaseCompetitionSyncBacklogStore: CompetitionLibrarySyncBacklogStoring {
    private let defaults: UserDefaults
    private let key = "com.refzone.supabase.competitionlibrary.pendingdeletes"
    private let queue = DispatchQueue(label: "com.refzone.supabase.competitionlibrary.backlog")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPendingDeletionIDs() -> Set<UUID> {
        queue.sync { loadLocked() }
    }

    func addPendingDeletion(id: UUID) {
        queue.async {
            var current = self.loadLocked()
            current.insert(id)
            self.persistLocked(current)
        }
    }

    func removePendingDeletion(id: UUID) {
        queue.async {
            var current = self.loadLocked()
            if current.remove(id) != nil {
                self.persistLocked(current)
            }
        }
    }

    func clearAll() {
        queue.async {
            self.defaults.removeObject(forKey: self.key)
        }
    }

    // MARK: - Private Helpers

    private func loadLocked() -> Set<UUID> {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            let ids = try JSONDecoder().decode([UUID].self, from: data)
            return Set(ids)
        } catch {
            // Invalid data, clear it
            defaults.removeObject(forKey: key)
            return []
        }
    }

    private func persistLocked(_ ids: Set<UUID>) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(Array(ids)) {
            defaults.set(data, forKey: key)
        }
    }
}