import XCTest
@testable import RefWatchiOS

final class OpenAIAssistantServiceTests: XCTestCase {
  func testBuildPayload_whenMessagesProvided_mapsToResponsesSchema() throws {
    let messages: [ChatMessage] = [
      ChatMessage(role: .user, text: "  Hello there "),
      ChatMessage(role: .assistant, text: "Hi ref!"),
      ChatMessage(role: .user, text: " "),
      ChatMessage(role: .user, text: "Need substitution guidance."),
    ]

    let payload = try OpenAIAssistantService.Testing.buildPayload(
      model: "gpt-4o-mini",
      systemPrompt: "System prompt",
      messages: messages)

    XCTAssertEqual(payload.instructions, "System prompt")
    XCTAssertEqual(payload.model, "gpt-4o-mini")
    XCTAssertTrue(payload.stream)
    XCTAssertEqual(payload.input.count, 3, "Whitespace-only messages should be filtered out")

    let first = try XCTUnwrap(payload.input.first)
    XCTAssertEqual(first.role, "user")
    XCTAssertEqual(first.content.first?.text, "Hello there")
    XCTAssertEqual(first.content.first?.type, "input_text")

    let encoded = try OpenAIAssistantService.Testing.encodePayload(payload)
    let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    let inputArray = json?["input"] as? [[String: Any]]
    let firstContent = inputArray?.first?["content"] as? [[String: Any]]
    XCTAssertEqual(firstContent?.first?["text"] as? String, "Hello there")
    XCTAssertEqual(firstContent?.first?["type"] as? String, "input_text")
  }

  func testBuildPayload_whenNoUsableMessages_throws() {
    let emptyMessages = [ChatMessage(role: .user, text: "   ")]
    XCTAssertThrowsError(
      try OpenAIAssistantService.Testing.buildPayload(
        model: "gpt-4o-mini",
        systemPrompt: "System prompt",
        messages: emptyMessages))
  }

  func testParseStream_whenReceivingDeltaEvents_emitsChunksAndUsage() {
    let donePayload =
      #"data: {"type":"response.done","response":{"id":"resp_123","status":"completed","# +
      #"usage":{"input_tokens":42,"output_tokens":7,"total_tokens":49}}}"#
    let lines = [
      "event: response.content_part.added",
      #"data: {"type":"response.content_part.added","content":{"type":"output_text","text":""}}"#,
      "",
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":"Hello"}"#,
      "",
      "event: response.output_text.delta",
      #"data: {"type":"response.output_text.delta","delta":" world"}"#,
      "",
      "event: response.done",
      donePayload,
      "",
    ]

    let result = OpenAIAssistantService.Testing.parseStream(lines: lines)

    XCTAssertEqual(result.chunks, ["Hello", " world"])
    XCTAssertTrue(result.shouldTerminate)
    XCTAssertEqual(result.usage?.inputTokens, 42)
    XCTAssertEqual(result.usage?.outputTokens, 7)
    XCTAssertEqual(result.usage?.totalTokens, 49)
  }

  func testParseStream_whenErrorEvent_occursStopsStreaming() {
    let lines = [
      "event: error",
      #"data: {"error":{"message":"Invalid authentication"} }"#,
      "",
    ]

    let result = OpenAIAssistantService.Testing.parseStream(lines: lines)

    XCTAssertTrue(result.shouldTerminate)
    XCTAssertTrue(result.chunks.isEmpty)
  }
}
