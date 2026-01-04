//
//  InMemoryJournalStore.swift
//  RefWatchiOS
//
//  Non-persistent fallback used only if SwiftData container fails to build.
//

import Foundation
import RefWatchCore

@MainActor
final class InMemoryJournalStore: JournalEntryStoring {
  private var items: [UUID: [JournalEntry]] = [:] // matchId -> entries

  func loadEntries(for matchId: UUID) async throws -> [JournalEntry] {
    (self.items[matchId] ?? []).sorted(by: { $0.updatedAt > $1.updatedAt })
  }

  func loadLatest(for matchId: UUID) async throws -> JournalEntry? {
    try await self.loadEntries(for: matchId).first
  }

  func loadRecent(limit: Int) async throws -> [JournalEntry] {
    let entries = self.items.values.flatMap { $0 }.sorted(by: { $0.updatedAt > $1.updatedAt })
    return Array(entries.prefix(max(1, limit)))
  }

  func upsert(_ entry: JournalEntry) async throws {
    var list = self.items[entry.matchId] ?? []
    if let idx = list.firstIndex(where: { $0.id == entry.id }) {
      list[idx] = entry
    } else {
      list.append(entry)
    }
    self.items[entry.matchId] = list
    NotificationCenter.default.post(name: .journalDidChange, object: nil)
  }

  func create(
    matchId: UUID,
    rating: Int?,
    overall: String?,
    wentWell: String?,
    toImprove: String?) async throws -> JournalEntry
  {
    let entry = JournalEntry(
      matchId: matchId,
      rating: rating,
      overall: overall,
      wentWell: wentWell,
      toImprove: toImprove)
    try await upsert(entry)
    return entry
  }

  func delete(id: UUID) async throws {
    for key in self.items.keys {
      self.items[key]?.removeAll { $0.id == id }
    }
    NotificationCenter.default.post(name: .journalDidChange, object: nil)
  }

  func deleteAll(for matchId: UUID) async throws {
    self.items[matchId] = []
    NotificationCenter.default.post(name: .journalDidChange, object: nil)
  }

  func wipeAllForLogout() async throws {
    self.items.removeAll()
    NotificationCenter.default.post(name: .journalDidChange, object: nil)
  }
}
