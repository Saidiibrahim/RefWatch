# Assistant Integration

Learn how the Assistant tab wires AI-powered responses into the RefZone experience.

## Components
- ``AssistantTabView``: Entry point that renders the conversational UI.
- ``OpenAIAssistantService``: Handles prompt submission and streaming responses.
- ``SupabaseAuthController``: Manages authentication, ensuring only authorized users access AI features.

## Flow
1. The view model composes a prompt and sends it through ``OpenAIAssistantService``.
2. Responses stream back asynchronously and update the assistant feed.
3. Persistent storage can record transcripts following the conventions in `docs/openai_responses_api.md`.

## Extending the Assistant
- Provide additional prompt builders or quick actions in the view model.
- Implement caching layers using shared services to sync across watch and iOS.
- For offline fallback, inject a mock implementation conforming to ``AIResponseProviding``.

## Related Resources
- <doc:MatchTimerArchitecture> for core match flows that the assistant references.
- `docs/features/assistant.md` for high-level UX guidance.
