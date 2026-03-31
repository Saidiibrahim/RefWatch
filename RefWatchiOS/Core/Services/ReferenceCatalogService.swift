//
//  ReferenceCatalogService.swift
//  RefWatchiOS
//
//  Shared helpers for fetching and materializing reference teams and competitions
//  from the Supabase catalog. Used by picker sheets and library list views.
//

import Foundation

// MARK: - DTOs

struct ReferenceTeamOption: Identifiable {
    let id: UUID
    let referenceKey: String
    let name: String
    let shortName: String?
    let competitionCode: String
    let competitionName: String
}

struct ReferenceCompetitionOption: Identifiable {
    let id: UUID
    let code: String
    let name: String
}

// MARK: - Service

enum ReferenceCatalogService {

    nonisolated static let seasonYear = 2026

    // MARK: - Teams

    static func fetchReferenceTeams(seasonYear: Int = seasonYear) async throws -> [ReferenceTeamOption] {
        let client = try await SupabaseClientProvider.shared.authorizedClient()
        let decoder = SupabaseJSONDecoderFactory.makeDecoder()

        let competitions: [ReferenceCompetitionRowDTO] = try await client.fetchRows(
            SupabaseFetchRequest(
                table: "reference_competitions",
                columns: "id, code, name, season_year",
                filters: [.equals("season_year", value: String(seasonYear))],
                orderBy: "name",
                ascending: true,
                limit: 0,
                decoder: decoder
            )
        )

        guard competitions.isEmpty == false else { return [] }

        let competitionsById = Dictionary(uniqueKeysWithValues: competitions.map { ($0.id, $0) })
        let competitionIds = competitions.map { $0.id.uuidString }

        let teamRows: [ReferenceTeamRowDTO] = try await client.fetchRows(
            SupabaseFetchRequest(
                table: "reference_teams",
                columns: "id, competition_id, name, short_name, reference_key, season_year",
                filters: [
                    .equals("season_year", value: String(seasonYear)),
                    .in("competition_id", values: competitionIds),
                ],
                orderBy: "name",
                ascending: true,
                limit: 0,
                decoder: decoder
            )
        )

        return teamRows.compactMap { row in
            guard let competition = competitionsById[row.competitionId] else { return nil }
            return ReferenceTeamOption(
                id: row.id,
                referenceKey: row.referenceKey,
                name: row.name,
                shortName: row.shortName,
                competitionCode: competition.code,
                competitionName: competition.name
            )
        }
    }

    @MainActor
    static func materializeReferenceTeam(
        _ reference: ReferenceTeamOption,
        into teamStore: TeamLibraryStoring,
        existingTeams: [TeamRecord]? = nil
    ) throws -> TeamRecord {
        let teams = try existingTeams ?? teamStore.loadAllTeams()
        if let existing = findExistingTeam(for: reference, in: teams) {
            return existing
        }

        let created = try teamStore.createTeam(
            name: reference.name,
            shortName: reference.shortName,
            division: reference.competitionName
        )
        created.referenceKey = reference.referenceKey
        try teamStore.updateTeam(created)
        return created
    }

    static func findExistingTeam(for reference: ReferenceTeamOption, in teams: [TeamRecord]) -> TeamRecord? {
        if let keyedMatch = teams.first(where: { $0.referenceKey == reference.referenceKey }) {
            return keyedMatch
        }
        return teams.first { team in
            normalized(team.name) == normalized(reference.name)
                && normalized(team.division) == normalized(reference.competitionName)
        }
    }

    static func isReferenceTeamMaterialized(_ reference: ReferenceTeamOption, in teams: [TeamRecord]) -> Bool {
        findExistingTeam(for: reference, in: teams) != nil
    }

    // MARK: - Competitions

    static func fetchReferenceCompetitions(seasonYear: Int = seasonYear) async throws -> [ReferenceCompetitionOption] {
        let client = try await SupabaseClientProvider.shared.authorizedClient()
        let decoder = SupabaseJSONDecoderFactory.makeDecoder()

        let rows: [ReferenceCompetitionRowDTO] = try await client.fetchRows(
            SupabaseFetchRequest(
                table: "reference_competitions",
                columns: "id, code, name, season_year",
                filters: [.equals("season_year", value: String(seasonYear))],
                orderBy: "name",
                ascending: true,
                limit: 0,
                decoder: decoder
            )
        )

        return rows.map { row in
            ReferenceCompetitionOption(
                id: row.id,
                code: row.code,
                name: row.name
            )
        }
    }

