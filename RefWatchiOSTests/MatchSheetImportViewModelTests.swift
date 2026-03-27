import Foundation
import UIKit
import XCTest
@testable import RefWatchiOS
import RefWatchCore

@MainActor
final class MatchSheetImportViewModelTests: XCTestCase {
  func testAppendImageData_whenValidImageProvided_addsAttachmentAndAllowsRemoval() async throws {
    let service = ControlledMatchSheetImportService()
    let viewModel = MatchSheetImportViewModel(side: .home, expectedTeamName: "Metro FC", service: service)
    let data = Self.makeJPEGData(size: CGSize(width: 48, height: 32), color: .systemBlue)

    await viewModel.appendImageData(data, filename: "sheet-1.jpg")

    XCTAssertEqual(viewModel.attachments.count, 1)
    XCTAssertEqual(viewModel.attachments.first?.filename, "sheet-1.jpg")
    XCTAssertTrue(viewModel.canParse)
    XCTAssertNil(viewModel.attachmentError)

    let attachmentID = try XCTUnwrap(viewModel.attachments.first?.id)
    viewModel.removeAttachment(id: attachmentID)

    XCTAssertTrue(viewModel.attachments.isEmpty)
    XCTAssertFalse(viewModel.canParse)
  }

  func testParse_whenServiceReturnsCompletedResult_buildsDraft() async throws {
    let service = ControlledMatchSheetImportService()
    service.result = .success(Self.makeResult(teamName: "Metro FC", starterName: "Alex Starter"))
    let viewModel = MatchSheetImportViewModel(side: .home, expectedTeamName: "  Metro FC  ", service: service)

    await viewModel.appendImageData(Self.makeJPEGData(size: CGSize(width: 40, height: 24), color: .systemGreen), filename: "sheet.jpg")
    let draft = await viewModel.parse()

    XCTAssertEqual(service.expectedTeamName, "Metro FC")
    XCTAssertEqual(draft?.side, .home)
    XCTAssertEqual(draft?.sheet.status, .draft)
    XCTAssertEqual(draft?.sheet.starters.first?.displayName, "Alex Starter")
    XCTAssertEqual(draft?.warnings.first?.code, .nonIntegerShirtNumber)
    XCTAssertNil(viewModel.transportError)
  }

  func testParse_whenSecondAttemptCompletesLast_dropsStaleFirstResult() async throws {
    let service = SequencedMatchSheetImportService()
    let viewModel = MatchSheetImportViewModel(side: .away, expectedTeamName: "Rivals", service: service)
    await viewModel.appendImageData(Self.makeJPEGData(size: CGSize(width: 44, height: 24), color: .systemOrange), filename: "sheet.jpg")

    let firstTask = Task { await viewModel.parse() }
    try await Self.waitUntil { service.invocationCount == 1 }

    let secondTask = Task { await viewModel.parse() }
    try await Self.waitUntil { service.invocationCount == 2 }

    service.completeInvocation(
      at: 0,
      with: .success(Self.makeResult(teamName: "Rivals", starterName: "First Result")))
    let firstDraft = await firstTask.value

    service.completeInvocation(
      at: 1,
      with: .success(Self.makeResult(teamName: "Rivals", starterName: "Second Result")))
    let secondDraft = await secondTask.value

    XCTAssertNil(firstDraft)
    XCTAssertEqual(secondDraft?.sheet.starters.first?.displayName, "Second Result")
    XCTAssertNil(viewModel.transportError)
  }

  func testParse_whenTerminalStatusIsIncomplete_setsTransportError() async {
    let service = ControlledMatchSheetImportService()
    service.result = .success(
      MatchSheetImportResult(
        parsedSheet: ScheduledMatchSheet(sourceTeamName: "Metro FC", status: .draft, updatedAt: Date()).normalized(),
        warnings: [
          MatchSheetImportWarning(
            code: .incompleteResponse,
            message: "The parser stopped before finishing the match sheet."),
        ],
        extractedTeamName: "Metro FC",
        terminalStatus: .incomplete))
    let viewModel = MatchSheetImportViewModel(side: .home, expectedTeamName: "Metro FC", service: service)

    await viewModel.appendImageData(Self.makeJPEGData(size: CGSize(width: 44, height: 24), color: .systemTeal), filename: "sheet.jpg")
    let draft = await viewModel.parse()

    XCTAssertNil(draft)
    XCTAssertEqual(viewModel.transportError, "The parser stopped before finishing the match sheet.")
  }

  private static func makeJPEGData(size: CGSize, color: UIColor) -> Data {
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
      color.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
    return image.jpegData(compressionQuality: 1.0) ?? Data()
  }

  private static func makeResult(teamName: String, starterName: String) -> MatchSheetImportResult {
    MatchSheetImportResult(
      parsedSheet: ScheduledMatchSheet(
        sourceTeamName: teamName,
        status: .draft,
        starters: [
          MatchSheetPlayerEntry(displayName: starterName, shirtNumber: 9, position: "FW", notes: nil, sortOrder: 0),
        ],
        substitutes: [
          MatchSheetPlayerEntry(displayName: "Riley Bench", shirtNumber: nil, position: nil, notes: "Number unreadable", sortOrder: 0),
        ],
        staff: [
          MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Head Coach", notes: nil, sortOrder: 0, category: .staff),
        ],
        otherMembers: [],
        updatedAt: Date()).normalized(),
      warnings: [
        MatchSheetImportWarning(
          code: .nonIntegerShirtNumber,
          message: "One substitute had an unreadable shirt number and it was cleared."),
      ],
      extractedTeamName: teamName,
      terminalStatus: .completed)
  }

  private static func waitUntil(
    timeout: TimeInterval = 2.0,
    pollInterval: UInt64 = 20_000_000,
    condition: @escaping () -> Bool) async throws
  {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() {
        return
      }
      try await Task.sleep(nanoseconds: pollInterval)
    }
    XCTFail("Timed out waiting for import state to settle.")
  }
}

private final class ControlledMatchSheetImportService: MatchSheetImportProviding {
  var result: Result<MatchSheetImportResult, Error>?
  private(set) var expectedTeamName: String?

  func parseMatchSheet(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) async throws -> MatchSheetImportResult
  {
    self.expectedTeamName = expectedTeamName
    switch self.result {
    case let .success(result):
      return result
    case let .failure(error):
      throw error
    case .none:
      return MatchSheetImportResult(
        parsedSheet: ScheduledMatchSheet(sourceTeamName: expectedTeamName, status: .draft, updatedAt: Date()).normalized(),
        warnings: [],
        extractedTeamName: expectedTeamName,
        terminalStatus: .completed)
    }
  }
}

private final class SequencedMatchSheetImportService: MatchSheetImportProviding {
  private var continuations: [CheckedContinuation<MatchSheetImportResult, Error>] = []
  private(set) var invocationCount = 0

  func parseMatchSheet(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) async throws -> MatchSheetImportResult
  {
    self.invocationCount += 1
    return try await withCheckedThrowingContinuation { continuation in
      self.continuations.append(continuation)
    }
  }

  func completeInvocation(at index: Int, with result: Result<MatchSheetImportResult, Error>) {
    guard index < self.continuations.count else { return }
    let continuation = self.continuations[index]
    switch result {
    case let .success(value):
      continuation.resume(returning: value)
    case let .failure(error):
      continuation.resume(throwing: error)
    }
  }
}
