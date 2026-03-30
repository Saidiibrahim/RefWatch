//
//  PreviewSupport.swift
//  RefWatchiOS
//
//  Helpers for safe, realistic previews.
//

import RefWatchCore
import SwiftUI
import UIKit

#if DEBUG
extension AppRouter {
  static func preview(selected: AppRouter.Tab = .matches) -> AppRouter {
    let router = AppRouter()
    router.selectedTab = selected
    return router
  }
}

extension MatchViewModel {
  @MainActor
  static func previewActive() -> MatchViewModel {
    let viewModel = MatchViewModel(haptics: NoopHaptics())
    viewModel.newMatch = Match(homeTeam: "HOM", awayTeam: "AWA")
    viewModel.createMatch()
    viewModel.startMatch()
    return viewModel
  }
}

enum MatchSheetImportPreviewSupport {
  nonisolated static let homeTeamName = "Metro FC"
  nonisolated static let awayTeamName = "Rivals FC"
  nonisolated static let warningMessage = "One substitute had an unreadable shirt number and it was cleared."
  nonisolated static let failureMessage = "The parser request failed with a temporary upstream error."

  struct TeamContext {
    let teamStore: InMemoryTeamLibraryStore
    let homeTeam: TeamRecord
    let awayTeam: TeamRecord

    var teams: [TeamRecord] {
      [self.homeTeam, self.awayTeam]
    }
  }

  struct SavedMatchContext {
    let scheduleStore: InMemoryScheduleStore
    let teamStore: InMemoryTeamLibraryStore
    let match: ScheduledMatch
    let homeTeam: TeamRecord
    let awayTeam: TeamRecord
  }

  enum ImportServiceMode {
    case success
    case failure(message: String)
  }

  @MainActor
  static func authController() -> SupabaseAuthController {
    SupabaseAuthController.previewSignedIn()
  }

  nonisolated static var canonicalKickoff: Date {
    let calendar = Calendar.current
    let targetDay = calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    let dayComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
    return calendar.date(from: DateComponents(
      year: dayComponents.year,
      month: dayComponents.month,
      day: dayComponents.day,
      hour: 14,
      minute: 0)) ?? targetDay
  }

  @MainActor
  static func makeTeamContext() -> TeamContext {
    let store = InMemoryTeamLibraryStore()

    let homeTeam = self.createTeam(
      name: self.homeTeamName,
      in: store,
      players: [
        ("Alex Starter", 9, "FW"),
        ("Jordan Starter", 8, "CM"),
        ("Sam Keeper", 1, "GK"),
        ("Casey Wing", 11, "RW"),
      ],
      officials: [
        ("Taylor Coach", "Head Coach"),
        ("Morgan Physio", "Physio"),
      ])

    let awayTeam = self.createTeam(
      name: self.awayTeamName,
      in: store,
      players: [
        ("Riley Captain", 6, "CM"),
        ("Jamie Defender", 4, "CB"),
        ("Avery Keeper", 1, "GK"),
      ],
      officials: [
        ("Rowan Coach", "Head Coach"),
      ])

    return TeamContext(teamStore: store, homeTeam: homeTeam, awayTeam: awayTeam)
  }

  nonisolated static func makeImportService(mode: ImportServiceMode = .success) -> MatchSheetImportProviding {
    PreviewMatchSheetImportService(mode: mode)
  }

  nonisolated static func sampleWarnings() -> [MatchSheetImportWarning] {
    [
      MatchSheetImportWarning(
        code: .nonIntegerShirtNumber,
        message: self.warningMessage),
    ]
  }

  nonisolated static func sampleAttachments() -> [AssistantImageAttachment] {
    [
      self.makeAttachment(
        filename: "metro-sheet-1.jpg",
        accentColor: .systemGreen,
        lines: [
          self.homeTeamName,
          "1 Sam Keeper",
          "8 Jordan Starter",
          "9 Alex Starter",
          "11 Casey Wing",
        ]),
      self.makeAttachment(
        filename: "metro-sheet-2.jpg",
        accentColor: .systemBlue,
        lines: [
          "Bench: Riley Bench",
          "Coach: Taylor Coach",
          "Physio: Morgan Physio",
          "Analyst: Casey Analyst",
        ]),
    ]
  }

