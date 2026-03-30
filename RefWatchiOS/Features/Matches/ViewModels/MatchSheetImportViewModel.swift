//
//  MatchSheetImportViewModel.swift
//  RefWatchiOS
//
//  Testable import-state coordinator for screenshot-driven match-sheet parsing.
//

import Foundation
import Observation
import RefWatchCore

@Observable
final class MatchSheetImportViewModel {
  static let maxScreenshotCount = 6
  static let maxTotalBytes = 16_000_000

  let side: MatchSheetSide
  var expectedTeamName: String
  var attachments: [AssistantImageAttachment] = []
  var attachmentError: String?
  var transportError: String?
  private(set) var isPreparingAttachments = false
  private(set) var isParsing = false

  private let service: MatchSheetImportProviding
  private var activeParseID: UUID?

  init(
    side: MatchSheetSide,
    expectedTeamName: String,
    service: MatchSheetImportProviding)
  {
    self.side = side
    self.expectedTeamName = expectedTeamName
    self.service = service
  }

  var canParse: Bool {
    self.attachments.isEmpty == false
      && self.isPreparingAttachments == false
      && self.isParsing == false
  }

  var totalByteCount: Int {
    self.attachments.reduce(0) { $0 + $1.byteCount }
  }

  func appendImageData(_ data: Data?, filename: String) async {
    self.attachmentError = nil
    self.transportError = nil
    self.isPreparingAttachments = true

    defer {
      self.isPreparingAttachments = false
    }

    guard self.attachments.count < Self.maxScreenshotCount else {
      self.attachmentError = MatchSheetImportAttachmentError.tooManyScreenshots(
        maxCount: Self.maxScreenshotCount).localizedDescription
      return
    }

    guard let data else {
      self.attachmentError = AssistantImageAttachmentError.unreadableImage.localizedDescription
      return
    }

    do {
      let attachment = try await Task.detached(priority: .userInitiated) {
        try AssistantImageAttachmentBuilder.prepare(from: data, filename: filename, detail: .high)
      }.value

      guard self.totalByteCount + attachment.byteCount <= Self.maxTotalBytes else {
        self.attachmentError = MatchSheetImportAttachmentError.totalPayloadTooLarge(
          maxBytes: Self.maxTotalBytes).localizedDescription
        return
      }

      self.attachments.append(attachment)
    } catch {
      self.attachmentError = error.localizedDescription
    }
  }

  func removeAttachment(id: UUID) {
    self.attachments.removeAll { $0.id == id }
    self.attachmentError = nil
    self.transportError = nil
  }

  func parse() async -> MatchSheetImportDraft? {
    guard self.attachments.isEmpty == false, self.isPreparingAttachments == false else { return nil }

    self.attachmentError = nil
    self.transportError = nil
    self.isParsing = true

    let parseID = UUID()
    self.activeParseID = parseID
    let attachments = self.attachments
    let trimmedExpectedTeamName = self.expectedTeamName.trimmingCharacters(in: .whitespacesAndNewlines)

    defer {
      if self.activeParseID == parseID {
        self.isParsing = false
      }
    }

    do {
      let result = try await self.service.parseMatchSheet(
        side: self.side,
        expectedTeamName: trimmedExpectedTeamName.isEmpty ? nil : trimmedExpectedTeamName,
        images: attachments)

      guard self.activeParseID == parseID else {
        return nil
      }

      guard result.isCompleted else {
        self.transportError = result.warnings.first?.message
          ?? "The parser stopped before finishing the match sheet."
        return nil
      }

      return MatchSheetImportDraft(
        side: self.side,
        sheet: result.parsedSheet.normalized(),
        warnings: result.warnings,
        extractedTeamName: result.extractedTeamName,
        attachmentCount: attachments.count)
    } catch {
      guard self.activeParseID == parseID else {
        return nil
      }
      self.transportError = error.localizedDescription
      return nil
    }
  }
}

#if DEBUG
extension MatchSheetImportViewModel {
  enum PreviewState {
    case empty
    case ready(attachments: [AssistantImageAttachment])
    case preparing(attachments: [AssistantImageAttachment])
    case parsing(attachments: [AssistantImageAttachment])
    case transportError(attachments: [AssistantImageAttachment], message: String)
  }

  @MainActor
  static func preview(
    side: MatchSheetSide = .home,
    expectedTeamName: String = MatchSheetImportPreviewSupport.homeTeamName,
    state: PreviewState,
    service: MatchSheetImportProviding = MatchSheetImportPreviewSupport.makeImportService()) -> MatchSheetImportViewModel
  {
    let viewModel = MatchSheetImportViewModel(
      side: side,
      expectedTeamName: expectedTeamName,
      service: service)

    switch state {
    case .empty:
      break
    case let .ready(attachments):
      viewModel.attachments = attachments
    case let .preparing(attachments):
      viewModel.attachments = attachments
      viewModel.isPreparingAttachments = true
    case let .parsing(attachments):
      viewModel.attachments = attachments
      viewModel.isParsing = true
    case let .transportError(attachments, message):
      viewModel.attachments = attachments
      viewModel.transportError = message
    }

    return viewModel
  }
}
#endif
