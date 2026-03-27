import Foundation
import XCTest
import UIKit
@testable import RefWatchiOS

@MainActor
final class AssistantViewModelTests: XCTestCase {
  private static var retainedViewModels: [AssistantViewModel] = []

  func testSend_whenInputIsWhitespaceAndNoAttachment_doesNothing() {
    let service = ControlledAssistantService()
    let viewModel = Self.retain(AssistantViewModel(service: service))
    viewModel.input = "   "

    viewModel.send()

    XCTAssertTrue(viewModel.messages.isEmpty)
    XCTAssertEqual(viewModel.input, "   ")
    XCTAssertFalse(viewModel.canSend)
    XCTAssertEqual(service.streamStartCount, 0)
  }

  func testPrepareAttachment_whenValidImageDataProvided_setsDraftAttachmentAndAllowsSend() async throws {
    let viewModel = Self.retain(AssistantViewModel(service: ControlledAssistantService()))
    let data = Self.makeJPEGData(size: CGSize(width: 48, height: 32), color: .systemBlue)

    viewModel.prepareAttachment(from: data, filename: "frame.jpg")
    try await Self.waitUntil { viewModel.isPreparingAttachment == false }

    let attachment = try XCTUnwrap(viewModel.draftAttachment)
    XCTAssertEqual(attachment.filename, "frame.jpg")
    XCTAssertEqual(attachment.mediaType, "image/jpeg")
    XCTAssertLessThanOrEqual(attachment.byteCount, AssistantImageAttachmentBuilder.maxBytes)
    XCTAssertTrue(viewModel.canSend)
    XCTAssertNil(viewModel.attachmentErrorMessage)

    viewModel.removeDraftAttachment()
    XCTAssertNil(viewModel.draftAttachment)
    XCTAssertFalse(viewModel.canSend)
  }

  func testPrepareAttachment_whenImageCannotBeDecoded_setsAttachmentError() async throws {
    let viewModel = Self.retain(AssistantViewModel(service: ControlledAssistantService()))

    viewModel.prepareAttachment(from: Data([0x00, 0x01, 0x02]), filename: "bad.bin")
    try await Self.waitUntil { viewModel.isPreparingAttachment == false }

    XCTAssertNil(viewModel.draftAttachment)
    XCTAssertEqual(viewModel.attachmentErrorMessage, AssistantImageAttachmentError.unreadableImage.localizedDescription)
    XCTAssertFalse(viewModel.canSend)
  }

  func testSend_whenImageDraftProvided_sendsImageWithoutText() async throws {
    let started = expectation(description: "assistant stream started")
    let service = ControlledAssistantService {
      started.fulfill()
    }
    let viewModel = Self.retain(AssistantViewModel(service: service))
    let data = Self.makeJPEGData(size: CGSize(width: 40, height: 24), color: .systemRed)

    viewModel.prepareAttachment(from: data, filename: "scene.jpg")
    try await Self.waitUntil { viewModel.isPreparingAttachment == false }

    viewModel.send()
    await fulfillment(of: [started], timeout: 1.0)

    XCTAssertEqual(viewModel.messages.count, 2)
    XCTAssertEqual(viewModel.messages[0].role, .user)
    XCTAssertEqual(viewModel.messages[0].text, "")
    XCTAssertNotNil(viewModel.messages[0].attachment)
    XCTAssertEqual(viewModel.messages[1].role, .assistant)
    XCTAssertEqual(viewModel.messages[1].text, "")
    XCTAssertNil(viewModel.draftAttachment)
    XCTAssertEqual(service.capturedMessages?.first?.attachment?.filename, "scene.jpg")
    XCTAssertEqual(service.capturedMessages?.first?.text, "")

    service.yield("Stub ")
    service.yield("reply")
    service.finish()
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(viewModel.messages[1].text, "Stub reply")
  }

  func testSend_whenTextAndImageDraftProvided_trimsTextAndClearsDraftAfterRequestStarts() async throws {
    let started = expectation(description: "assistant stream started")
    let service = ControlledAssistantService {
      started.fulfill()
    }
    let viewModel = Self.retain(AssistantViewModel(service: service))
    let data = Self.makeJPEGData(size: CGSize(width: 48, height: 48), color: .systemGreen)

    viewModel.input = "  Need help with this image?  "
    viewModel.prepareAttachment(from: data, filename: "field.jpg")
    try await Self.waitUntil { viewModel.isPreparingAttachment == false }

    XCTAssertTrue(viewModel.canSend)
    viewModel.send()
    await fulfillment(of: [started], timeout: 1.0)

    XCTAssertEqual(viewModel.input, "")
    XCTAssertNil(viewModel.draftAttachment)
    XCTAssertEqual(viewModel.messages.count, 2)
    XCTAssertEqual(viewModel.messages[0].text, "Need help with this image?")
    XCTAssertEqual(viewModel.messages[0].attachment?.filename, "field.jpg")
    XCTAssertTrue(service.capturedMessages?.first?.hasRenderableContent ?? false)
    XCTAssertEqual(service.capturedMessages?.first?.trimmedText, "Need help with this image?")
  }

  func testStopStreaming_whenActiveResponseExists_cancelsUpstreamStream() async throws {
    let started = expectation(description: "assistant stream started")
    let service = ControlledAssistantService {
      started.fulfill()
    }
    let viewModel = Self.retain(AssistantViewModel(service: service))

    viewModel.input = "Please inspect this"
    viewModel.send()
    await fulfillment(of: [started], timeout: 1.0)

    XCTAssertTrue(viewModel.isStreaming)
    viewModel.stopStreaming()

    XCTAssertFalse(viewModel.isStreaming)
    XCTAssertEqual(service.cancelCount, 1)
  }

  func testSend_whenTappedAgainBeforeStreamStarts_doesNotStartDuplicateRequest() async throws {
    let service = ControlledAssistantService()
    let viewModel = Self.retain(AssistantViewModel(service: service))

    viewModel.input = "Double-send guard"
    viewModel.send()
    viewModel.send()

    XCTAssertTrue(viewModel.isStreaming)
    try await Self.waitUntil { service.streamStartCount == 1 }
    XCTAssertEqual(service.streamStartCount, 1)
  }

  private static func makeJPEGData(size: CGSize, color: UIColor) -> Data {
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
      color.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
    return image.jpegData(compressionQuality: 1.0) ?? Data()
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
    XCTFail("Timed out waiting for assistant state to settle.")
  }

  private static func retain(_ viewModel: AssistantViewModel) -> AssistantViewModel {
    self.retainedViewModels.append(viewModel)
    return viewModel
  }
}

private final class ControlledAssistantService: AssistantProviding, @unchecked Sendable {
  var onStreamStart: (() -> Void)?
  private(set) var capturedMessages: [ChatMessage]?
  private(set) var streamStartCount = 0
  private(set) var cancelCount = 0
  private var continuation: AsyncThrowingStream<String, Error>.Continuation?

  init(onStreamStart: (() -> Void)? = nil) {
    self.onStreamStart = onStreamStart
  }

  func streamResponse(for messages: [ChatMessage]) async throws -> AssistantResponseStream {
    self.streamStartCount += 1
    self.capturedMessages = messages
    self.onStreamStart?()
    let stream = AsyncThrowingStream<String, Error> { continuation in
      self.continuation = continuation
    }
    return AssistantResponseStream(
      stream: stream,
      cancelHandler: {
        self.cancelCount += 1
        self.continuation?.finish()
      })
  }

  func yield(_ chunk: String) {
    self.continuation?.yield(chunk)
  }

  func finish() {
    self.continuation?.finish()
  }
}
