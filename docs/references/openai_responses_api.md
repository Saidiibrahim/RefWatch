# OpenAI Responses API Integration

This document captures the RefWatch iOS migration from the legacy Chat Completions endpoint to the modern [OpenAI Responses API](https://platform.openai.com/docs/api-reference/responses/create). It is intended as a reference for future maintenance and for onboarding teammates who need to touch the assistant feature.

## Overview

- **Primary client**: `RefWatchiOS/Core/Platform/AI/OpenAIAssistantService.swift`
- **Protocol**: `AssistantProviding` (unchanged)
- **Target endpoint**: `POST https://api.openai.com/v1/responses`
- **Transport**: Server Sent Events (SSE) with `stream: true`
- **System instructions**: Sent via the top-level `instructions` key instead of the first chat message

The service keeps the public API identical (`AsyncStream<String>`) so the existing `AssistantViewModel` continues to consume streaming text with no changes.

## Request Construction

```jsonc
{
  "model": "gpt-4o-mini",
  "stream": true,
  "instructions": "You are RefWatch's helpful football referee assistant on iOS.",
  "input": [
    {
      "role": "user",
      "content": [
        { "type": "input_text", "text": "How do I signal offside?" }
      ]
    }
  ]
}
```

Implementation notes:

- The `input` array is built from `ChatMessage` instances; empty/whitespace-only messages are filtered.
- The system prompt now lives in `instructions`.
- Optional fields (`metadata`, `previous_response_id`, `max_output_tokens`) can be added easily inside `ResponsesPayload` if we need them later.

## Streaming Events

The Responses API emits richer SSE events than Chat Completions. The parser handles:

| Event | Action |
|-------|--------|
| `response.output_text.delta` | Append incremental text to the active assistant message |
| `response.output_text.done` | Marks the end of a single content part |
| `response.content_part.done` | Confirms the content array is finalized |
| `response.output_item.done` | Signals completion of a message item |
| `response.completed` / `response.done` | Terminates stream and captures usage |
| `response.failed` / `error` | Terminates stream and logs details in DEBUG builds |

Because these events arrive sequentially, the parser must flush buffered `data:` lines whenever a new `event:` header is observed. This was the root cause of the missing UI updates during testing.

## Logging & Diagnostics

For easier debugging in Xcode:

- `OpenAI[Responses] ...` log statements trace request preparation, SSE frames, and terminal events (only compiled in DEBUG).
- HTTP error status codes print the response body when available.
- Token usage metrics (`input`, `output`, `total`) are surfaced after the stream completes.

If the UI fails to update, confirm that `response.output_text.delta` messages are being logged. Missing deltas usually point to parsing issues or incorrect payloads.

## Testing

Unit coverage lives in `RefWatchiOSTests/OpenAIAssistantServiceTests.swift`:

- Payload generation trims whitespace and preserves roles.
- SSE parser tests validate delta accumulation, done events, and error paths.

When running `xcodebuild test`, ensure the simulator destination references an available iOS runtime (e.g. `iPhone 16`). The hosted environment may require adjusting destinations if bundled simulators differ.

## Troubleshooting Checklist

1. **No streaming text** → Verify SSE parser flush logic and watch for logged `response.output_text.delta` events.
2. **HTTP 401/403** → Confirm `Secrets.openAIKey` is populated; otherwise the feature falls back to the stub service.
3. **UI stuck on stub messaging** → Ensure `OpenAIAssistantService.fromBundleIfAvailable()` returns a non-nil service (valid key in bundle).
4. **Rate limits or server errors** → DEBUG logs include `error` payload contents for quick diagnosis.

## Future Enhancements

- Support `previous_response_id` to let OpenAI manage conversation state server-side.
- Surface token usage/stats to the UI or analytics pipeline.
- Introduce tool/function calling once the Responses API toolchain is finalized.
- Extend the parser for multimodal content (`output_image`, `output_audio`) as product needs expand.

_Last updated: 2025-10-10_
