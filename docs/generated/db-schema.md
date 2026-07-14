# Database Schema Snapshot

Preliminary source-of-truth inventory for migration planning: live Supabase MCP readback on `2026-07-14` (not repository migration parsing). It is not the final cutover snapshot.

- Provider: the live RefWatch Supabase project
- Evidence method: MCP-backed schema/column, row-count, and RLS introspection
- Read back on: `2026-07-14`
- Schema: `public`

Repository SQL migrations are historical intent and may not match the live provider. The most important confirmed drift is identity: live `public.users` has an internal UUID `id`, but it does **not** have a `clerk_user_id` column. A Clerk-subject-to-internal-ID mapping therefore has to be created and backfilled during migration; existing internal UUIDs must be preserved.

## Cutover-critical live evidence

All preliminary live row counts were captured in one SQL statement on 2026-07-14. The
cutover-critical non-zero counts are:

| Table | Rows |
| --- | ---: |
| `users` | 42 |
| `matches` | 62 |
| `match_periods` | 119 |
| `match_events` | 579 |
| `match_metrics` | 62 |
| `match_assessments` | 6 |
| `scheduled_matches` | 38 |
| `teams` | 77 |
| `competitions` | 3 |
| `venues` | 3 |
| `pages` | 2 |
| `reference_competitions` | 5 |
| `reference_teams` | 54 |
| `reference_disciplinary_codes` | 30 |
| `reference_disciplinary_rules` | 3 |
| `workout_presets` | 20 |
| `workout_sessions` | 1 |

The remaining 22 public tables were empty. Supabase Auth contained 43 users,
so one auth identity had no `public.users` profile. Its migration disposition
and every Clerk-subject mapping remain explicit production gates.

Nine live public tables had RLS disabled:

- `match_officials`
- `match_assessments`
- `trend_snapshots`
- `workout_session_metrics`
- `workout_intensity_profile`
- `workout_segments`
- `coaches`
- `feedback_attachments`
- `ai_usage_daily`

This is an active security risk while any client can still reach Supabase directly. It must not be treated as authorization evidence for the target system. PlanetScale has no Supabase RLS boundary; the Worker must enforce user ownership on every query and mutation using the internal app-user ID resolved from the verified Clerk token.

## Reference catalog

The four `reference_*` tables are present in the live Supabase source. The
PlanetScale/Drizzle target currently ports all four and seeds the competition
and team catalog idempotently. The catalog remains global and read-only through
authenticated Worker endpoints.

## Public Enums
- `ai_message_role`
- `assessment_mood`
- `coaching_session_type`
- `match_event_type`
- `match_status`
- `match_team_side`
- `official_role`
- `page_status`
- `page_type`
- `report_status`
- `session_context`
- `shared_resource_kind`
- `team_official_role`
- `workout_intensity_zone`
- `workout_kind`
- `workout_metric_kind`
- `workout_metric_unit`
- `workout_segment_purpose`
- `workout_state`

## Public Tables
- `ai_attachments`
- `ai_messages`
- `ai_threads`
- `ai_usage_daily`
- `coaches`
- `coaching_sessions`
- `competitions`
- `feedback_attachments`
- `feedback_items`
- `feedback_threads`
- `match_assessments`
- `match_events`
- `match_metrics`
- `match_officials`
- `match_periods`
- `match_reports`
- `matches`
- `pages`
- `reference_competitions`
- `reference_disciplinary_codes`
- `reference_disciplinary_rules`
- `reference_teams`
- `resource_shares`
- `scheduled_matches`
- `team_members`
- `team_officials`
- `team_tags`
- `teams`
- `trend_snapshots`
- `user_devices`
- `users`
- `venues`
- `wellness_check_ins`
- `workout_events`
- `workout_intensity_profile`
- `workout_presets`
- `workout_segments`
- `workout_session_metrics`
- `workout_sessions`

## Regeneration
Preferred while Supabase remains the migration source:

1. Use `refwatch-database` MCP `execute_sql` to introspect current live schema objects:

```sql
select t.typname as enum_name
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
  and t.typtype = 'e'
order by t.typname;
```

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_type = 'BASE TABLE'
order by table_name;
```

2. Also read back `public.users` columns, core table counts, and `pg_class.relrowsecurity` for every public table. Regenerate this file from the same live evidence session, keeping lists sorted and timestamping the result.

Secondary fallback (only if MCP is unavailable): migration-derived parsing from repository root. Label fallback output as unverified; do not use it for a production cutover decision.

```bash
# Enumerations
rg --no-filename -o -i "create type public\.[a-z0-9_]+" RefWatchiOS/Core/Platform/Supabase/migrations/*.sql \
  | awk -F'public\\.' '{print tolower($2)}' \
  | sort -u

# Tables
rg --no-filename -o -i "create table if not exists public\.[a-z0-9_]+" RefWatchiOS/Core/Platform/Supabase/migrations/*.sql \
  | sed -E 's/create table if not exists public\\.//' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u
```

## PlanetScale target status

- Target dialect: PlanetScale Postgres, not MySQL/Vitess.
- Target schema definition: `api/src/db/schema.ts`.
- Generated target migration: `api/src/db/migrations/`.
- Runtime access path: Cloudflare Hyperdrive binding; direct `DATABASE_URL` is reserved for local fallback and migration tooling.
- Authorization replacement: API-level owner filtering derived from Clerk authentication; no client-supplied owner is authoritative.
- Disposable rehearsal branch: `cutover-rehearsal-20260714` in PlanetScale
  database `refwatch`; all six migrations applied and provider readback found
  26 public tables, five required legacy/reference tables, five reference
  competitions, and 54 reference teams.
- Staging Worker/Hyperdrive reaches that disposable branch and passes `select 1`;
  this is target connectivity, not source-schema or production proof. Global
  rehearsal hashes match for the 5/54 reference catalog business columns, 30
  disciplinary codes, 3 rules, and 20 creator-free workout presets.
- Production `main` was not changed. Remaining data import, identity mapping,
  full referential/count checks, production Hyperdrive/Worker deployment, and
  cutover are not complete.
- A fresh `REPEATABLE READ, READ ONLY` Supabase snapshot and final delta export
  are mandatory immediately before production import; this preliminary document
  cannot satisfy that gate.
