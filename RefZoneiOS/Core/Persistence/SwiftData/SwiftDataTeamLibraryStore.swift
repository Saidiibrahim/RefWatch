//
//  SwiftDataTeamLibraryStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of TeamLibraryStoring
//

import Foundation
import SwiftData
import RefWatchCore
import Combine
import OSLog

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
            initial = try context.fetch(FetchDescriptor<TeamRecord>(sortBy: [SortDescriptor(\.name, order: .forward)]))
        } catch {
            log.error("Failed to load initial teams for publisher bootstrap: \(error.localizedDescription, privacy: .public)")
            initial = []
        }
        self.changesSubject = CurrentValueSubject(initial)
    }

    var changesPublisher: AnyPublisher<[TeamRecord], Never> {
        changesSubject.eraseToAnyPublisher()
    }

    // MARK: - Teams
    func loadAllTeams() throws -> [TeamRecord] {
        let desc = FetchDescriptor<TeamRecord>(sortBy: [SortDescriptor(\.name, order: .forward)])
        return try context.fetch(desc)
    }

    func searchTeams(query: String) throws -> [TeamRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return try loadAllTeams() }
        let predicate = #Predicate<TeamRecord> { team in
            (team.name.localizedStandardContains(trimmed)) ||
            ((team.shortName ?? "").localizedStandardContains(trimmed)) ||
            ((team.division ?? "").localizedStandardContains(trimmed))
        }
        let desc = FetchDescriptor<TeamRecord>(predicate: predicate, sortBy: [SortDescriptor(\.name, order: .forward)])
        return try context.fetch(desc)
    }

    func createTeam(name: String, shortName: String?, division: String?) throws -> TeamRecord {
        let ownerId = try requireSignedIn(operation: "create team")
        let team = TeamRecord(name: name, shortName: shortName, division: division, ownerSupabaseId: ownerId)
        team.markLocallyModified(ownerSupabaseId: ownerId)
        context.insert(team)
        try context.save()
        publishChanges()
        return team
    }

    func updateTeam(_ team: TeamRecord) throws {
        let ownerId = try requireSignedIn(operation: "update team")
        // TeamRecord is reference type in ModelContext; fields mutated directly by caller.
        team.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
        publishChanges()
    }

    func deleteTeam(_ team: TeamRecord) throws {
        _ = try requireSignedIn(operation: "delete team")
        context.delete(team)
        try context.save()
        publishChanges()
    }

    // MARK: - Players
    func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
        let ownerId = try requireSignedIn(operation: "add player")
        let p = PlayerRecord(name: name, number: number, team: team)
        team.players.append(p)
        context.insert(p)
        team.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
        publishChanges()
        return p
    }

    func updatePlayer(_ player: PlayerRecord) throws {
        let ownerId = try requireSignedIn(operation: "update player")
        player.team?.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
        publishChanges()
    }

    func deletePlayer(_ player: PlayerRecord) throws {
        let ownerId = try requireSignedIn(operation: "delete player")
        if let team = player.team {
            team.markLocallyModified(ownerSupabaseId: ownerId)
            team.players.removeAll { $0.id == player.id }
        }
        context.delete(player)
        try context.save()
        publishChanges()
    }

    // MARK: - Officials
    func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord {
        let ownerId = try requireSignedIn(operation: "add official")
        let o = TeamOfficialRecord(name: name, roleRaw: roleRaw, team: team)
        team.officials.append(o)
        context.insert(o)
        team.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
        publishChanges()
        return o
    }

    func updateOfficial(_ official: TeamOfficialRecord) throws {
        let ownerId = try requireSignedIn(operation: "update official")
        official.team?.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
        publishChanges()
    }

    func deleteOfficial(_ official: TeamOfficialRecord) throws {
        let ownerId = try requireSignedIn(operation: "delete official")
        if let team = official.team {
            team.markLocallyModified(ownerSupabaseId: ownerId)
            team.officials.removeAll { $0.id == official.id }
        }
        context.delete(official)
        try context.save()
        publishChanges()
    }

    func persistMetadataChanges(for team: TeamRecord) throws {
        _ = try requireSignedIn(operation: "persist team metadata")
        // Metadata adjustments do not require additional mutations; simply saving commits changes.
        try context.save()
        publishChanges()
    }

    func wipeAllForLogout() throws {
        let teams = try context.fetch(FetchDescriptor<TeamRecord>())
        for team in teams { context.delete(team) }
        if context.hasChanges {
            try context.save()
        }
        publishChanges()
    }

    func refreshFromRemote() async throws { }

    private func requireSignedIn(operation: String) throws -> String {
        guard let userId = auth.currentUserId else {
            throw PersistenceAuthError.signedOut(operation: operation)
        }
        return userId
    }

    func publishChanges() {
        do {
            let all = try loadAllTeams()
            changesSubject.send(all)
        } catch {
            log.error("Failed to publish team changes: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Aggregate Delta Support

    func fetchTeam(id: UUID) throws -> TeamRecord? {
        var descriptor = FetchDescriptor<TeamRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func upsertFromAggregate(_ aggregate: AggregateSnapshotPayload.Team, ownerSupabaseId ownerId: String) throws -> TeamRecord {
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
                needsRemoteSync: true
            )
            context.insert(record)
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
                    team: record
                )
                record.players.append(newPlayer)
                context.insert(newPlayer)
            }
        }
        if record.players.isEmpty == false {
            record.players.removeAll { player in
                if seenPlayerIDs.contains(player.id) {
                    return false
                }
                context.delete(player)
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
                    team: record
                )
                record.officials.append(newOfficial)
                context.insert(newOfficial)
            }
        }
        if record.officials.isEmpty == false {
            record.officials.removeAll { official in
                if seenOfficialIDs.contains(official.id) {
                    return false
                }
                context.delete(official)
                return true
            }
        }

        try context.save()
        publishChanges()
        return record
    }

    func deleteTeam(id: UUID) throws {
        guard let existing = try fetchTeam(id: id) else { return }
        context.delete(existing)
        try context.save()
        publishChanges()
    }
}
