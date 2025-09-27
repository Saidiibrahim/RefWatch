//
//  SupabaseMatchSyncBacklogStore.swift
//  RefZoneiOS
//
//  Persists pending completed match deletion identifiers so the repository can
//  retry remote deletions when connectivity or authorization returns.
//

import Foundation

protocol MatchSyncBacklogStoring: AnyObject {
  func loadPendingDeletionIDs() -> Set<UUID>
  func addPendingDeletion(id: UUID)
  func removePendingDeletion(id: UUID)
}

final class SupabaseMatchSyncBacklogStore: MatchSyncBacklogStoring {
  private let defaults: UserDefaults
  private let key = "com.refzone.supabase.matches.pendingdeletes"
  private let queue = DispatchQueue(label: "com.refzone.supabase.matches.backlog")

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
      let decoded = try JSONDecoder().decode([UUID].self, from: data)
      return Set(decoded)
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
}
