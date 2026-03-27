# PLAN_match-sheet-import

## Purpose / Big Picture
Document the iPhone-only screenshot import flow for upcoming match sheets. The docs should clearly state that this is a separate parser from assistant chat, that it produces a transient review draft, and that only the normalized schedule-owned sheet is persisted after referee confirmation.

## Context and Orientation
- Product spec: `docs/product-specs/scheduled-match-sheets.md`
- iOS architecture: `docs/design-docs/architecture/ios.md`
- Shared services: `docs/design-docs/architecture/shared-services.md`
- OpenAI reference: `docs/references/openai_responses_api.md`
- Installation notes: `docs/references/getting-started/installation.md`
- Exec-plan index: `docs/exec-plans/index.md`

## Plan of Work
1. Update the scheduled match-sheet product spec to include the screenshot import workflow and review/apply rules.
2. Update iOS and shared-service architecture docs so the import boundary stays iPhone-only and separate from assistant chat.
3. Update OpenAI and installation docs with the separate parser contract and deployment notes.
4. Register the active initiative in the exec-plan index and keep the task file alongside the plan.

## Concrete Steps
- (TASK_01_match-sheet-import.md) Update the docs set and active plan index in one batch.

## Progress
- [x] TASK_01_match-sheet-import.md

## Surprises & Discoveries
- The schedule model already has dedicated home and away match-sheet blobs, so the import flow can stay inside the existing schedule-owned JSON boundary.
- The assistant refresh work already introduced the image normalization pattern we want to reference in the docs, but the import flow should remain a separate contract.

## Decision Log
- Decision: Treat screenshot import as a transient parse-and-confirm workflow rather than a chat-style assistant conversation.
- Rationale: referees need a review step before the imported sheet replaces the selected side.
- Date/Author: 2026-03-27 / Codex

## Testing Approach
- Verify the doc references, plan path, and new active entry with `rg`.
- Confirm the install and OpenAI docs mention the separate parser deployment path without implying a database migration.

## Constraints & Considerations
- Do not add code or test changes in this batch.
- Keep the documentation aligned with the approved plan: separate parser, transient drafts, and no schema migration for MVP.

## Outcomes & Retrospective
- The docs now describe the upcoming-match screenshot import flow, its iPhone-only boundary, the separate parser contract, and the deployment reference for the new edge function.
