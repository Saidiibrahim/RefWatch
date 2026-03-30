# PLAN_match-sheet-import

## Purpose / Big Picture
Ship a debug-only Xcode Canvas preview matrix for the iPhone match-sheet screenshot import flow. The work should let the team inspect upload, parse, review/apply, and saved-result states without live Supabase, Photos, or OpenAI dependencies while preserving the existing iPhone-only parser contract.

## Context and Orientation
- Product spec: `docs/product-specs/scheduled-match-sheets.md`
- iOS architecture: `docs/design-docs/architecture/ios.md`
- Shared services: `docs/design-docs/architecture/shared-services.md`
- OpenAI reference: `docs/references/openai_responses_api.md`
- Installation notes: `docs/references/getting-started/installation.md`
- Exec-plan index: `docs/exec-plans/index.md`

## Plan of Work
1. Preserve the existing docs/spec contract for the screenshot import flow and keep the active initiative open for code work.
2. Add preview-only auth and fixture support for a signed-in iPhone preview harness.
3. Add preview-only state seeding for upload, parse progress/error, import review, and post-apply/save states.
4. Prove the preview declarations compile on the primary iPhone simulator target and rerun the focused import regression slice.

## Concrete Steps
- (TASK_01_match-sheet-import.md) Update the docs set and active plan index in one batch.
- (TASK_02_match-sheet-import-preview-matrix.md) Add the iPhone preview harness, preview matrices, and validation evidence for the match-sheet import flow.

## Progress
- [x] TASK_01_match-sheet-import.md
- [x] TASK_02_match-sheet-import-preview-matrix.md

## Surprises & Discoveries
- The schedule model already has dedicated home and away match-sheet blobs, so the import flow can stay inside the existing schedule-owned JSON boundary.
- The assistant refresh work already introduced the image normalization pattern we want to reference in the docs, but the import flow should remain a separate contract.
- `UpcomingMatchEditorView` is auth-gated and only shows screenshot import on iPhone with a non-nil parser service, so Canvas coverage needs a preview-only signed-in harness rather than the existing generic preview.
- The most useful Canvas coverage is a state matrix across `MatchSheetImportPickerSheet`, `MatchSheetEditorView`, `UpcomingMatchEditorView`, and one saved-result `MatchesTabView` preview rather than a single monolithic preview.
- The local simulator set did not include `iPhone 15 Pro Max` on `OS=latest`, so the validation pass had to pin the installed `iPhone 15 Pro Max (iOS 17.0.1)` runtime instead.

## Decision Log
- Decision: Treat screenshot import as a transient parse-and-confirm workflow rather than a chat-style assistant conversation.
- Rationale: referees need a review step before the imported sheet replaces the selected side.
- Date/Author: 2026-03-27 / Codex
- Decision: keep all preview support debug-only and inject fake auth/parser state through typed preview helpers instead of reusing UI-test environment switches.
- Rationale: Canvas should render realistic states without changing runtime contracts or depending on external services.
- Date/Author: 2026-03-30 / Codex

## Testing Approach
- Verify preview declarations land in the intended files with `rg`.
- Build `RefWatchiOS` for the installed `iPhone 15 Pro Max (iOS 17.0.1)` simulator with an isolated DerivedData path and `CODE_SIGNING_ALLOWED=NO`.
- Run the focused import regression slice:
  - `RefWatchiOSTests/MatchSheetImportViewModelTests`
  - `RefWatchiOSTests/OpenAIMatchSheetImportServiceTests`
  - `RefWatchiOSUITests/MatchSheetImportUITests`
- Capture Canvas or equivalent visual proof for upload, parse failure/progress, import review, and saved-result preview groups, and record any missing visual proof as a gap.

## Constraints & Considerations
- Keep the work iPhone-only and preview-only.
- Do not reuse `TestEnvironment` or UI-test auth forcing as the preview mechanism.
- Imported preview sheets must remain `draft`, and raw screenshot bytes stay transient preview fixtures only.
- Do not change parser, persistence, or production auth behavior.

## Outcomes & Retrospective
- The active initiative now tracks both the earlier docs/spec work and the follow-on preview harness required to inspect the implemented iPhone flow in Xcode Canvas.
- Added debug-only preview auth, typed fixtures, and seeded state builders so Canvas can render upload, parse progress/error, review/apply, pre-save, and saved-result states without live services.
- Preview declarations compile successfully, and the focused import regression slice passed on `iPhone 15 Pro Max (iOS 17.0.1)`.
- Manual Canvas screenshot capture remains an explicit follow-up because this environment cannot render or export Xcode Canvas directly.
