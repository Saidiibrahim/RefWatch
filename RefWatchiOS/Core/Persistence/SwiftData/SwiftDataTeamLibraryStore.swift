//
//  SwiftDataTeamLibraryStore.swift
//  RefWatchiOS
//
//  SwiftData-backed implementation of TeamLibraryStoring
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

@MainActor
final class SwiftDataTeamLibraryStore: TeamLibraryStoring, TeamLibraryMetadataPersisting {
  private let container: ModelContainer
  let context: ModelContext
  private let auth: AuthenticationProviding
  private let log = AppLog.supabase
  private let changesSubject: CurrentValueSubject<[TeamRecord], Never>

  init(container: ModelContainer, auth: AuthenticationProviding) {
    self.container = container
    self.context = ModelContext(container)
    self.auth = auth
    let initial: [TeamRecord]
    do {
      initial = try self.context.fetch(FetchDescriptor<TeamRecord>(sortBy: [SortDescriptor(\.name, order: .forward)]))
    } catch {
      self.log.error(
        "Failed to load initial teams for publisher bootstrap: \(error.localizedDescription, privacy: .public)")
      initial = []
    }
    self.changesSubject = CurrentValueSubject(initial)
  }

  var changesPublisher: AnyPublisher<[TeamRecord], Never> {
    self.changesSubject.eraseToAnyPublisher()
  }

  // MARK: - Teams

  func loadAllTeams() throws -> [TeamRecord] {
    let desc = FetchDescriptor<TeamRecord>(sortBy: [SortDescriptor(\.name, order: .forward)])
    return try self.context.fetch(desc)
  }

