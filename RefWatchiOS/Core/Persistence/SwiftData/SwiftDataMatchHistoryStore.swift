//
//  SwiftDataMatchHistoryStore.swift
//  RefWatchiOS
//
//  iOS implementation of MatchHistoryStoring backed by SwiftData.
//
//  Responsibilities
//  - Persist completed match snapshots using a SwiftData model (`CompletedMatchRecord`).
//  - On first use, perform a one-time import from the legacy JSON store with de-duplication by `id`.
//  - Attach `ownerId` using the injected `AuthenticationProviding` if the snapshot is missing it (idempotent).
//  - Post `.matchHistoryDidChange` notifications on the main thread after mutations.
//
//  Threading & Actor
//  - The store is `@MainActor` to align with SwiftData usage in this app and simplify UI integration.
//  - Encoding/decoding JSON blobs happen synchronously on the main actor; payload sizes
//    are limited to single snapshots.
//
//  Loading Strategy
//  - `loadAll()` returns a bounded, most-recent-first list (default limit applied) to avoid unbounded memory use.
//  - A `loadPage(offset:limit:)` helper is provided for full-history screens.
//

import Foundation
import RefWatchCore
import SwiftData

@MainActor
final class SwiftDataMatchHistoryStore: MatchHistoryStoring {
  private let container: ModelContainer
  let context: ModelContext
  private let auth: AuthenticationProviding

  init(container: ModelContainer, auth: AuthenticationProviding = NoopAuth()) {
    self.container = container
    self.context = ModelContext(container)
    self.auth = auth
  }

  // MARK: - MatchHistoryStoring

  /// Loads a bounded set of most recent completed matches.
  ///
  /// Note: This method intentionally applies a default fetch limit to avoid
  /// unbounded memory use when many rows exist. Use `loadPage(offset:limit:)`
  /// when full pagination is needed.
  func loadAll() throws -> [CompletedMatch] {
    var desc = FetchDescriptor<CompletedMatchRecord>(
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
    // Reasonable default bound to protect memory on large datasets
    desc.fetchLimit = 200
    let rows = try context.fetch(desc)
    return rows.compactMap { Self.decode($0.payload) }
  }

  /// Paginates completed matches using SwiftData’s fetch offset/limit.
  func loadPage(offset: Int, limit: Int) throws -> [CompletedMatch] {
    var desc = FetchDescriptor<CompletedMatchRecord>(
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
    desc.fetchOffset = max(0, offset)
    desc.fetchLimit = max(1, limit)
    let rows = try context.fetch(desc)
    return rows.compactMap { Self.decode($0.payload) }
  }

  /// Cursor-based pagination that returns snapshots completed strictly before the given timestamp.
  /// When `completedAt` is `nil`, returns the newest `limit` snapshots.
  func loadBefore(completedAt: Date?, limit: Int) throws -> [CompletedMatch] {
    var desc = FetchDescriptor<CompletedMatchRecord>(
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
    desc.fetchLimit = max(1, limit)
    if let cutoff = completedAt {
      desc.predicate = #Predicate { $0.completedAt < cutoff }
    }
    let rows = try context.fetch(desc)
    return rows.compactMap { Self.decode($0.payload) }
  }

  func save(_ match: CompletedMatch) throws {
    try self.requireSignedIn(operation: "save match history")
    let snapshot = self.attachOwnerIfNeeded(match)
    let data = try Self.encode(snapshot)

    if let existing = try fetchRecord(id: snapshot.id) {
      existing.completedAt = snapshot.completedAt
      existing.ownerId = snapshot.ownerId
      existing.homeTeam = snapshot.match.homeTeam
      existing.awayTeam = snapshot.match.awayTeam
      existing.homeScore = snapshot.match.homeScore
      existing.awayScore = snapshot.match.awayScore
      existing.homeTeamId = snapshot.match.homeTeamId
      existing.awayTeamId = snapshot.match.awayTeamId
      existing.competitionId = snapshot.match.competitionId
      existing.competitionName = snapshot.match.competitionName
      existing.venueId = snapshot.match.venueId
      existing.venueName = snapshot.match.venueName
      existing.payload = data
      existing.needsRemoteSync = true
    } else {
      let row = CompletedMatchRecord(
        id: snapshot.id,
        completedAt: snapshot.completedAt,
        ownerId: snapshot.ownerId,
        homeTeam: snapshot.match.homeTeam,
        awayTeam: snapshot.match.awayTeam,
        homeScore: snapshot.match.homeScore,
        awayScore: snapshot.match.awayScore,
        homeTeamId: snapshot.match.homeTeamId,
        awayTeamId: snapshot.match.awayTeamId,
        competitionId: snapshot.match.competitionId,
        competitionName: snapshot.match.competitionName,
        venueId: snapshot.match.venueId,
        venueName: snapshot.match.venueName,
        payload: data,
        needsRemoteSync: true)
      self.context.insert(row)
    }
    try self.context.save()
    NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
  }

  func delete(id: UUID) throws {
    try self.requireSignedIn(operation: "delete match history")
    if let existing = try fetchRecord(id: id) {
      self.context.delete(existing)
      try self.context.save()
      NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
    }
  }

  func wipeAll() throws {
    try self.requireSignedIn(operation: "wipe match history")
    try performWipeAll()
  }

  func wipeAllForLogout() throws {
    try performWipeAll()
  }

  // MARK: - Helpers

  func fetchRecord(id: UUID) throws -> CompletedMatchRecord? {
    var desc = FetchDescriptor<CompletedMatchRecord>(predicate: #Predicate { $0.id == id })
    desc.fetchLimit = 1
    return try self.context.fetch(desc).first
  }

  func fetchAllRecords() throws -> [CompletedMatchRecord] {
    let desc = FetchDescriptor<CompletedMatchRecord>()
    return try self.context.fetch(desc)
  }

  /// Attaches the current user as owner if snapshot lacks an `ownerId`.
  private func attachOwnerIfNeeded(_ match: CompletedMatch) -> CompletedMatch {
    match.attachingOwnerIfMissing(using: self.auth)
  }

  /// Ensures a Supabase user is available before mutating persistence.
  private func requireSignedIn(operation: String) throws {
    guard self.auth.currentUserId != nil else {
      throw PersistenceAuthError.signedOut(operation: operation)
    }
  }

  static func encoder() -> JSONEncoder {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted]
    enc.dateEncodingStrategy = .iso8601
    return enc
  }

  static func decoder() -> JSONDecoder {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    return dec
  }

  static func encode(_ obj: CompletedMatch) throws -> Data { try self.encoder().encode(obj) }
  static func decode(_ data: Data) -> CompletedMatch? { try? self.decoder().decode(CompletedMatch.self, from: data) }
}

extension SwiftDataMatchHistoryStore {
  private func performWipeAll() throws {
    let all = try context.fetch(FetchDescriptor<CompletedMatchRecord>())
    for item in all {
      self.context.delete(item)
    }
    if self.context.hasChanges {
      try self.context.save()
    }
    NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
  }
}
