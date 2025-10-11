//
//  TeamLibraryStoring.swift
//  RefZoneiOS
//
//  Abstraction for Teams library persistence (SwiftData-backed in iOS).
//

import Foundation

@MainActor
protocol TeamLibraryStoring {
    // Teams
    func loadAllTeams() throws -> [TeamRecord]
    func searchTeams(query: String) throws -> [TeamRecord]
    func createTeam(name: String, shortName: String?, division: String?) throws -> TeamRecord
    func updateTeam(_ team: TeamRecord) throws
    func deleteTeam(_ team: TeamRecord) throws

    // Players
    func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord
    func updatePlayer(_ player: PlayerRecord) throws
    func deletePlayer(_ player: PlayerRecord) throws

    // Officials
    func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord
    func updateOfficial(_ official: TeamOfficialRecord) throws
    func deleteOfficial(_ official: TeamOfficialRecord) throws
}

@MainActor
protocol TeamLibraryMetadataPersisting {
    func persistMetadataChanges(for team: TeamRecord) throws
}
