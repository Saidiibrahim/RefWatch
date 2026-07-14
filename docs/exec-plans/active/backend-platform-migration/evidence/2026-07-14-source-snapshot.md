# Preliminary Source Inventory — 2026-07-14

## Method

Live RefWatch Supabase provider readback through the project database connector.
All public-table counts were returned by one SQL statement, so those counts have
statement-level consistency. Auth count, RLS state, enums, columns, and preflight
checks were separate reads in the same operator session and are not claimed to
share that statement snapshot. No repository migration was used as a substitute
for provider state.

The exact UTC timestamp, project reference, transaction identifier, and raw
connector output were not retained, so this is preparation evidence only. A
fresh `REPEATABLE READ, READ ONLY` transaction with sanitized raw output is a
mandatory final-cutover artifact.

## Identity

- `auth.users`: 43
- `public.users`: 42
- Auth identities without a public profile: 1
- `public.users.id` is the internal UUID; live `public.users` has no
  `clerk_user_id` column.
- Production import requires a reviewed Clerk-subject mapping for every public
  profile and an explicit keep/import/archive decision for the auth-only user.

## Public Table Counts

| Table | Rows | Table | Rows |
| --- | ---: | --- | ---: |
| `ai_attachments` | 0 | `ai_messages` | 0 |
| `ai_threads` | 0 | `ai_usage_daily` | 0 |
| `coaches` | 0 | `coaching_sessions` | 0 |
| `competitions` | 3 | `feedback_attachments` | 0 |
| `feedback_items` | 0 | `feedback_threads` | 0 |
| `match_assessments` | 6 | `match_events` | 579 |
| `match_metrics` | 62 | `match_officials` | 0 |
| `match_periods` | 119 | `match_reports` | 0 |
| `matches` | 62 | `pages` | 2 |
| `reference_competitions` | 5 | `reference_disciplinary_codes` | 30 |
| `reference_disciplinary_rules` | 3 | `reference_teams` | 54 |
| `resource_shares` | 0 | `scheduled_matches` | 38 |
| `team_members` | 0 | `team_officials` | 0 |
| `team_tags` | 0 | `teams` | 77 |
| `trend_snapshots` | 0 | `user_devices` | 0 |
| `users` | 42 | `venues` | 3 |
| `wellness_check_ins` | 0 | `workout_events` | 0 |
| `workout_intensity_profile` | 0 | `workout_presets` | 20 |
| `workout_segments` | 0 | `workout_session_metrics` | 0 |
| `workout_sessions` | 1 |  |  |

## Preflight Results

- A follow-up preliminary read found zero orphan owners across competitions,
  teams, venues, schedules, matches, metrics, assessments, pages, and workout
  sessions; it also found zero missing match parents for periods/events/metrics/
  assessments/pages, zero missing workout preset parents, and zero owner
  mismatches between matches and referenced schedules/competitions/venues/teams.
- A later aggregate read found zero page-to-match owner mismatches, zero
  reference-team composite competition/season orphans, and zero user-owned
  workout presets.
- No owned workout presets (`created_by` was null for all 20).
- One assessment has a mood; no assessment rating violates the target range.
- No null match scores, period added time, or metric average added time.
- No event currently has `team_id` or `team_member_id` populated.
- No venue currently has coordinates populated.
- Assessment mood values: `calm`, `focused`, `stressed`, `fatigued`.
- Several currently empty tables have source/target shape drift despite a target
  table existing (for example AI messages/attachments, devices, and team-tag
  naming). The validator therefore does not silently promote them into the
  verified import order. If any becomes non-empty in the final snapshot, its
  import contract must be extended before cutover; non-empty rows hard-block the
  validator and cannot be accepted for archival.

## Legacy RLS Risk

RLS was disabled on nine public tables: `match_officials`,
`match_assessments`, `trend_snapshots`, `workout_session_metrics`,
`workout_intensity_profile`, `workout_segments`, `coaches`,
`feedback_attachments`, and `ai_usage_daily`. This is source risk, not target
authorization evidence. The Worker must enforce owner scoping for every
user-owned access.
