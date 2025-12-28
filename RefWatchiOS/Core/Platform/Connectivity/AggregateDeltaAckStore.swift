//
//  AggregateDeltaAckStore.swift
//  RefWatchiOS
//
//  Persists acknowledgement identifiers for watch-originated aggregate deltas
//  so the next snapshot can echo them back reliably.
//

import Foundation

protocol AggregateDeltaAckStoring: AnyObject {
  func recordAck(id: UUID)
  func drainAckIDs() -> [UUID]
}

final class AggregateDeltaAckStore: AggregateDeltaAckStoring {
  private let defaults: UserDefaults
  private let key = "com.refzone.aggregate.delta.acks"
  private let queue = DispatchQueue(label: "com.refzone.aggregate.delta.acks")

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func recordAck(id: UUID) {
    queue.async {
      var existing = self.loadLocked()
      existing.insert(id)
      self.persistLocked(existing)
    }
  }

  func drainAckIDs() -> [UUID] {
    queue.sync {
      let current = loadLocked()
      persistLocked([])
      return Array(current)
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
    if ids.isEmpty {
      defaults.removeObject(forKey: key)
      return
    }
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(Array(ids)) {
      defaults.set(data, forKey: key)
    }
  }
}
