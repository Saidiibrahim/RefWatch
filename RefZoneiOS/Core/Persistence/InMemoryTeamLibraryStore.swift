//
//  InMemoryTeamLibraryStore.swift
//  RefZoneiOS
//
//  Simple in-memory fallback that satisfies TeamLibraryStoring when SwiftData is unavailable.
//  Not persisted; intended only for graceful degradation.
//

import Foundation

@MainActor
final class InMemoryTeamLibraryStore: TeamLibraryStoring {
    private var teams: [TeamRecord] = []

    func loadAllTeams() throws -> [TeamRecord] { teams.sorted { $0.name < $1.name } }

    func searchTeams(query: String) throws -> [TeamRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return try loadAllTeams() }
        return try loadAllTeams().filter { t in
            t.name.localizedCaseInsensitiveContains(q) ||
            (t.shortName ?? "").localizedCaseInsensitiveContains(q) ||
            (t.division ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    func createTeam(name: String, shortName: String?, division: String?) throws -> TeamRecord {
        let t = TeamRecord(name: name, shortName: shortName, division: division)
        teams.append(t)
        return t
    }

    func updateTeam(_ team: TeamRecord) throws { /* structs are reference models; nothing extra */ }

    func deleteTeam(_ team: TeamRecord) throws { teams.removeAll { $0.id == team.id } }

    func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
        let p = PlayerRecord(name: name, number: number, team: team)
        team.players.append(p)
        return p
    }

    func updatePlayer(_ player: PlayerRecord) throws { }

    func deletePlayer(_ player: PlayerRecord) throws {
        player.team?.players.removeAll { $0.id == player.id }
    }

    func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord {
        let o = TeamOfficialRecord(name: name, roleRaw: roleRaw, team: team)
        team.officials.append(o)
        return o
    }

    func updateOfficial(_ official: TeamOfficialRecord) throws { }

    func deleteOfficial(_ official: TeamOfficialRecord) throws {
        official.team?.officials.removeAll { $0.id == official.id }
    }
}

