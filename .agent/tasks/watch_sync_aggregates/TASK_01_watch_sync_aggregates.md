---
task_id: 01
plan_id: PLAN_watch_sync_aggregates
plan_file: ../../plans/watch_sync_aggregates/PLAN_watch_sync_aggregates.md
title: Catalogue existing data sources and sync touchpoints
phase: Phase 1 - Discovery
---

## Objective
Document all repositories, models, and storage layers involved in teams, venues, competitions, schedules, and existing match sync so we can understand required fields and ownership rules.

## Scope
- Review SwiftData models and Supabase repositories under `RefZoneiOS/Core/Platform/Supabase/`.
- Note identifiers, timestamps, and relationships that must travel to the watch.
- Map current WatchConnectivity usage (match payloads, media commands) and identify available hooks for new aggregate sync.

## Deliverables
- Annotated inventory of relevant types and their key properties.
- Summary of current notifications/publishers that fire on data changes.
- Risks or gaps discovered during the audit (e.g., missing stable IDs).

## Findings

### Repository & Model Inventory
- **Teams** – `SupabaseTeamLibraryRepository` (`RefZoneiOS/Core/Platform/Supabase/SupabaseTeamLibraryRepository.swift`) queues pushes/deletes with `SupabaseTeamSyncBacklogStore`. SwiftData models live in `RefZoneiOS/Core/Persistence/SwiftData/TeamRecord.swift` and capture team `id`, `ownerSupabaseId`, `lastModifiedAt`, `remoteUpdatedAt`, `needsRemoteSync`, plus child `PlayerRecord` and `TeamOfficialRecord` rows. Local store `SwiftDataTeamLibraryStore` (`…/SwiftData/SwiftDataTeamLibraryStore.swift`) lacks a change publisher and performs synchronous fetch/save operations guarded by `AuthenticationProviding`.
- **Competitions** – `SupabaseCompetitionLibraryRepository` (& backlog) in `RefZoneiOS/Core/Platform/Supabase/SupabaseCompetitionLibraryRepository.swift`; persists `CompetitionRecord` (`…/SwiftData/CompetitionRecord.swift`) with unique `id`, `ownerSupabaseId`, `lastModifiedAt`, `remoteUpdatedAt`, `needsRemoteSync`. `SwiftDataCompetitionLibraryStore` exposes a `changesPublisher` for observers.
- **Venues** – `SupabaseVenueLibraryRepository` (`RefZoneiOS/Core/Platform/Supabase/SupabaseVenueLibraryRepository.swift`) mirrors the competition pattern with geodata fields (`latitude`, `longitude`) in `VenueRecord` (`…/SwiftData/VenueRecord.swift`). Local `SwiftDataVenueLibraryStore` publishes changes via Combine and filters search results manually.
- **Schedules** – `SupabaseScheduleRepository` (`RefZoneiOS/Core/Platform/Supabase/SupabaseScheduleRepository.swift`) coordinates periodic pulls (`pullInterval`, default 5 min) and backlog persistence. SwiftData backing (`SwiftDataScheduleStore` at `…/SwiftData/SwiftDataScheduleStore.swift`) stores `ScheduledMatchRecord` with denormalised team names, `statusRaw`, `needsRemoteSync`, `sourceDeviceId`, and exposes `changesPublisher` (`CurrentValueSubject`).
- **Match History (iOS)** – `SupabaseMatchHistoryRepository` (`RefZoneiOS/Core/Platform/Supabase/SupabaseMatchHistoryRepository.swift`) handles Supabase ingest/push with exponential backoff metadata. SwiftData layer (`SwiftDataMatchHistoryStore` + `CompletedMatchRecord` in `…/SwiftData/`) stores JSON payloads and index fields; posts `.matchHistoryDidChange` after mutations. `CompletedMatch` domain object (`RefWatchCore/Sources/RefWatchCore/Domain/CompletedMatch.swift`) includes optional team/competition/venue foreign keys used during fan-out.
- **Match History (watchOS)** – Watch still uses `MatchHistoryService` (`RefWatchCore/Sources/RefWatchCore/Services/MatchHistoryService.swift`), persisting JSON to Documents with async-safe read/write and re-posting `.syncNonrecoverableError` on persistence failures. No existing watch stores for teams/venues/competitions.

### WatchConnectivity Touchpoints
- **iOS receiver** – `IOSConnectivitySyncClient` (`RefZoneiOS/Core/Platform/Connectivity/IOSConnectivitySyncClient.swift`) activates `WCSession`, listens for `completedMatch` payloads via `sendMessage` and `transferUserInfo`, and handles `mediaCommand`. Manual queueing occurs while signed out. The client posts `.matchHistoryDidChange` after persisting and uses `.syncFallbackOccurred` / `.syncNonrecoverableError` for diagnostics.
- **watch sender** – `WatchConnectivitySyncClient` (`RefZoneWatchOS/Core/Platform/Connectivity/WatchConnectivitySyncClient.swift`) only supports `sendCompletedMatch`, preferring `sendMessage` with fallback to `transferUserInfo`. No inbound handling for library data or request/response patterns.
- **Manual sync affordance** – Settings tab `Resync Now` button (`RefZoneiOS/Features/Settings/Views/SettingsTabView.swift`) logs a message but does not invoke repositories or connectivity clients; there is no matching “Sync now” UI on watch.

### Change Signals & Diagnostics
- Repositories post `.syncStatusUpdate` with component metadata (see `RefWatchCore/Sources/RefWatchCore/Extensions/Notifications+SyncDiagnostics.swift`); consumed by `SyncDiagnosticsCenter` for banner messaging.
- `.syncFallbackOccurred` & `.syncNonrecoverableError` fire from both connectivity clients and stores on error paths.
- `SwiftDataVenueLibraryStore` and `SwiftDataCompetitionLibraryStore` expose Combine `changesPublisher`. `SwiftDataScheduleStore` publishes via `CurrentValueSubject`. Team library currently lacks an equivalent publisher, so consumers must re-query.
- `SwiftDataMatchHistoryStore` posts `.matchHistoryDidChange`; `MatchHistoryService` relies on callers to reload (no publisher).
- `Supabase*Repository` types maintain internal retry queues but do not currently surface connectivity reachability events—those are inferred via `.syncStatusUpdate` payload content.

### Risks & Gaps
- No watch-side persistence for teams/competitions/venues/schedules today; new sync must define storage (likely lightweight SwiftData or JSON) and model translation.
- Team library store lacking a change publisher complicates automatic fan-out; either expose Combine support or plan a higher-level notification during sync packaging.
- Connectivity layer handles only `completedMatch`/`mediaCommand`; inbound schemas, acknowledgement flows, and reachability-driven queue flushing for aggregates are absent.
- Manual “Resync Now” button is a no-op; iOS has no orchestration to combine Supabase refresh + WatchConnectivity snapshot push.
- `Supabase*Repository` components gate on `SupabaseAuthStateProviding` with UUID owner assumptions—payload schemas must carry `ownerSupabaseId` or allow post-processing to avoid rejected writes.
