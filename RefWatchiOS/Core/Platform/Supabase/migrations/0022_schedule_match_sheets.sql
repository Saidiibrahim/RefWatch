-- 0022_schedule_match_sheets.sql
--
-- Purpose
--   Add schedule-owned frozen match-sheet payload columns to scheduled matches.
--   The payloads are optional so existing rows continue to decode cleanly.

alter table public.scheduled_matches
  add column if not exists home_match_sheet jsonb,
  add column if not exists away_match_sheet jsonb;
