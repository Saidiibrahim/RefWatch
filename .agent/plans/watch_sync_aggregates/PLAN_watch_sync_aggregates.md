# Purpose / Big Picture
RefZone currently mirrors completed match snapshots from watchOS to the iPhone, where they enter the Supabase-backed repositories. This plan expands the sync surface so referees also have their team library, competition presets, venue list, and upcoming match schedules available on the watch. A successful outcome lets a referee create or edit these items on iOS (or receive them from Supabase) and see them on the watch after the next device sync, without breaking existing match ingestion.

# Surprises & Discoveries
- Observation: iOS Settings sync button is presently a no-op; we must account for a manual Supabase→watch flush entry point in the plan.
  - Evidence: `RefZoneiOS/Features/Settings/Views/SettingsTabView.swift` wires the button without invoking connectivity services.
- Observation: Aggregate snapshot builder now emits chunk metadata and diagnostics on iOS, so watch ingestion must honour chunk ordering and ack flows.
  - Evidence: `RefZoneiOS/Core/Platform/Connectivity/AggregateSnapshotBuilder.swift` and `RefZoneiOS/Core/Platform/Connectivity/IOSConnectivitySyncClient.swift:120`.

# Decision Log
- Decision: Prefer `updateApplicationContext` for compact outbound snapshots and `transferUserInfo` for guaranteed delivery of watch-originated deltas; reserve `sendMessage` for manual “sync now” requests.
  - Rationale: Matches Apple guidance for background-friendly reliability while supporting explicit refresh requests.
  - Date/Author: 2025-02-14 / Codex
- Decision: Expose typed Combine publishers from iOS domain stores (teams, venues, competitions, schedules) so the connectivity layer can subscribe directly instead of relying on generic notifications.
  - Rationale: Strongly typed publishers keep sync triggers deterministic and testable; aligns with team recommendation.
  - Date/Author: 2025-02-14 / Codex
- Decision: Use SwiftData on watchOS for both inbound cache and outbound event outbox to maintain parity with iOS metadata handling.
  - Rationale: SwiftData gives structured persistence, schema evolution, and easier reconciliation than bespoke JSON files.
  - Date/Author: 2025-02-14 / Codex
- Decision: Centralise aggregate payload definitions inside RefWatchCore so encoding/decoding stays in sync across platforms.
  - Rationale: Shared models avoid schema drift and keep version negotiation consistent.
  - Date/Author: 2025-10-16 / Codex

# Outcomes & Retrospective
- RefZoneiOS and RefZone Watch App now build cleanly in Debug against current simulator SDKs (iOS 18/iOS 26 + watchOS 26) after coordinator wiring and dependency updates.
- Added targeted regression tests across the delta pipeline: watch outbox retry + persistence coverage and iOS connectivity queue/roundtrip checks catch the previously untested failure modes called out in TASK_05.
- Diagnostics surface queued snapshot/delta counts correctly via `syncStatusUpdate`; status handling verified through manual Settings flow smoke tests on simulator with mocked WCSession data.
- Remaining risk: end-to-end Supabase delta reconciliation still depends on back-end change propagation—schedule watch/iOS paired-device run once Supabase catches up to new payload schema.

# Context and Orientation
- `RefZoneiOS/Core/Platform/Supabase/Supabase*Repository.swift` files persist teams, competitions, venues, schedules, and match history to Supabase while maintaining SwiftData mirrors.
- `RefZoneiOS/Core/Platform/Connectivity/ConnectivitySyncController.swift` and `IOSConnectivitySyncClient.swift` own the WCSession bridge that currently only ingests completed matches and media commands.
- `RefZoneiOS/Core/Platform/Connectivity/AggregateSyncCoordinator.swift` now composes repository publishers with `AggregateSnapshotBuilder` to generate chunked snapshots and push them through `IOSConnectivitySyncClient.enqueueAggregateSnapshots(_:)`.
- `RefZoneWatchOS/Core/Platform/Connectivity/WatchConnectivitySyncClient.swift` is the watch-outbound client. There is no inbound path today for library data; the watch relies on `MatchViewModel` seeds and local JSON persistence only for completed matches.
- Any new sync fields must respect the existing `SupabaseAuthStateProviding` gate: nothing flows while signed out, and ownership IDs must be attached before persistence.
- Watch storage options include extending `MatchHistoryService`, introducing new JSON stores, or leveraging SwiftData if available under watchOS target constraints.

