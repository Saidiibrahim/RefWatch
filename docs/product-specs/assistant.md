# Assistant Feature Guide

## Overview
The Assistant tab integrates AI-powered workflows to support referees with quick insights, rules lookup, and match preparation tips.

## Key Components
- `AssistantTabView`: SwiftUI entry for the tab.
- `OpenAIAssistantService`: wraps AI requests and response streaming.
- `SupabaseAuthController`: authenticates and authorizes AI usage.

## Data Flow
1. User prompts originate from Assistant views.
2. ViewModel calls `OpenAIAssistantService` for responses.
3. Responses persist via `openai_responses_api.md` guidelines (see [docs/references/openai_responses_api.md](../references/openai_responses_api.md)).
4. Display updates in the Assistant feed, optionally syncing to history.

## Extension Points
- Add new prompt templates in the ViewModel.
- Expand AI response storage by implementing additional persistence in shared services.
- Consider rate limiting or offline fallbacks if connectivity fails.

## Testing
- Provide mocks for AI services to exercise ViewModel logic without network calls.
- Validate UI states (loading, error, success) with unit or UI tests.
