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
  @State private var kickoff: Date
  @State private var homeMatchSheet: ScheduledMatchSheet
  @State private var awayMatchSheet: ScheduledMatchSheet

  @State private var activeTeamPickerSide: MatchSheetSide?
  @State private var activeSheetSide: MatchSheetSide?
  @State private var activeImportSide: MatchSheetSide?
  @State private var importDraft: MatchSheetImportDraft?
  @State private var errorMessage: String?
  @State private var hasWarmedTeamLibrary = false

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
    _kickoff = State(initialValue: existingMatch?.kickoff ?? Self.defaultKickoff())
    _homeMatchSheet = State(
      initialValue: existingMatch?.homeMatchSheet
        ?? MatchSheetDraftFactory.emptyDraft(teamName: initialHomeName))
    _awayMatchSheet = State(
      initialValue: existingMatch?.awayMatchSheet
        ?? MatchSheetDraftFactory.emptyDraft(teamName: initialAwayName))
  }

#if DEBUG
  struct PreviewSeed {
    let scheduleStore: ScheduleStoring
    let teamStore: TeamLibraryStoring
    let matchSheetImportService: MatchSheetImportProviding?
    let existingMatch: ScheduledMatch?
    let homeName: String
    let awayName: String
    let kickoff: Date
    let homeMatchSheet: ScheduledMatchSheet
    let awayMatchSheet: ScheduledMatchSheet
  }

  init(
    previewSeed: PreviewSeed,
    onSaved: (() -> Void)? = nil)
  {
    self.scheduleStore = previewSeed.scheduleStore
    self.teamStore = previewSeed.teamStore
    self.matchSheetImportService = previewSeed.matchSheetImportService
    self.existingMatch = previewSeed.existingMatch
    self.onSaved = onSaved

    _homeName = State(initialValue: previewSeed.homeName)
    _awayName = State(initialValue: previewSeed.awayName)
    _kickoff = State(initialValue: previewSeed.kickoff)
    _homeMatchSheet = State(initialValue: previewSeed.homeMatchSheet)
    _awayMatchSheet = State(initialValue: previewSeed.awayMatchSheet)
  }
