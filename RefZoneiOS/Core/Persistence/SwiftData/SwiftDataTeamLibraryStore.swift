//
//  SwiftDataTeamLibraryStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of TeamLibraryStoring
//

import Foundation
import SwiftData
import RefWatchCore

@MainActor
final class SwiftDataTeamLibraryStore: TeamLibraryStoring, TeamLibraryMetadataPersisting {
    private let container: ModelContainer
    let context: ModelContext
    private let auth: AuthenticationProviding

    init(container: ModelContainer, auth: AuthenticationProviding) {
        self.container = container
        self.context = ModelContext(container)
        self.auth = auth
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
        return team
    }

    func updateTeam(_ team: TeamRecord) throws {
        let ownerId = try requireSignedIn(operation: "update team")
        // TeamRecord is reference type in ModelContext; fields mutated directly by caller.
        team.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
    }

    func deleteTeam(_ team: TeamRecord) throws {
        try requireSignedIn(operation: "delete team")
        context.delete(team)
        try context.save()
    }

    // MARK: - Players
    func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
        let ownerId = try requireSignedIn(operation: "add player")
        let p = PlayerRecord(name: name, number: number, team: team)
        team.players.append(p)
        context.insert(p)
        team.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
        return p
    }

    func updatePlayer(_ player: PlayerRecord) throws {
        let ownerId = try requireSignedIn(operation: "update player")
        player.team?.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
    }

    func deletePlayer(_ player: PlayerRecord) throws {
        let ownerId = try requireSignedIn(operation: "delete player")
        if let team = player.team {
            team.markLocallyModified(ownerSupabaseId: ownerId)
            team.players.removeAll { $0.id == player.id }
        }
        context.delete(player)
        try context.save()
    }

    // MARK: - Officials
    func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord {
        let ownerId = try requireSignedIn(operation: "add official")
        let o = TeamOfficialRecord(name: name, roleRaw: roleRaw, team: team)
        team.officials.append(o)
        context.insert(o)
        team.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
        return o
    }

    func updateOfficial(_ official: TeamOfficialRecord) throws {
        let ownerId = try requireSignedIn(operation: "update official")
        official.team?.markLocallyModified(ownerSupabaseId: ownerId)
        try context.save()
    }

    func deleteOfficial(_ official: TeamOfficialRecord) throws {
        let ownerId = try requireSignedIn(operation: "delete official")
        if let team = official.team {
            team.markLocallyModified(ownerSupabaseId: ownerId)
            team.officials.removeAll { $0.id == official.id }
        }
        context.delete(official)
        try context.save()
    }

    func persistMetadataChanges(for team: TeamRecord) throws {
        try requireSignedIn(operation: "persist team metadata")
        // Metadata adjustments do not require additional mutations; simply saving commits changes.
        try context.save()
    }

    func wipeAllForLogout() throws {
        let teams = try context.fetch(FetchDescriptor<TeamRecord>())
        for team in teams { context.delete(team) }
        if context.hasChanges {
            try context.save()
        }
    }

    private func requireSignedIn(operation: String) throws -> String {
        guard let userId = auth.currentUserId else {
            throw PersistenceAuthError.signedOut(operation: operation)
        }
        return userId
    }
}
