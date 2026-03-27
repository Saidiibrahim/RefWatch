//
//  UpcomingMatchEditorView.swift
//  RefWatchiOS
//
//  Create or edit a scheduled match with schedule-owned match sheets.
//

import OSLog
import RefWatchCore
import SwiftUI

struct UpcomingMatchEditorView: View {
  let scheduleStore: ScheduleStoring
  let teamStore: TeamLibraryStoring
  let matchSheetImportService: MatchSheetImportProviding?
  let existingMatch: ScheduledMatch?
  var onSaved: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var authController: SupabaseAuthController
  @State private var homeName: String
  @State private var awayName: String
  @State private var selectedHomeTeam: TeamRecord?
  @State private var selectedAwayTeam: TeamRecord?
  @State private var kickoff: Date
  @State private var homeMatchSheet: ScheduledMatchSheet
  @State private var awayMatchSheet: ScheduledMatchSheet

  @State private var teams: [TeamRecord] = []
  @State private var hasLoadedTeams = false
  @State private var activeSheetSide: MatchSheetSide?
  @State private var activeImportSide: MatchSheetSide?
  @State private var importDraft: MatchSheetImportDraft?
  @State private var editingSourceTeam: TeamRecord?
  @State private var showingHomePicker = false
  @State private var showingAwayPicker = false
  @State private var pendingSourceTeamChange: PendingSourceTeamChange?
  @State private var errorMessage: String?

  init(
    scheduleStore: ScheduleStoring,
    teamStore: TeamLibraryStoring,
    matchSheetImportService: MatchSheetImportProviding? = MatchSheetImportServiceFactory.makeDefault(),
    existingMatch: ScheduledMatch? = nil,
    onSaved: (() -> Void)? = nil)
  {
    self.scheduleStore = scheduleStore
    self.teamStore = teamStore
    self.matchSheetImportService = matchSheetImportService
    self.existingMatch = existingMatch
    self.onSaved = onSaved

    let initialHomeName = existingMatch?.homeTeam ?? ""
    let initialAwayName = existingMatch?.awayTeam ?? ""
    _homeName = State(initialValue: initialHomeName)
    _awayName = State(initialValue: initialAwayName)
    _selectedHomeTeam = State(initialValue: nil)
    _selectedAwayTeam = State(initialValue: nil)
    _kickoff = State(initialValue: existingMatch?.kickoff ?? Self.defaultKickoff())
    _homeMatchSheet = State(
      initialValue: existingMatch?.homeMatchSheet
        ?? MatchSheetDraftFactory.emptyDraft(sourceTeam: nil, fallbackTeamName: initialHomeName))
    _awayMatchSheet = State(
      initialValue: existingMatch?.awayMatchSheet
        ?? MatchSheetDraftFactory.emptyDraft(sourceTeam: nil, fallbackTeamName: initialAwayName))
  }