    static func materializeReferenceCompetition(
        _ reference: ReferenceCompetitionOption,
        into competitionStore: CompetitionLibraryStoring,
        existingCompetitions: [CompetitionRecord]? = nil
    ) throws -> CompetitionRecord {
        let competitions = try existingCompetitions ?? competitionStore.loadAll()
        if let existing = findExistingCompetition(for: reference, in: competitions) {
            return existing
        }

        let created = try competitionStore.create(
            name: reference.name,
            level: reference.code.uppercased()
        )
        return created
    }

    static func findExistingCompetition(
        for reference: ReferenceCompetitionOption,
        in competitions: [CompetitionRecord]
    ) -> CompetitionRecord? {
        competitions.first { competition in
            normalized(competition.name) == normalized(reference.name)
                && normalized(competition.level) == normalized(reference.code.uppercased())
        }
    }

    static func isReferenceCompetitionMaterialized(
        _ reference: ReferenceCompetitionOption,
        in competitions: [CompetitionRecord]
    ) -> Bool {
        findExistingCompetition(for: reference, in: competitions) != nil
    }

    // MARK: - Helpers

    private static func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    #if DEBUG
    static var previewReferenceTeams: [ReferenceTeamOption] {
        let competitions = fixtureCompetitionRows()
        let competitionsById = Dictionary(uniqueKeysWithValues: competitions.map { ($0.id, $0) })
        return fixtureTeamRows().compactMap { row in
            guard let competition = competitionsById[row.competitionId] else { return nil }
            return ReferenceTeamOption(
                id: row.id,
                referenceKey: row.referenceKey,
                name: row.name,
                shortName: row.shortName,
                competitionCode: competition.code,
                competitionName: competition.name
            )
        }
    }

    static func fixtureCompetitionRows(seasonYear: Int = seasonYear) -> [ReferenceCompetitionRowDTO] {
        guard seasonYear == self.seasonYear else { return [] }
        return [
            ReferenceCompetitionRowDTO(
                id: UUID(uuidString: "4A111111-1111-4111-8111-111111111111")!,
                code: "PSL",
                name: "Premier Soccer League",
                seasonYear: seasonYear),
            ReferenceCompetitionRowDTO(
                id: UUID(uuidString: "4A222222-2222-4222-8222-222222222222")!,
                code: "NFD",
                name: "National First Division",
                seasonYear: seasonYear),
        ]
    }

    static func fixtureTeamRows(seasonYear: Int = seasonYear) -> [ReferenceTeamRowDTO] {
        let competitionRows = fixtureCompetitionRows(seasonYear: seasonYear)
        guard
            let pslId = competitionRows.first(where: { $0.code == "PSL" })?.id,
            let nfdId = competitionRows.first(where: { $0.code == "NFD" })?.id
        else { return [] }

        return [
            ReferenceTeamRowDTO(
                id: UUID(uuidString: "5B111111-1111-4111-8111-111111111111")!,
                competitionId: pslId,
                name: "Kaizer Chiefs",
                shortName: "CHI",
                referenceKey: "sa-kaizer-chiefs",
                seasonYear: seasonYear),
            ReferenceTeamRowDTO(
                id: UUID(uuidString: "5B222222-2222-4222-8222-222222222222")!,
                competitionId: pslId,
                name: "Orlando Pirates",
                shortName: "PIR",
                referenceKey: "sa-orlando-pirates",
                seasonYear: seasonYear),
            ReferenceTeamRowDTO(
                id: UUID(uuidString: "5B333333-3333-4333-8333-333333333333")!,
                competitionId: pslId,
                name: "Mamelodi Sundowns",
                shortName: "SUN",
                referenceKey: "sa-mamelodi-sundowns",
                seasonYear: seasonYear),
            ReferenceTeamRowDTO(
                id: UUID(uuidString: "5B444444-4444-4444-8444-444444444444")!,
                competitionId: nfdId,
                name: "TS Galaxy",
                shortName: "GAL",
                referenceKey: "sa-ts-galaxy",
                seasonYear: seasonYear),
            ReferenceTeamRowDTO(
                id: UUID(uuidString: "5B555555-5555-4555-8555-555555555555")!,
                competitionId: nfdId,
                name: "Mbombela United",
                shortName: "MBU",
                referenceKey: "sa-mbombela-united",
                seasonYear: seasonYear),
        ]
    }
    #endif
}

// MARK: - Internal DTOs (Supabase row shapes)

struct ReferenceCompetitionRowDTO: Codable {
    let id: UUID
    let code: String
    let name: String
    let seasonYear: Int

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case seasonYear = "season_year"
    }
}

struct ReferenceTeamRowDTO: Codable {
    let id: UUID
    let competitionId: UUID
    let name: String
    let shortName: String?
    let referenceKey: String
    let seasonYear: Int

    enum CodingKeys: String, CodingKey {
        case id
        case competitionId = "competition_id"
        case name
        case shortName = "short_name"
        case referenceKey = "reference_key"
        case seasonYear = "season_year"
    }
}
