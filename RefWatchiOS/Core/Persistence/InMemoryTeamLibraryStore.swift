//
//  InMemoryTeamLibraryStore.swift
//  RefWatchiOS
//
//  Simple in-memory fallback that satisfies TeamLibraryStoring when SwiftData is unavailable.
//  Not persisted; intended only for graceful degradation.
//

import Foundation
import Combine

@MainActor
final class InMemoryTeamLibraryStore: TeamLibraryStoring, TeamLibraryMetadataPersisting {
    private var teams: [TeamRecord] = []
    private let subject = CurrentValueSubject<[TeamRecord], Never>([])

    var changesPublisher: AnyPublisher<[TeamRecord], Never> {
        subject.eraseToAnyPublisher()
    }

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
        t.markLocallyModified()
        teams.append(t)
        publish()
        return t
    }

    func updateTeam(_ team: TeamRecord) throws {
        team.markLocallyModified()
        publish()
    }

    func deleteTeam(_ team: TeamRecord) throws {
        teams.removeAll { $0.id == team.id }
        publish()
    }

    func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
        let p = PlayerRecord(name: name, number: number, team: team)
        team.players.append(p)
        team.markLocallyModified()
        publish()
        return p
    }

    func updatePlayer(_ player: PlayerRecord) throws {
        player.team?.markLocallyModified()
        publish()
    }

    func deletePlayer(_ player: PlayerRecord) throws {
        if let team = player.team {
            team.players.removeAll { $0.id == player.id }
            team.markLocallyModified()
        }
        publish()
    }

    func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord {
        let o = TeamOfficialRecord(name: name, roleRaw: roleRaw, team: team)
        team.officials.append(o)
        team.markLocallyModified()
        publish()
        return o
    }

    func updateOfficial(_ official: TeamOfficialRecord) throws {
        official.team?.markLocallyModified()
        publish()
    }

    func deleteOfficial(_ official: TeamOfficialRecord) throws {
        if let team = official.team {
            team.officials.removeAll { $0.id == official.id }
            team.markLocallyModified()
        }
        publish()
    }

    func persistMetadataChanges(for team: TeamRecord) throws { publish() }

    func refreshFromRemote() async throws { }

    private func publish() {
        subject.send(teams.sorted { $0.name < $1.name })
    }
}
