//
//  SwiftDataCompetitionLibraryStore.swift
//  RefWatchiOS
//
//  SwiftData-backed implementation of CompetitionLibraryStoring.
//  Persists competitions to disk and provides query capabilities.
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

/// SwiftData implementation for competition library persistence
@MainActor
final class SwiftDataCompetitionLibraryStore: CompetitionLibraryStoring {
  private let container: ModelContainer
  private let auth: SupabaseAuthStateProviding
  private let log = AppLog.supabase
  private let changesSubject = PassthroughSubject<[CompetitionRecord], Never>()

  /// Computed property to access the main context
  var context: ModelContext {
    self.container.mainContext
  }

  var changesPublisher: AnyPublisher<[CompetitionRecord], Never> {
    self.changesSubject.eraseToAnyPublisher()
  }

  init(container: ModelContainer, auth: SupabaseAuthStateProviding) {
    self.container = container
    self.auth = auth
  }

  func loadAll() throws -> [CompetitionRecord] {
    let descriptor = FetchDescriptor<CompetitionRecord>(
      sortBy: [SortDescriptor(\.name, order: .forward)])
    return try self.context.fetch(descriptor)
  }

  func search(query: String) throws -> [CompetitionRecord] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedQuery.isEmpty == false else {
      return try self.loadAll()
    }

    let descriptor = FetchDescriptor<CompetitionRecord>(
      sortBy: [SortDescriptor(\.name, order: .forward)])
    let records = try context.fetch(descriptor)
    let lowercasedQuery = trimmedQuery.lowercased()
    return records.filter { record in
      record.name.lowercased().contains(lowercasedQuery)
    }
  }

  func create(name: String, level: String?) throws -> CompetitionRecord {
    guard let userId = auth.currentUserId else {
      throw PersistenceAuthError.signedOut(operation: "create competition")
    }

    let record = CompetitionRecord(
      id: UUID(),
      name: name,
      level: level,
      ownerSupabaseId: userId,
      lastModifiedAt: Date(),
      remoteUpdatedAt: nil,
      needsRemoteSync: true)

    self.context.insert(record)
    try self.context.save()

    self.log.info("Created competition: \(name, privacy: .public)")
    self.notifyChanges()

    return record
  }

  func update(_ competition: CompetitionRecord) throws {
    guard self.auth.currentUserId != nil else {
      throw PersistenceAuthError.signedOut(operation: "update competition")
    }

    competition.lastModifiedAt = Date()
    competition.needsRemoteSync = true

    try self.context.save()

    self.log.info("Updated competition: \(competition.name, privacy: .public)")
    self.notifyChanges()
  }

  func delete(_ competition: CompetitionRecord) throws {
    guard self.auth.currentUserId != nil else {
      throw PersistenceAuthError.signedOut(operation: "delete competition")
    }

    self.context.delete(competition)
    try self.context.save()

    self.log.info("Deleted competition: \(competition.name, privacy: .public)")
    self.notifyChanges()
  }

  func wipeAllForLogout() throws {
    let competitions = try loadAll()
    for competition in competitions {
      self.context.delete(competition)
    }
    try self.context.save()
    self.log.notice("Wiped all competitions on sign-out")
    self.notifyChanges()
  }

  func refreshFromRemote() async throws {
    // SwiftData store does not talk to remote directly; Supabase repository handles pulls.
  }

  // MARK: - Internal Helpers

  /// Notify observers that competitions changed
  private func notifyChanges() {
    do {
      let all = try loadAll()
      self.changesSubject.send(all)
    } catch {
      self.log.error(
        "Failed to load competitions for change notification: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Aggregate Delta Support

  func fetchCompetition(id: UUID) throws -> CompetitionRecord? {
    var descriptor = FetchDescriptor<CompetitionRecord>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try self.context.fetch(descriptor).first
  }

  func upsertFromAggregate(
    _ aggregate: AggregateSnapshotPayload.Competition,
    ownerSupabaseId ownerId: String) throws -> CompetitionRecord
  {
    let record: CompetitionRecord
    if let existing = try fetchCompetition(id: aggregate.id) {
      record = existing
    } else {
      record = CompetitionRecord(
        id: aggregate.id,
        name: aggregate.name,
        level: aggregate.level,
        ownerSupabaseId: ownerId,
        lastModifiedAt: aggregate.lastModifiedAt,
        remoteUpdatedAt: aggregate.remoteUpdatedAt,
        needsRemoteSync: true)
      self.context.insert(record)
    }

    record.name = aggregate.name
    record.level = aggregate.level
    record.ownerSupabaseId = ownerId
    record.lastModifiedAt = aggregate.lastModifiedAt
    record.remoteUpdatedAt = aggregate.remoteUpdatedAt
    record.needsRemoteSync = true

    try self.context.save()
    self.notifyChanges()
    return record
  }

  func deleteCompetition(id: UUID) throws {
    guard let existing = try fetchCompetition(id: id) else { return }
    self.context.delete(existing)
    try self.context.save()
    self.notifyChanges()
  }
}