#endif

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
    .onAppear {
      self.warmTeamLibraryIfNeeded()
    }
  }

  private var isSignedIn: Bool { self.authController.isSignedIn }

  @ViewBuilder
  private var formContent: some View {
    Form {
      Section("Teams") {
        self.teamField(title: "Home Team", side: .home, name: self.$homeName)
        self.teamField(title: "Away Team", side: .away, name: self.$awayName)
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
    .sheet(item: self.$activeTeamPickerSide) { side in
      TeamPickerSheet(teamStore: self.teamStore, mode: .libraryOnly) { team in
        self.applyTeamNameAutofill(team.name, for: side)
      }
    }
    .sheet(item: self.$activeSheetSide) { side in
      MatchSheetEditorView(
        sideTitle: side.title,
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
    .onChange(of: self.homeName) { _, _ in
      self.homeMatchSheet = self.reconciledSheet(
        current: self.homeMatchSheet,
        fallbackName: self.homeName)
    }
    .onChange(of: self.awayName) { _, _ in
      self.awayMatchSheet = self.reconciledSheet(
        current: self.awayMatchSheet,
        fallbackName: self.awayName)
    }
    .alert("Unable to Save", isPresented: self.alertBinding) {
      Button("OK", role: .cancel) { self.errorMessage = nil }
    } message: {
      Text(self.errorMessage ?? "Sign in to save scheduled matches on your phone.")
    }
  }

  private func teamField(
    title: String,
    side: MatchSheetSide,
    name: Binding<String>) -> some View
  {
    LabeledContent(title) {
      HStack(spacing: 12) {
        TextField(title, text: name)
          .multilineTextAlignment(.trailing)
          .textInputAutocapitalization(.words)
          .autocorrectionDisabled(true)
          .accessibilityLabel(title)

        Button {
          self.activeTeamPickerSide = side
        } label: {
          Image(systemName: "books.vertical")
            .font(.body)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(self.autofillAccessibilityLabel(for: side))
        .accessibilityIdentifier("team-name-autofill-\(side.rawValue)")
      }
    }
  }

  @ViewBuilder
  private func matchSheetSection(side: MatchSheetSide) -> some View {
    let sheet = self.sheet(for: side)

    Section("\(side.title) Match Sheet") {
      if sheet.hasAnyEntries {
        Text(self.sheetSummary(for: sheet))
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        Text("Optional. Save the match without a sheet now, or add one later.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Button(sheet.hasAnyEntries ? "Edit" : "Add Manually") {
        self.activeSheetSide = side
      }
      .accessibilityIdentifier("match-sheet-edit-\(side.rawValue)")

      if self.supportsMatchSheetImport {
        Button(sheet.hasAnyEntries ? "Replace from Screenshots" : "Import Screenshots") {
          self.activeImportSide = side
        }
        .accessibilityIdentifier("match-sheet-import-\(side.rawValue)")
      }

      if sheet.hasAnyEntries {
        Button("Remove Sheet", role: .destructive) {
          self.removeSheet(for: side)
        }
        .accessibilityIdentifier("match-sheet-remove-\(side.rawValue)")
      }
    }
  }

  private func save() {
    let item = Self.scheduledMatchForSave(
      existingMatch: self.existingMatch,
      homeName: self.homeName,
      awayName: self.awayName,
      kickoff: self.kickoff,
      homeMatchSheet: self.homeMatchSheet,
      awayMatchSheet: self.awayMatchSheet)

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

  private func teamName(for side: MatchSheetSide) -> String {
    switch side {
    case .home:
      return self.homeName.trimmingCharacters(in: .whitespacesAndNewlines)
    case .away:
      return self.awayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  private func reconciledSheet(
    current: ScheduledMatchSheet,
    fallbackName: String) -> ScheduledMatchSheet
  {
    MatchSheetEditorState.normalizedSheet(
      current,
      fallbackTeamName: fallbackName)
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

  private func prepareImportDraft(_ draft: MatchSheetImportDraft) -> MatchSheetImportDraft {
    var aligned = draft
    aligned.sheet = MatchSheetEditorState.normalizedSheet(
      draft.sheet,
      fallbackTeamName: self.teamName(for: draft.side))
    aligned.sheet.status = .draft
    aligned.sheet = aligned.sheet.normalized()
    return aligned
  }

  private func applyImportSheet(_ sheet: ScheduledMatchSheet, for side: MatchSheetSide) {
    let normalized = MatchSheetEditorState.normalizedSheet(
      sheet,
      fallbackTeamName: self.teamName(for: side))

    switch side {
    case .home:
      self.homeMatchSheet = normalized
    case .away:
      self.awayMatchSheet = normalized
    }

    self.importDraft = nil
  }

  private func removeSheet(for side: MatchSheetSide) {
    let emptySheet = MatchSheetDraftFactory.emptyDraft(teamName: self.teamName(for: side))

    switch side {
    case .home:
      self.homeMatchSheet = emptySheet
    case .away:
      self.awayMatchSheet = emptySheet
    }
  }

  private func sheetSummary(for sheet: ScheduledMatchSheet) -> String {
    [
      self.sheetSummaryPart(count: sheet.starterCount, singular: "starter"),
      self.sheetSummaryPart(count: sheet.substituteCount, singular: "substitute"),
      self.sheetSummaryPart(count: sheet.staffCount, singular: "staff member"),
      self.sheetSummaryPart(count: sheet.otherMemberCount, singular: "other member"),
    ].joined(separator: " | ")
  }

  private func sheetSummaryPart(count: Int, singular: String) -> String {
    let suffix = count == 1 ? singular : "\(singular)s"
    return "\(count) \(suffix)"
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
          ?? MatchSheetDraftFactory.emptyDraft(teamName: "")
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

  private func warmTeamLibraryIfNeeded() {
    guard self.isSignedIn, self.hasWarmedTeamLibrary == false else { return }
    self.hasWarmedTeamLibrary = true

    do {
      _ = try self.teamStore.loadAllTeams()
    } catch {
      AppLog.library.error("Upcoming match team warm load failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func applyTeamNameAutofill(_ teamName: String, for side: MatchSheetSide) {
    switch side {
    case .home:
      self.homeName = teamName
    case .away:
      self.awayName = teamName
    }
  }

  private func autofillAccessibilityLabel(for side: MatchSheetSide) -> String {
    switch side {
    case .home:
      return "Autofill Home Team Name from Team Library"
    case .away:
      return "Autofill Away Team Name from Team Library"
    }
  }

  static func scheduledMatchForSave(
    existingMatch: ScheduledMatch?,
    homeName: String,
    awayName: String,
    kickoff: Date,
    homeMatchSheet: ScheduledMatchSheet,
    awayMatchSheet: ScheduledMatchSheet,
    now: Date = Date()) -> ScheduledMatch
  {
    let trimmedHomeName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedAwayName = awayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedHomeSheet = MatchSheetEditorState.normalizedSheet(
      homeMatchSheet,
      fallbackTeamName: trimmedHomeName)
      .preparedForScheduleSave()
    let normalizedAwaySheet = MatchSheetEditorState.normalizedSheet(
      awayMatchSheet,
      fallbackTeamName: trimmedAwayName)
      .preparedForScheduleSave()

    return ScheduledMatch(
      id: existingMatch?.id ?? UUID(),
      homeTeam: trimmedHomeName,
      awayTeam: trimmedAwayName,
      homeTeamId: existingMatch?.homeTeamId,
      awayTeamId: existingMatch?.awayTeamId,
      homeMatchSheet: normalizedHomeSheet,
      awayMatchSheet: normalizedAwaySheet,
      kickoff: kickoff,
      competition: existingMatch?.competition,
      notes: existingMatch?.notes,
      status: existingMatch?.status ?? .scheduled,
      ownerSupabaseId: existingMatch?.ownerSupabaseId,
      remoteUpdatedAt: existingMatch?.remoteUpdatedAt,
      needsRemoteSync: true,
      sourceDeviceId: existingMatch?.sourceDeviceId,
      lastModifiedAt: now)
  }
}

#if DEBUG
#Preview("Upcoming Match - Import Entry Point") {
  UpcomingMatchEditorView(previewSeed: MatchSheetImportPreviewSupport.makeUpcomingEntryPointSeed())
    .environmentObject(MatchSheetImportPreviewSupport.authController())
}

#Preview("Upcoming Match - Imported Side Pending Save") {
  UpcomingMatchEditorView(previewSeed: MatchSheetImportPreviewSupport.makeUpcomingPostApplySeed())
    .environmentObject(MatchSheetImportPreviewSupport.authController())
}
#endif
