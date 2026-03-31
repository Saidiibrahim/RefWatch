//
//  MatchSheetEditorView.swift
//  RefWatchiOS
//
//  Editor for schedule-owned frozen match sheets.
//

import RefWatchCore
import SwiftUI

enum MatchSheetDraftFactory {
  static func emptyDraft(teamName: String) -> ScheduledMatchSheet {
    let normalizedTeamName = teamName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    return ScheduledMatchSheet(
      sourceTeamId: nil,
      sourceTeamName: normalizedTeamName,
      status: .draft,
      starters: [],
      substitutes: [],
      staff: [],
      otherMembers: [],
      updatedAt: Date()).normalized()
  }
}

enum MatchSheetEditorMode: Equatable {
  case standard
  case importReview(warnings: [MatchSheetImportWarning], extractedTeamName: String?)
}

struct MatchSheetEditorView: View {
  let sideTitle: String
  let fallbackTeamName: String
  @Binding var sheet: ScheduledMatchSheet
  let mode: MatchSheetEditorMode
  let onCancelRequest: (() -> Void)?
  let onConfirmImport: ((ScheduledMatchSheet) -> Void)?
  let replaceConfirmationMessage: String?

  @Environment(\.dismiss) private var dismiss
  @State private var playerDraft: PlayerDraft?
  @State private var staffDraft: StaffDraft?
  @State private var showingReplaceConfirmation = false

