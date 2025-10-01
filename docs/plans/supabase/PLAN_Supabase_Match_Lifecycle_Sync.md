# PLAN — Supabase Match Lifecycle Sync

This plan captures the next wave of work for bringing the RefZone iOS app’s
match flow fully onto Supabase. Today we intentionally upload matches only after
the final whistle so the watch/iPhone experience stays simple while we are still
early in the project. The goal of this roadmap is to harden the completed-match
sync, expand supporting data (teams, scheduled matches, journals), and close the
auth and observability gaps – without giving up the offline-first experience
that referees rely on. New teammates can read this document to understand the
current state, the gaps we still need to close, and how we intend to stage the
rollout safely.

## Current Findings
- `RefZoneiOS/App/RefZoneiOSApp.swift:74` already swaps in `SupabaseMatchHistoryRepository` (wrapping `SwiftDataMatchHistoryStore`) whenever the Supabase client initializes, so `MatchViewModel` writes go through that repository.
- `RefZoneiOS/Core/Platform/Supabase/SupabaseMatchHistoryRepository.swift:35` pushes completed matches via `SupabaseMatchIngestService` and periodically pulls remote updates into SwiftData, letting the app stay offline-first while syncing when signed in.
- `RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift:246` posts a `MatchBundleRequest` (match + periods + events + final score) to the `matches-ingest` Edge Function, while `fetchMatchBundles` hydrates the local store from `matches`, `match_periods`, and `match_events`.
- `SupabaseMatchHistoryRepository` now records push retry metadata with exponential backoff and sends idempotency headers when calling the ingest function, so uploads survive longer offline gaps without duplicate writes.
- `MatchBundleRequest` now includes a metrics payload mirroring `match_metrics`; ingest needs to persist it to unlock analytics queries.
- `SyncDiagnosticsCenter` listens for `syncStatusUpdate` notifications from match/team/schedule repositories so QA can spot stuck backlogs without diving into logs.
- `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift:747` calls `history.save(_:)` on finalize, so any repository conforming to `MatchHistoryStoring` (Supabase-backed or local) receives the completed snapshot.
- Supabase currently exposes full match tables (`matches`, `match_periods`, `match_events`, `match_metrics`); owner-scoped RLS policies now protect all of them. `match_metrics` remains empty until we start persisting aggregates.
- `RefZoneiOS/Core/Platform/Supabase/SupabaseTeamLibraryRepository.swift:12` and `SupabaseScheduleRepository.swift:18` already sync team libraries and upcoming matches through Supabase, including offline backlogs and auth-driven ownership.
- Journaling remains local-only (`SwiftDataJournalStore`), though the Supabase schema defines `match_assessments` for future syncing.

## Gaps To Address
- No server-side RLS on `matches`, `match_periods`, or `match_metrics`, so we can’t safely expose those tables even for finalized-match reads.
- The ingest Edge Function remains the sole entry point; we need stronger validation, logging, and retry semantics to guarantee final-whistle uploads succeed without shifting to real-time writes yet.
- `match_metrics` is defined but unused; key stats (cards, substitutions, stoppage, etc.) stay inside the JSON payload we upload, so Supabase can’t serve reporting queries yet.
- Team library and scheduled-match tables have RLS in place, but the plan lacks a cohesive rollout strategy (backlog flush, schema migrations, diagnostics) for those flows.
- Journaling is still local-only; there is no plan to map `JournalEntry` to `match_assessments` or enforce auth gating for journal creation/retrieval.
- Auth state drives repository behaviour, yet the roadmap doesn’t spell out enforcement – signed-out users should stay local-only, and policies must back the requirement that only the owner can CRUD matches, teams, schedules, or journals.
- Edge function ownership, telemetry, and integration testing are missing, so failures remain hard to detect across ingest, library, schedule, and future journal endpoints.

