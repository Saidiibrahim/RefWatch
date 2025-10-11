//
//  CompetitionPickerSheet.swift
//  RefZoneiOS
//
//  Sheet interface for selecting a saved competition from the library.
//

import SwiftUI

struct CompetitionPickerSheet: View {
    let competitionStore: CompetitionLibraryStoring
    let onSelect: (CompetitionRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var competitions: [CompetitionRecord] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var loadError: String?

    private var filteredCompetitions: [CompetitionRecord] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return competitions }
        let lowercased = trimmed.lowercased()
        return competitions.filter { competition in
            competition.name.lowercased().contains(lowercased) ||
            (competition.level?.lowercased().contains(lowercased) ?? false)
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
                } else if competitions.isEmpty {
                    ContentUnavailableView(
                        "No Competitions Yet",
                        systemImage: "trophy",
                        description: Text("Create competitions in Settings → Library → Competitions")
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
            let results = filteredCompetitions
            if results.isEmpty {
                ContentUnavailableView(
                    "No Competitions Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ForEach(results, id: \.id) { competition in
                    Button {
                        onSelect(competition)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(competition.name)
                                .font(.headline)
                            if let level = competition.level, level.isEmpty == false {
                                Text(level)
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
            do {
                try await competitionStore.refreshFromRemote()
            } catch {
                print("Competition refresh failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                do {
                    competitions = try competitionStore.loadAll()
                } catch {
                    loadError = error.localizedDescription
                    competitions = []
                }
                isLoading = false
            }
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