  var body: some View {
    NavigationStack {
      Group {
        if self.isSignedIn {
          self.formContent
        } else {
          SignedOutFeaturePlaceholder(
            description: "Sign in to create or edit scheduled matches.")
        }
      }
      .navigationTitle(self.existingMatch == nil ? "Upcoming Match" : "Edit Match")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          SheetDismissButton { self.dismiss() }
        }
      }
    }
    .task {
      await self.loadTeams()
    }
  }

  private var isSignedIn: Bool { self.authController.isSignedIn }

  @ViewBuilder
  private var formContent: some View {
    Form {
      Section("Teams") {
        self.teamField(
          title: "Home Team",
          name: self.$homeName,
          selectedTeam: self.$selectedHomeTeam,
          showingPicker: self.$showingHomePicker)
        self.teamField(
          title: "Away Team",
          name: self.$awayName,
          selectedTeam: self.$selectedAwayTeam,
          showingPicker: self.$showingAwayPicker)
      }

      Section("Kickoff") {
        DatePicker("Date & Time", selection: self.$kickoff, displayedComponents: [.date, .hourAndMinute])
      }

      self.matchSheetSection(side: .home)
      self.matchSheetSection(side: .away)

      Section {
        Button(action: self.save) {
          Label(self.existingMatch == nil ? "Save" : "Save Changes", systemImage: "checkmark.circle.fill")
        }
        .disabled(!self.isValid)
      }
    }
    .sheet(isPresented: self.$showingHomePicker) {
      TeamPickerSheet(teamStore: self.teamStore) { team in
        self.handleSelectedSourceTeam(team, for: .home)
      }
    }
    .sheet(isPresented: self.$showingAwayPicker) {
      TeamPickerSheet(teamStore: self.teamStore) { team in
        self.handleSelectedSourceTeam(team, for: .away)
      }
    }
    .sheet(item: self.$activeSheetSide) { side in
      MatchSheetEditorView(
        sideTitle: side.title,
        sourceTeam: self.sourceTeam(for: side),
        fallbackTeamName: self.teamName(for: side),
        sheet: self.binding(for: side))
    }
    .sheet(item: self.$activeImportSide) { side in
      if let service = self.matchSheetImportService {
        MatchSheetImportPickerSheet(
          side: side,
          service: service,
          expectedTeamName: self.teamName(for: side),
          onCancel: {
            self.activeImportSide = nil
          },
          onImported: { draft in
            let preparedDraft = self.prepareImportDraft(draft)
            self.activeImportSide = nil
            Task { @MainActor in
              self.importDraft = preparedDraft
            }
          })
      }
    }
    .sheet(isPresented: self.importReviewBinding) {
      if let importDraft = self.importDraft {
        MatchSheetEditorView(
          sideTitle: importDraft.side.title,
          sourceTeam: self.sourceTeam(for: importDraft.side),
          fallbackTeamName: self.teamName(for: importDraft.side),
          sheet: self.importDraftSheetBinding,
          mode: .importReview(
            warnings: importDraft.warnings,
            extractedTeamName: importDraft.extractedTeamName),
          onCancelRequest: {
            self.importDraft = nil
          },
          onConfirmImport: { normalizedSheet in
            self.applyImportSheet(normalizedSheet, for: importDraft.side)
          },
          replaceConfirmationMessage: self.sheet(for: importDraft.side).hasAnyEntries
            ? "\(importDraft.side.title) match sheet already has entries. Applying this import will replace the entire side."
            : nil)
      }
    }
    .sheet(item: self.$editingSourceTeam) { team in
      NavigationStack {
        TeamEditorView(teamStore: self.teamStore, team: team)
      }
    }
    .onChange(of: self.homeName) { _, newValue in
      if newValue != self.selectedHomeTeam?.name {
        self.selectedHomeTeam = nil
      }
      self.homeMatchSheet = self.reconciledSheet(
        current: self.homeMatchSheet,
        selectedTeam: self.selectedHomeTeam,
        fallbackName: self.homeName)
    }
    .onChange(of: self.awayName) { _, newValue in
      if newValue != self.selectedAwayTeam?.name {
        self.selectedAwayTeam = nil
      }
      self.awayMatchSheet = self.reconciledSheet(
        current: self.awayMatchSheet,
        selectedTeam: self.selectedAwayTeam,
        fallbackName: self.awayName)
    }
    .onChange(of: self.selectedHomeTeam?.id) { _, _ in
      self.homeMatchSheet = self.reconciledSheet(
        current: self.homeMatchSheet,
        selectedTeam: self.selectedHomeTeam,
        fallbackName: self.homeName)
    }
    .onChange(of: self.selectedAwayTeam?.id) { _, _ in
      self.awayMatchSheet = self.reconciledSheet(
        current: self.awayMatchSheet,
        selectedTeam: self.selectedAwayTeam,
        fallbackName: self.awayName)
    }
    .alert("Unable to Save", isPresented: self.alertBinding) {
      Button("OK", role: .cancel) { self.errorMessage = nil }
    } message: {
      Text(self.errorMessage ?? "Sign in to save scheduled matches on your phone.")
    }
    .alert(
      "Reset Match Sheet?",
      isPresented: self.pendingSourceTeamChangeAlertBinding,
      presenting: self.pendingSourceTeamChange)
    { pending in
      Button("Keep Existing Sheet", role: .cancel) {
        self.pendingSourceTeamChange = nil
      }
      Button("Reset Sheet", role: .destructive) {
        self.commitSourceTeamChange(pending)
      }
    } message: { pending in
      Text("\(pending.side.title) match sheet already has entries. Changing the source team will reset the current frozen draft.")
    }
  }

  private func teamField(
    title: String,
    name: Binding<String>,
    selectedTeam: Binding<TeamRecord?>,
    showingPicker: Binding<Bool>) -> some View
  {
    HStack {
      TextField(title, text: name)
      Button {
        showingPicker.wrappedValue = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }
      .accessibilityLabel("Select \(title) from Library")
    }
  }

  @ViewBuilder
  private func matchSheetSection(side: MatchSheetSide) -> some View {
    let sheet = self.sheet(for: side)
    let team = self.sourceTeam(for: side)

    Section("\(side.title) Match Sheet") {
      LabeledContent("Status") {
        Text(sheet.isReady ? "Ready" : "Draft")
          .foregroundStyle(sheet.isReady ? .green : .secondary)
      }
      LabeledContent("Starters") { Text("\(sheet.starterCount)") }
      LabeledContent("Substitutes") { Text("\(sheet.substituteCount)") }
      LabeledContent("Staff") { Text("\(sheet.staffCount)") }
      LabeledContent("Other Members") { Text("\(sheet.otherMemberCount)") }

      Button(sheet.hasAnyEntries ? "Edit Match Sheet" : "Create Match Sheet") {
        if sheet.hasAnyEntries == false {
          self.seedSheetIfNeeded(for: side)
        }
        self.activeSheetSide = side
      }

      Button("Add Players") {
        self.seedSheetIfNeeded(for: side)
        self.activeSheetSide = side
      }

      Button("Add Staff") {
        self.seedSheetIfNeeded(for: side)
        self.activeSheetSide = side
      }

      if self.supportsMatchSheetImport {
        Button("Import from Screenshots") {
          self.activeImportSide = side
        }
        .accessibilityIdentifier("match-sheet-import-\(side.rawValue)")
        .disabled(self.hasLoadedTeams == false)
      }

      if let team {
        Button("Edit Source Team") {
          self.editingSourceTeam = team
        }
      }

      if let warning = self.rosterWarning(for: side) {
        Text(warning)
          .font(.footnote)
          .foregroundStyle(.orange)
      }
    }
  }

  private func save() {
    let normalizedHomeSheet = self.reconciledSheet(
      current: self.homeMatchSheet,
      selectedTeam: self.selectedHomeTeam,
      fallbackName: self.homeName)
    let normalizedAwaySheet = self.reconciledSheet(
      current: self.awayMatchSheet,
      selectedTeam: self.selectedAwayTeam,
      fallbackName: self.awayName)

    let item = ScheduledMatch(
      id: self.existingMatch?.id ?? UUID(),
      homeTeam: self.homeName.trimmingCharacters(in: .whitespacesAndNewlines),
      awayTeam: self.awayName.trimmingCharacters(in: .whitespacesAndNewlines),
      homeTeamId: self.selectedHomeTeam?.id ?? normalizedHomeSheet.sourceTeamId ?? self.existingMatch?.homeTeamId,
      awayTeamId: self.selectedAwayTeam?.id ?? normalizedAwaySheet.sourceTeamId ?? self.existingMatch?.awayTeamId,
      homeMatchSheet: normalizedHomeSheet,
      awayMatchSheet: normalizedAwaySheet,
      kickoff: self.kickoff,
      competition: self.existingMatch?.competition,
      notes: self.existingMatch?.notes,
      status: self.existingMatch?.status ?? .scheduled,
      ownerSupabaseId: self.existingMatch?.ownerSupabaseId,
      remoteUpdatedAt: self.existingMatch?.remoteUpdatedAt,
      needsRemoteSync: true,
      sourceDeviceId: self.existingMatch?.sourceDeviceId,
      lastModifiedAt: Date())

    do {
      try self.scheduleStore.save(item)
      AppLog.schedule.info(
        "Saved scheduled match: \(item.homeTeam) vs \(item.awayTeam) @ \(item.kickoff.timeIntervalSince1970, privacy: .public)")
      self.onSaved?()
      self.dismiss()
    } catch {
      AppLog.schedule.error("Scheduled match save failed: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = error.localizedDescription
    }
  }

  private func loadTeams() async {
    defer {
      self.hasLoadedTeams = true
    }

    do {
      try await self.teamStore.refreshFromRemote()
    } catch {
      AppLog.library.error("Team refresh failed: \(error.localizedDescription, privacy: .public)")
    }

    do {
      self.teams = try self.teamStore.loadAllTeams()
      if let existingMatch {
        self.selectedHomeTeam = self.teams.first(where: { $0.id == existingMatch.homeTeamId })
        self.selectedAwayTeam = self.teams.first(where: { $0.id == existingMatch.awayTeamId })
        self.homeMatchSheet = self.reconciledSheet(
          current: existingMatch.homeMatchSheet
            ?? MatchSheetDraftFactory.emptyDraft(sourceTeam: self.selectedHomeTeam, fallbackTeamName: self.homeName),
          selectedTeam: self.selectedHomeTeam,
          fallbackName: self.homeName)
        self.awayMatchSheet = self.reconciledSheet(
          current: existingMatch.awayMatchSheet
            ?? MatchSheetDraftFactory.emptyDraft(sourceTeam: self.selectedAwayTeam, fallbackTeamName: self.awayName),
          selectedTeam: self.selectedAwayTeam,
          fallbackName: self.awayName)
      }
    } catch {
      self.errorMessage = error.localizedDescription
    }
  }

  private func binding(for side: MatchSheetSide) -> Binding<ScheduledMatchSheet> {
    switch side {
    case .home:
      return self.$homeMatchSheet
    case .away:
      return self.$awayMatchSheet
    }
  }

  private func sheet(for side: MatchSheetSide) -> ScheduledMatchSheet {
    switch side {
    case .home:
      return self.homeMatchSheet
    case .away:
      return self.awayMatchSheet
    }
  }

  private func sourceTeam(for side: MatchSheetSide) -> TeamRecord? {
    switch side {
    case .home:
      return self.selectedHomeTeam
    case .away:
      return self.selectedAwayTeam
    }
  }

  private func teamName(for side: MatchSheetSide) -> String {
    switch side {
    case .home:
      return self.homeName.trimmingCharacters(in: .whitespacesAndNewlines)
    case .away:
      return self.awayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  private func seedSheetIfNeeded(for side: MatchSheetSide) {
    let team = self.sourceTeam(for: side)
    let fallbackName = self.teamName(for: side)
    switch side {
    case .home:
      if self.homeMatchSheet.hasAnyEntries == false {
        self.homeMatchSheet = MatchSheetDraftFactory.seededDraft(sourceTeam: team, fallbackTeamName: fallbackName)
      }
    case .away:
      if self.awayMatchSheet.hasAnyEntries == false {
        self.awayMatchSheet = MatchSheetDraftFactory.seededDraft(sourceTeam: team, fallbackTeamName: fallbackName)
      }
    }
  }

  private func reconciledSheet(
    current: ScheduledMatchSheet,
    selectedTeam: TeamRecord?,
    fallbackName: String) -> ScheduledMatchSheet
  {
    let normalizedFallback = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedCurrent = current.normalized()
    let desiredTeamId = selectedTeam?.id ?? normalizedCurrent.sourceTeamId
    let desiredTeamName = selectedTeam?.name
      ?? normalizedCurrent.sourceTeamName
      ?? normalizedFallback
    let sourceSelectionChanged = selectedTeam != nil
      && normalizedCurrent.sourceTeamId != nil
      && normalizedCurrent.sourceTeamId != desiredTeamId

    if sourceSelectionChanged {
      return MatchSheetDraftFactory.emptyDraft(sourceTeam: selectedTeam, fallbackTeamName: desiredTeamName)
    }

    var updated = normalizedCurrent
    updated.sourceTeamId = desiredTeamId
    updated.sourceTeamName = desiredTeamName
    return updated.normalized()
  }

  private func rosterWarning(for side: MatchSheetSide) -> String? {
    guard let team = self.sourceTeam(for: side) else { return nil }
    if team.players.isEmpty && team.officials.isEmpty {
      return "Source team has no players or staff yet. Use Edit Source Team or enter ad hoc match-sheet members."
    }
    if team.players.isEmpty {
      return "Source team has no players yet. Add players in the source team or enter ad hoc match-sheet players."
    }
    if team.officials.isEmpty {
      return "Source team has no staff yet. Add staff in the source team or enter ad hoc match-sheet members."
    }
    return nil
  }

  private var isValid: Bool {
    !self.homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !self.awayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var alertBinding: Binding<Bool> {
    Binding(
      get: { self.errorMessage != nil },
      set: { newValue in
        if newValue == false { self.errorMessage = nil }
      })
  }

  private var pendingSourceTeamChangeAlertBinding: Binding<Bool> {
    Binding(
      get: { self.pendingSourceTeamChange != nil },
      set: { newValue in
        if newValue == false { self.pendingSourceTeamChange = nil }
      })
  }

  private func handleSelectedSourceTeam(_ team: TeamRecord, for side: MatchSheetSide) {
    let currentSheet = self.sheet(for: side)
    let currentSourceTeamId = currentSheet.sourceTeamId ?? self.sourceTeam(for: side)?.id
    let matchesCurrentSourceName = currentSheet.sourceTeamName?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .localizedCaseInsensitiveCompare(team.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    let isSameSource = currentSourceTeamId == team.id
      || (currentSourceTeamId == nil && matchesCurrentSourceName == true)

    if isSameSource || currentSheet.hasAnyEntries == false || currentSheet.sourceTeamId == nil {
      self.commitSourceTeamChange(.init(side: side, team: team))
    } else {
      self.pendingSourceTeamChange = .init(side: side, team: team)
    }
  }

  private func commitSourceTeamChange(_ pending: PendingSourceTeamChange) {
    self.pendingSourceTeamChange = nil

    switch pending.side {
    case .home:
      self.selectedHomeTeam = pending.team
      self.homeName = pending.team.name
      if self.homeMatchSheet.sourceTeamId == nil, self.homeMatchSheet.hasAnyEntries {
        self.homeMatchSheet = MatchSheetEditorState.normalizedSheet(
          self.homeMatchSheet,
          sourceTeam: pending.team,
          fallbackTeamName: pending.team.name)
      } else if self.homeMatchSheet.sourceTeamId != pending.team.id {
        self.homeMatchSheet = MatchSheetDraftFactory.emptyDraft(
          sourceTeam: pending.team,
          fallbackTeamName: pending.team.name)
      }
    case .away:
      self.selectedAwayTeam = pending.team
      self.awayName = pending.team.name
      if self.awayMatchSheet.sourceTeamId == nil, self.awayMatchSheet.hasAnyEntries {
        self.awayMatchSheet = MatchSheetEditorState.normalizedSheet(
          self.awayMatchSheet,
          sourceTeam: pending.team,
          fallbackTeamName: pending.team.name)
      } else if self.awayMatchSheet.sourceTeamId != pending.team.id {
        self.awayMatchSheet = MatchSheetDraftFactory.emptyDraft(
          sourceTeam: pending.team,
          fallbackTeamName: pending.team.name)
      }
    }
  }

  private func prepareImportDraft(_ draft: MatchSheetImportDraft) -> MatchSheetImportDraft {
    var aligned = draft
    aligned.sheet = MatchSheetEditorState.normalizedSheet(
      draft.sheet,
      sourceTeam: self.sourceTeam(for: draft.side),
      fallbackTeamName: self.teamName(for: draft.side))
    aligned.sheet.status = .draft
    aligned.sheet = aligned.sheet.normalized()
    return aligned
  }

  private func applyImportSheet(_ sheet: ScheduledMatchSheet, for side: MatchSheetSide) {
    let normalized = MatchSheetEditorState.normalizedSheet(
      sheet,
      sourceTeam: self.sourceTeam(for: side),
      fallbackTeamName: self.teamName(for: side))

    switch side {
    case .home:
      self.homeMatchSheet = normalized
    case .away:
      self.awayMatchSheet = normalized
    }

    self.importDraft = nil
  }

  private var supportsMatchSheetImport: Bool {
    UIDevice.current.userInterfaceIdiom == .phone && self.matchSheetImportService != nil
  }

  private var importReviewBinding: Binding<Bool> {
    Binding(
      get: { self.importDraft != nil },
      set: { isPresented in
        if isPresented == false {
          self.importDraft = nil
        }
      })
  }

  private var importDraftSheetBinding: Binding<ScheduledMatchSheet> {
    Binding(
      get: {
        self.importDraft?.sheet
          ?? MatchSheetDraftFactory.emptyDraft(sourceTeam: nil, fallbackTeamName: "")
      },
      set: { updatedSheet in
        guard var importDraft = self.importDraft else { return }
        importDraft.sheet = updatedSheet
        self.importDraft = importDraft
      })
  }

  private static func defaultKickoff() -> Date {
    let cal = Calendar.current
    let now = Date()
    var comps = DateComponents()
    comps.weekday = 7
    comps.hour = 14
    comps.minute = 0
    return cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
  }
}

private struct PendingSourceTeamChange: Identifiable {
  let side: MatchSheetSide
  let team: TeamRecord

  var id: String { "\(self.side.rawValue)-\(self.team.id.uuidString)" }
}

#Preview {
  UpcomingMatchEditorView(scheduleStore: InMemoryScheduleStore(), teamStore: InMemoryTeamLibraryStore())
    .environmentObject(SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
}
