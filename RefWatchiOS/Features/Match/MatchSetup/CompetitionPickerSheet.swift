//
//  CompetitionPickerSheet.swift
//  RefWatchiOS
//
//  Sheet interface for selecting saved or canonical reference competitions.
//

import SwiftUI

struct CompetitionPickerSheet: View {
    let competitionStore: CompetitionLibraryStoring
    let onSelect: (CompetitionRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var competitions: [CompetitionRecord] = []
    @State private var referenceCompetitions: [ReferenceCompetitionOption] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var loadError: String?
    private let seasonYear = 2026

    private var filteredOptions: [CompetitionPickerOption] {
        let options = self.materializedOptions
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return options }
        let lowercased = trimmed.lowercased()
        return options.filter { option in
            option.searchIndex.contains(lowercased)
        }
    }

    private var materializedOptions: [CompetitionPickerOption] {
        let local = self.competitions.map { CompetitionPickerOption.local($0) }
        let references = self.referenceCompetitions
            .filter { self.isReferenceCompetitionMaterialized($0, in: self.competitions) == false }
            .map { CompetitionPickerOption.reference($0) }
        return (local + references)
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading competitions…")
                } else if let error = loadError {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if materializedOptions.isEmpty {
                    ContentUnavailableView(
                        "No Competitions Available",
                        systemImage: "trophy",
                        description: Text("No saved or reference competitions were found for your account.")
                    )
                } else {
                    competitionList
                }
            }
            .navigationTitle("Select Competition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search competitions")
            .onAppear(perform: loadCompetitions)
        }
    }

    private var competitionList: some View {
        List {
            let results = filteredOptions
            if results.isEmpty {
                ContentUnavailableView(
                    "No Competitions Found",
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

    private func loadCompetitions() {
        isLoading = true
        loadError = nil

        Task {
            var loadedCompetitions: [CompetitionRecord] = []
            var loadedReferences: [ReferenceCompetitionOption] = []
            var resolvedError: Error?

            do {
                try await self.competitionStore.refreshFromRemote()
            } catch {
                // Continue with local + reference fallback.
            }

            do {
                loadedCompetitions = try self.competitionStore.loadAll()
            } catch {
                resolvedError = error
            }

            do {
                loadedReferences = try await self.fetchReferenceCompetitions()
            } catch {
                if loadedCompetitions.isEmpty {
                    resolvedError = resolvedError ?? error
                }
            }

            await MainActor.run {
                self.competitions = loadedCompetitions
                self.referenceCompetitions = loadedReferences
                self.loadError = resolvedError?.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func handleSelection(_ option: CompetitionPickerOption) {
        do {
            let competition: CompetitionRecord
            switch option {
            case let .local(local):
                competition = local
            case let .reference(reference):
                competition = try self.materializeReferenceCompetition(reference)
            }
            self.onSelect(competition)
            self.dismiss()
        } catch {
            self.loadError = error.localizedDescription
        }
    }

    private func materializeReferenceCompetition(_ reference: ReferenceCompetitionOption) throws -> CompetitionRecord {
        let existingCompetitions = try self.competitionStore.loadAll()
        if let existing = self.findExistingCompetition(for: reference, in: existingCompetitions) {
            return existing
        }

        let created = try self.competitionStore.create(
            name: reference.name,
            level: reference.code.uppercased()
        )
        self.competitions = try self.competitionStore.loadAll()
        return created
    }

    private func findExistingCompetition(
        for reference: ReferenceCompetitionOption,
        in competitions: [CompetitionRecord]
    ) -> CompetitionRecord? {
        competitions.first { competition in
            self.normalized(competition.name) == self.normalized(reference.name)
                && self.normalized(competition.level) == self.normalized(reference.code.uppercased())
        }
    }

    private func isReferenceCompetitionMaterialized(
        _ reference: ReferenceCompetitionOption,
        in competitions: [CompetitionRecord]
    ) -> Bool {
        self.findExistingCompetition(for: reference, in: competitions) != nil
    }

    private func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func fetchReferenceCompetitions() async throws -> [ReferenceCompetitionOption] {
        let client = try await SupabaseClientProvider.shared.authorizedClient()
        let decoder = SupabaseJSONDecoderFactory.makeDecoder()

        let rows: [ReferenceCompetitionDTO] = try await client.fetchRows(
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

        return rows.map { row in
            ReferenceCompetitionOption(
                id: row.id,
                code: row.code,
                name: row.name
            )
        }
    }
}

private enum CompetitionPickerOption: Identifiable {
    case local(CompetitionRecord)
    case reference(ReferenceCompetitionOption)

    var id: String {
        switch self {
        case let .local(competition):
            return competition.id.uuidString
        case let .reference(reference):
            return "reference-\(reference.id.uuidString)"
        }
    }

    var name: String {
        switch self {
        case let .local(competition):
            return competition.name
        case let .reference(reference):
            return reference.name
        }
    }

    var subtitle: String? {
        switch self {
        case let .local(competition):
            return competition.level
        case let .reference(reference):
            return reference.code.uppercased()
        }
    }

    var searchIndex: String {
        switch self {
        case let .local(competition):
            return [
                competition.name,
                competition.level ?? "",
            ]
            .joined(separator: " ")
            .lowercased()
        case let .reference(reference):
            return [
                reference.name,
                reference.code,
            ]
            .joined(separator: " ")
            .lowercased()
        }
    }
}

private struct ReferenceCompetitionOption: Identifiable {
    let id: UUID
    let code: String
    let name: String
}

private struct ReferenceCompetitionDTO: Decodable {
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

#if DEBUG
struct CompetitionPickerSheet_Previews: PreviewProvider {
    static func previewStore() -> CompetitionLibraryStoring {
        let store = InMemoryCompetitionLibraryStore()
        _ = try? store.create(name: "Premier League", level: "Professional")
        _ = try? store.create(name: "FA Cup", level: "Knockout")
        _ = try? store.create(name: "Sunday League", level: "Amateur")
        return store
    }

    static var previews: some View {
        CompetitionPickerSheet(competitionStore: previewStore()) { _ in }
    }
}
#endif
