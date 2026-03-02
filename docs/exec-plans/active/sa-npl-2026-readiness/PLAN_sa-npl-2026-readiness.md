# PLAN_sa-npl-2026-readiness

## Purpose / Big Picture
Prepare RefWatch for official South Australian competitions in 2026 by shipping a canonical reference catalog for teams (Men + State Leagues + WNPL), structured disciplinary reference tables, and app-level import + event metadata alignment needed for compliance checks.

## Context and Orientation
- Supabase migration root: `RefWatchiOS/Core/Platform/Supabase/migrations/`
- Team sync API/repository: `RefWatchiOS/Core/Platform/Supabase/SupabaseTeamLibraryAPI.swift`, `RefWatchiOS/Core/Platform/Supabase/SupabaseTeamLibraryRepository.swift`
- Team UI entrypoint: `RefWatchiOS/Features/Library/Views/TeamsListView.swift`
- Card domain/event pipeline: `RefWatchCore/Sources/RefWatchCore/Domain/MatchEventRecord.swift`, `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift`, `RefWatchiOS/Core/Platform/Supabase/SupabaseMatchHistoryRepository.swift`
- Misconduct template source: `RefWatchCore/Sources/RefWatchCore/Domain/MisconductTemplates.swift`

## Plan of Work
1. Add reference competition/team schema + seed data for SA 2026 (including WNPL).
2. Add structured disciplinary reference schema + baseline sanctions/rules.
3. Add owner-library import function that materializes canonical teams into `public.teams` idempotently.
4. Wire iOS team library import action + API/repository support.
5. Extend card payload metadata (`reasonCode`, `reasonTitle`) and second-yellow persistence mapping.
6. Align iOS card reason selection to template-driven catalog (parity with watch flow source).
7. Add/adjust tests for SA template coverage and card metadata compatibility.

## Concrete Steps
- (TASK_01_sa-npl-2026-readiness.md) Create and annotate migrations `0017`, `0018`, `0019`.
- (TASK_02_sa-npl-2026-readiness.md) Implement iOS team import API/repository/UI integration.
- (TASK_03_sa-npl-2026-readiness.md) Implement card metadata + second-yellow persistence updates.
- (TASK_04_sa-npl-2026-readiness.md) Add tests and capture verification commands + handoff notes.

## Progress
- [x] TASK_01_sa-npl-2026-readiness.md
- [x] TASK_02_sa-npl-2026-readiness.md
- [x] TASK_03_sa-npl-2026-readiness.md
- [x] TASK_04_sa-npl-2026-readiness.md

## Surprises & Discoveries
- The active session cannot execute live DB verification due MCP auth handshake failures on `refwatch-database`/Supabase.
- Existing app/card flows used mixed reason sources (watch template-driven, iOS hardcoded), which blocked deterministic sanction-code mapping.

## Decision Log
- Decision: Keep canonical federation data in global reference tables and import into owner-scoped `teams`.
- Rationale: Preserves existing ownership/RLS model while allowing deterministic league catalogs.
- Date/Author: 2026-02-28 / Codex

- Decision: Include WNPL in the same 2026 SA rollout scope.
- Rationale: User requested full SA readiness with men + state leagues + WNPL.
- Date/Author: 2026-02-28 / Codex

## Testing Approach
- Run core unit tests for misconduct template and card payload compatibility.
- Run migration-level SQL checks once MCP access is restored.
- Confirm iOS library import action performs idempotent imports with expected counts (deferred until MCP SQL apply/verify is available).

## Constraints & Considerations
- Final DB sign-off is blocked until MCP auth is restored.
- Disciplinary schedule rows seeded as baseline must be validated against live 2026 regulations via MCP before production lock.

## Outcomes & Retrospective
- Implemented schema + code path changes required for SA 2026 readiness, including WNPL.
- Left a deterministic verification script path and heavily commented migrations for the next coding agent to finalize with MCP evidence.
