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
    @State private var selectionError: String?

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var unmaterializedReferences: [ReferenceTeamOption] {
        self.referenceTeams
            .filter { ReferenceCatalogService.isReferenceTeamMaterialized($0, in: self.teams) == false }
    }

    private var hasAnyOptions: Bool {
        !self.teams.isEmpty || !self.unmaterializedReferences.isEmpty
    }

    init(
        teamStore: TeamLibraryStoring,
        onSelect: @escaping (TeamRecord) -> Void
    ) {
        self.teamStore = teamStore
        self.onSelect = onSelect
    }

    private var localTeamsSorted: [TeamRecord] {
        self.teams
            .filter { team in
                self.matchesSearch(
                    team.name,
                    team.shortName ?? "",
                    team.division ?? "")
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredReferenceTeams: [ReferenceTeamOption] {
        self.unmaterializedReferences.filter { reference in
            self.matchesSearch(
                reference.name,
                reference.shortName ?? "",
                reference.competitionName,
                reference.competitionCode)
        }
    }

    private var groupedReferenceTeams: [(String, [ReferenceTeamOption])] {
        let grouped = Dictionary(grouping: self.filteredReferenceTeams, by: \.competitionName)
        return grouped
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { ($0.key, $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
    }

    private var hasVisibleOptions: Bool {
        !self.localTeamsSorted.isEmpty || !self.groupedReferenceTeams.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading teams…")
                } else if let error = loadError, !self.hasAnyOptions {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if !hasAnyOptions {
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
                    SheetDismissButton { dismiss() }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search teams")
            .onAppear(perform: loadTeams)
        }
        .alert("Unable to Select Team", isPresented: self.selectionErrorBinding) {
            Button("OK", role: .cancel) {
                self.selectionError = nil
            }
        } message: {
            Text(self.selectionError ?? "We couldn't select that team.")
        }
    }

    private var teamList: some View {
        List {
            if !self.hasVisibleOptions {
                ContentUnavailableView(
                    "No Teams Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
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
                loadedReferenceTeams = try await ReferenceCatalogService.fetchReferenceTeams()
            } catch {
                if loadedTeams.isEmpty {
                    resolvedError = resolvedError ?? error
                }
            }

            self.teams = loadedTeams
            self.referenceTeams = loadedReferenceTeams
            self.loadError = (!loadedTeams.isEmpty || !loadedReferenceTeams.isEmpty)
                ? nil
                : resolvedError?.localizedDescription
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
                team = try ReferenceCatalogService.materializeReferenceTeam(reference, into: self.teamStore)
                self.teams = try self.teamStore.loadAllTeams()
            }
            self.onSelect(team)
            self.dismiss()
        } catch {
            self.selectionError = error.localizedDescription
        }
    }

    private func matchesSearch(_ values: String...) -> Bool {
        guard !self.searchQuery.isEmpty else { return true }
        return values
            .joined(separator: " ")
            .lowercased()
            .contains(self.searchQuery)
    }

    private var selectionErrorBinding: Binding<Bool> {
        Binding(
            get: { self.selectionError != nil },
            set: { isPresented in
                if isPresented == false {
                    self.selectionError = nil
                }
            })
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