  func searchTeams(query: String) throws -> [TeamRecord] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return try self.loadAllTeams() }
    let predicate = #Predicate<TeamRecord> { team in
      (team.name.localizedStandardContains(trimmed)) ||
        ((team.shortName ?? "").localizedStandardContains(trimmed)) ||
        ((team.division ?? "").localizedStandardContains(trimmed))
    }
    let desc = FetchDescriptor<TeamRecord>(predicate: predicate, sortBy: [SortDescriptor(\.name, order: .forward)])
    return try self.context.fetch(desc)
  }

  func createTeam(name: String, shortName: String?, division: String?) throws -> TeamRecord {
    let ownerId = try requireSignedIn(operation: "create team")
    let team = TeamRecord(name: name, shortName: shortName, division: division, ownerSupabaseId: ownerId)
    team.markLocallyModified(ownerSupabaseId: ownerId)
    self.context.insert(team)
    try self.context.save()
    self.publishChanges()
    return team
  }

  func updateTeam(_ team: TeamRecord) throws {
    let ownerId = try requireSignedIn(operation: "update team")
    // TeamRecord is reference type in ModelContext; fields mutated directly by caller.
    team.markLocallyModified(ownerSupabaseId: ownerId)
    try self.context.save()
    self.publishChanges()
  }

  func deleteTeam(_ team: TeamRecord) throws {
    _ = try self.requireSignedIn(operation: "delete team")
    self.context.delete(team)
    try self.context.save()
    self.publishChanges()
  }

  // MARK: - Players

  func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
    let ownerId = try requireSignedIn(operation: "add player")
    let p = PlayerRecord(name: name, number: number, team: team)
    team.players.append(p)
    self.context.insert(p)
    team.markLocallyModified(ownerSupabaseId: ownerId)
    try self.context.save()
    self.publishChanges()
    return p
  }

  func updatePlayer(_ player: PlayerRecord) throws {
    let ownerId = try requireSignedIn(operation: "update player")
    player.team?.markLocallyModified(ownerSupabaseId: ownerId)
    try self.context.save()
    self.publishChanges()
  }

  func deletePlayer(_ player: PlayerRecord) throws {
    let ownerId = try requireSignedIn(operation: "delete player")
    if let team = player.team {
      team.markLocallyModified(ownerSupabaseId: ownerId)
      team.players.removeAll { $0.id == player.id }
    }
    self.context.delete(player)
    try self.context.save()
    self.publishChanges()
  }

  // MARK: - Officials

  func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord {
    let ownerId = try requireSignedIn(operation: "add official")
    let o = TeamOfficialRecord(name: name, roleRaw: roleRaw, team: team)
    team.officials.append(o)
    self.context.insert(o)
    team.markLocallyModified(ownerSupabaseId: ownerId)
    try self.context.save()
    self.publishChanges()
    return o
  }

  func updateOfficial(_ official: TeamOfficialRecord) throws {
    let ownerId = try requireSignedIn(operation: "update official")
    official.team?.markLocallyModified(ownerSupabaseId: ownerId)
    try self.context.save()
    self.publishChanges()
  }

  func deleteOfficial(_ official: TeamOfficialRecord) throws {
    let ownerId = try requireSignedIn(operation: "delete official")
    if let team = official.team {
      team.markLocallyModified(ownerSupabaseId: ownerId)
      team.officials.removeAll { $0.id == official.id }
    }
    self.context.delete(official)
    try self.context.save()
    self.publishChanges()
  }

  func persistMetadataChanges(for team: TeamRecord) throws {
    _ = try self.requireSignedIn(operation: "persist team metadata")
    // Metadata adjustments do not require additional mutations; simply saving commits changes.
    try self.context.save()
    self.publishChanges()
  }

  func wipeAllForLogout() throws {
    let teams = try context.fetch(FetchDescriptor<TeamRecord>())
    for team in teams {
      self.context.delete(team)
    }
    if self.context.hasChanges {
      try self.context.save()
    }
    self.publishChanges()
  }

  func refreshFromRemote() async throws {}

  private func requireSignedIn(operation: String) throws -> String {
    guard let userId = auth.currentUserId else {
      throw PersistenceAuthError.signedOut(operation: operation)
    }
    return userId
  }

  func publishChanges() {
    do {
      let all = try loadAllTeams()
      self.changesSubject.send(all)
    } catch {
      self.log.error("Failed to publish team changes: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Aggregate Delta Support

  func fetchTeam(id: UUID) throws -> TeamRecord? {
    var descriptor = FetchDescriptor<TeamRecord>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try self.context.fetch(descriptor).first
  }

  func upsertFromAggregate(
    _ aggregate: AggregateSnapshotPayload.Team,
    ownerSupabaseId ownerId: String) throws -> TeamRecord
  {
    let record: TeamRecord
    if let existing = try fetchTeam(id: aggregate.id) {
      record = existing
    } else {
      record = TeamRecord(
        id: aggregate.id,
        name: aggregate.name,
        shortName: aggregate.shortName,
        division: aggregate.division,
        primaryColorHex: aggregate.primaryColorHex,
        secondaryColorHex: aggregate.secondaryColorHex,
        ownerSupabaseId: ownerId,
        lastModifiedAt: aggregate.lastModifiedAt,
        remoteUpdatedAt: aggregate.remoteUpdatedAt,
        needsRemoteSync: true)
      self.context.insert(record)
    }

    record.name = aggregate.name
    record.shortName = aggregate.shortName
    record.division = aggregate.division
    record.primaryColorHex = aggregate.primaryColorHex
    record.secondaryColorHex = aggregate.secondaryColorHex
    record.ownerSupabaseId = ownerId
    record.lastModifiedAt = aggregate.lastModifiedAt
    record.remoteUpdatedAt = aggregate.remoteUpdatedAt
    record.needsRemoteSync = true

    // Players
    var seenPlayerIDs = Set<UUID>()
    let existingPlayers = Dictionary(uniqueKeysWithValues: record.players.map { ($0.id, $0) })
    for player in aggregate.players {
      seenPlayerIDs.insert(player.id)
      if let existing = existingPlayers[player.id] {
        existing.name = player.name
        existing.number = player.number
        existing.position = player.position
        existing.notes = player.notes
      } else {
        let newPlayer = PlayerRecord(
          id: player.id,
          name: player.name,
          number: player.number,
          position: player.position,
          notes: player.notes,
          team: record)
        record.players.append(newPlayer)
        self.context.insert(newPlayer)
      }
    }
    if record.players.isEmpty == false {
      record.players.removeAll { player in
        if seenPlayerIDs.contains(player.id) {
          return false
        }
        self.context.delete(player)
        return true
      }
    }

    // Officials
    var seenOfficialIDs = Set<UUID>()
    let existingOfficials = Dictionary(uniqueKeysWithValues: record.officials.map { ($0.id, $0) })
    for official in aggregate.officials {
      seenOfficialIDs.insert(official.id)
      if let existing = existingOfficials[official.id] {
        existing.name = official.name
        existing.roleRaw = official.roleRaw
        existing.phone = official.phone
        existing.email = official.email
      } else {
        let newOfficial = TeamOfficialRecord(
          id: official.id,
          name: official.name,
          roleRaw: official.roleRaw,
          phone: official.phone,
          email: official.email,
          team: record)
        record.officials.append(newOfficial)
        self.context.insert(newOfficial)
      }
    }
    if record.officials.isEmpty == false {
      record.officials.removeAll { official in
        if seenOfficialIDs.contains(official.id) {
          return false
        }
        self.context.delete(official)
        return true
      }
    }

    try self.context.save()
    self.publishChanges()
    return record
  }

  func deleteTeam(id: UUID) throws {
    guard let existing = try fetchTeam(id: id) else { return }
    self.context.delete(existing)
    try self.context.save()
    self.publishChanges()
  }
}
