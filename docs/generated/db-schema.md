# Database Schema Snapshot

Intended source of truth: `refwatch-database` MCP server.

This snapshot was generated from live MCP-backed SQL introspection (not migration parsing).

- Preferred source of truth: `refwatch-database` MCP server output
- MCP access mode used: direct MCP tools (`execute_sql`, `list_tables`)
- Generated on: `2026-02-24`
- Schema: `public`

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
Preferred (MCP-first):

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

2. Regenerate this file from MCP query results, keeping both lists sorted.

Secondary fallback (only if MCP is unavailable): migration-derived parsing from repository root:

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
