//
//  MatchSheetImportModels.swift
//  RefWatchiOS
//
//  Transient models that support screenshot-driven match-sheet import.
//

import Foundation
import RefWatchCore

enum MatchSheetSide: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
  case home
  case away

  var id: String { self.rawValue }

  var title: String {
    switch self {
    case .home:
      return "Home"
    case .away:
      return "Away"
    }
  }
}

enum MatchSheetImportTerminalStatus: String, Codable, Equatable, Sendable {
  case completed
  case incomplete
  case refused
}

struct MatchSheetImportWarning: Identifiable, Codable, Hashable, Equatable, Sendable {
  enum Code: String, Codable, Hashable, Sendable {
    case ambiguity = "ambiguity"
    case duplicateEntry = "duplicate_entry"
    case unreadableText = "unreadable_text"
    case teamNameMismatch = "team_name_mismatch"
    case unsupportedRole = "unsupported_role"
    case missingName = "missing_name"
    case nonIntegerShirtNumber = "non_integer_shirt_number"
    case refusal = "refusal"
    case incompleteResponse = "incomplete_response"
    case droppedEntry = "dropped_entry"
  }

  let code: Code
  let message: String

  var id: String { "\(self.code.rawValue):\(self.message)" }
}

struct MatchSheetImportResult: Codable, Equatable, Sendable {
  var parsedSheet: ScheduledMatchSheet
  var warnings: [MatchSheetImportWarning]
  var extractedTeamName: String?
  var terminalStatus: MatchSheetImportTerminalStatus

  var isCompleted: Bool {
    self.terminalStatus == .completed
  }
}

struct MatchSheetImportDraft: Identifiable, Equatable {
  let id: UUID
  let side: MatchSheetSide
  var sheet: ScheduledMatchSheet
  var warnings: [MatchSheetImportWarning]
  var extractedTeamName: String?
  var attachmentCount: Int

  init(
    id: UUID = UUID(),
    side: MatchSheetSide,
    sheet: ScheduledMatchSheet,
    warnings: [MatchSheetImportWarning],
    extractedTeamName: String?,
    attachmentCount: Int)
  {
    self.id = id
    self.side = side
    self.sheet = sheet
    self.warnings = warnings
    self.extractedTeamName = extractedTeamName
    self.attachmentCount = attachmentCount
  }
}

enum MatchSheetImportAttachmentError: LocalizedError, Equatable {
  case tooManyScreenshots(maxCount: Int)
  case totalPayloadTooLarge(maxBytes: Int)

  var errorDescription: String? {
    switch self {
    case let .tooManyScreenshots(maxCount):
      return "Select up to \(maxCount) screenshots for one import."
    case let .totalPayloadTooLarge(maxBytes):
      let maxMB = Double(maxBytes) / 1_000_000
      return "The selected screenshots are too large to upload together. Keep the total under \(String(format: "%.0f", maxMB)) MB."
    }
  }
}
