---
task_id: 03
plan_id: openai_responses_migration
plan_file: ../plans/PLAN_openai_responses_migration.md
title: Redesign SSE parser for Responses API events
phase: Phase 3 - SSE Parser Redesign
created: 2025-10-09
status: Completed
priority: High
estimated_minutes: 180
dependencies: [TASK_02_openai_responses_request_builder.md]
tags: [ios, streaming, networking, sse, parsing]
---

## Objective
Replace the Chat Completions SSE parsing logic with a new parser that handles Responses API events (`response.output_text.delta`, `response.done`, etc.) while maintaining the `AsyncStream<String>` output contract.

## Current SSE Parsing Logic
```swift
for try await line in bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let dataStr = String(line.dropFirst("data: ".count))
    if dataStr == "[DONE]" {
        break
    }
    if let chunkData = dataStr.data(using: .utf8) {
        if let text = Self.parseDelta(from: chunkData) {
            continuation.yield(text)
        }
    }
}
```

## New Responses API Event Structure

### Event Format
```
event: response.output_text.delta
data: {"event_id":"evt_123","type":"response.output_text.delta","delta":"Hello","item_id":"msg_007"}

event: response.done
data: {"type":"response.done","response":{...}}
```

### Key Events to Handle
1. **response.content_part.added**: Signals new content part starting
2. **response.output_text.delta**: Contains incremental text in `delta` field
3. **response.content_part.done**: Signals content part finished
4. **response.done**: Final event with full response object
5. **error**: Error event with error details

## Implementation Plan

### 1. Event Parser Structure
```swift
private struct SSEEvent {
    let type: String
    let data: [String: Any]
}

private static func parseSSELine(_ line: String, currentEvent: inout SSEEvent?) -> SSEEvent? {
    if line.hasPrefix("event: ") {
        let eventType = String(line.dropFirst("event: ".count))
        currentEvent = SSEEvent(type: eventType, data: [:])
        return nil
    } else if line.hasPrefix("data: ") {
        let dataStr = String(line.dropFirst("data: ".count))
        if let data = try? JSONSerialization.jsonObject(with: Data(dataStr.utf8)) as? [String: Any] {
            currentEvent?.data = data
            return currentEvent
        }
    } else if line.isEmpty {
        // Blank line signals end of event
        defer { currentEvent = nil }
        return currentEvent
    }
    return nil
}
```

### 2. Event Handler
```swift
private static func handleResponseEvent(_ event: SSEEvent, continuation: AsyncStream<String>.Continuation) {
    switch event.type {
    case "response.output_text.delta":
        if let delta = event.data["delta"] as? String {
            continuation.yield(delta)
        }
    case "response.done":
        // Stream is complete, no action needed (will break naturally)
        break
    case "error":
        // Log error in DEBUG mode
        #if DEBUG
        if let error = event.data["error"] as? [String: Any] {
            print("[OpenAI] Error: \(error)")
        }
        #endif
    default:
        // Unknown event, log in DEBUG mode
        #if DEBUG
        print("[OpenAI] Unknown event type: \(event.type)")
        #endif
    }
}
```

### 3. Updated Streaming Loop
```swift
return AsyncStream { continuation in
    Task {
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                continuation.finish()
                return
            }

            var currentEvent: SSEEvent? = nil

            for try await line in bytes.lines {
                if let event = Self.parseSSELine(line, currentEvent: &currentEvent) {
                    Self.handleResponseEvent(event, continuation: continuation)

                    // Check for stream termination
                    if event.type == "response.done" {
                        break
                    }
                }
            }
        } catch {
            #if DEBUG
            print("[OpenAI] Streaming error: \(error)")
            #endif
        }
        continuation.finish()
    }
}
```

### 4. Response Models (for type safety)
```swift
private struct ResponseOutputTextDelta: Decodable {
    let type: String
    let delta: String
    let item_id: String?
    let event_id: String?
}

private struct ResponseDone: Decodable {
    let type: String
    let response: ResponseObject?
}

private struct ResponseObject: Decodable {
    let id: String
    let status: String
    let usage: UsageStats?
}

private struct UsageStats: Decodable {
    let input_tokens: Int
    let output_tokens: Int
    let total_tokens: Int
}
```

## Edge Cases to Handle
1. **Malformed JSON**: Catch decode errors, log in DEBUG, continue stream
2. **Unknown event types**: Log and ignore (forward compatibility)
3. **Missing delta field**: Skip event silently
4. **Premature stream end**: Handle gracefully in catch block
5. **Multiple content parts**: Accumulate all deltas (current behavior)

## Testing Strategy
- **Mock SSE data**: Create test strings with sample events
- **Event parser tests**: Verify correct parsing of event/data pairs
- **Delta accumulation**: Ensure all delta chunks are yielded
- **Error handling**: Test malformed JSON, unknown events
- **Manual testing**: Real API calls with DEBUG logging

## Deliverables
1. New SSE parser supporting Responses API events
2. Event type routing logic
3. Maintained `AsyncStream<String>` output contract
4. DEBUG logging for diagnostics
5. Graceful handling of unknown events

## Acceptance Criteria
✅ Parses `event:` and `data:` lines correctly
✅ Yields delta text from `response.output_text.delta` events
✅ Terminates on `response.done` event
✅ Handles unknown events gracefully
✅ Logs errors/warnings in DEBUG mode only
✅ Output contract unchanged (`AsyncStream<String>`)
✅ Manual testing shows streaming text works

---

## Implementation Notes (2025-10-10)
- Introduced `ResponsesStreamParser` with explicit state for the current event, accumulated `data:` fragments, and captured usage statistics.
- Normalized SSE processing to support both continuation-based streaming and a closure-driven variant for unit testing.
- Routed `response.output_text.delta`, `response.done`, and `error` events through dedicated decoding structs; deltas append text, `response.done` stores usage, and `error` triggers DEBUG logging plus termination.
- Ignored unknown events while retaining DEBUG logging breadcrumbs so future event types can be diagnosed without crashing the stream.
- Added a DEBUG `Testing.parseStream` helper that reuses the production parser to feed synthetic SSE lines in tests.
