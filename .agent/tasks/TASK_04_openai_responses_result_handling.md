---
task_id: 04
plan_id: openai_responses_migration
plan_file: ../plans/PLAN_openai_responses_migration.md
title: Enhance error handling and usage data extraction
phase: Phase 4 - Error Handling & Edge Cases
created: 2025-10-09
status: Ready
priority: Medium
estimated_minutes: 90
dependencies: [TASK_03_openai_responses_streaming_pipeline.md]
tags: [ios, robustness, error-handling, logging]
---

## Objective
Improve error visibility and optionally expose usage statistics from the `response.done` event, while maintaining backward compatibility with the existing service interface.

## Current Error Handling Issues
- Silent failures on HTTP errors
- No visibility into malformed SSE events
- No access to token usage statistics
- Generic catch-all error handling

## Improvements to Implement

### 1. HTTP Error Surfacing
```swift
let (bytes, response) = try await URLSession.shared.bytes(for: req)
guard let http = response as? HTTPURLResponse else {
    #if DEBUG
    print("[OpenAI] Invalid response type")
    #endif
    continuation.finish()
    return
}

guard (200...299).contains(http.statusCode) else {
    #if DEBUG
    print("[OpenAI] HTTP error: \(http.statusCode)")
    // Optionally read error body
    #endif
    continuation.finish()
    return
}
```

### 2. SSE Event Error Handling
```swift
case "error":
    if let errorData = event.data["error"] as? [String: Any],
       let message = errorData["message"] as? String {
        #if DEBUG
        print("[OpenAI] API Error: \(message)")
        #endif
        // Could throw custom error to propagate upstream
    }
    continuation.finish()
```

### 3. Usage Statistics Extraction (Optional)
Add optional completion handler to capture usage data:

```swift
struct UsageInfo {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
}

// Option 1: Callback-based (doesn't change interface)
private var usageHandler: ((UsageInfo) -> Void)?

func streamResponse(
    for messages: [ChatMessage],
    usageHandler: ((UsageInfo) -> Void)? = nil
) -> AsyncStream<String> {
    self.usageHandler = usageHandler
    // ... rest of implementation
}

// In response.done handler:
case "response.done":
    if let responseObj = event.data["response"] as? [String: Any],
       let usage = responseObj["usage"] as? [String: Any],
       let input = usage["input_tokens"] as? Int,
       let output = usage["output_tokens"] as? Int,
       let total = usage["total_tokens"] as? Int {
        usageHandler?(UsageInfo(
            inputTokens: input,
            outputTokens: output,
            totalTokens: total
        ))
    }
```

### 4. Structured Error Types
```swift
enum OpenAIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String, code: String?)
    case streamingError(Error)
    case malformedEvent(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message, _):
            return "API error: \(message)"
        case .streamingError(let error):
            return "Streaming error: \(error.localizedDescription)"
        case .malformedEvent(let details):
            return "Malformed SSE event: \(details)"
        }
    }
}
```

### 5. DEBUG Logging Strategy
```swift
#if DEBUG
private static func logEvent(_ event: SSEEvent) {
    print("[OpenAI] Event: \(event.type)")
    if !event.data.isEmpty {
        print("[OpenAI] Data: \(event.data)")
    }
}

private static func logError(_ message: String, error: Error? = nil) {
    print("[OpenAI] Error: \(message)")
    if let error = error {
        print("[OpenAI] Details: \(error)")
    }
}
#endif
```

## Implementation Considerations

### Interface Stability
- Keep `streamResponse(for:)` signature unchanged for now
- Add optional `usageHandler` parameter with default `nil`
- Don't break existing callers

### Error Propagation
- Continue yielding text until error occurs
- Use `continuation.finish()` to end stream on error
- Log errors in DEBUG mode for diagnostics

### Performance
- Avoid excessive logging in production
- Only parse usage data if handler is provided
- Minimize allocations in hot path

## Testing Strategy
- **Error scenarios**: Test with invalid API key, rate limits, network errors
- **Malformed events**: Test with corrupted SSE data
- **Usage tracking**: Verify correct token counts
- **DEBUG logs**: Verify logs appear only in DEBUG builds

## Deliverables
1. Improved HTTP error handling
2. Structured error types
3. DEBUG logging infrastructure
4. Optional usage statistics extraction
5. Documentation of error cases

## Acceptance Criteria
✅ HTTP errors logged in DEBUG mode
✅ API errors from `error` events handled
✅ Malformed events don't crash the app
✅ Usage statistics optionally captured
✅ No logging in Release builds
✅ Existing interface unchanged
✅ Error scenarios tested