## Implementation Plan
1. **Lock Down Completed-Match Tables**
   - Ship migrations that enable RLS on `matches`, `match_periods`, and `match_metrics`, adding `owner_can_crud` policies bound to `auth.uid()`.
   - Add supporting indexes (`owner_id`, `updated_at`, `match_id`) so ingest and fetch remain performant.
   - Document the migrations alongside expectations for Supabase deploy processes in `docs/plans/supabase/PLAN_Supabase_Database_Schema.md`.
   - 2025-03-09: Migration `0016_match_rls.sql` shipped; RLS now covers matches, periods, and metrics with owner-scoped policies.
2. **Harden the Final-Whistle Ingest Path**
   - Keep the “final whistle only” contract but tighten reliability: enrich the `matches-ingest` Edge Function with stricter validation, idempotency keys, structured logging, and alert-friendly metrics.
   - Extend `SupabaseMatchIngestService` retries/backoff and backlog persistence to ensure uploads survive connectivity drops.
   - Add integration tests (Deno unit tests + disposable branches) that exercise finalize → ingest → fetch flows.
   - 2025-03-09: iOS client now attaches idempotency headers, persists retry metadata with exponential backoff, and logs retry scheduling. Edge function updates remain TODO.
3. **Persist and Surface Match Metrics**
   - Define the canonical metrics (`goals`, `cards`, `subs`, `added_time`, penalties, device info) in `match_metrics` and ensure the ingest endpoint writes them.
   - Provide a lightweight backfill strategy (SQL or re-run ingest) for existing matches and expose the data through `SupabaseMatchIngestService.fetchMatchBundles` (client now hydrates metrics alongside matches).
   - 2025-03-09: iOS uploads structured metrics alongside match bundles; Supabase ingest must upsert into `match_metrics`.
4. **Team Library & Schedule Sync Readiness**
   - Review `teams`, `team_members`, `team_officials`, `team_tags`, and `scheduled_matches` policies/constraints; align with the iOS repositories so offline queues (`SupabaseTeamLibraryRepository`, `SupabaseScheduleRepository`) can flush reliably.
   - Add Supabase-side telemetry for library/schedule upserts and extend `SyncDiagnosticsCenter` to surface stuck queues.
   - Update the plan to note schema ownership (migrations, RLS policies) and any client fallbacks when signed out.
   - 2025-03-09: iOS now posts `syncStatusUpdate` snapshots for match, schedule, and team queues so diagnostics can warn about backlogs; pending work: wire Supabase telemetry + match ingest Edge Function.
5. **Journal Sync Strategy**
   - Map `JournalEntry` models to Supabase `match_assessments` (fields, ownership, timestamps) and add RLS enforcing `owner_id = auth.uid()`.
   - Provide a `SupabaseJournalRepository` mirroring the existing backlog-driven pattern so creating/updating journals when offline remains safe.
   - Update `MatchesTabView` and history detail flows to reflect remote journal availability and handle the signed-out/offline states gracefully.
6. **Auth & UX Guardrails**
   - Make “signed-in users unlock Supabase sync” explicit: document UI prompts, disable remote actions when `authController.currentUserId` is nil, and ensure policies back that requirement.
   - Audit repositories for correct owner attachment (teams, schedules, matches, journals) and add analytics events/OSLog breadcrumbs when auth state changes affect sync.
7. **Testing, Tooling & Rollout**
   - Expand XCTests around backlog stores, ingest retries, team/schedule/journal repositories, and Supabase auth gating.
   - Provide developer runbooks for migrations, function deploys, and diagnostics; automate branch-based smoke tests that validate finalize → ingest → fetch, team library upserts, schedule creation, and journal sync.
   - Stage rollout behind runtime flags or remote config, monitor backlog metrics and Supabase logs, then enable for internal testers before GA.
   - 2025-03-09: Added unit coverage for metrics payloads and sync status broadcasting; continue building integration harness against the matches-ingest function.