  nonisolated static func importedHomeSheet(sourceTeam: TeamRecord? = nil) -> ScheduledMatchSheet {
    let teamName = sourceTeam?.name ?? self.homeTeamName
    return ScheduledMatchSheet(
      sourceTeamId: sourceTeam?.id,
      sourceTeamName: teamName,
      status: .draft,
      starters: [
        MatchSheetPlayerEntry(displayName: "Alex Starter", shirtNumber: 9, position: "FW", notes: nil, sortOrder: 0),
        MatchSheetPlayerEntry(displayName: "Jordan Starter", shirtNumber: 8, position: "CM", notes: "Captain", sortOrder: 1),
      ],
      substitutes: [
        MatchSheetPlayerEntry(displayName: "Riley Bench", shirtNumber: nil, position: nil, notes: "Number unreadable", sortOrder: 0),
      ],
      staff: [
        MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Head Coach", notes: nil, sortOrder: 0, category: .staff),
        MatchSheetStaffEntry(displayName: "Morgan Physio", roleLabel: "Physio", notes: nil, sortOrder: 1, category: .staff),
      ],
      otherMembers: [
        MatchSheetStaffEntry(displayName: "Casey Analyst", roleLabel: "Analyst", notes: nil, sortOrder: 0, category: .otherMember),
      ],
      updatedAt: self.canonicalKickoff).normalized()
  }

  nonisolated static func cleanImportedSheet(sourceTeam: TeamRecord? = nil) -> ScheduledMatchSheet {
    let teamName = sourceTeam?.name ?? self.homeTeamName
    return ScheduledMatchSheet(
      sourceTeamId: sourceTeam?.id,
      sourceTeamName: teamName,
      status: .draft,
      starters: [
        MatchSheetPlayerEntry(displayName: "Alex Starter", shirtNumber: 9, position: "FW", notes: nil, sortOrder: 0),
        MatchSheetPlayerEntry(displayName: "Jordan Starter", shirtNumber: 8, position: "CM", notes: "Captain", sortOrder: 1),
      ],
      substitutes: [
        MatchSheetPlayerEntry(displayName: "Sam Bench", shirtNumber: 14, position: "DF", notes: nil, sortOrder: 0),
      ],
      staff: [
        MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Head Coach", notes: nil, sortOrder: 0, category: .staff),
      ],
      otherMembers: [],
      updatedAt: self.canonicalKickoff).normalized()
  }

  @MainActor
  static func makeUpcomingEntryPointSeed() -> UpcomingMatchEditorView.PreviewSeed {
    let teams = self.makeTeamContext()
    return UpcomingMatchEditorView.PreviewSeed(
      scheduleStore: InMemoryScheduleStore(),
      teamStore: teams.teamStore,
      matchSheetImportService: self.makeImportService(),
      existingMatch: nil,
      homeName: teams.homeTeam.name,
      awayName: teams.awayTeam.name,
      selectedHomeTeam: teams.homeTeam,
      selectedAwayTeam: teams.awayTeam,
      kickoff: self.canonicalKickoff,
      homeMatchSheet: MatchSheetDraftFactory.emptyDraft(
        sourceTeam: teams.homeTeam,
        fallbackTeamName: teams.homeTeam.name),
      awayMatchSheet: MatchSheetDraftFactory.emptyDraft(
        sourceTeam: teams.awayTeam,
        fallbackTeamName: teams.awayTeam.name),
      teams: teams.teams,
      hasLoadedTeams: true)
  }

  @MainActor
  static func makeUpcomingPostApplySeed() -> UpcomingMatchEditorView.PreviewSeed {
    let teams = self.makeTeamContext()
    return UpcomingMatchEditorView.PreviewSeed(
      scheduleStore: InMemoryScheduleStore(),
      teamStore: teams.teamStore,
      matchSheetImportService: self.makeImportService(),
      existingMatch: nil,
      homeName: teams.homeTeam.name,
      awayName: teams.awayTeam.name,
      selectedHomeTeam: teams.homeTeam,
      selectedAwayTeam: teams.awayTeam,
      kickoff: self.canonicalKickoff,
      homeMatchSheet: self.importedHomeSheet(sourceTeam: teams.homeTeam),
      awayMatchSheet: MatchSheetDraftFactory.emptyDraft(
        sourceTeam: teams.awayTeam,
        fallbackTeamName: teams.awayTeam.name),
      teams: teams.teams,
      hasLoadedTeams: true)
  }

