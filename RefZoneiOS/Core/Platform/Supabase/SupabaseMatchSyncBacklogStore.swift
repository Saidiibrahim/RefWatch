//
//  SupabaseMatchSyncBacklogStore.swift
//  RefZoneiOS
//
//  Persists pending match sync operations (deletions + push retry metadata)
//  so the repository can resume uploads when connectivity or auth returns.
//

import Foundation

/// Metadata describing when the next push attempt should occur and how many
/// retries have been attempted so far.
struct MatchSyncPushMetadata: Codable, Equatable {
  let retryCount: Int
  let nextAttempt: Date
}

protocol MatchSyncBacklogStoring: AnyObject {
  func loadPendingDeletionIDs() -> Set<UUID>
  func addPendingDeletion(id: UUID)
  func removePendingDeletion(id: UUID)

  func loadPendingPushMetadata() -> [UUID: MatchSyncPushMetadata]
  func updatePendingPushMetadata(_ metadata: MatchSyncPushMetadata, for id: UUID)
  func removePendingPushMetadata(for id: UUID)
  func clearAll()
}

final class SupabaseMatchSyncBacklogStore: MatchSyncBacklogStoring {
  private let defaults: UserDefaults
  private let deletionKey = "com.refzone.supabase.matches.pendingdeletes"
  private let pushKey = "com.refzone.supabase.matches.pendingpushes"
  private let queue = DispatchQueue(label: "com.refzone.supabase.matches.backlog")
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  // MARK: - Deletions

  func loadPendingDeletionIDs() -> Set<UUID> {
    queue.sync { loadDeletionIDsLocked() }
  }

  func addPendingDeletion(id: UUID) {
    queue.async {
      var current = self.loadDeletionIDsLocked()
      current.insert(id)
      self.persistDeletionIDsLocked(current)
    }
  }

  func removePendingDeletion(id: UUID) {
    queue.async {
      var current = self.loadDeletionIDsLocked()
      guard current.remove(id) != nil else { return }
      self.persistDeletionIDsLocked(current)
    }
  }

  private func loadDeletionIDsLocked() -> Set<UUID> {
    guard let data = defaults.data(forKey: deletionKey) else { return [] }
    do {
      let decoded = try decoder.decode([UUID].self, from: data)
      return Set(decoded)
    } catch {
      defaults.removeObject(forKey: deletionKey)
      return []
    }
  }

  private func persistDeletionIDsLocked(_ ids: Set<UUID>) {
    guard let data = try? encoder.encode(Array(ids)) else { return }
    defaults.set(data, forKey: deletionKey)
  }

  // MARK: - Push Metadata

  func loadPendingPushMetadata() -> [UUID: MatchSyncPushMetadata] {
    queue.sync { loadPushMetadataLocked() }
  }

  func updatePendingPushMetadata(_ metadata: MatchSyncPushMetadata, for id: UUID) {
    queue.async {
      var current = self.loadPushMetadataLocked()
      current[id] = metadata
      self.persistPushMetadataLocked(current)
    }
  }

  func removePendingPushMetadata(for id: UUID) {
    queue.async {
      var current = self.loadPushMetadataLocked()
      guard current.removeValue(forKey: id) != nil else { return }
      self.persistPushMetadataLocked(current)
    }
  }

  private func loadPushMetadataLocked() -> [UUID: MatchSyncPushMetadata] {
    guard let data = defaults.data(forKey: pushKey) else { return [:] }
    do {
      let decoded = try decoder.decode([UUID: MatchSyncPushMetadata].self, from: data)
      return decoded
    } catch {
      defaults.removeObject(forKey: pushKey)
      return [:]
    }
  }

  private func persistPushMetadataLocked(_ metadata: [UUID: MatchSyncPushMetadata]) {
    guard let data = try? encoder.encode(metadata) else { return }
    defaults.set(data, forKey: pushKey)
  }

  func clearAll() {
    queue.async {
      self.defaults.removeObject(forKey: self.deletionKey)
      self.defaults.removeObject(forKey: self.pushKey)
    }
  }
}
