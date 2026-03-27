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

## Feature Modules
- `Matches`: watch match history, continue sessions, and manage saved data.
- `Live`: planned for real-time monitoring or scoreboard.
- `Library`: references to training material, rules, or external content.
- `Trends`: analytics and performance insights.
- `Assistant`: iOS-only multimodal chat, attachment drafting, and streamed AI responses.
- `Settings`: account management and device preferences.

## Scheduled Match Sheets
- iPhone owns creation and editing of scheduled match sheets for upcoming fixtures.
- `UpcomingMatchEditorView` is the scheduling surface that chooses source teams, persists explicit draft home/away sheet shells, and owns the explicit create/add/edit actions that seed or mutate schedule-owned snapshots from the library.
- Newly saved schedules persist explicit draft home/away sheet shells so legacy no-sheet schedules remain distinguishable from schedules authored under the new model.
- Existing schedules need a dedicated pre-kickoff edit route back into `UpcomingMatchEditorView`; the schedule editor, not match setup, owns official match-sheet authoring.
- Schedule persistence/sync owns the frozen sheet boundary:
  - local SwiftData schedule records store home/away sheet blobs
  - Supabase `scheduled_matches` rows store additive JSON sheet columns
  - aggregate snapshot export ships the frozen sheets to watch
- iPhone is responsible for freezing the scheduled sheets onto the live `Match` before kickoff so later library edits do not rewrite in-progress participant choices.
- This freeze guarantee applies when the schedule carries match-sheet data; legacy no-sheet schedules still rely on the older backward-compatible library lookup path on watch.
- When kickoff starts from a scheduled fixture, the live match must preserve the schedule's home/away team identity alongside the frozen match sheets; changing teams requires going back through the schedule editor first.
- Watch remains a consumer of the synced frozen schedule data; it does not author official match sheets.
- The assistant surface is not shared to watchOS; keep all assistant network and Photos attachment handling inside the iOS target.

## Shared Code Consumption
- Most domain models originate in watch feature modules and are shared via target membership.
- Services like `MatchHistoryService` are reused directly on iOS when platform adapters satisfy the dependencies.

## Testing Notes
- Unit tests should exercise shared services inside the iOS context where behavior diverges (e.g., networking).
- Snapshot/UI tests can validate tab navigation once the UI test target is configured.
