---
task_id: 01
plan_id: openai_responses_migration
plan_file: ../plans/PLAN_openai_responses_migration.md
title: Audit current implementation and define input mapping
phase: Phase 1 - Data Model & Request Construction
created: 2025-10-09
status: Completed
priority: High
estimated_minutes: 90
dependencies: []
tags: [api, design, documentation, audit]
---

## Objective
Analyze the current `OpenAIAssistantService.swift` implementation and define the exact mapping from Chat Completions format to Responses API format.

## Current Implementation Details

### Request Payload (Chat Completions)
```swift
[
  "model": "gpt-4o-mini",
  "stream": true,
  "messages": [
    {"role": "system", "content": "You are RefWatch's helpful..."},
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi there!"},
    {"role": "user", "content": "How are you?"}
  ]
]
```

### Target Payload (Responses API)
```swift
[
  "model": "gpt-4o-mini",
  "stream": true,
  "instructions": "You are RefWatch's helpful...",
  "input": [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi there!"},
    {"role": "user", "content": "How are you?"}
  ]
]
```

## Key Mapping Rules

### 1. System Prompt Extraction
- **Current**: First message with `role: "system"`
- **Target**: Top-level `instructions` field
- **Implementation**: Extract system prompt before building `input` array

### 2. Message Array Transformation
- **Current**: `messages` array includes system message
- **Target**: `input` array excludes system message (moved to `instructions`)
- **Roles**: Keep `user` and `assistant` roles unchanged

### 3. Optional Parameters
Document these for future use (not implemented in Phase 1):
- `previous_response_id`: For stateful conversations
- `metadata`: For request tracking
- `max_output_tokens`: Token limit control
- `temperature`, `top_p`: Sampling parameters (currently defaults)

## Validation Rules
- System prompt must not be empty
- Input array must have at least one message after system extraction
- All messages must have valid `role` (`user` or `assistant`)
- All messages must have non-empty `content`

## Deliverables
1. **Design document** (inline or in this file) with:
   - Exact transformation algorithm
   - Edge case handling (empty history, missing system prompt)
   - Validation rules
2. **Code comments** outlining the mapping for Task 02 implementation
3. **Examples** of valid request payloads for testing

## Edge Cases to Consider
- **Empty chat history**: Only system prompt, no user messages yet
- **Missing system prompt**: Use default or return error?
- **Mixed role order**: Validate alternating user/assistant pattern?
- **Long messages**: Handle truncation strategy

## Acceptance Criteria
✅ Clear mapping rules documented
✅ Edge cases identified and resolution defined
✅ Validation rules specified
✅ Examples created for common scenarios

---

## Mapping Design Notes (2025-10-09)

### Transformation Algorithm
1. Partition the incoming `ChatMessage` array into `system`, `user`, and `assistant` roles.
2. Extract the most recent `.system` entry (if one exists) to use as the `instructions` string; otherwise fall back to the service's default prompt.
3. Build the `input` array by iterating the remaining messages in chronological order and mapping each to a dictionary with unchanged `role` (`user` or `assistant`) and `content` text.
4. Assemble the final payload dictionary with at minimum `model`, `stream`, `instructions`, and `input`. Optional knobs (`temperature`, `top_p`, `metadata`, `max_output_tokens`, `previous_response_id`) remain unset for now but are reserved keys in the builder.

### Validation Rules
- Ensure there is a non-empty `instructions` string after extraction; if missing, use the service default to maintain backwards compatibility.
- Confirm the `input` array is non-empty before issuing a network request; if empty, short-circuit with an error so the UI can surface a helpful message.
- Reject any message whose role is not `.user` or `.assistant`; log in DEBUG builds and drop the entry to avoid malformed payloads.
- Trim whitespace-only `content` values and verify non-empty; if trimming results in empty text, skip the message but keep processing the remaining history.

### Edge Case Handling
- **Empty chat history**: With no prior user messages, skip the network call and instruct the caller to supply at least one user turn; this mirrors current UX that requires input before streaming.
- **Missing system prompt**: When no explicit `.system` message is present, rely on the `systemPrompt` stored on `OpenAIAssistantService` so brand voice remains consistent.
- **Mixed role order**: Preserve existing chronology even if user/assistant turns do not alternate perfectly; the Responses API accepts repeated roles as long as they are valid strings.
- **Legacy data**: If legacy messages include carriage returns or control characters, sanitize by normalizing to standard whitespace so JSON encoding succeeds.

### Example Payloads
```json
{
  "model": "gpt-4o-mini",
  "stream": true,
  "instructions": "You are RefWatch's helpful football referee assistant on iOS.",
  "input": [
    {"role": "user", "content": "Hello!"},
    {"role": "assistant", "content": "Hi ref, ready to manage today's match?"},
    {"role": "user", "content": "What is the correct hand signal for a corner kick?"}
  ]
}
```

```json
{
  "model": "gpt-4o-mini",
  "stream": true,
  "instructions": "You are RefWatch's helpful football referee assistant on iOS.",
  "input": [
    {"role": "user", "content": "Provide a pre-match checklist for assistant referees."}
  ],
  "metadata": {
    "feature": "assistant-tab",
    "platform": "ios"
  }
}
```

### Implementation Notes
- Add a focused helper (`buildInputArray`) that returns a `[ResponsesMessage]` model rather than raw dictionaries so unit tests can assert on strong types before JSON encoding.
- Centralize validation failures into a lightweight `enum PayloadError: Error` to keep the service's public API stable while allowing detailed logging in DEBUG builds.
- Keep serialization via `JSONEncoder` with `.withoutEscapingSlashes` to match OpenAI examples once the type layer is in place.
