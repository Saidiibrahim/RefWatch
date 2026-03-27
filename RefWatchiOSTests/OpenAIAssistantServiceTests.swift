import XCTest
@testable import RefWatchiOS

final class OpenAIAssistantServiceTests: XCTestCase {
  func testBuildPayload_whenMessagesProvided_mapsToProxySchema() throws {
    let attachment = AssistantImageAttachment(
      filename: "frame.jpg",
      jpegData: Data([0x01, 0x02, 0x03]),
      detail: .auto,
      pixelWidth: 120,
      pixelHeight: 80)
    let messages: [ChatMessage] = [
      ChatMessage(role: .user, text: "  Hello there ", imageAttachment: attachment),
      ChatMessage(role: .assistant, text: "Hi ref!"),
      ChatMessage(role: .user, text: " "),
      ChatMessage(role: .user, text: "Need substitution guidance."),
    ]

    let payload = try OpenAIAssistantService.Testing.buildPayload(
      systemPrompt: "System prompt",
      messages: messages)

    XCTAssertEqual(payload.instructions, "System prompt")
    XCTAssertEqual(payload.messages.count, 3, "Whitespace-only messages should be filtered out")

    let first = try XCTUnwrap(payload.messages.first)
    XCTAssertEqual(first.role, "user")
    XCTAssertEqual(first.content.map(\.type), ["input_text", "input_image"])
    XCTAssertEqual(first.content.first?.text, "Hello there")
    XCTAssertEqual(first.content.last?.detail, "auto")

    let second = try XCTUnwrap(payload.messages.dropFirst().first)
    XCTAssertEqual(second.role, "assistant")
    XCTAssertEqual(second.content.first?.type, "output_text")
    XCTAssertEqual(second.content.first?.text, "Hi ref!")

    let encoded = try OpenAIAssistantService.Testing.encodePayload(payload)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertEqual(json["instructions"] as? String, "System prompt")
    let messagesArray = try XCTUnwrap(json["messages"] as? [[String: Any]])
    let firstContent = try XCTUnwrap(messagesArray.first?["content"] as? [[String: Any]])
    XCTAssertEqual(firstContent.first?["text"] as? String, "Hello there")
    XCTAssertEqual(firstContent.first?["type"] as? String, "input_text")
    XCTAssertNotNil(firstContent.last?["image_url"] as? String)
  }

  func testBuildPayload_whenImageOnlyMessageProvided_keepsUsableMessage() throws {
    let attachment = AssistantImageAttachment(
      filename: "frame.jpg",
      jpegData: Data([0xFF, 0xD8, 0xFF]),
      detail: .auto,
      pixelWidth: 60,
      pixelHeight: 60)
    let payload = try OpenAIAssistantService.Testing.buildPayload(
      systemPrompt: "System prompt",
      messages: [ChatMessage(role: .user, text: " ", imageAttachment: attachment)])

    XCTAssertEqual(payload.messages.count, 1)
    XCTAssertEqual(payload.messages.first?.role, "user")
    XCTAssertEqual(payload.messages.first?.content.map(\.type), ["input_image"])
  }

  func testBuildPayload_whenNoUsableMessages_throws() {
    let emptyMessages = [ChatMessage(role: .user, text: "   ")]
    XCTAssertThrowsError(
      try OpenAIAssistantService.Testing.buildPayload(
        systemPrompt: "System prompt",
        messages: emptyMessages)) { error in
          XCTAssertEqual(error as? AssistantServiceError, .emptyConversation)
        }
  }

  func testParseStream_whenReceivingCompletedEvent_emitsChunksAndUsage() {
    let completedPayload = #"data: {"type":"response.completed","response":{"id":"resp_456","status":"completed","usage":{"input_tokens":11,"output_tokens":5,"total_tokens":16}}}"#
    let lines = [
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":"Hello"}"#,
      "",
      "event: response.output_item.added",
      #"data: {"type":"response.output_item.added","item":{"type":"output_text"}}"#,
      "",
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":" world"}"#,
      "",
      "event: response.completed",
      completedPayload,
      "",
    ]

    let result = OpenAIAssistantService.Testing.parseStream(lines: lines)

    XCTAssertEqual(result.chunks, ["Hello", " world"])
    XCTAssertTrue(result.shouldTerminate)
    XCTAssertEqual(result.usage?.inputTokens, 11)
    XCTAssertEqual(result.usage?.outputTokens, 5)
    XCTAssertEqual(result.usage?.totalTokens, 16)
    XCTAssertNil(result.terminalError)
  }

