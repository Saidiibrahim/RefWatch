# AGENTS.md — Supabase Plans & Migrations

## Scope
- Applies to everything in `docs/plans/supabase/**` (plans, edge-function notes, SQL migrations).
- Focuses on documenting and iterating the Supabase backend plan without touching runtime code.
- Files here are not part of any build target; they guide database and edge-function work.

## Folder Purpose
- `PLAN_Supabase_Database_Schema.md` is the canonical roadmap for tables/enums/policies.
- `PLAN_Supabase_Backend_Architecture.md` covers integration strategy across apps and Supabase.
- `edge_functions/` keeps design notes for Supabase functions (no source code committed).
- `migrations/` holds ordered SQL drafts that mirror the schema plan.

## Editing Guidelines
- Keep documents ASCII, concise, and reference other plans via relative links.
- When updating the schema plan, reflect changes in the corresponding migration SQL in the same PR.
- Maintain descriptive comments (`-- Progress: ...`) at the top of every SQL file; update the status when work ships.
- Prefer `create or replace function` when defining shared helpers (e.g., `set_updated_at`) so repeated applies stay idempotent.
- Note rule application: Always-add-comments.

## Migration Workflow
1. **Ordering:** filenames are numeric (`0000_...` → `0011_...`). Apply or edit them in ascending order.
   - Identity foundation (`0000_identity.sql`) must run before tables referencing `public.users`.
   - Enums (`0001_enums_core.sql`, `0002_enums_workout.sql`, `0003_enums_coaching.sql`) should be applied before any table that depends on them.
2. **Editing Existing Files:**
   - Update comments describing intent when logic changes.
   - Keep schema aligned with the Swift models (values, field names, constraints). Use the plan doc to explain rationale; mirror the final shape in SQL.
   - If a migration must evolve, note the change in the plan and document any backfill/migration considerations inside the SQL file as comments.
3. **Applying to Supabase:**
   - You have access to the Supabase MCP, you can apply the migrations directly to the Supabase database using the Supabase MCP.
4. **Shared Helpers:** if a helper (e.g., `set_updated_at()`) is reused, declare it once in the earliest migration and avoid redefining it elsewhere.

## Edge Function Notes
- Keep `edge_functions/README.md` up to date whenever the iOS app starts relying on a new endpoint.
- Document expected request/response shapes and any latency/observability notes so app diagnostics stay accurate.

## Peer Review Checklist
- Schema plan and SQL migrations match field names/types used in the iOS/watchOS code.
- RLS policies reference valid tables and respect Supabase auth user mapping.
- Comments annotate intent and status (`-- Progress: ...` → `-- Shipped: YYYY-MM-DD` once live).

