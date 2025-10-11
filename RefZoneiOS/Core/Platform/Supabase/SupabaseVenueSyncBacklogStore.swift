//
//  SupabaseVenueSyncBacklogStore.swift
//  RefZoneiOS
//
//  Persists pending venue deletion identifiers so the repository can retry
//  remote deletions when connectivity returns.
//

import Foundation

/// Protocol for persisting pending venue sync operations
protocol VenueLibrarySyncBacklogStoring: AnyObject {
    /// Load pending deletion IDs from persistent storage
    func loadPendingDeletionIDs() -> Set<UUID>

    /// Add a venue ID to the pending deletion queue
    func addPendingDeletion(id: UUID)

    /// Remove a venue ID from the pending deletion queue
    func removePendingDeletion(id: UUID)

    /// Clear all pending operations
    func clearAll()
}

/// UserDefaults-backed implementation of venue sync backlog storage
final class SupabaseVenueSyncBacklogStore: VenueLibrarySyncBacklogStoring {
    private let defaults: UserDefaults
    private let key = "com.refzone.supabase.venuelibrary.pendingdeletes"
    private let queue = DispatchQueue(label: "com.refzone.supabase.venuelibrary.backlog")

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