  @MainActor
  static func makeSavedMatchContext() -> SavedMatchContext {
    let teams = self.makeTeamContext()
    let savedMatch = ScheduledMatch(
      homeTeam: teams.homeTeam.name,
      awayTeam: teams.awayTeam.name,
      homeTeamId: teams.homeTeam.id,
      awayTeamId: teams.awayTeam.id,
      homeMatchSheet: self.importedHomeSheet(sourceTeam: teams.homeTeam),
      awayMatchSheet: MatchSheetDraftFactory.emptyDraft(
        sourceTeam: teams.awayTeam,
        fallbackTeamName: teams.awayTeam.name),
      kickoff: self.canonicalKickoff,
      status: .scheduled)
    let scheduleStore = InMemoryScheduleStore(initial: [savedMatch])
    return SavedMatchContext(
      scheduleStore: scheduleStore,
      teamStore: teams.teamStore,
      match: savedMatch,
      homeTeam: teams.homeTeam,
      awayTeam: teams.awayTeam)
  }

  @MainActor
  private static func createTeam(
    name: String,
    in store: InMemoryTeamLibraryStore,
    players: [(String, Int?, String?)],
    officials: [(String, String)]) -> TeamRecord
  {
    let team = self.unwrap(try store.createTeam(name: name, shortName: nil, division: "Premier"))
    for player in players {
      let playerRecord = self.unwrap(try store.addPlayer(to: team, name: player.0, number: player.1))
      playerRecord.position = player.2
    }
    for official in officials {
      _ = self.unwrap(try store.addOfficial(to: team, name: official.0, roleRaw: official.1))
    }
    return team
  }

  nonisolated private static func makeAttachment(
    filename: String,
    accentColor: UIColor,
    lines: [String]) -> AssistantImageAttachment
  {
    let size = CGSize(width: 320, height: 560)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
      UIColor.systemBackground.setFill()
      context.fill(CGRect(origin: .zero, size: size))

      accentColor.withAlphaComponent(0.18).setFill()
      context.fill(CGRect(x: 16, y: 16, width: size.width - 32, height: size.height - 32))

      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .left

      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .medium),
        .foregroundColor: UIColor.label,
        .paragraphStyle: paragraph,
      ]
      lines.joined(separator: "\n").draw(
        in: CGRect(x: 32, y: 40, width: size.width - 64, height: size.height - 80),
        withAttributes: attributes)
    }

    let jpegData = image.jpegData(compressionQuality: 0.88) ?? Data()
    return AssistantImageAttachment(
      filename: filename,
      jpegData: jpegData,
      detail: .high,
      pixelWidth: Int(size.width),
      pixelHeight: Int(size.height))
  }

  nonisolated private static func unwrap<T>(_ value: @autoclosure () throws -> T) -> T {
    do {
      return try value()
    } catch {
      fatalError("Failed to build preview fixtures: \(error)")
    }
  }
}

private final class PreviewMatchSheetImportService: MatchSheetImportProviding {
  nonisolated let mode: MatchSheetImportPreviewSupport.ImportServiceMode

  nonisolated
  init(mode: MatchSheetImportPreviewSupport.ImportServiceMode) {
    self.mode = mode
  }

  nonisolated
  func parseMatchSheet(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) async throws -> MatchSheetImportResult
  {
    switch self.mode {
    case .success:
      let teamName = expectedTeamName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ?? MatchSheetImportPreviewSupport.homeTeamName
      var parsedSheet = MatchSheetImportPreviewSupport.importedHomeSheet()
      parsedSheet.sourceTeamName = teamName
      return MatchSheetImportResult(
        parsedSheet: parsedSheet.normalized(),
        warnings: MatchSheetImportPreviewSupport.sampleWarnings(),
        extractedTeamName: teamName,
        terminalStatus: .completed)
    case let .failure(message):
      throw MatchSheetImportServiceError.http(status: 502, body: message)
    }
  }
}

private extension String {
  nonisolated
  var nilIfEmpty: String? {
    self.isEmpty ? nil : self
  }
}
#endif
