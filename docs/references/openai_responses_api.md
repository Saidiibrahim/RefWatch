# OpenAI Responses API Integration

This document captures the RefWatch assistant path after the move to a server-backed multimodal Responses flow. The iOS app now sends draft turns to a Supabase Edge Function, and that function forwards the request to OpenAI's Responses API.

## Overview

- **Primary iOS client**: `RefWatchiOS/Core/Platform/AI/OpenAIAssistantService.swift`
- **Protocol**: `AssistantProviding`
- **Proxy transport**: authenticated Supabase Edge Function
- **Upstream endpoint**: `POST https://api.openai.com/v1/responses`
- **Transport**: Server-Sent Events with `stream: true`
- **Model tier**: `gpt-5.4-mini`
- **Conversation policy**: stateless replay in this wave, `store: false`

The app no longer stores or reads an OpenAI API key from the bundle. The assistant surface remains iOS-only.

## Request Construction

The edge function forwards multimodal turns using the Responses `input` array. Local Photos attachments are normalized to JPEG and encoded as a base64 data URL before the request is sent upstream.

```jsonc
{
  "model": "gpt-5.4-mini",
  "stream": true,
  "store": false,
  "instructions": "You are RefWatch's helpful football referee assistant on iOS.",
  "input": [
    {
      "role": "user",
      "content": [
        { "type": "input_text", "text": "How do I signal offside?" },
        { "type": "input_image", "image_url": "data:image/jpeg;base64,..." }
      ]
    }
  ]
}
```

Implementation notes:

- The `input` array is built from the current assistant history plus the in-flight user turn.
- Empty text is allowed when an image is attached; empty text with no image remains invalid.
- `previous_response_id` is intentionally deferred for this wave so the assistant remains stateless and easy to reason about.

## Streaming Events

The current Responses parser should handle the following events:

| Event | Action |
|-------|--------|
| `response.output_text.delta` | Append incremental text to the active assistant message |
| `response.output_text.done` | Mark the end of a text content part |
| `response.content_part.done` | Confirm the content array is finalized |
| `response.output_item.done` | Signal completion of a message item |
| `response.completed` | Terminate the stream cleanly |
| `response.failed` | Terminate the stream and surface the upstream failure |
| `error` | Terminate the stream and surface the transport failure |

Unknown non-text events should be ignored or logged rather than aborting the stream. That keeps the assistant resilient when OpenAI adds new event types.

## Logging & Diagnostics

For easier debugging in Xcode or proxy logs:

- Request-preparation logs should identify the selected model and whether an image was attached.
- SSE logs should show the upstream event type and terminal status.
- HTTP error status codes should capture the response body when available.
- Token usage metrics can still be surfaced after completion if the proxy chooses to forward them.

If the UI fails to update, confirm that `response.output_text.delta` messages are being observed by the proxy and forwarded to the app. Missing deltas usually point to payload construction or SSE parsing issues.

## Testing

Unit coverage should live in `RefWatchiOSTests/OpenAIAssistantServiceTests.swift` and related view-model tests:

- Payload generation trims whitespace and preserves roles.
- Multimodal encoding covers text-only, text-plus-image, and image-only turns.
- SSE parser tests validate delta accumulation, completion, failure, and unknown-event handling.

When running `xcodebuild test`, use an available iOS simulator runtime for the RefWatchiOS scheme. The exact simulator name may differ across machines.

## Troubleshooting Checklist

1. **No streaming text** → Verify the proxy forwards `response.output_text.delta` and that the parser flushes each SSE event frame.
2. **HTTP 401/403** → Confirm the Supabase JWT and server-side OpenAI secret are configured; the iOS bundle no longer carries an OpenAI key.
3. **UI stuck on stub messaging** → Ensure the server-backed assistant path is enabled and `StubAssistantService` is only being used as the fallback.
4. **Rate limits or server errors** → Surface the upstream `response.failed` payload in logs before changing the client-side parser.

## Future Enhancements

- Introduce `previous_response_id` only if the product needs server-managed conversation state.
- Surface token usage/stats to the UI or analytics pipeline.
- Add tool/function calling once the assistant contract stabilizes.
- Consider a Files API upload path only if image sizes or retention requirements outgrow the current data URL approach.

_Last updated: 2026-03-26_
