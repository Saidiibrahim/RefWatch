# PLAN — Supabase Team & Match Sync Fixes

## Findings
- The client posts completed matches to a Supabase edge function named `matches-ingest` (`RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift:328`), but that function is not deployed in the project (`supabase__get_edge_function("matches-ingest")` returned “Function not found”). The repeated 404 responses in the Xcode logs are the Supabase gateway reporting that missing function.
- The signed-in requirement plan will stop new ownerless records on iOS, but we still need coverage that proves the existing repositories drain backlogs once a session is restored and that ingest failures are surfaced to diagnostics.

## Proposed Plan
1. Deploy the `matches-ingest` edge function with the contract expected by `SupabaseMatchIngestService`, including any required secrets/configuration, and document how to redeploy the function.
2. Add a smoke/integration test (Supabase CLI or XCTest network shim) that exercises finalize → ingest → fetch against the deployed edge function so CI fails fast if the function is missing or misconfigured.
3. Extend automated coverage for backlog recovery: write a regression test that creates unsigned teams and matches while the app is signed out, signs back in, and asserts the repositories enqueue pushes and clear `needsRemoteSync` once the session is available.
4. Improve observability by ensuring `SupabaseTeamLibraryRepository` and `SupabaseMatchHistoryRepository` surface ingest/sync failures through `SyncDiagnosticsCenter`, including a specific breadcrumb for 404 (missing function) responses.
5. After the above, perform manual validation: create teams offline, sign back in, confirm rows appear in `public.teams`, and ingest a completed match to verify the edge function responds with 2xx.

## Verification Notes — 2025-09-29
- Deployed `matches-ingest` via Supabase MCP (`version 1`, verify_jwt enabled). Verified availability by running the new `SupabaseMatchIngestSmokeTests` (requires `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) — the test exercises finalize → ingest → fetch against the live endpoint and deletes the bundle.
- Supabase SQL spot-checks (`select count(*) from public.matches`, `select count(*) from public.teams`) confirm tables are reachable; automated backlog regression now ensures offline-created teams & matches clear `needsRemoteSync` immediately after auth recovery.
- Manual runbook: 1) run `SupabaseMatchIngestSmokeTests` with real env to confirm 2xx ingest, 2) launch app or call `SupabaseTeamLibraryRepository` with a signed-out store, create teams, then sign in and confirm rows appear in `public.teams` (via SQL) and diagnostics stay clean.
