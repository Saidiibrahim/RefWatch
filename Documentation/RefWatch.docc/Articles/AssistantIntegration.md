# Assistant Integration

Learn how the iOS Assistant tab wires multimodal, server-backed AI responses into the RefWatch experience.

## Components
- ``AssistantTabView``: Entry point that renders the conversational UI and Photos attachment flow.
- ``OpenAIAssistantService``: Handles prompt submission and streaming responses through the server proxy.
- ``AssistantProviding``: Protocol boundary for the assistant transport.
- ``SupabaseAuthController``: Manages authentication, ensuring only authorized users access AI features.
- ``ChatMessage``: Multimodal message model for text plus one optional image attachment on user turns.

## Flow
1. The view model composes a prompt and optional image attachment and sends it through ``AssistantProviding``.
2. The Supabase Edge Function authenticates the request, forwards the multimodal payload to OpenAI Responses, and streams the response back.
3. The assistant feed updates as text deltas arrive; this wave does not add new transcript persistence.

## Extending the Assistant
- Provide additional prompt builders or quick actions in the view model.
- Add more attachment sources or additional multimodal inputs only after the product contract changes.
- Keep watchOS references honest: the assistant runtime is iOS-only in this repository.
- For offline fallback, inject a mock implementation conforming to ``AssistantProviding`` or use ``StubAssistantService``.

## Related Resources
- <doc:MatchTimerArchitecture> for core match flows that the assistant references.
- `docs/product-specs/assistant.md` for high-level UX guidance.
