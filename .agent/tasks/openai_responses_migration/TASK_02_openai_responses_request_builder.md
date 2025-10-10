---
task_id: 02
plan_id: openai_responses_migration
plan_file: ../plans/PLAN_openai_responses_migration.md
title: Implement new request builder with instructions field
phase: Phase 2 - HTTP Client Update
created: 2025-10-09
status: Completed
priority: High
estimated_minutes: 120
dependencies: [TASK_01_openai_responses_payload_audit.md]
tags: [ios, networking, implementation]
---

## Objective
Update `OpenAIAssistantService.swift` to construct Responses API requests and call the `/v1/responses` endpoint while maintaining the existing service interface.

## Implementation Tasks

### 1. Update Endpoint URL
```swift
// Old
let url = URL(string: "https://api.openai.com/v1/chat/completions")!

// New
let url = URL(string: "https://api.openai.com/v1/responses")!
```

### 2. Create Request Builder
Implement new payload construction following Task 01 mapping:

```swift
private static func buildResponsesPayload(
    model: String,
    systemPrompt: String,
    messages: [ChatMessage]
) -> [String: Any] {
    // Extract instructions (system prompt)
    // Build input array from messages
    // Return payload dict
    return [
        "model": model,
        "stream": true,
        "instructions": systemPrompt,
        "input": buildInputArray(from: messages)
    ]
}

private static func buildInputArray(from messages: [ChatMessage]) -> [[String: String]] {
    return messages.map { message in
        [
            "role": message.role == .user ? "user" : "assistant",
            "content": message.text
        ]
    }
}
```

### 3. Preserve Headers
Ensure all required headers are set:
```swift
req.setValue("application/json", forHTTPHeaderField: "Content-Type")
req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
```

### 4. Update streamResponse Method
Replace payload building logic:
```swift
func streamResponse(for messages: [ChatMessage]) -> AsyncStream<String> {
    let url = URL(string: "https://api.openai.com/v1/responses")!

    let payload = Self.buildResponsesPayload(
        model: model,
        systemPrompt: systemPrompt,
        messages: messages
    )

    let req = Self.makeRequest(url: url, apiKey: apiKey, json: payload)

    // ... rest of streaming logic (updated in Task 03)
}
```

### 5. Add Configuration Support
Prepare for future optional parameters (implement stubs):
```swift
struct ResponsesConfig {
    var previousResponseId: String?
    var metadata: [String: String]?
    var maxOutputTokens: Int?
}
```

## Testing Strategy
- **Compile check**: Ensure code builds without errors
- **Payload inspection**: Log generated JSON in DEBUG mode
- **Manual curl test**: Verify payload works with OpenAI API

## Code Quality Requirements
- Add inline comments explaining Responses API structure
- Reference OpenAI documentation URLs in comments
- Maintain existing code style and patterns
- Keep DEBUG-only secret loading pattern

## Deliverables
1. Updated `OpenAIAssistantService.swift` with new request builder
2. Endpoint URL changed to `/v1/responses`
3. Payload structure matches Responses API format
4. Code compiles cleanly
5. Inline documentation added

## Acceptance Criteria
✅ Endpoint URL points to `/v1/responses`
✅ Payload includes `instructions` field
✅ Payload includes `input` array (not `messages`)
✅ System prompt extracted correctly
✅ Headers preserved from old implementation
✅ Code compiles without warnings
✅ DEBUG logging shows correct JSON payload

---

## Implementation Notes (2025-10-10)
- Swapped the endpoint to `https://api.openai.com/v1/responses` with an explicit 60s timeout and preserved streaming headers.
- Added `ResponsesPayload`/`InputMessage`/`InputContent` encodable types to serialize the `instructions` plus trimmed chat history into the Responses API schema.
- Replaced the JSON dictionary builder with `makeRequest(apiKey:payload:)`, which encodes the payload via a dedicated `JSONEncoder` and keeps the service interface unchanged.
- Added DEBUG-only `OpenAIAssistantService.Testing` helpers so unit tests can exercise the builder without exposing the helpers to production callers.
- Inlined documentation links (create, streaming, input items) above the streaming pipeline to keep engineers anchored to the latest OpenAI docs.
