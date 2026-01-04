//
//  CompetitionEditorView.swift
//  RefWatchiOS
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
  @State private var errorMessage: String?
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
          TextField("Competition Name", text: self.$name)
            .autocorrectionDisabled()
        } header: {
          Text("Name")
        } footer: {
          Text("Required. E.g., \"Premier League\", \"Champions League\"")
        }

        Section {
          TextField("Level", text: self.$level)
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
      .navigationTitle(self.competition == nil ? "New Competition" : "Edit Competition")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            self.saveCompetition()
          }
          .disabled(!self.isValid)
        }
      }
    }
  }

  private var isValid: Bool {
    !self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func saveCompetition() {
    self.errorMessage = nil

    let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      self.errorMessage = "Name is required"
      return
    }

    guard trimmedName.count <= 100 else {
      self.errorMessage = "Name must be 100 characters or less"
      return
    }

    let trimmedLevel = self.level.trimmingCharacters(in: .whitespacesAndNewlines)
    let levelToSave = trimmedLevel.isEmpty ? nil : trimmedLevel

    if let levelToSave, levelToSave.count > 50 {
      self.errorMessage = "Level must be 50 characters or less"
      return
    }

    do {
      if let competition {
        // Update existing
        competition.name = trimmedName
        competition.level = levelToSave
        try self.store.update(competition)
      } else {
        // Create new
        _ = try self.store.create(name: trimmedName, level: levelToSave)
      }
      self.onSave()
    } catch {
      self.errorMessage = "Failed to save: \(error.localizedDescription)"
    }
  }
}

#if DEBUG
#Preview("New Competition") {
  CompetitionEditorView(
    store: InMemoryCompetitionLibraryStore(),
    competition: nil,
    onSave: {})
}

#Preview("Edit Competition") {
  let record = CompetitionRecord(
    id: UUID(),
    name: "Premier League",
    level: "Professional",
    ownerSupabaseId: "test-user",
    lastModifiedAt: Date(),
    remoteUpdatedAt: nil,
    needsRemoteSync: false)
  CompetitionEditorView(
    store: InMemoryCompetitionLibraryStore(preloadedCompetitions: [record]),
    competition: record,
    onSave: {})
}
#endif
