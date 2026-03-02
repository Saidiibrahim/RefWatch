//
//  TeamPickerSheet.swift
//  RefWatchiOS
//
//  Select a team from saved library entries and canonical reference catalog.
//

import SwiftUI

struct TeamPickerSheet: View {
    let teamStore: TeamLibraryStoring
    let onSelect: (TeamRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var teams: [TeamRecord] = []
    @State private var referenceTeams: [ReferenceTeamOption] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var loadError: String?
    private let seasonYear = 2026

    private var filteredOptions: [TeamPickerOption] {
        let options = self.materializedOptions
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return options }
        let lowercased = trimmed.lowercased()
        return options.filter { option in
            option.searchIndex.contains(lowercased)
        }
    }

    private var materializedOptions: [TeamPickerOption] {
        let local = self.teams.map { TeamPickerOption.local($0) }
        let references = self.referenceTeams
            .filter { self.isReferenceTeamMaterialized($0, in: self.teams) == false }
            .map { TeamPickerOption.reference($0) }
        return (local + references)
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading teams…")
                } else if let error = loadError {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if materializedOptions.isEmpty {
                    ContentUnavailableView(
                        "No Teams Available",
                        systemImage: "person.3",
                        description: Text("No saved or reference teams were found for your account.")
                    )
                } else {
                    teamList
                }
            }
            .navigationTitle("Select Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search teams")
            .onAppear(perform: loadTeams)
        }
    }

    private var teamList: some View {
        List {
            let results = filteredOptions
            if results.isEmpty {
                ContentUnavailableView(
                    "No Teams Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ForEach(results) { option in
                    Button {
                        self.handleSelection(option)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.name)
                                .font(.headline)
                            if let subtitle = option.subtitle, subtitle.isEmpty == false {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func loadTeams() {
        isLoading = true
        loadError = nil

        Task { @MainActor in
            var loadedTeams: [TeamRecord] = []
            var loadedReferenceTeams: [ReferenceTeamOption] = []
            var resolvedError: Error?

            do {
                try await self.teamStore.refreshFromRemote()
            } catch {
                // Continue with local + reference fallback.
            }

            do {
                loadedTeams = try self.teamStore.loadAllTeams()
            } catch {
                resolvedError = error
            }

            do {
                loadedReferenceTeams = try await self.fetchReferenceTeams()
            } catch {
                if loadedTeams.isEmpty {
                    resolvedError = resolvedError ?? error
                }
            }

            self.teams = loadedTeams
            self.referenceTeams = loadedReferenceTeams
            self.loadError = resolvedError?.localizedDescription
            self.isLoading = false
        }
    }

    private func handleSelection(_ option: TeamPickerOption) {
        do {
            let team: TeamRecord
            switch option {
            case let .local(local):
                team = local
            case let .reference(reference):
                team = try self.materializeReferenceTeam(reference)
            }
            self.onSelect(team)
            self.dismiss()
        } catch {
            self.loadError = error.localizedDescription
        }
    }

    private func materializeReferenceTeam(_ reference: ReferenceTeamOption) throws -> TeamRecord {
        let existingTeams = try self.teamStore.loadAllTeams()
        if let existing = self.findExistingTeam(for: reference, in: existingTeams) {
            return existing
        }

        let created = try self.teamStore.createTeam(
            name: reference.name,
            shortName: reference.shortName,
            division: reference.competitionName
        )
        created.referenceKey = reference.referenceKey
        try self.teamStore.updateTeam(created)
        self.teams = try self.teamStore.loadAllTeams()
        return created
    }

    private func findExistingTeam(for reference: ReferenceTeamOption, in teams: [TeamRecord]) -> TeamRecord? {
        if let keyedMatch = teams.first(where: { $0.referenceKey == reference.referenceKey }) {
            return keyedMatch
        }
        return teams.first { team in
            self.normalized(team.name) == self.normalized(reference.name)
                && self.normalized(team.division) == self.normalized(reference.competitionName)
        }
    }

    private func isReferenceTeamMaterialized(_ reference: ReferenceTeamOption, in teams: [TeamRecord]) -> Bool {
        self.findExistingTeam(for: reference, in: teams) != nil
    }

    private func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func fetchReferenceTeams() async throws -> [ReferenceTeamOption] {
        let client = try await SupabaseClientProvider.shared.authorizedClient()
        let decoder = SupabaseJSONDecoderFactory.makeDecoder()

        let competitions: [ReferenceCompetitionRowDTO] = try await client.fetchRows(
            SupabaseFetchRequest(
                table: "reference_competitions",
                columns: "id, code, name, season_year",
                filters: [.equals("season_year", value: String(self.seasonYear))],
                orderBy: "name",
                ascending: true,
                limit: 0,
                decoder: decoder
            )
        )

        guard competitions.isEmpty == false else {
            return []
        }

        let competitionsById = Dictionary(uniqueKeysWithValues: competitions.map { ($0.id, $0) })
        let competitionIds = competitions.map { $0.id.uuidString }

        let teamRows: [ReferenceTeamRowDTO] = try await client.fetchRows(
            SupabaseFetchRequest(
                table: "reference_teams",
                columns: "id, competition_id, name, short_name, reference_key, season_year",
                filters: [
                    .equals("season_year", value: String(self.seasonYear)),
                    .in("competition_id", values: competitionIds),
                ],
                orderBy: "name",
                ascending: true,
                limit: 0,
                decoder: decoder
            )
        )

        return teamRows.compactMap { row in
            guard let competition = competitionsById[row.competitionId] else {
                return nil
            }
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
}

private enum TeamPickerOption: Identifiable {
    case local(TeamRecord)
    case reference(ReferenceTeamOption)

    var id: String {
        switch self {
        case let .local(team):
            return team.id.uuidString
        case let .reference(reference):
            return "reference-\(reference.referenceKey)"
        }
    }

    var name: String {
        switch self {
        case let .local(team):
            return team.name
        case let .reference(reference):
            return reference.name
        }
    }

    var subtitle: String? {
        switch self {
        case let .local(team):
            return team.division
        case let .reference(reference):
            return reference.competitionName
        }
    }

    var searchIndex: String {
        switch self {
        case let .local(team):
            return [
                team.name,
                team.shortName ?? "",
                team.division ?? "",
            ]
            .joined(separator: " ")
            .lowercased()
        case let .reference(reference):
            return [
                reference.name,
                reference.shortName ?? "",
                reference.competitionName,
                reference.competitionCode,
            ]
            .joined(separator: " ")
            .lowercased()
        }
    }
}

private struct ReferenceTeamOption: Identifiable {
    let id: UUID
    let referenceKey: String
    let name: String
    let shortName: String?
    let competitionCode: String
    let competitionName: String
}

private struct ReferenceCompetitionRowDTO: Decodable {
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

private struct ReferenceTeamRowDTO: Decodable {
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

#if DEBUG
struct TeamPickerSheet_Previews: PreviewProvider {
    @MainActor static func previewStore() -> TeamLibraryStoring {
        let store = InMemoryTeamLibraryStore()
        _ = try? store.createTeam(name: "Arsenal", shortName: "ARS", division: "Premier League")
        _ = try? store.createTeam(name: "Chelsea", shortName: "CHE", division: "Premier League")
        _ = try? store.createTeam(name: "Barcelona", shortName: "FCB", division: "La Liga")
        return store
    }

    static var previews: some View {
        TeamPickerSheet(teamStore: previewStore()) { _ in }
    }
}
#endif
