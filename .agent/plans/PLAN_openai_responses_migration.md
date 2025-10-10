---
plan_id: openai_responses_migration
title: OpenAI Responses API Migration Plan
created: 2025-10-09
status: Ready
total_tasks: 6
completed_tasks: 0
estimated_hours: 8-10
priority: High
tags: [ios, ai, networking, streaming, responses-api]
---

## Objective
Migrate `RefZoneiOS/Core/Platform/AI/OpenAIAssistantService.swift` from the Chat Completions API (`/v1/chat/completions`) to the Responses API (`/v1/responses`) to leverage advanced features and align with modern OpenAI patterns.

## Current Implementation Analysis
- **Endpoint**: `POST https://api.openai.com/v1/chat/completions`
- **Request format**: `messages` array with `role`/`content` pairs
- **Streaming**: SSE with `data: ` prefix, parsing `choices[0].delta.content`
- **Termination**: `data: [DONE]` signal
- **System prompt**: Sent as first message with `role: "system"`

## Responses API Key Differences

### Request Structure
```json
{
  "model": "gpt-4o-mini",
  "input": [
    {"role": "user", "content": "Hello"}
  ],
  "instructions": "You are RefWatch's helpful football referee assistant on iOS.",
  "stream": true
}
```

**Changes from Chat Completions**:
1. `messages` → `input` (array of objects with `role`/`content`)
2. System prompt moves to `instructions` field (top-level)
3. `input` can be a simple string OR array of message objects
4. Supports `previous_response_id` for stateful conversations (optional)

### Response Structure (Non-Streaming)
```json
{
  "id": "resp_xxx",
  "object": "response",
  "status": "completed",
  "model": "gpt-4o-mini",
  "output": [
    {
      "type": "message",
      "role": "assistant",
      "content": [
        {"type": "output_text", "text": "Hello! How can I help?"}
      ]
    }
  ],
  "usage": {...}
}
```

### Streaming Events
The Responses API emits different SSE events:

| Event Type | Description | Action |
|------------|-------------|--------|
| `response.content_part.added` | New content part started | Initialize accumulator |
| `response.output_text.delta` | Incremental text | Append `delta` field to text |
| `response.content_part.done` | Content part finished | Finalize current part |
| `response.done` | Response complete | Extract usage, cleanup |
| `error` | Error occurred | Handle error |

**Event format**:
```
event: response.output_text.delta
data: {"event_id":"evt_123","type":"response.output_text.delta","delta":"Hello","item_id":"msg_007","output_index":0,"content_index":0}

event: response.done
data: {"type":"response.done","response":{...}}
```

## Migration Benefits
1. **Future-ready**: Positions codebase for advanced features (tools, multimodal, reasoning)
2. **Cleaner API**: Separates system instructions from conversation history
3. **Stateful conversations**: Optional `previous_response_id` for server-side context
4. **Richer metadata**: Better usage stats and response introspection

## Migration Strategy

### Phase 1: Data Model & Request Construction
- Map `ChatMessage` array to `input` array format
- Extract system prompt to `instructions` parameter
- Build new request payload structure
- Add configuration for optional parameters (`previous_response_id`, `metadata`)

### Phase 2: HTTP Client Update
- Update endpoint URL to `/v1/responses`
- Preserve headers (`Authorization`, `Content-Type`, `Accept: text/event-stream`)
- Ensure streaming parameter `"stream": true` is set
- Maintain non-streaming mode compatibility (future-proofing)

### Phase 3: SSE Parser Redesign
- Parse SSE events with `event:` and `data:` lines
- Implement event type routing:
  - `response.output_text.delta` → yield delta text
  - `response.done` → finalize stream
  - `error` → propagate error
- Handle unknown events gracefully (log in DEBUG mode)
- Maintain `AsyncStream<String>` output contract

### Phase 4: Error Handling & Edge Cases
- Parse and surface HTTP error responses
- Handle malformed SSE events
- Implement timeout handling
- Add DEBUG logging for diagnostics
- Extract and optionally expose usage statistics

### Phase 5: Testing & Validation
- Unit tests for request payload building
- Mock SSE event parsing tests
- Manual integration testing with real API key
- Verify stub service still works for DEBUG without secrets
- Performance comparison with old implementation

### Phase 6: Documentation & Cleanup
- Update inline code comments
- Document migration notes
- Add usage examples
- Remove deprecated Chat Completions code
- Update README if applicable

## Testing Approach
- **Unit tests**: Request builder, event parser with mock SSE data
- **Integration tests**: Mock `URLSession` with canned responses
- **Manual tests**: Real API calls in simulator with valid key
- **Regression tests**: Verify `AssistantViewModel` UI behavior unchanged

## Constraints & Considerations
- **Backward compatibility**: Keep `StubAssistantService` functional
- **Contract preservation**: `AssistantProviding` interface unchanged
- **Incremental adoption**: Client code (ViewModel) requires no changes
- **Error visibility**: Surface HTTP/SSE errors better than current implementation
- **DEBUG-only secrets**: Maintain existing `Secrets.xcconfig` pattern

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| SSE event schema changes | Centralize event parsing, log unknown types |
| Breaking UI contract | Extensive manual testing before release |
| Rate limit differences | Monitor and surface HTTP status codes |
| Documentation drift | Reference official OpenAI docs in code comments |

## Task Breakdown
1. **TASK_01**: Audit current implementation and define `input` mapping
2. **TASK_02**: Implement new request builder with `instructions` field
3. **TASK_03**: Redesign SSE parser for Responses API events
4. **TASK_04**: Enhance error handling and usage data extraction
5. **TASK_05**: Add unit tests and perform manual validation
6. **TASK_06**: Document migration and clean up old code

## Success Criteria
✅ Streaming chat works identically to current implementation
✅ All unit tests pass
✅ Manual testing shows no regressions
✅ Code is well-documented with OpenAI API references
✅ DEBUG builds without secrets still use stub service

## Future Enhancements (Post-Migration)
- Add `previous_response_id` support for stateful conversations
- Implement tool calling for referee-specific functions
- Add multimodal support (image analysis)
- Consider Supabase Edge Function implementation

## Documentation References
- **Responses API**: https://platform.openai.com/docs/api-reference/responses/create
- **Streaming Events**: https://platform.openai.com/docs/guides/streaming-responses
- **Input Format**: https://platform.openai.com/docs/api-reference/responses/input-items

