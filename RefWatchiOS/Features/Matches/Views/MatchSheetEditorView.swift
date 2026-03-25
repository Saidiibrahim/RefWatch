//
//  MatchSheetEditorView.swift
//  RefWatchiOS
//
//  Editor for schedule-owned frozen match sheets.
//

import RefWatchCore
import SwiftUI

enum MatchSheetDraftFactory {
  static func emptyDraft(sourceTeam: TeamRecord?, fallbackTeamName: String) -> ScheduledMatchSheet {
    ScheduledMatchSheet(
      sourceTeamId: sourceTeam?.id,
      sourceTeamName: sourceTeam?.name ?? fallbackTeamName,
      status: .draft,
      starters: [],
      substitutes: [],
      staff: [],
      otherMembers: [],
      updatedAt: Date()).normalized()
  }

  static func seededDraft(sourceTeam: TeamRecord?, fallbackTeamName: String) -> ScheduledMatchSheet {
    guard let sourceTeam else {
      return self.emptyDraft(sourceTeam: nil, fallbackTeamName: fallbackTeamName)
    }

    let orderedPlayers = sourceTeam.players.sorted { lhs, rhs in
      let lhsNumber = lhs.number ?? Int.max
      let rhsNumber = rhs.number ?? Int.max
      if lhsNumber != rhsNumber {
        return lhsNumber < rhsNumber
      }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    let starters = orderedPlayers.prefix(11).enumerated().map { index, player in
      MatchSheetPlayerEntry(
        sourcePlayerId: player.id,
        displayName: player.name,
        shirtNumber: player.number,
        position: player.position,
        notes: player.notes,
        sortOrder: index)
    }

    let substitutes = orderedPlayers.dropFirst(11).enumerated().map { index, player in
      MatchSheetPlayerEntry(
        sourcePlayerId: player.id,
        displayName: player.name,
        shirtNumber: player.number,
        position: player.position,
        notes: player.notes,
        sortOrder: index)
    }

    let staff = sourceTeam.officials.sorted { lhs, rhs in
      lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }.enumerated().map { index, official in
      MatchSheetStaffEntry(
        sourceOfficialId: official.id,
        displayName: official.name,
        roleLabel: official.roleRaw,
        notes: nil,
        sortOrder: index,
        category: .staff)
    }

    return ScheduledMatchSheet(
      sourceTeamId: sourceTeam.id,
      sourceTeamName: sourceTeam.name,
      status: .draft,
      starters: starters,
      substitutes: substitutes,
      staff: staff,
      otherMembers: [],
      updatedAt: Date()).normalized()
  }
}

struct MatchSheetEditorView: View {
  let sideTitle: String
  let sourceTeam: TeamRecord?
  let fallbackTeamName: String
  @Binding var sheet: ScheduledMatchSheet

  @Environment(\.dismiss) private var dismiss
  @State private var playerDraft: PlayerDraft?
  @State private var staffDraft: StaffDraft?

  var body: some View {
    NavigationStack {
      Form {
        Section("Status") {
          LabeledContent("Source Team") {
            Text(self.sheet.sourceTeamName ?? self.fallbackTeamName)
              .foregroundStyle(.secondary)
          }
          LabeledContent("State") {
            Text(self.sheet.isReady ? "Ready" : "Draft")
              .foregroundStyle(self.sheet.isReady ? .green : .secondary)
          }
          LabeledContent("Starters") { Text("\(self.sheet.starterCount)") }
          LabeledContent("Substitutes") { Text("\(self.sheet.substituteCount)") }
          LabeledContent("Staff") { Text("\(self.sheet.staffCount)") }
          LabeledContent("Other Members") { Text("\(self.sheet.otherMemberCount)") }

          if self.sheet.meetsReadyRequirements == false {
            Text("Needs at least one starter with valid display data before the sheet can be marked ready.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section("Source Actions") {
          Button("Reseed from Source Team") {
            self.sheet = MatchSheetDraftFactory.seededDraft(
              sourceTeam: self.sourceTeam,
              fallbackTeamName: self.fallbackTeamName)
          }
          .disabled(self.sourceTeam == nil)
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

        Section {
          if self.sheet.isReady {
            Button("Mark Draft") {
              self.sheet.status = .draft
              self.sheet = self.normalizedSheet()
            }
            .foregroundStyle(.orange)
          } else {
            Button("Mark Ready") {
              var updated = self.normalizedSheet()
              updated.status = .ready
              self.sheet = updated.normalized()
            }
            .disabled(self.normalizedSheet().meetsReadyRequirements == false)
          }
        }
      }
      .navigationTitle("\(self.sideTitle) Match Sheet")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") {
            self.sheet = self.normalizedSheet()
            self.dismiss()
          }
        }
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
      sourceTeam: self.sourceTeam,
      fallbackTeamName: self.fallbackTeamName)
  }

  private func playerTitle(_ entry: MatchSheetPlayerEntry) -> String {
    switch (entry.shirtNumber, entry.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
    case let (shirtNumber?, false):
      return "#\(shirtNumber) \(entry.displayName)"
    case let (shirtNumber?, true):
      return "#\(shirtNumber)"
    default:
      return entry.displayName
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
    sourceTeam: TeamRecord?,
    fallbackTeamName: String,
    updatedAt: Date = Date()) -> ScheduledMatchSheet
  {
    var updated = sheet

    if let sourceTeam {
      updated.sourceTeamId = sourceTeam.id
      updated.sourceTeamName = sourceTeam.name
    } else {
      updated.sourceTeamName = updated.sourceTeamName?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nilIfEmpty ?? fallbackTeamName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

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
