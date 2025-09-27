# PLAN — Supabase Integration Rollout for RefZone iOS

> **Status Update (Mar 2025):** The project now uses Supabase native authentication exclusively. References to Clerk and the interim identity coordinator in this document are kept for historical context only.

This plan details how we will migrate the iOS app from a purely SwiftData-backed experience to a Supabase-connected architecture while preserving offline-first behavior. Phases progress from identity/bootstrap to feature-specific data sync.

## Guiding Principles
- **Offline first**: SwiftData remains the source of truth when offline. Supabase upserts are idempotent and retry-friendly.
- **Clerk-authenticated**: Every Supabase request includes a Clerk JWT via `SupabaseTokenProvider`, enabling RLS.
- **Incremental delivery**: Ship feature-sized slices (identity → teams → schedules → matches) to de-risk.
- **Diagnostics and logging**: Surface configuration/auth errors quickly through Settings diagnostics and `AppLog.supabase`.

## Update — 2025-??-??
- Edge-function backed diagnostics have been retired. Identity bootstrap now reads from the Clerk Backend API (using the existing Clerk secret key) and upserts straight into `public.users` via PostgREST.
- The watch/device reporter is paused until we rebuild the flow without edge functions; Settings shows a lightweight identity summary instead of the previous diagnostics matrix.

## Phase 0 — Foundation & Diagnostics ✅ (Completed 2025-09-24)
- [x] Extend existing token/client scaffolding tests to confirm JWT plumbing before each request.
- [x] Enhance `SupabaseEnvironment` logging to detail configuration sources; add debug-time assertions for missing values.
- [x] Replace Settings’ simple hello-world check with a diagnostics view model that will later surface identity/device sync state.

## Phase 1 — Identity Bootstrap (`rpc.upsert_user_from_clerk`) ✅ (Completed 2025-09-24)
1. [x] Create `SupabaseIdentityCoordinator` that listens for Clerk session changes and invokes the RPC with a serialized Clerk payload.
2. [x] Cache the returned Supabase `users.id` alongside the Clerk ID via a secure `SupabaseIdentityCache`.
3. [x] Propagate the Supabase owner UUID through auth abstractions and notify observers when identity sync succeeds.
4. [x] Add unit tests using mock `SupabaseClientProviding` instances to validate payloads, retries, and errors.

## Phase 2 — Device Reporting (`rpc.upsert_user_device_from_clerk`) ✅ (Legacy 2025-09-24)
- The edge-function implementation is parked; we will revisit once a PostgREST-based reporter is designed.

## Phase 3 — Profile Fetch & Settings Diagnostics ✅ (Completed 2025-09-24)
1. [x] Build `SupabaseProfileService` that selects the `public.users` row for the current JWT (`eq(clerk_user_id, sub)`).
2. [x] (Retired) Diagnostics view model replaced by a lightweight identity summary during the Clerk backend pivot.
3. [x] Test coverage migrated to the new Clerk-backed identity service.

## Phase 4 — Team Library Sync (`teams`, `team_members`, `team_officials`, `team_tags`) ✅ (Completed 2025-09-25)
1. [x] Add `SupabaseTeamLibraryAPI` for CRUD operations mapped to Supabase tables.
2. [x] Wrap existing `TeamLibraryStoring` with a sync-aware repository that pushes local changes (upsert/delete) and merges remote pulls by `updated_at`.
3. [x] Replace direct `TeamLibraryStoring` injections with the repository while keeping SwiftData underneath for offline access.
4. [x] Unit test repository conflict resolution and error handling; consider an opt-in integration test against staging Supabase.

## Phase 5 — Schedule Sync (`scheduled_matches`) ✅ (Completed 2025-09-26)
1. [x] Mirror the team approach with `SupabaseScheduleAPI` and a `ScheduleRepository` that bridges SwiftData and Supabase.
2. [x] Trigger syncs on local mutations and set up periodic/foreground pulls.
3. [x] Update `MatchesTabView` and related flows to observe repository publishers for remote updates.

## Phase 6 — Completed Matches & Events (`matches`, `match_periods`, `match_events`) ✅ (Completed 2025-09-27)
1. [x] Create `SupabaseMatchIngestService` to upsert match bundles atomically (match + periods + events).
2. [x] Update `MatchViewModel` / `MatchHistoryService` save flow to enqueue Supabase sync tasks post-completion, shared with watch connectivity imports.
3. [x] Implement reconciliation that fetches recent Supabase matches, merges them into SwiftData, and prevents duplicates via stored Supabase IDs.
4. [x] Provide a manual "Sync history" action in Settings.

## Phase 7 — Trends & Future Tables
1. Once match ingest is stable, add read-side services (`SupabaseTrendsService`, analytics queries) aligned with schema roadmap.
2. Plan future workout ingestion mirroring RefWorkoutCore models using the same upsert-and-merge approach.

## Cross-cutting Tasks
- Standardize Supabase error types and feed them into `SyncDiagnosticsCenter`.
- Instrument structured logs with trace IDs for major RPC/API calls.
- Evaluate a lightweight background queue for deferred retries (e.g., based on `Task` or `BGTaskScheduler`).
- Expand tests across services, add UI coverage for Settings diagnostics, and gate integration tests behind an env flag.
- Update docs (`PLAN_Supabase_Database_Schema.md`, contributor guide) with configuration workflow and manual verification steps.
- Guard Supabase-backed features behind a runtime flag (`@AppStorage` or remote config) to allow gradual rollout and QA comparison.
- Rebuild device reporting without edge functions; decide whether it remains a client concern or shifts server-side.
