//
//  SwiftDataVenueLibraryStore.swift
//  RefWatchiOS
//
//  SwiftData-backed implementation of VenueLibraryStoring.
//  Persists venues to disk and provides query capabilities.
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

/// SwiftData implementation for venue library persistence
@MainActor
final class SwiftDataVenueLibraryStore: VenueLibraryStoring {
  private let container: ModelContainer
  private let auth: SupabaseAuthStateProviding
  private let log = AppLog.supabase
  private let changesSubject = PassthroughSubject<[VenueRecord], Never>()

  /// Computed property to access the main context
  var context: ModelContext {
    self.container.mainContext
  }

  var changesPublisher: AnyPublisher<[VenueRecord], Never> {
    self.changesSubject.eraseToAnyPublisher()
  }

  init(container: ModelContainer, auth: SupabaseAuthStateProviding) {
    self.container = container
    self.auth = auth
  }

  func loadAll() throws -> [VenueRecord] {
    let descriptor = FetchDescriptor<VenueRecord>(
      sortBy: [SortDescriptor(\.name, order: .forward)])
    return try self.context.fetch(descriptor)
  }

  func search(query: String) throws -> [VenueRecord] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedQuery.isEmpty == false else {
      return try self.loadAll()
    }

    let descriptor = FetchDescriptor<VenueRecord>(
      sortBy: [SortDescriptor(\.name, order: .forward)])
    let records = try context.fetch(descriptor)
    let lowercasedQuery = trimmedQuery.lowercased()
    return records.filter { venue in
      venue.name.lowercased().contains(lowercasedQuery) ||
        (venue.city?.lowercased().contains(lowercasedQuery) ?? false) ||
        (venue.country?.lowercased().contains(lowercasedQuery) ?? false)
    }
  }

  func create(name: String, city: String?, country: String?) throws -> VenueRecord {
    guard let userId = auth.currentUserId else {
      throw PersistenceAuthError.signedOut(operation: "create venue")
    }

    let record = VenueRecord(
      id: UUID(),
      name: name,
      city: city,
      country: country,
      latitude: nil,
      longitude: nil,
      ownerSupabaseId: userId,
      lastModifiedAt: Date(),
      remoteUpdatedAt: nil,
      needsRemoteSync: true)

    self.context.insert(record)
    try self.context.save()

    self.log.info("Created venue: \(name, privacy: .public)")
    self.notifyChanges()

    return record
  }

  func update(_ venue: VenueRecord) throws {
    guard self.auth.currentUserId != nil else {
      throw PersistenceAuthError.signedOut(operation: "update venue")
    }

    venue.lastModifiedAt = Date()
    venue.needsRemoteSync = true

    try self.context.save()

    self.log.info("Updated venue: \(venue.name, privacy: .public)")
    self.notifyChanges()
  }

  func delete(_ venue: VenueRecord) throws {
    guard self.auth.currentUserId != nil else {
      throw PersistenceAuthError.signedOut(operation: "delete venue")
    }

    self.context.delete(venue)
    try self.context.save()

    self.log.info("Deleted venue: \(venue.name, privacy: .public)")
    self.notifyChanges()
  }

  func wipeAllForLogout() throws {
    let venues = try loadAll()
    for venue in venues {
      self.context.delete(venue)
    }
    try self.context.save()
    self.log.notice("Wiped all venues on sign-out")
    self.notifyChanges()
  }

  func refreshFromRemote() async throws {
    // SwiftData store relies on Supabase repository for remote pulls.
  }

  // MARK: - Internal Helpers

  /// Notify observers that venues changed
  private func notifyChanges() {
    do {
      let all = try loadAll()
      self.changesSubject.send(all)
    } catch {
      self.log.error("Failed to load venues for change notification: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Aggregate Delta Support

  func fetchVenue(id: UUID) throws -> VenueRecord? {
    var descriptor = FetchDescriptor<VenueRecord>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try self.context.fetch(descriptor).first
  }

  func upsertFromAggregate(
    _ aggregate: AggregateSnapshotPayload.Venue,
    ownerSupabaseId ownerId: String) throws -> VenueRecord
  {
    let record: VenueRecord
    if let existing = try fetchVenue(id: aggregate.id) {
      record = existing
    } else {
      record = VenueRecord(
        id: aggregate.id,
        name: aggregate.name,
        city: aggregate.city,
        country: aggregate.country,
        latitude: aggregate.latitude,
        longitude: aggregate.longitude,
        ownerSupabaseId: ownerId,
        lastModifiedAt: aggregate.lastModifiedAt,
        remoteUpdatedAt: aggregate.remoteUpdatedAt,
        needsRemoteSync: true)
      self.context.insert(record)
    }

    record.name = aggregate.name
    record.city = aggregate.city
    record.country = aggregate.country
    record.latitude = aggregate.latitude
    record.longitude = aggregate.longitude
    record.ownerSupabaseId = ownerId
    record.lastModifiedAt = aggregate.lastModifiedAt
    record.remoteUpdatedAt = aggregate.remoteUpdatedAt
    record.needsRemoteSync = true

    try self.context.save()
    self.notifyChanges()
    return record
  }

  func deleteVenue(id: UUID) throws {
    guard let existing = try fetchVenue(id: id) else { return }
    self.context.delete(existing)
    try self.context.save()
    self.notifyChanges()
  }
}
