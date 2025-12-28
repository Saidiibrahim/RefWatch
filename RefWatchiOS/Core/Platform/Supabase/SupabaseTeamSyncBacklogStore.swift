//
//  SupabaseTeamSyncBacklogStore.swift
//  RefWatchiOS
//
//  Persists pending team deletion identifiers so the repository can retry
//  remote deletions when connectivity returns.
//

import Foundation

protocol TeamLibrarySyncBacklogStoring: AnyObject {
  func loadPendingDeletionIDs() -> Set<UUID>
  func addPendingDeletion(id: UUID)
  func removePendingDeletion(id: UUID)
  func clearAll()
}

final class SupabaseTeamSyncBacklogStore: TeamLibrarySyncBacklogStoring {
  private let defaults: UserDefaults
  private let key = "com.refzone.supabase.teamlibrary.pendingdeletes"
  private let queue = DispatchQueue(label: "com.refzone.supabase.teamlibrary.backlog")

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

  private func loadLocked() -> Set<UUID> {
    guard let data = defaults.data(forKey: key) else { return [] }
    do {
      let ids = try JSONDecoder().decode([UUID].self, from: data)
      return Set(ids)
    } catch {
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

  func clearAll() {
    queue.async {
      self.defaults.removeObject(forKey: self.key)
    }
  }
}
