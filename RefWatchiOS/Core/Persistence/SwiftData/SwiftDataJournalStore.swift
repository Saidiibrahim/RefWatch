//
//  SwiftDataJournalStore.swift
//  RefWatchiOS
//
//  iOS implementation of JournalEntryStoring backed by SwiftData.
//

import Foundation
import RefWatchCore
import SwiftData

extension Notification.Name {
  static let journalDidChange = Notification.Name("JournalDidChange")
}

@MainActor
final class SwiftDataJournalStore: JournalEntryStoring {
  private let container: ModelContainer
  private let context: ModelContext
  private let auth: AuthenticationProviding

  init(container: ModelContainer, auth: AuthenticationProviding) {
    self.container = container
    self.context = ModelContext(container)
    self.auth = auth
  }

  // MARK: - Load

  func loadEntries(for matchId: UUID) async throws -> [JournalEntry] {
    var desc = FetchDescriptor<JournalEntryRecord>(
      predicate: #Predicate { $0.matchId == matchId },
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
    desc.fetchLimit = 500
    return try self.context.fetch(desc).map(Self.map)
  }

  func loadLatest(for matchId: UUID) async throws -> JournalEntry? {
    var desc = FetchDescriptor<JournalEntryRecord>(
      predicate: #Predicate { $0.matchId == matchId },
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
    desc.fetchLimit = 1
    return try self.context.fetch(desc).first.map(Self.map)
  }

  func loadRecent(limit: Int) async throws -> [JournalEntry] {
    var desc = FetchDescriptor<JournalEntryRecord>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
    desc.fetchLimit = max(1, limit)
    return try self.context.fetch(desc).map(Self.map)
  }

  // MARK: - Mutations

  func upsert(_ entry: JournalEntry) async throws {
    try self.requireSignedIn(operation: "save journal entry")
    if let existing = try fetchRecord(id: entry.id) {
      existing.updatedAt = entry.updatedAt
      existing.ownerId = entry.ownerId ?? existing.ownerId
      existing.rating = entry.rating
      existing.overall = entry.overall
      existing.wentWell = entry.wentWell
      existing.toImprove = entry.toImprove
    } else {
      let owned = self.attachOwnerIfNeeded(entry)
      let row = JournalEntryRecord(
        id: owned.id,
        matchId: owned.matchId,
        createdAt: owned.createdAt,
        updatedAt: owned.updatedAt,
        ownerId: owned.ownerId,
        rating: owned.rating,
        overall: owned.overall,
        wentWell: owned.wentWell,
        toImprove: owned.toImprove)
      self.context.insert(row)
    }
    try self.context.save()
    NotificationCenter.default.post(name: .journalDidChange, object: nil)
  }

  func create(
    matchId: UUID,
    rating: Int?,
    overall: String?,
    wentWell: String?,
    toImprove: String?) async throws -> JournalEntry
  {
    try self.requireSignedIn(operation: "create journal entry")
    var entry = JournalEntry(
      matchId: matchId,
      ownerId: nil,
      rating: rating,
      overall: overall,
      wentWell: wentWell,
      toImprove: toImprove)
    entry = self.attachOwnerIfNeeded(entry)
    try await self.upsert(entry)
    return entry
  }

  func delete(id: UUID) async throws {
    try self.requireSignedIn(operation: "delete journal entry")
    if let record = try fetchRecord(id: id) {
      self.context.delete(record)
      try self.context.save()
      NotificationCenter.default.post(name: .journalDidChange, object: nil)
    }
  }

  func deleteAll(for matchId: UUID) async throws {
    try self.requireSignedIn(operation: "delete journal entries")
    let descriptor = FetchDescriptor<JournalEntryRecord>(
      predicate: #Predicate { $0.matchId == matchId })
    let all = try context.fetch(descriptor)
    for r in all {
      self.context.delete(r)
    }
    try self.context.save()
    NotificationCenter.default.post(name: .journalDidChange, object: nil)
  }

  func wipeAllForLogout() async throws {
    let all = try context.fetch(FetchDescriptor<JournalEntryRecord>())
    for record in all {
      self.context.delete(record)
    }
    if self.context.hasChanges {
      try self.context.save()
    }
    NotificationCenter.default.post(name: .journalDidChange, object: nil)
  }

  // MARK: - Helpers

  private func fetchRecord(id: UUID) throws -> JournalEntryRecord? {
    var desc = FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.id == id })
    desc.fetchLimit = 1
    return try self.context.fetch(desc).first
  }

  private func attachOwnerIfNeeded(_ entry: JournalEntry) -> JournalEntry {
    guard entry.ownerId == nil, let uid = auth.currentUserId else { return entry }
    var e = entry
    e.ownerId = uid
    return e
  }

  private func requireSignedIn(operation: String) throws {
    guard self.auth.currentUserId != nil else {
      throw PersistenceAuthError.signedOut(operation: operation)
    }
  }

  private static func map(_ r: JournalEntryRecord) -> JournalEntry {
    JournalEntry(
      id: r.id,
      matchId: r.matchId,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      ownerId: r.ownerId,
      rating: r.rating,
      overall: r.overall,
      wentWell: r.wentWell,
      toImprove: r.toImprove)
  }
}
