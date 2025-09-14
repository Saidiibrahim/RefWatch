//
//  SwiftDataTeamLibraryStore.swift
//  RefZoneiOS
//
//  SwiftData-backed implementation of TeamLibraryStoring
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTeamLibraryStore: TeamLibraryStoring {
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
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
        let team = TeamRecord(name: name, shortName: shortName, division: division)
        context.insert(team)
        try context.save()
        return team
    }

    func updateTeam(_ team: TeamRecord) throws {
        // TeamRecord is reference type in ModelContext; fields mutated directly by caller.
        try context.save()
    }

    func deleteTeam(_ team: TeamRecord) throws {
        context.delete(team)
        try context.save()
    }

    // MARK: - Players
    func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
        let p = PlayerRecord(name: name, number: number, team: team)
        team.players.append(p)
        context.insert(p)
        try context.save()
        return p
    }

    func updatePlayer(_ player: PlayerRecord) throws { try context.save() }

    func deletePlayer(_ player: PlayerRecord) throws {
        if let team = player.team { team.players.removeAll { $0.id == player.id } }
        context.delete(player)
        try context.save()
    }

    // MARK: - Officials
    func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord {
        let o = TeamOfficialRecord(name: name, roleRaw: roleRaw, team: team)
        team.officials.append(o)
        context.insert(o)
        try context.save()
        return o
    }

    func updateOfficial(_ official: TeamOfficialRecord) throws { try context.save() }

    func deleteOfficial(_ official: TeamOfficialRecord) throws {
        if let team = official.team { team.officials.removeAll { $0.id == official.id } }
        context.delete(official)
        try context.save()
    }
}

