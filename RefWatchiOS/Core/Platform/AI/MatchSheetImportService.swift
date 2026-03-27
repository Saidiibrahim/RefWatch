//
//  MatchSheetImportService.swift
//  RefWatchiOS
//
//  Typed transport for screenshot-based match-sheet parsing.
//

import Foundation

protocol MatchSheetImportProviding {
  func parseMatchSheet(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) async throws -> MatchSheetImportResult
}

enum MatchSheetImportServiceError: LocalizedError, Equatable {
  case emptySelection
  case invalidResponse
  case unsupportedClient
  case sessionUnavailable
  case http(status: Int, body: String?)

  var errorDescription: String? {
    switch self {
    case .emptySelection:
      return "Add at least one screenshot before parsing."
    case .invalidResponse:
      return "The match-sheet parser returned an invalid response."
    case .unsupportedClient:
      return "Match-sheet import is unavailable on this build."
    case .sessionUnavailable:
      return "Sign in again to import a match sheet."
    case let .http(status, body):
      if status == 401 {
        return "Sign in again to import a match sheet."
      }
      if let body, body.isEmpty == false {
        return body
      }
      return "The match-sheet import failed with HTTP \(status)."
    }
  }
}