  init(
    sideTitle: String,
    fallbackTeamName: String,
    sheet: Binding<ScheduledMatchSheet>,
    mode: MatchSheetEditorMode = .standard,
    onCancelRequest: (() -> Void)? = nil,
    onConfirmImport: ((ScheduledMatchSheet) -> Void)? = nil,
    replaceConfirmationMessage: String? = nil)
  {
    self.sideTitle = sideTitle
    self.fallbackTeamName = fallbackTeamName
    self._sheet = sheet
    self.mode = mode
    self.onCancelRequest = onCancelRequest
    self.onConfirmImport = onConfirmImport
    self.replaceConfirmationMessage = replaceConfirmationMessage
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Summary") {
          LabeledContent("Starters") { Text("\(self.sheet.starterCount)") }
          LabeledContent("Substitutes") { Text("\(self.sheet.substituteCount)") }
          LabeledContent("Staff") { Text("\(self.sheet.staffCount)") }
          LabeledContent("Other Members") { Text("\(self.sheet.otherMemberCount)") }

          if self.sheet.hasAnyEntries == false {
            Text("No entries added yet.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        if case let .importReview(warnings, extractedTeamName) = self.mode {
          Section("Import Review") {
            Text("Review the imported entries below. Using this import updates this side in the upcoming match editor. Save the match afterwards to keep the change.")
              .font(.footnote)
              .foregroundStyle(.secondary)

            if let extractedTeamName {
              LabeledContent("Detected Team") {
                Text(extractedTeamName)
              }
            }

            if warnings.isEmpty {
              Text("No parser warnings were reported.")
                .foregroundStyle(.secondary)
            } else {
              ForEach(warnings) { warning in
                Text(warning.message)
                  .font(.footnote)
                  .foregroundStyle(.orange)
              }
            }
          }
        }

        Section("Starters") {
          self.playerRows(self.sheet.starters, section: .starters)
          Button("Add Starter") {
            self.playerDraft = PlayerDraft(
              section: .starters,
              sortOrder: MatchSheetEditorState.nextPlayerSortOrder(for: self.sheet.starters))
          }
        }

        Section("Substitutes") {
          self.playerRows(self.sheet.substitutes, section: .substitutes)
          Button("Add Substitute") {
            self.playerDraft = PlayerDraft(
              section: .substitutes,
              sortOrder: MatchSheetEditorState.nextPlayerSortOrder(for: self.sheet.substitutes))
          }
        }

        Section("Staff") {
          self.staffRows(self.sheet.staff, defaultCategory: .staff)
          Button("Add Staff") {
            self.staffDraft = StaffDraft(
              category: .staff,
              sortOrder: MatchSheetEditorState.nextStaffSortOrder(for: self.sheet.staff))
          }
        }

        Section("Other Members") {
          self.staffRows(self.sheet.otherMembers, defaultCategory: .otherMember)
          Button("Add Other Member") {
            self.staffDraft = StaffDraft(
              category: .otherMember,
              sortOrder: MatchSheetEditorState.nextStaffSortOrder(for: self.sheet.otherMembers))
          }
        }

      }
      .navigationTitle("\(self.sideTitle) Match Sheet")
      .toolbar {
        switch self.mode {
        case .standard:
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") {
              self.sheet = self.normalizedSheet()
              self.dismiss()
            }
          }
        case .importReview:
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              self.onCancelRequest?()
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Use Import") {
              if self.replaceConfirmationMessage == nil {
                self.applyImport()
              } else {
                self.showingReplaceConfirmation = true
              }
            }
            .accessibilityIdentifier("match-sheet-import-apply")
          }
        }
      }
      .alert("Replace Existing Match Sheet?", isPresented: self.$showingReplaceConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Replace", role: .destructive) {
          self.applyImport()
        }
      } message: {
        Text(self.replaceConfirmationMessage ?? "Applying this import will replace the current match sheet.")
      }
      .sheet(item: self.$playerDraft) { draft in
        NavigationStack {
          MatchSheetPlayerEntryEditor(
            draft: draft,
            onSave: { entry, section in
              self.upsertPlayer(entry, into: section)
              self.playerDraft = nil
            },
            onCancel: {
              self.playerDraft = nil
            })
        }
      }
      .sheet(item: self.$staffDraft) { draft in
        NavigationStack {
          MatchSheetStaffEntryEditor(
            draft: draft,
            onSave: { entry in
              self.upsertStaff(entry)
              self.staffDraft = nil
            },
            onCancel: {
              self.staffDraft = nil
            })
        }
      }
    }
  }

  @ViewBuilder
  private func playerRows(_ entries: [MatchSheetPlayerEntry], section: PlayerSection) -> some View {
    if entries.isEmpty {
      Text("None yet")
        .foregroundStyle(.secondary)
    } else {
      ForEach(entries) { entry in
        VStack(alignment: .leading, spacing: 4) {
          Text(self.playerTitle(entry))
          if let subtitle = self.playerSubtitle(entry) {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .swipeActions {
          Button("Edit") {
            self.playerDraft = PlayerDraft(entry: entry, section: section)
          }
          .tint(.blue)
          Button("Delete", role: .destructive) {
            self.deletePlayer(entry)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func staffRows(_ entries: [MatchSheetStaffEntry], defaultCategory: MatchSheetStaffCategory) -> some View {
    if entries.isEmpty {
      Text("None yet")
        .foregroundStyle(.secondary)
    } else {
      ForEach(entries) { entry in
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.displayName)
          if let subtitle = self.staffSubtitle(entry) {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .swipeActions {
          Button("Edit") {
            self.staffDraft = StaffDraft(entry: entry, category: defaultCategory)
          }
          .tint(.blue)
          Button("Delete", role: .destructive) {
            self.deleteStaff(entry)
          }
        }
      }
    }
  }

  private func upsertPlayer(_ entry: MatchSheetPlayerEntry, into section: PlayerSection) {
    var updated = self.normalizedSheet()
    updated.starters.removeAll { $0.entryId == entry.entryId }
    updated.substitutes.removeAll { $0.entryId == entry.entryId }

    switch section {
    case .starters:
      updated.starters.append(entry)
    case .substitutes:
      updated.substitutes.append(entry)
    }

    self.sheet = updated.normalized()
  }

  private func upsertStaff(_ entry: MatchSheetStaffEntry) {
    var updated = self.normalizedSheet()
    updated.staff.removeAll { $0.entryId == entry.entryId }
    updated.otherMembers.removeAll { $0.entryId == entry.entryId }

    switch entry.category {
    case .staff:
      updated.staff.append(entry)
    case .otherMember:
      updated.otherMembers.append(entry)
    }

    self.sheet = updated.normalized()
  }

  private func deletePlayer(_ entry: MatchSheetPlayerEntry) {
    var updated = self.normalizedSheet()
    updated.starters.removeAll { $0.entryId == entry.entryId }
    updated.substitutes.removeAll { $0.entryId == entry.entryId }
    self.sheet = updated.normalized()
  }

  private func deleteStaff(_ entry: MatchSheetStaffEntry) {
    var updated = self.normalizedSheet()
    updated.staff.removeAll { $0.entryId == entry.entryId }
    updated.otherMembers.removeAll { $0.entryId == entry.entryId }
    self.sheet = updated.normalized()
  }

  private func normalizedSheet() -> ScheduledMatchSheet {
    MatchSheetEditorState.normalizedSheet(
      self.sheet,
      fallbackTeamName: self.fallbackTeamName)
  }

  private func applyImport() {
    var updated = self.normalizedSheet()
    updated.status = .draft
    updated = updated.normalized()
    self.sheet = updated
    self.onConfirmImport?(updated)
  }

  private func playerTitle(_ entry: MatchSheetPlayerEntry) -> String {
    let trimmedName = entry.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

    switch (entry.shirtNumber, trimmedName.isEmpty ? nil : trimmedName) {
    case let (shirtNumber?, name?):
      return "#\(shirtNumber) \(name)"
    case let (shirtNumber?, nil):
      return "#\(shirtNumber)"
    case let (nil, name?):
      return "#? \(name)"
    case (nil, nil):
      return "Player"
    }
  }

  private func playerSubtitle(_ entry: MatchSheetPlayerEntry) -> String? {
    [entry.position, entry.notes]
      .compactMap { value in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
      }
      .joined(separator: " | ")
      .nilIfEmpty
  }

  private func staffSubtitle(_ entry: MatchSheetStaffEntry) -> String? {
    [entry.roleLabel, entry.notes]
      .compactMap { value in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
      }
      .joined(separator: " | ")
      .nilIfEmpty
  }
}

#if DEBUG
private struct MatchSheetEditorPreviewHost: View {
  let sideTitle: String
  let fallbackTeamName: String
  let mode: MatchSheetEditorMode
  let initialSheet: ScheduledMatchSheet
  let replaceConfirmationMessage: String?

  @State private var sheet: ScheduledMatchSheet

  init(
    sideTitle: String,
    fallbackTeamName: String,
    mode: MatchSheetEditorMode,
    initialSheet: ScheduledMatchSheet,
    replaceConfirmationMessage: String? = nil)
  {
    self.sideTitle = sideTitle
    self.fallbackTeamName = fallbackTeamName
    self.mode = mode
    self.initialSheet = initialSheet
    self.replaceConfirmationMessage = replaceConfirmationMessage
    _sheet = State(initialValue: initialSheet)
  }

  var body: some View {
    MatchSheetEditorView(
      sideTitle: self.sideTitle,
      fallbackTeamName: self.fallbackTeamName,
      sheet: self.$sheet,
      mode: self.mode,
      onCancelRequest: {},
      onConfirmImport: { _ in },
      replaceConfirmationMessage: self.replaceConfirmationMessage)
  }
}

#Preview("Match Sheet Review - Warnings") {
  let teams = MatchSheetImportPreviewSupport.makeTeamContext()
  return MatchSheetEditorPreviewHost(
    sideTitle: MatchSheetSide.home.title,
    fallbackTeamName: teams.homeTeam.name,
    mode: .importReview(
      warnings: MatchSheetImportPreviewSupport.sampleWarnings(),
      extractedTeamName: MatchSheetImportPreviewSupport.homeTeamName),
    initialSheet: MatchSheetImportPreviewSupport.importedHomeSheet(
      sourceTeamId: teams.homeTeam.id,
      teamName: teams.homeTeam.name))
}

#Preview("Match Sheet Review - Clean Parse") {
  let teams = MatchSheetImportPreviewSupport.makeTeamContext()
  return MatchSheetEditorPreviewHost(
    sideTitle: MatchSheetSide.home.title,
    fallbackTeamName: teams.homeTeam.name,
    mode: .importReview(
      warnings: [],
      extractedTeamName: MatchSheetImportPreviewSupport.homeTeamName),
    initialSheet: MatchSheetImportPreviewSupport.cleanImportedSheet(
      sourceTeamId: teams.homeTeam.id,
      teamName: teams.homeTeam.name))
}
#endif

private enum PlayerSection: String, CaseIterable, Identifiable {
  case starters
  case substitutes

  var id: String { self.rawValue }

  var title: String {
    switch self {
    case .starters:
      return "Starters"
    case .substitutes:
      return "Substitutes"
    }
  }
}

private struct PlayerDraft: Identifiable {
  let id = UUID()
  let entry: MatchSheetPlayerEntry?
  let section: PlayerSection
  let sortOrder: Int

  init(entry: MatchSheetPlayerEntry? = nil, section: PlayerSection, sortOrder: Int? = nil) {
    self.entry = entry
    self.section = section
    self.sortOrder = sortOrder ?? entry?.sortOrder ?? 0
  }
}

private struct StaffDraft: Identifiable {
  let id = UUID()
  let entry: MatchSheetStaffEntry?
  let category: MatchSheetStaffCategory
  let sortOrder: Int

  init(entry: MatchSheetStaffEntry? = nil, category: MatchSheetStaffCategory, sortOrder: Int? = nil) {
    self.entry = entry
    self.category = category
    self.sortOrder = sortOrder ?? entry?.sortOrder ?? 0
  }
}

private struct MatchSheetPlayerEntryEditor: View {
  let draft: PlayerDraft
  let onSave: (MatchSheetPlayerEntry, PlayerSection) -> Void
  let onCancel: () -> Void

  @State private var displayName: String
  @State private var shirtNumber: String
  @State private var position: String
  @State private var notes: String
  @State private var section: PlayerSection

  init(
    draft: PlayerDraft,
    onSave: @escaping (MatchSheetPlayerEntry, PlayerSection) -> Void,
    onCancel: @escaping () -> Void)
  {
    self.draft = draft
    self.onSave = onSave
    self.onCancel = onCancel
    _displayName = State(initialValue: draft.entry?.displayName ?? "")
    _shirtNumber = State(initialValue: draft.entry?.shirtNumber.map(String.init) ?? "")
    _position = State(initialValue: draft.entry?.position ?? "")
    _notes = State(initialValue: draft.entry?.notes ?? "")
    _section = State(initialValue: draft.section)
  }

  var body: some View {
    Form {
      TextField("Display Name", text: self.$displayName)
      TextField("Shirt Number", text: self.$shirtNumber)
        .keyboardType(.numberPad)
      TextField("Position", text: self.$position)
      TextField("Notes", text: self.$notes, axis: .vertical)
      Picker("Section", selection: self.$section) {
        ForEach(PlayerSection.allCases) { section in
          Text(section.title).tag(section)
        }
      }
    }
    .navigationTitle(self.draft.entry == nil ? "Add Player" : "Edit Player")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { self.onCancel() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { self.save() }
          .disabled(self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private func save() {
    let cleanedName = self.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let entry = MatchSheetPlayerEntry(
      entryId: self.draft.entry?.entryId ?? UUID(),
      sourcePlayerId: self.draft.entry?.sourcePlayerId,
      displayName: cleanedName,
      shirtNumber: Int(self.shirtNumber),
      position: self.position.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      notes: self.notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      sortOrder: self.draft.sortOrder)
    self.onSave(entry, self.section)
  }
}

private struct MatchSheetStaffEntryEditor: View {
  let draft: StaffDraft
  let onSave: (MatchSheetStaffEntry) -> Void
  let onCancel: () -> Void

  @State private var displayName: String
  @State private var roleLabel: String
  @State private var notes: String
  @State private var category: MatchSheetStaffCategory

  init(
    draft: StaffDraft,
    onSave: @escaping (MatchSheetStaffEntry) -> Void,
    onCancel: @escaping () -> Void)
  {
    self.draft = draft
    self.onSave = onSave
    self.onCancel = onCancel
    _displayName = State(initialValue: draft.entry?.displayName ?? "")
    _roleLabel = State(initialValue: draft.entry?.roleLabel ?? "")
    _notes = State(initialValue: draft.entry?.notes ?? "")
    _category = State(initialValue: draft.entry?.category ?? draft.category)
  }

  var body: some View {
    Form {
      TextField("Display Name", text: self.$displayName)
      TextField("Role Label", text: self.$roleLabel)
      TextField("Notes", text: self.$notes, axis: .vertical)
      Picker("Category", selection: self.$category) {
        Text("Staff").tag(MatchSheetStaffCategory.staff)
        Text("Other Member").tag(MatchSheetStaffCategory.otherMember)
      }
    }
    .navigationTitle(self.draft.entry == nil ? "Add Member" : "Edit Member")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { self.onCancel() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { self.save() }
          .disabled(self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private func save() {
    let entry = MatchSheetStaffEntry(
      entryId: self.draft.entry?.entryId ?? UUID(),
      sourceOfficialId: self.draft.entry?.sourceOfficialId,
      displayName: self.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
      roleLabel: self.roleLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      notes: self.notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      sortOrder: self.draft.sortOrder,
      category: self.category)
    self.onSave(entry)
  }
}

enum MatchSheetEditorState {
  static func normalizedSheet(
    _ sheet: ScheduledMatchSheet,
    fallbackTeamName: String,
    updatedAt: Date = Date()) -> ScheduledMatchSheet
  {
    var updated = sheet
    updated.sourceTeamName = updated.sourceTeamName?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty ?? fallbackTeamName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

    updated.starters = self.reindexedPlayers(updated.starters)
    updated.substitutes = self.reindexedPlayers(updated.substitutes)
    updated.staff = self.reindexedStaff(updated.staff, category: .staff)
    updated.otherMembers = self.reindexedStaff(updated.otherMembers, category: .otherMember)
    updated.updatedAt = updatedAt
    return updated.normalized()
  }

  static func nextPlayerSortOrder(for entries: [MatchSheetPlayerEntry]) -> Int {
    entries.count
  }

  static func nextStaffSortOrder(for entries: [MatchSheetStaffEntry]) -> Int {
    entries.count
  }

  private static func reindexedPlayers(_ entries: [MatchSheetPlayerEntry]) -> [MatchSheetPlayerEntry] {
    entries.enumerated().map { index, entry in
      MatchSheetPlayerEntry(
        entryId: entry.entryId,
        sourcePlayerId: entry.sourcePlayerId,
        displayName: entry.displayName,
        shirtNumber: entry.shirtNumber,
        position: entry.position,
        notes: entry.notes,
        sortOrder: index)
    }
  }

  private static func reindexedStaff(
    _ entries: [MatchSheetStaffEntry],
    category: MatchSheetStaffCategory) -> [MatchSheetStaffEntry]
  {
    entries.enumerated().map { index, entry in
      MatchSheetStaffEntry(
        entryId: entry.entryId,
        sourceOfficialId: entry.sourceOfficialId,
        displayName: entry.displayName,
        roleLabel: entry.roleLabel,
        notes: entry.notes,
        sortOrder: index,
        category: category)
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    self.isEmpty ? nil : self
  }
}
