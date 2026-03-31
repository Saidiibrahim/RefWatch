//
//  TeamPickerSheet.swift
//  RefWatchiOS
//
//  Select a team from saved library entries and canonical reference catalog.
//

import SwiftUI

enum TeamPickerSheetMode: Equatable {
    case fullCatalog
    case libraryOnly
}

struct TeamPickerSheet: View {
    let teamStore: TeamLibraryStoring
    let mode: TeamPickerSheetMode
    let onSelect: (TeamRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var teams: [TeamRecord] = []
    @State private var referenceTeams: [ReferenceTeamOption] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var loadError: String?

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredOptions: [TeamPickerOption] {
        let options = self.materializedOptions
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return options }
        let lowercased = trimmed.lowercased()
        return options.filter { option in
            option.searchIndex.contains(lowercased)
        }
    }

    private var unmaterializedReferences: [ReferenceTeamOption] {
        self.referenceTeams
            .filter { ReferenceCatalogService.isReferenceTeamMaterialized($0, in: self.teams) == false }
    }

    private var hasAnyOptions: Bool {
        !self.teams.isEmpty || !self.unmaterializedReferences.isEmpty
    }

    private var emptyStateDescription: String {
        switch self.mode {
        case .fullCatalog:
            return "No saved or reference teams were found for your account."
        case .libraryOnly:
            return "No saved library teams were found for your account."
        }
    }

    init(
        teamStore: TeamLibraryStoring,
        mode: TeamPickerSheetMode = .fullCatalog,
        onSelect: @escaping (TeamRecord) -> Void
    ) {
        self.teamStore = teamStore
        self.mode = mode
        self.onSelect = onSelect
    }

    private var materializedOptions: [TeamPickerOption] {
        let local = self.teams.map { TeamPickerOption.local($0) }
        let references = self.unmaterializedReferences.map { TeamPickerOption.reference($0) }
        return (local + references)
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var localTeamsSorted: [TeamRecord] {
        self.teams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var groupedReferenceTeams: [(String, [ReferenceTeamOption])] {
        let grouped = Dictionary(grouping: self.unmaterializedReferences, by: \.competitionName)
        return grouped
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { ($0.key, $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
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
                } else if !hasAnyOptions {
                    ContentUnavailableView(
                        "No Teams Available",
                        systemImage: "person.3",
                        description: Text(self.emptyStateDescription)
                    )
                } else {
                    teamList
                }
            }
            .navigationTitle("Select Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search teams")
            .onAppear(perform: loadTeams)
        }
    }

    private var teamList: some View {
        List {
            if isSearching {
                let results = filteredOptions
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Teams Found",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    ForEach(results) { option in
                        teamOptionRow(option)
                    }
                }
            } else {
                if !localTeamsSorted.isEmpty {
                    Section("Your Teams") {
                        ForEach(localTeamsSorted, id: \.id) { team in
                            teamOptionRow(.local(team))
                        }
                    }
                }
                ForEach(groupedReferenceTeams, id: \.0) { competitionName, refs in
                    Section(competitionName) {
                        ForEach(refs) { ref in
                            teamOptionRow(.reference(ref))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func teamOptionRow(_ option: TeamPickerOption) -> some View {
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
        .accessibilityLabel(option.name)
        .accessibilityIdentifier(option.accessibilityIdentifier)
    }

    private func loadTeams() {
        isLoading = true
        loadError = nil

        Task { @MainActor in
            var loadedTeams: [TeamRecord] = []
            var loadedReferenceTeams: [ReferenceTeamOption] = []
            var resolvedError: Error?

            if self.mode == .fullCatalog {
                do {
                    try await self.teamStore.refreshFromRemote()
                } catch {
                    // Continue with local + reference fallback.
                }
            }

            do {
                loadedTeams = try self.teamStore.loadAllTeams()
            } catch {
                resolvedError = error
            }

            if self.mode == .fullCatalog {
                do {
                    loadedReferenceTeams = try await ReferenceCatalogService.fetchReferenceTeams()
                } catch {
                    if loadedTeams.isEmpty {
                        resolvedError = resolvedError ?? error
                    }
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
                guard self.mode == .fullCatalog else {
                    throw TeamPickerSheetError.referenceSelectionUnavailable
                }
                team = try ReferenceCatalogService.materializeReferenceTeam(reference, into: self.teamStore)
                self.teams = try self.teamStore.loadAllTeams()
            }
            self.onSelect(team)
            self.dismiss()
        } catch {
            self.loadError = error.localizedDescription
        }
    }
}

private enum TeamPickerSheetError: LocalizedError {
    case referenceSelectionUnavailable

    var errorDescription: String? {
        switch self {
        case .referenceSelectionUnavailable:
            return "Reference teams are unavailable in this picker."
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

    var accessibilityIdentifier: String {
        switch self {
        case let .local(team):
            return "team-picker-local-\(Self.identifierComponent(for: team.name))"
        case let .reference(reference):
            return "team-picker-reference-\(reference.referenceKey)"
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

    private static func identifierComponent(for value: String) -> String {
        value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")
            .lowercased()
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