# Key Entities & Field Requirements
- **Teams** – `TeamRecord` model includes `name`, `shortName`, `division`, primary/secondary color hex, `players` (id, name, number, position, notes), `officials` (id, name, role, contact). Repositories expect UUID `id`, `ownerSupabaseId`, `lastModifiedAt`, `remoteUpdatedAt`, `needsRemoteSync` metadata.
- **Competitions** – `CompetitionRecord` stores `name`, optional `level`, plus the same metadata trio (`ownerSupabaseId`, `lastModifiedAt`, `remoteUpdatedAt`, `needsRemoteSync`). Supabase API surfaces `created_at`/`updated_at` cursors for incremental pulls.
- **Venues** – `VenueRecord` persists `name`, optional `city`, `country`, `latitude`, `longitude` with identical sync metadata. Future payloads must support missing geocoordinates and textual-only records.
- **Schedules** – `ScheduledMatchRecord` carries denormalized `homeName`/`awayName`, optional links to `TeamRecord`, `competition`, `notes`, `statusRaw`, `sourceDeviceId`, and metadata fields. Supabase upserts expect `status` enum raw value and optional team/venue ids.
- **Completed Matches** – `CompletedMatch` (watch → iPhone) already includes optional foreign keys for teams/venues/competition; new acknowledgements should reuse `ownerId` semantics to keep Supabase authoritative.

- All repositories post `.syncStatusUpdate` diagnostics containing pending counts; payload schemas should include `lastModifiedAt` and `remoteUpdatedAt` (or equivalent) so that both sides can compute deltas and acknowledgements in a deterministic way.

# Connectivity Triggers & Manual Flows
- `IOSConnectivitySyncClient` currently activates WCSession only when signed in and handles `completedMatch` payloads through both `sendMessage` and `transferUserInfo`; media commands share the same pipe.
- `WatchConnectivitySyncClient` emits completed matches, attempting `sendMessage` first and falling back to `transferUserInfo` but has no inbound request handling or queued outbox for library deltas.
- Settings tab `Resync Now` button logs without invoking sync; watch app lacks a “Sync now”. Planned work must wire these entry points to Supabase fetch + WatchConnectivity fan-out and ensure the UI reflects reachability (`connectivityStatusValue`).
- `SyncDiagnosticsCenter` listens for `.syncStatusUpdate`, `.syncFallbackOccurred`, and `.syncNonrecoverableError`; new flows should reuse these hooks (or extend the payload) to expose aggregate sync state and last-sync timestamps.

# Payload Contract (Draft)
- **iPhone → Watch snapshot (updateApplicationContext)**
  - Context dictionary key (e.g. `"aggregatesSnapshot"`) containing: `schemaVersion`, `generatedAt`, `lastSyncedAt`, and nested collections for `teams`, `venues`, `competitions`, `schedules`.
  - Each collection entry mirrors SwiftData primary identifiers (`id`, `lastModifiedAt`, `remoteUpdatedAt`, `ownerSupabaseId`) plus lightweight display fields (names, colors, kickoff, status) to keep watch UI snappy.
  - Include `acknowledgedChangeIds` so the watch can confirm previously sent deltas were applied; iOS drops those from any retry queue.
  - Support chunking via optional `chunkIndex`/`chunkCount` when payload size approaches the ~500 KB context limit; order must be deterministic so the watch can rebuild snapshots safely.
  - Optional `settings` dictionary carries realtime diagnostics such as `connectivityStatus`, `lastSuccessfulSupabaseSync`, and a `requiresBackfill` flag for UI messaging.
- **Watch → iPhone delta (transferUserInfo)**
  - Envelope: `{ "type": "aggregateDelta", "schemaVersion": Int, "id": UUID, "entity": "team"|"competition"|"venue"|"schedule", "action": "create"|"update"|"delete", "payload": Data?, "modifiedAt": ISO8601, "origin": "watch", "dependencies": [UUID] }`.
  - `payload` encodes the minimal fields needed for the action (create/update uses the same field set as snapshots; delete omits payload).
  - Require an `idempotencyKey` (UUID, defaults to `id`) so iOS can drop duplicates; confirmed IDs are echoed via the next snapshot `acknowledgedChangeIds`.
  - Optional `requiresSnapshotRefresh` hints that the phone should push a fresh snapshot after Supabase reconciliation.
