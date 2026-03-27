# PLAN_assistant-multimodal-refresh

## Purpose / Big Picture
Align the RefWatch assistant documentation and config with the new server-backed multimodal iOS assistant. The resulting docs should clearly state that the assistant is iOS-only, supports one Photos-library image per turn, uses a Supabase Edge Function proxy, and no longer exposes an OpenAI key in the app bundle.

## Context and Orientation
- Assistant product spec: `docs/product-specs/assistant.md`
- OpenAI reference note: `docs/references/openai_responses_api.md`
- DocC assistant article: `Documentation/RefWatch.docc/Articles/AssistantIntegration.md`
- Architecture docs: `docs/design-docs/architecture/overview.md`, `docs/design-docs/architecture/ios.md`, `docs/design-docs/architecture/shared-services.md`, `docs/design-docs/architecture/watchos.md`
- Testing/release docs: `docs/references/testing/strategy.md`, `docs/references/process/release-checklist.md`
- Config cleanup: `RefWatchiOS/Info.plist`, `RefWatch.xcodeproj/project.pbxproj`, `RefWatchiOS/Config/Secrets.xcconfig`

## Plan of Work
1. Rewrite the assistant product and DocC/reference docs to describe the server-backed multimodal flow.
2. Scrub shared/watch architecture docs so they do not imply a live watch assistant runtime.
3. Remove `OPENAI_API_KEY` from the app bundle/config exposure path and align the iOS/watch instruction docs with that change.
4. Update testing/release guidance and the exec-plan index so the new assistant contract is discoverable.

## Concrete Steps
- (TASK_01_assistant-multimodal-refresh.md) Update docs, config cleanup, and plan/index entries in one batch.

## Progress
- [x] TASK_01_assistant-multimodal-refresh.md

## Surprises & Discoveries
- The watchOS architecture/docs already had no live assistant runtime, but some shared-service wording still implied a generic AI protocol that could be reused there.
- The only tracked OpenAI exposure in the app bundle was the iOS `Info.plist`/pbxproj build setting path plus the local secrets template.

## Decision Log
- Decision: Treat the assistant as an iOS-only, server-backed feature.
- Rationale: The app should never ship an OpenAI key in the bundle, and the watch target does not host a live assistant runtime.
- Date/Author: 2026-03-26 / Codex

## Testing Approach
- Verify docs consistency with `rg` over `assistant`, `OpenAI`, `AIResponseProviding`, and `OPENAI_API_KEY`.
- Confirm the iOS project settings no longer inject `OPENAI_API_KEY` into the app bundle.

## Constraints & Considerations
- Do not edit iOS assistant production Swift files or tests in this batch.
- Keep watch docs honest: no language should imply the watch target owns assistant transport or OpenAI credentials.

## Outcomes & Retrospective
- _Pending_