  func testParseStream_whenReceivingFailedEvent_stopsStreamingAndCapturesTerminalError() {
    let lines = [
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":"Partial answer"}"#,
      "",
      "event: response.failed",
      #"data: {"error":{"message":"Model rejected the prompt","code":"bad_request","type":"invalid_request_error"}}"#,
      "",
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":"ignored"}"#,
      "",
    ]

    let result = OpenAIAssistantService.Testing.parseStream(lines: lines)

    XCTAssertEqual(result.chunks, ["Partial answer"])
    XCTAssertTrue(result.shouldTerminate)
    XCTAssertNil(result.usage)
    XCTAssertEqual(result.terminalError, .streamFailed(message: "Model rejected the prompt"))
  }

  func testParseStream_whenUnknownEventAppears_ignoresItAndContinuesParsing() {
    let lines = [
      "event: response.output_item.added",
      #"data: {"type":"response.output_item.added","item":{"type":"output_text","text":""}}"#,
      "",
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":"Hello"}"#,
      "",
      "event: response.completed",
      #"data: {"type":"response.completed","response":{"id":"resp_789","status":"completed","usage":{"input_tokens":9,"output_tokens":1,"total_tokens":10}}}"#,
      "",
    ]

    let result = OpenAIAssistantService.Testing.parseStream(lines: lines)

    XCTAssertEqual(result.chunks, ["Hello"])
    XCTAssertTrue(result.shouldTerminate)
    XCTAssertEqual(result.usage?.totalTokens, 10)
    XCTAssertNil(result.terminalError)
  }

  func testParseStream_whenErrorEventOccurs_stopsStreamingWithTerminalError() {
    let lines = [
      "event: error",
      #"data: {"error":{"message":"Invalid authentication"} }"#,
      "",
    ]

    let result = OpenAIAssistantService.Testing.parseStream(lines: lines)

    XCTAssertTrue(result.shouldTerminate)
    XCTAssertTrue(result.chunks.isEmpty)
    XCTAssertEqual(result.terminalError, .streamFailed(message: "Invalid authentication"))
  }

  func testParseStream_whenIncompleteEventOccurs_stopsStreamingWithTerminalError() {
    let lines = [
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":"Partial answer"}"#,
      "",
      "event: response.incomplete",
      #"data: {"type":"response.incomplete","response":{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"}}}"#,
      "",
    ]

    let result = OpenAIAssistantService.Testing.parseStream(lines: lines)

    XCTAssertEqual(result.chunks, ["Partial answer"])
    XCTAssertTrue(result.shouldTerminate)
    XCTAssertEqual(result.terminalError, .streamFailed(message: "The assistant stopped before finishing the answer."))
  }

  func testDecodeStreamLines_whenUTF8ScalarSpansChunks_preservesDecodedText() throws {
    let firstChunk = Data("data: {\"delta\":\"caf".utf8) + Data([0xC3])
    let secondChunk = Data([0xA9]) + Data("\"}\n\n".utf8)

    XCTAssertEqual(
      try OpenAIAssistantService.Testing.decodeStreamLines(chunks: [firstChunk, secondChunk]),
      ["data: {\"delta\":\"café\"}", ""]
    )
  }

  func testDecodeStreamLines_whenStreamEndsWithoutTrailingNewline_returnsRemainingLine() throws {
    XCTAssertEqual(
      try OpenAIAssistantService.Testing.decodeStreamLines(chunks: [
        Data("event: response.completed\n".utf8),
        Data("data: {\"type\":\"response.completed\"}".utf8),
      ]),
      ["event: response.completed", #"data: {"type":"response.completed"}"#]
    )
  }

  func testDecodeStreamLines_whenUTF8IsInvalid_throwsInvalidResponse() {
    XCTAssertThrowsError(
      try OpenAIAssistantService.Testing.decodeStreamLines(chunks: [
        Data([0xC3, 0x28, 0x0A]),
      ])
    ) { error in
      XCTAssertEqual(error as? AssistantServiceError, .invalidResponse)
    }
  }
}