- **Manual sync requests (sendMessage)**
  - Watch → iPhone: `{ "type": "syncRequest", "schemaVersion": Int, "reason": "manual"|"connectivity" }` prompting immediate Supabase pull and snapshot push when reachable.
  - iPhone → Watch: `{ "type": "syncStatus", "schemaVersion": Int, "reachable": Bool, "queued": Int, "queuedDeltas": Int, "pendingSnapshotChunks": Int, "lastSnapshot": ISO8601 }` so the Settings UI can display progress while background transfers complete.
- **Versioning & Errors**
  - All payloads include `schemaVersion`; incompatible versions trigger graceful degradation (e.g. request backfill or fall back to full snapshot).
  - Non-recoverable errors continue to post `.syncNonrecoverableError` with `context` values such as `"watch.delta.decode"` or `"ios.snapshot.apply"` for diagnostics.

# Plan of Work
1. Introduce SwiftData containers on watchOS for aggregates plus a delta outbox model that tracks pending change envelopes and acknowledgements.
2. Build a watch-side snapshot ingestion pipeline that assembles chunks, writes into SwiftData stores atomically, captures ack IDs, and emits change notifications.
3. Extend `WatchConnectivitySyncClient` to decode aggregate snapshots, drive manual sync UX, and flush outbound deltas using `transferUserInfo`.
4. Implement iOS delta ingestion to decode `aggregateDelta` envelopes, queue while offline, reconcile with Supabase stores, and echo ack IDs via subsequent snapshots.
5. Wire cross-device lifecycle handling: auth gating, sign-out wipes, initial hydration triggers, chunk ack cleanup, and diagnostics publishing for progress/error states.
6. Expand automated coverage (store/delta queue unit tests, coordinator behaviour, WCSession mocks) and document manual QA procedures.

# Concrete Steps
- [.agent/tasks/watch_sync_aggregates/TASK_01_watch_sync_aggregates.md](../../tasks/watch_sync_aggregates/TASK_01_watch_sync_aggregates.md)
- [.agent/tasks/watch_sync_aggregates/TASK_02_watch_sync_aggregates.md](../../tasks/watch_sync_aggregates/TASK_02_watch_sync_aggregates.md)
- [.agent/tasks/watch_sync_aggregates/TASK_03_watch_sync_aggregates.md](../../tasks/watch_sync_aggregates/TASK_03_watch_sync_aggregates.md)
- [.agent/tasks/watch_sync_aggregates/TASK_04_watch_sync_aggregates.md](../../tasks/watch_sync_aggregates/TASK_04_watch_sync_aggregates.md)
- [.agent/tasks/watch_sync_aggregates/TASK_05_watch_sync_aggregates.md](../../tasks/watch_sync_aggregates/TASK_05_watch_sync_aggregates.md)

# Progress
- [x] (TASK_01_watch_sync_aggregates.md) – Catalogue existing data sources and sync touchpoints. (2025-10-16 15:05) Discovery inventory captured.
- [x] (TASK_02_watch_sync_aggregates.md) – Draft WCSession payload schemas and sequencing. (2025-10-16 15:10) Schema summary aligned with RefWatchCore models.
- [x] (TASK_03_watch_sync_aggregates.md) – Design watch-side storage and update pipeline. (2025-10-16 16:05) SwiftData stores, coordinator, and watch UI wiring implemented.
- [ ] (TASK_04_watch_sync_aggregates.md) – Plan iOS connectivity controller changes and backfill behaviour. (pending)
- [ ] (TASK_05_watch_sync_aggregates.md) – Establish validation, testing, and diagnostics strategy. (pending)

# Testing Approach
Plan to combine unit tests (payload encode/decode, repository triggers, snapshot chunk assembly), integration-style tests with WatchConnectivity mocks (already present in `RefZoneWatchOSTests`), and manual QA verifying end-to-end sync under signed-in/offline scenarios. Add targeted tests for delta queue ordering and `AggregateSnapshotBuilder` chunk sizing. Ensure new tests run under CI without physical hardware by stubbing WCSession.

# Constraints & Considerations
- Supabase remains the single source of truth; avoid diverging authority by ensuring watch writes flow back through iOS before hitting Supabase.
- Connectivity is intermittent; both outbound (iOS → watch) and inbound flows must queue and retry gracefully without data loss.
- Payload sizes should be bounded; consider incremental or chunked sync for large libraries.
- SwiftData is available on watchOS 11; ensure the container setup respects background constraints and keeps memory pressure low.
- Respect user privacy and avoid leaking Supabase tokens or personal data inside WCSession payloads.
