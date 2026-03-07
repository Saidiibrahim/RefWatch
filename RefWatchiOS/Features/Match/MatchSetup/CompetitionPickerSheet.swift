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
            .filter { ReferenceCatalogService.isReferenceCompetitionMaterialized($0, in: self.competitions) == false }
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
                    SheetDismissButton { dismiss() }
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

        Task { @MainActor in
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
                loadedReferences = try await ReferenceCatalogService.fetchReferenceCompetitions()
            } catch {
                if loadedCompetitions.isEmpty {
                    resolvedError = resolvedError ?? error
                }
            }

            self.competitions = loadedCompetitions
            self.referenceCompetitions = loadedReferences
            self.loadError = resolvedError?.localizedDescription
            self.isLoading = false
        }
    }

    private func handleSelection(_ option: CompetitionPickerOption) {
        do {
            let competition: CompetitionRecord
            switch option {
            case let .local(local):
                competition = local
            case let .reference(reference):
                competition = try ReferenceCatalogService.materializeReferenceCompetition(reference, into: self.competitionStore)
                self.competitions = try self.competitionStore.loadAll()
            }
            self.onSelect(competition)
            self.dismiss()
        } catch {
            self.loadError = error.localizedDescription
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
