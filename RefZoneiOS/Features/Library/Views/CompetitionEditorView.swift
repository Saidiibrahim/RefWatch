//
//  CompetitionEditorView.swift
//  RefZoneiOS
//
//  Form for creating and editing competitions.
//

import SwiftUI

struct CompetitionEditorView: View {
    let store: CompetitionLibraryStoring
    let competition: CompetitionRecord?
    let onSave: () -> Void

    @State private var name: String
    @State private var level: String
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    init(store: CompetitionLibraryStoring, competition: CompetitionRecord?, onSave: @escaping () -> Void) {
        self.store = store
        self.competition = competition
        self.onSave = onSave

        _name = State(initialValue: competition?.name ?? "")
        _level = State(initialValue: competition?.level ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Competition Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                } footer: {
                    Text("Required. E.g., \"Premier League\", \"Champions League\"")
                }

                Section {
                    TextField("Level", text: $level)
                        .autocorrectionDisabled()
                } header: {
                    Text("Level")
                } footer: {
                    Text("Optional. E.g., \"Professional\", \"Amateur\", \"Youth\"")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(competition == nil ? "New Competition" : "Edit Competition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCompetition()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveCompetition() {
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name is required"
            return
        }

        guard trimmedName.count <= 100 else {
            errorMessage = "Name must be 100 characters or less"
            return
        }

        let trimmedLevel = level.trimmingCharacters(in: .whitespacesAndNewlines)
        let levelToSave = trimmedLevel.isEmpty ? nil : trimmedLevel

        if let levelToSave, levelToSave.count > 50 {
            errorMessage = "Level must be 50 characters or less"
            return
        }

        do {
            if let competition {
                // Update existing
                competition.name = trimmedName
                competition.level = levelToSave
                try store.update(competition)
            } else {
                // Create new
                _ = try store.create(name: trimmedName, level: levelToSave)
            }
            onSave()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
#Preview("New Competition") {
    CompetitionEditorView(
        store: InMemoryCompetitionLibraryStore(),
        competition: nil,
        onSave: {}
    )
}

#Preview("Edit Competition") {
    let record = CompetitionRecord(
        id: UUID(),
        name: "Premier League",
        level: "Professional",
        ownerSupabaseId: "test-user",
        lastModifiedAt: Date(),
        remoteUpdatedAt: nil,
        needsRemoteSync: false
    )
    CompetitionEditorView(
        store: InMemoryCompetitionLibraryStore(preloadedCompetitions: [record]),
        competition: record,
        onSave: {}
    )
}
#endif