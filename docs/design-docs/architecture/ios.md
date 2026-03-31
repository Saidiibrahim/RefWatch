# iOS Architecture

## Entry Points
- `RefWatchiOSApp` bootstraps the iOS experience.
- `MainTabView` provides navigation across Matches, Live, Library, Trends, and Settings.
- `AppRouter` coordinates deep links and onboarding routes.

## Platform Core
- `DesignSystem/Theme` centralizes typography, colors, and reusable components.
- `Platform` adapters implement watch-shared protocols, e.g.:
  - `IOSHaptics` for tactile feedback.
  - `ConnectivityClient` (placeholder) for syncing with watch.
  - `SupabaseAuthController` for authentication flows.
  - `AssistantProviding` / `OpenAIAssistantService` for the server-backed multimodal assistant proxy.
  - `MatchSheetImportProviding` / `OpenAIMatchSheetImportService` for the iPhone-only screenshot-to-match-sheet import flow.

## Feature Modules
- `Matches`: watch match history, continue sessions, and manage saved data.
- `Live`: planned for real-time monitoring or scoreboard.
- `Library`: references to training material, rules, or external content.
- `Trends`: analytics and performance insights.
- `Assistant`: iOS-only multimodal chat, attachment drafting, and streamed AI responses.
- `Settings`: account management and device preferences.

## Scheduled Match Sheets
- iPhone owns creation and editing of scheduled match sheets for upcoming fixtures.
- `UpcomingMatchEditorView` is the scheduling surface that keeps home/away team names as free-text schedule data, offers optional saved-library Team Library autofill for the visible name only, and owns all per-side match-sheet actions.
- Saving the upcoming match is valid without any match sheets. Each side is prepared independently at the save boundary: complete sides persist as internal `ready`, incomplete or empty sides persist as internal `draft`.
- Newly saved schedules may still persist explicit home/away sheet shells internally so legacy no-sheet schedules remain distinguishable from schedules authored under the new model.
- Existing schedules need a dedicated pre-kickoff edit route back into `UpcomingMatchEditorView`; the schedule editor, not match setup, owns official match-sheet authoring.
- `MatchSheetEditorView` edits schedule-owned manual/ad hoc entries plus imported drafts. It preserves existing `sourceTeamId` / `sourceTeamName` already stored on a sheet, but it does not reseed or rewrite sheet provenance from local `TeamRecord` selection.
- Upcoming-match Team Library autofill does not reintroduce `TeamRecord` editor state. It uses already-saved library teams only, does not materialize reference teams for this flow, updates only `homeName` / `awayName`, and leaves existing stored `homeTeamId` / `awayTeamId` and imported `sourceTeamId` / `sourceTeamName` as preserved pass-through data on edit.
- iPhone keeps the internal `draft` / `ready` state out of the visible schedule-owned UI:
  - `UpcomingMatchEditorView` shows optional per-side count summaries only when a side has entries
  - each side exposes `Add Manually` or `Edit`, `Import Screenshots` or `Replace from Screenshots`, and `Remove Sheet` when that side has saved entries
  - `MatchSheetEditorView` shows participant sections plus import warnings/review state only; it does not surface `State`, `Mark Ready`, or `Mark Draft` controls
- Schedule persistence/sync owns the frozen sheet boundary:
  - local SwiftData schedule records store home/away sheet blobs
  - Supabase `scheduled_matches` rows store additive JSON sheet columns
  - aggregate snapshot export ships the frozen sheets to watch
- iPhone is responsible for freezing the scheduled sheets onto the live `Match` before kickoff so later library edits do not rewrite in-progress participant choices.
- This freeze guarantee applies when the schedule carries match-sheet data; legacy no-sheet schedules still rely on the older backward-compatible library lookup path on watch.
- When kickoff starts from a scheduled fixture, the live match must preserve the schedule's home/away team identity alongside the frozen match sheets; changing teams requires going back through the schedule editor first.
- Watch remains a consumer of the synced frozen schedule data; it does not author official match sheets.
- The assistant surface is not shared to watchOS; keep all assistant network and Photos attachment handling inside the iOS target.
- Screenshot import for upcoming matches is iPhone-only as well. `UpcomingMatchEditorView` owns the multi-image Photos picker, transient parse state, and final save boundary, while `MatchSheetEditorView` is reused as the review surface for imported drafts before they replace the selected side inside the parent editor state.
- The import flow should reuse the assistant's image-normalization approach, but it must not reuse the assistant chat history or streaming response contract.

## Shared Code Consumption
- Most domain models originate in watch feature modules and are shared via target membership.
- Services like `MatchHistoryService` are reused directly on iOS when platform adapters satisfy the dependencies.

## Testing Notes
- Unit tests should exercise shared services inside the iOS context where behavior diverges (e.g., networking).
- Snapshot/UI tests can validate tab navigation once the UI test target is configured.
