---
task_id: 05
plan_id: openai_responses_migration
plan_file: ../plans/PLAN_openai_responses_migration.md
title: Add unit tests and perform manual validation
phase: Phase 5 - Testing & Validation
created: 2025-10-09
status: Ready
priority: High
estimated_minutes: 150
dependencies: [TASK_04_openai_responses_result_handling.md]
tags: [testing, validation, unit-tests, integration-tests]
---

## Objective
Create comprehensive unit tests for the new Responses API implementation and perform manual integration testing to ensure no regressions.

## Unit Testing Strategy

### 1. Request Builder Tests
```swift
class OpenAIRequestBuilderTests: XCTestCase {
    func test_buildResponsesPayload_extractsSystemPrompt() {
        let messages: [ChatMessage] = [
            .init(role: .user, text: "Hello")
        ]
        let systemPrompt = "You are a helpful assistant."

        let payload = OpenAIAssistantService.buildResponsesPayload(
            model: "gpt-4o-mini",
            systemPrompt: systemPrompt,
            messages: messages
        )

        XCTAssertEqual(payload["instructions"] as? String, systemPrompt)
        XCTAssertEqual(payload["model"] as? String, "gpt-4o-mini")
        XCTAssertTrue(payload["stream"] as? Bool ?? false)
    }

    func test_buildInputArray_excludesSystemPrompt() {
        let messages: [ChatMessage] = [
            .init(role: .user, text: "Hello"),
            .init(role: .assistant, text: "Hi there!")
        ]

        let input = OpenAIAssistantService.buildInputArray(from: messages)

        XCTAssertEqual(input.count, 2)
        XCTAssertEqual(input[0]["role"], "user")
        XCTAssertEqual(input[0]["content"], "Hello")
        XCTAssertEqual(input[1]["role"], "assistant")
        XCTAssertEqual(input[1]["content"], "Hi there!")
    }
}
```

### 2. SSE Parser Tests
```swift
class SSEParserTests: XCTestCase {
    func test_parseSSELine_extractsEventAndData() {
        var currentEvent: OpenAIAssistantService.SSEEvent? = nil

        // Parse event line
        var result = OpenAIAssistantService.parseSSELine(
            "event: response.output_text.delta",
            currentEvent: &currentEvent
        )
        XCTAssertNil(result)
        XCTAssertEqual(currentEvent?.type, "response.output_text.delta")

        // Parse data line
        let jsonData = #"{"delta":"Hello","item_id":"msg_001"}"#
        result = OpenAIAssistantService.parseSSELine(
            "data: \(jsonData)",
            currentEvent: &currentEvent
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data["delta"] as? String, "Hello")

        // Parse blank line (completes event)
        result = OpenAIAssistantService.parseSSELine(
            "",
            currentEvent: &currentEvent
        )
        XCTAssertNil(currentEvent) // Should be reset
    }

    func test_handleResponseEvent_yieldsDeltas() {
        var yieldedText: [String] = []

        let stream = AsyncStream<String> { continuation in
            let event = OpenAIAssistantService.SSEEvent(
                type: "response.output_text.delta",
                data: ["delta": "Hello"]
            )
            OpenAIAssistantService.handleResponseEvent(
                event,
                continuation: continuation
            )
            continuation.finish()
        }

        Task {
            for await text in stream {
                yieldedText.append(text)
            }
        }

        // Wait for async completion
        XCTAssertEqual(yieldedText.first, "Hello")
    }
}
```

### 3. Mock URLSession Tests
```swift
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

class IntegrationTests: XCTestCase {
    func test_streamResponse_withMockSSE() async throws {
        // Set up mock response
        MockURLProtocol.requestHandler = { request in
            let sseData = """
            event: response.output_text.delta
            data: {"delta":"Hello"}

            event: response.output_text.delta
            data: {"delta":" world"}

            event: response.done
            data: {"type":"response.done"}

            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return (response, sseData)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        // Test implementation
        // ... (call service with mocked session)
    }
}
```

## Manual Testing Plan

### Test Case 1: Basic Streaming
1. Configure valid OpenAI API key in `Secrets.xcconfig`
2. Build and run iOS app in simulator
3. Navigate to assistant chat
4. Send message: "Hello"
5. Verify: Streaming response appears token-by-token
6. Verify: No crashes or errors

### Test Case 2: Multi-Turn Conversation
1. Send: "Hello"
2. Wait for response
3. Send: "Tell me a joke"
4. Wait for response
5. Verify: Both responses appear correctly
6. Verify: Context is maintained (if using `previous_response_id`)

### Test Case 3: Error Handling
1. Temporarily use invalid API key
2. Send message
3. Verify: Graceful error handling (no crash)
4. Check Xcode console for DEBUG error logs
5. Restore valid API key

### Test Case 4: Network Interruption
1. Start sending message
2. During streaming, toggle airplane mode
3. Verify: Stream terminates gracefully
4. Re-enable network
5. Send new message
6. Verify: Works normally

### Test Case 5: Stub Service (DEBUG without secrets)
1. Remove API key from `Secrets.xcconfig`
2. Build and run
3. Verify: `StubAssistantService` is used
4. Verify: Fake streaming text appears
5. Verify: No API calls made

## Performance Testing
- **Streaming latency**: Measure time to first token
- **Memory usage**: Monitor during long conversations
- **CPU usage**: Check for excessive parsing overhead
- **Network efficiency**: Compare payload sizes with old implementation

## Regression Checklist
✅ Streaming works as before
✅ UI updates smoothly
✅ No memory leaks
✅ DEBUG builds work without secrets
✅ Existing ViewModel code unchanged
✅ No new crashes introduced

## Deliverables
1. Unit test suite with >80% coverage
2. Mock URLSession integration tests
3. Manual test results documented
4. Performance metrics recorded
5. Regression testing passed

## Acceptance Criteria
✅ All unit tests pass
✅ Integration tests pass with mock data
✅ Manual testing shows no regressions
✅ Performance is comparable or better
✅ Stub service still works
✅ No crashes or errors in production scenarios

