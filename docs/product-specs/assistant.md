# Assistant Feature Guide

## Overview
The Assistant tab is RefWatch's iOS-only multimodal assistant. Users can send text, attach one Photos-library image per turn, and receive streamed answers through a Supabase Edge Function proxy that forwards to OpenAI's Responses API.

## Key Components
- `AssistantTabView`: SwiftUI entry point for chat, attachment picker, and send controls.
- `OpenAIAssistantService`: iOS transport adapter that streams assistant responses through the server proxy.
- `AssistantProviding`: protocol boundary used by the view model.
- `SupabaseAuthController`: authenticates the user before AI usage.
- `ChatMessage`: multimodal message model that supports text plus one optional image attachment on user turns.

## Data Flow
1. User drafts a text prompt and optionally attaches one image from Photos.
2. The view model packages the current turn and sends it through `AssistantProviding` to the Supabase Edge Function.
3. The edge function authenticates the request, applies the repo-selected `gpt-5.4-mini` model, sets `store: false`, and forwards the multimodal payload to OpenAI's Responses API.
4. Responses stream back as SSE text deltas and terminal events; the app updates the feed as chunks arrive.
5. The assistant conversation remains ephemeral/local in this wave. No app-bundle OpenAI key is used and no new transcript persistence is introduced.

## Extension Points
- Add more prompt templates or quick actions in the view model.
- Add alternate attachment sources or more than one image only after product approval.
- Introduce persistence only if future product decisions require it.
- Keep watchOS documentation honest: there is no live assistant runtime on watch today.

## Testing
- Extend service tests for multimodal payload encoding, streaming event handling, and failure cases.
- Add view-model tests for attachment lifecycle and send enablement.
- Add UI tests for Photos picker attach/remove/send flows.
- Validate on iPhone 15 Pro Max with a real photo-library image before release.
