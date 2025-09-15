# AGENTS.md

## Scope
AI assistant integration for iOS. Applies to `RefZoneiOS/Core/Platform/AI/`.

## Conventions
- All network/API access is adapter‑based (`AssistantService`, `OpenAIAssistantService`) behind protocols for easy testing.
- Do not commit secrets. Load keys/config via `.xcconfig` (see `RefZoneiOS/Config/`) and a local `Secrets.swift` used only by this module.
- Provide a safe no‑op or stub implementation when credentials are absent to keep the app running.

## Testing
- Use stubbed services with deterministic responses. Avoid live network calls in tests.
- Support timeouts and cancellation; surface errors explicitly to callers.

