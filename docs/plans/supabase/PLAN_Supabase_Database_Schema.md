# PLAN — Supabase Database Schema Roadmap

This plan shifts focus from entitlements to the broader data model RefWatch will
need once backend scaffolding is ready. It is an iterative roadmap that keeps
offline-first constraints and the existing SwiftData models in mind while laying
out how Supabase tables should evolve.

> **Status Update (Mar 2025):** Supabase is now the sole identity provider. Replace references to Clerk IDs/claims with Supabase `auth.users` identifiers and access tokens when implementing migrations.

## Objectives
- Mirror the core domain objects already present on-device (matches, teams,
  schedules, trends) so the backend can ingest, aggregate, and share data when
  the user opts in.
- Keep the schema "tier aware" without forcing paid tiers today; support future
  entitlements without blocking current work.
- Ensure every table can enforce Row Level Security (RLS) using Clerk
  `user_id`/`sub` while allowing service-role automation for ingestion and
  analytics.
- Make it easy to run incremental migrations that align with how features roll
  out in the apps.

## Guiding Principles
- **Offline first**: iOS/watchOS remain the source of truth while offline. The
  backend receives snapshots or summaries; it should accept idempotent upserts
  keyed by locally generated UUIDs.
- **User scoped**: Almost every table includes `owner_id` (FK to `users`). RLS
  should ensure a user only sees their own data unless explicitly shared.
- **Append friendly**: Avoid destructive writes. Prefer `upsert` (by primary key)
  or `insert` with conflict resolution so retries are safe.
- **Analytics ready**: Capture enough metadata (timestamps, counts, enums) that
  we can build trends dashboards later without schema churn.

## Phase 0 — Identity & Audit (foundation)
These tables are minimal and can land immediately.

| Table | Purpose | Notes |
| --- | --- | --- |
| `users` | Canonical identity row keyed by Clerk `user_id`. | Columns now mirror Clerk profile/meta (`clerk_user_id`, `primary_email`, `first_name`, `last_name`, `display_name`, `image_url`, metadata blobs, status, sync timestamps) with UUID default + RLS binding to JWT `sub`. |
| `user_devices` | Optional mapping of device IDs to users for debugging sync issues. | Tracks Clerk session + client details (`session_id`, `platform`, `client_name`, `ip_address`, `location`, `user_agent`, `metadata`) with `last_active_at`; RLS via parent join. |

Supporting RPCs:
- `rpc.upsert_user_from_clerk(payload jsonb)`: security-definer helper that validates the JWT `sub`, mirrors Clerk profile data into `users`, and updates sync timestamps.
- `rpc.upsert_user_device_from_clerk(payload jsonb)`: associates a Clerk session/device payload with the authenticated user while keeping `session_id` unique.

## Phase 1 — Team Library
Matches iOS Team Management features.

| Table | Columns (key fields only) | Notes |
| --- | --- | --- |
| `teams` | `id uuid PK`, `owner_id uuid FK`, `name text`, `short_name text`, `division text`, `color_primary text`, `color_secondary text`, timestamps | RLS by `owner_id`. |
| `team_members` | `id uuid PK`, `team_id uuid FK`, `display_name text`, `jersey_number text`, `role text`, `position text`, `notes text`, `created_at` | Mirrors SwiftData `PlayerRecord`. |
| `team_officials` | `id uuid PK`, `team_id uuid FK`, `display_name text`, `role team_official_role`, `phone text`, `email text`, `created_at` | Mirrors `TeamOfficialRecord`. |
| `team_tags` | `team_id uuid FK`, `tag text`, composite PK | Optional user-defined taxonomy for quick filtering. |

SwiftData already captures similar tables; migrations can mirror property names
so we can sync with minimal mapping.

## Phase 2 — Scheduling & Matches
Supports schedule view + match history ingestion.

| Table | Columns | Notes |
| --- | --- | --- |
| `scheduled_matches` | `id uuid PK`, `owner_id`, library FKs + text fallbacks, `kickoff_at`, `notes text`, timestamps, `source_device_id` | Derived directly from Schedule feature. |
| `matches` | `id uuid PK`, `owner_id`, optional `scheduled_match_id`, competition/venue FKs + text, team FKs + text, `status`, `started_at`, `completed_at`, `duration_seconds`, `home_score`, `away_score`, `final_score jsonb`, `source_device_id`, timestamps | Accept watch snapshots pushed via iPhone. Owner RLS shipped 2025-03-09. |
| `match_periods` | `id uuid PK`, `match_id`, `index integer`, `regulation_seconds`, `added_time_seconds`, `result jsonb`, `created_at` | Renders timers accurately. Owner RLS via parent match shipped 2025-03-09. |
| `match_events` | `id uuid PK`, `match_id`, `occurred_at timestamptz`, `period_index`, `clock_seconds`, `event_type enum`, `payload jsonb`, optional team/member FKs, `created_at` | Supports kickoff, stoppage, penalties, etc. |
| `match_officials` | `match_id`, `user_id`, `role enum`, composite PK | Enables shared officiating in future. |

### Event Type Enumeration (initial)
`kickOff`, `periodStart`, `periodEnd`, `halfTime`, `matchEnd`, `stoppageStart`,
`stoppageEnd`, `goal`, `goalOverruled`, `cardYellow`, `cardRed`,
`cardSecondYellow`, `penaltyAwarded`, `penaltyScored`, `penaltyMissed`,
`penaltiesStart`, `penaltyAttempt`, `penaltiesEnd`, `injury`, `substitution`,
`note`.

## Phase 3 — Analytics & Trends
Once matches exist, we can precompute insights.

| Table | Columns | Notes |
| --- | --- | --- |
| `match_metrics` | `match_id PK`, `owner_id`, `total_goals`, `total_cards`, `total_penalties`, `possession_home_percent`, `possession_away_percent`, `generated_at` | Pre-aggregated numbers for quick dashboards. Owner RLS shipped 2025-03-09; iOS uploads metrics with match ingestion. |
| `trend_snapshots` | `id uuid PK`, `owner_id`, `period_start`, `period_end`, `metrics jsonb`, `generated_at` | Stores rolling aggregates (per week/month). |
| `shared_reports` | `id uuid PK`, `owner_id`, `slug text unique`, `report_type enum`, `payload jsonb`, `expires_at` | Foundation for share links. |

## Optional Tables (future considerations)
- `entitlements` / `iap_transactions`: keep in backlog until we resume purchase
  work.
- `match_media_assets`: storage references for photos/video once we handle large
  uploads.
- `collaborators`: allow multiple Clerk users to view the same data when team
  sharing launches.

## Row Level Security Strategy
1. All user-owned tables include `owner_id` referencing `users.id`.
2. JWT claims from Clerk should set `request.jwt.claim.sub` (Clerk `user_id`).
3. Policies follow the pattern:
   ```sql
   -- Progress: Not yet implemented
   create policy "select own rows" on public.matches
     for select using (
       owner_id in (
         select id from public.users
         where clerk_user_id = current_setting('request.jwt.claim.sub', true)
       )
     );
   ```
4. Edge functions acting on behalf of the user either set the config manually or
   run with service-role credentials and enforce auth in code.

## Migration Ordering
1. Identity foundation (`users`, `user_devices`).
2. Team library tables (keeps parity with existing feature).
3. Scheduling + matches (requires more ingestion code on iOS).
4. Analytics tables (after ingestion is reliable).

Each step should ship with:
- SQL migration file (e.g., `00X_<feature>.sql`).
- Companion Supabase function or RPC notes if needed.
- Update to client services that read/write the new tables.

## Open Questions
- Do we store full event payloads or only summaries for privacy? (lean summary.)
- How do we map existing SwiftData IDs to backend IDs? (likely app-generated
  UUIDs reused server-side.)
- Should `teams` be deduplicated across users? (not initially; keep per-user.)
- How do we expose read-optimized views for the watch? (maybe skip until sharing
  is needed.)

Capturing these decisions now lets us stage backend work gradually without
blocking ongoing iOS/watchOS development.


## Expanded Schema Details (Complete)

This section refines the roadmap into a concrete schema aligned with the iOS app’s feature set: team library, Start Match flow, Scheduling, full match lifecycle (periods, events, stoppage), journaling/self‑assessment, and analytics for the Trends tab. All tables assume Row Level Security with `owner_id` and Clerk mapping as described above.

### Conventions
- UUID primary keys (`uuid`), generated client‑side for idempotent upserts.
- Timestamps use `timestamptz`. `created_at` default `now()`, `updated_at` via trigger.
- Nullable FKs for library references (teams/competitions/venues) so the app can start with plain text when the library isn’t used.
- Text enums modelled as Postgres `enum` types for consistency; add values via migrations.

### Enums
```sql
-- Progress: Not yet implemented
-- Match status through its lifecycle
create type match_status as enum (
  'scheduled',      -- created as a fixture
  'in_progress',    -- running on watch
  'completed',      -- final whistle recorded
  'canceled'        -- not played
);

-- Role of an official in a match
create type official_role as enum ('center', 'assistant_1', 'assistant_2', 'fourth');

-- Event types captured during a match timeline
create type match_event_type as enum (
  'kick_off',
  'period_start', 'period_end',
  'half_time',
  'match_end',
  'stoppage_start', 'stoppage_end',
  'goal', 'goal_overruled',
  'card_yellow', 'card_red', 'card_second_yellow',
  'penalty_awarded', 'penalty_scored', 'penalty_missed',
  'penalties_start', 'penalty_attempt', 'penalties_end',
  'injury', 'substitution',
  'note'
);

create type match_team_side as enum ('home', 'away');

-- Self-assessment mood scale (example set; can evolve)
create type assessment_mood as enum ('calm', 'focused', 'stressed', 'fatigued');

-- Workout state aligned with RefWorkoutCore.WorkoutSession.State
create type workout_state as enum ('planned', 'active', 'paused', 'ended', 'aborted');

-- Workout kind aligned with RefWorkoutCore.WorkoutKind
create type workout_kind as enum (
  'outdoorRun', 'outdoorWalk', 'indoorRun', 'indoorCycle', 'strength', 'mobility', 'refereeDrill', 'custom'
);

-- Workout segment purpose aligned with RefWorkoutCore.WorkoutSegment.Purpose
create type workout_segment_purpose as enum ('warmup', 'work', 'recovery', 'cooldown', 'free');

-- Core workout metric kinds and units (subset for stable storage; additional are embedded in JSONB)
create type workout_metric_kind as enum (
  'distance', 'duration', 'averagePace', 'averageSpeed', 'averageHeartRate', 'maximumHeartRate', 'calories', 'elevationGain', 'cadence', 'power', 'perceivedExertion'
);
create type workout_metric_unit as enum (
  'meters', 'kilometers', 'seconds', 'minutes', 'minutesPerKilometer', 'kilometersPerHour', 'beatsPerMinute', 'kilocalories', 'metersClimbed', 'stepsPerMinute', 'watts', 'ratingOfPerceivedExertion'
);

create type workout_intensity_zone as enum ('recovery', 'aerobic', 'tempo', 'threshold', 'anaerobic');
```

### Library: Teams, Competitions, Venues
```sql
-- Progress: Not yet implemented
-- Teams owned by a user
create table if not exists public.teams (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  short_name text,
  division text,
  color_primary text,        -- optional hex
  color_secondary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Team members; minimal fields to support jersey and selection
create table if not exists public.team_members (
  id uuid primary key,
  team_id uuid not null references public.teams(id) on delete cascade,
  display_name text not null,
  jersey_number text,
  role text,                 -- 'player'|'coach'|'staff' (text to keep flexible)
  position text,
  notes text,
  created_at timestamptz not null default now()
);
-- Team staff/officials aligned with TeamOfficialRecord
create type if not exists team_official_role as enum ('Manager', 'Assistant Manager', 'Coach', 'Physio', 'Doctor');

create table if not exists public.team_officials (
  id uuid primary key,
  team_id uuid not null references public.teams(id) on delete cascade,
  display_name text not null,
  role team_official_role not null,
  phone text,
  email text,
  created_at timestamptz not null default now()
);


-- Free-form tags for filtering teams in Library/Start Match
create table if not exists public.team_tags (
  team_id uuid not null references public.teams(id) on delete cascade,
  tag text not null,
  primary key (team_id, tag)
);

-- Competitions (leagues/cups) in the user’s library
create table if not exists public.competitions (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  level text,                -- e.g., 'U18', 'Amateur', 'Pro'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Venues the user commonly officiates at
create table if not exists public.venues (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  city text,
  country text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Scheduling & Fixtures
These power upcoming/past lists and integrate with the Start Match flow.
```sql
-- Progress: Not yet implemented
create table if not exists public.scheduled_matches (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  status match_status not null default 'scheduled',
  kickoff_at timestamptz not null,
  -- Either link to library entries or store plain text
  competition_id uuid references public.competitions(id),
  competition_name text,
  venue_id uuid references public.venues(id),
  venue_name text,
  home_team_id uuid references public.teams(id),
  home_team_name text not null,
  away_team_id uuid references public.teams(id),
  away_team_name text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Aid idempotent imports from iOS SwiftData
  source_device_id text,
  unique (owner_id, kickoff_at, home_team_name, away_team_name)
);

-- Helpful partial indexes for upcoming/past lookups
create index if not exists idx_sched_owner_kickoff on public.scheduled_matches(owner_id, kickoff_at);
create index if not exists idx_sched_status on public.scheduled_matches(status);
```

### Matches (Execution & Results)
The running/finished match is separate from the fixture but can reference it.
```sql
-- Progress: Not yet implemented
create table if not exists public.matches (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  scheduled_match_id uuid references public.scheduled_matches(id) on delete set null,
  status match_status not null default 'in_progress',
  started_at timestamptz not null,
  completed_at timestamptz,
  duration_seconds integer,
  competition_id uuid references public.competitions(id),
  competition_name text,
  venue_id uuid references public.venues(id),
  venue_name text,
  home_team_id uuid references public.teams(id),
  home_team_name text not null,
  away_team_id uuid references public.teams(id),
  away_team_name text not null,
  regulation_minutes integer,
  number_of_periods integer not null default 2,
  half_time_minutes integer,
  extra_time_enabled boolean not null default false,
  extra_time_half_minutes integer,
  penalties_enabled boolean not null default false,
  penalty_initial_rounds integer not null default 5,
  -- Final score duplicated as scalar columns for easy sorting; detailed by events below
  home_score integer default 0,
  away_score integer default 0,
  final_score jsonb,                    -- optional shape {home: N, away: N}
  source_device_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_matches_owner_completed on public.matches(owner_id, completed_at desc);
create index if not exists idx_matches_owner_started on public.matches(owner_id, started_at desc);

-- Officials participating in the match (future sharing/collab ready)
create table if not exists public.match_officials (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role official_role not null,
  primary key (match_id, user_id)
);

-- Period breakdown for accurate timers and added time
create table if not exists public.match_periods (
  id uuid primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  index integer not null,               -- 1,2,(ET1),(ET2)
  regulation_seconds integer not null,  -- scheduled period duration
  added_time_seconds integer default 0,
  result jsonb,                         -- e.g., partial score at end of period
  created_at timestamptz not null default now()
);
create unique index if not exists idx_period_unique on public.match_periods(match_id, index);

-- Timeline of events; payload captures flexible details (player, reason, etc.)
create table if not exists public.match_events (
  id uuid primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  occurred_at timestamptz not null,     -- absolute time
  period_index integer not null,
  clock_seconds integer not null,       -- seconds from period start
  match_time_label text not null,       -- formatted clock string (e.g., "45+2")
  event_type match_event_type not null,
  payload jsonb,                        -- see appendix for shapes
  team_id uuid references public.teams(id),           -- optional attribution
  team_member_id uuid references public.team_members(id),
  team_side match_team_side,            -- fallback when team_id is nil
  created_at timestamptz not null default now()
);
create index if not exists idx_events_match_time on public.match_events(match_id, occurred_at);
create index if not exists idx_events_match_clock on public.match_events(match_id, period_index, clock_seconds);
```

### Journaling / Self‑Assessment
Allows post‑match reflection to support personal development.
```sql
-- Progress: Not yet implemented
create table if not exists public.match_assessments (
  id uuid primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  mood assessment_mood,
  rating integer check (rating between 1 and 5),    -- matches UI stepper 0-5
  overall text,
  went_well text,
  to_improve text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, owner_id)                       -- one assessment per user/match
);
```

### Analytics & Trends
Pre-compute metrics for fast rendering in the Trends tab. Values derived from `match_events` and `matches`.
```sql
-- Progress: Not yet implemented
-- Per-match aggregates (denormalized for quick reads)
create table if not exists public.match_metrics (
  match_id uuid primary key references public.matches(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  regulation_minutes integer,
  half_time_minutes integer,
  extra_time_minutes integer,
  penalties_enabled boolean not null default false,
  total_goals integer not null default 0,
  total_cards integer not null default 0,
  total_penalties integer not null default 0,
  yellow_cards integer not null default 0,
  red_cards integer not null default 0,
  home_cards integer not null default 0,
  away_cards integer not null default 0,
  home_substitutions integer not null default 0,
  away_substitutions integer not null default 0,
  penalties_scored integer not null default 0,
  penalties_missed integer not null default 0,
  avg_added_time_seconds integer default 0,
  generated_at timestamptz not null default now()
);
create index if not exists idx_metrics_owner on public.match_metrics(owner_id);

-- Rolling aggregates; materialized view refreshed daily or on demand
create table if not exists public.trend_snapshots (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  metrics jsonb not null,                -- shape: {matches: N, avgCards: X, ...}
  generated_at timestamptz not null default now(),
  unique (owner_id, period_start, period_end)
);
```

### Workouts (Non‑Match Training)
Mirror `RefWorkoutCore` domain to store non‑officiating training sessions from the watch.
```sql
-- Progress: Not yet implemented
-- User workout sessions
create table if not exists public.workout_sessions (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  state workout_state not null,
  kind workout_kind not null,
  title text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  perceived_exertion integer,
  preset_id uuid,                           -- optional reference to presets table
  notes text,
  metadata jsonb default '{}'::jsonb,
  summary jsonb,                            -- {averageHeartRate, maximumHeartRate, totalDistance, activeEnergy, duration}
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_workouts_owner_started on public.workout_sessions(owner_id, started_at desc);

-- Optional: normalized metrics table (denormalized summary also captured above)
create table if not exists public.workout_session_metrics (
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  kind workout_metric_kind not null,
  unit workout_metric_unit not null,
  value double precision not null,
  primary key (session_id, kind)
);

-- Intensity profile (zones) as ordered bins
create table if not exists public.workout_intensity_profile (
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  zone_index integer not null,
  zone workout_intensity_zone not null,
  label text,
  lower_bound double precision,
  upper_bound double precision,
  time_seconds integer,
  primary key (session_id, zone_index)
);

-- Segments composing the workout (intervals)
create table if not exists public.workout_segments (
  id uuid primary key,
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  name text not null,
  purpose workout_segment_purpose not null,
  planned_duration_seconds integer,
  planned_distance_meters double precision,
  target jsonb,                              -- {metric, value, unit, intensityZone}
  notes text
);
create index if not exists idx_workout_segments_session on public.workout_segments(session_id);

-- Time‑series workout events (laps, interval transitions, HR samples, GPS points)
create table if not exists public.workout_events (
  id uuid primary key,
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  occurred_at timestamptz not null,
  event_type text not null,                  -- 'lap'|'intervalCompleted'|'heartRateSample'|'gpsPoint'|'custom'
  payload jsonb not null                      -- schema varies by type
);
create index if not exists idx_workout_events_time on public.workout_events(session_id, occurred_at);

-- User presets to allow starting structured workouts quickly
create table if not exists public.workout_presets (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  kind workout_kind not null,
  title text not null,
  description text,
  segments jsonb not null,                    -- array of segment definitions
  default_zones workout_intensity_zone[] not null default '{}'::workout_intensity_zone[],
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, title)
);
```

#### Workouts RLS
```sql
-- Progress: Not yet implemented
alter table public.workout_sessions enable row level security;
create policy "workouts_own_rows" on public.workout_sessions for all using (
  owner_id in (
    select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
) with check (
  owner_id in (
    select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

alter table public.workout_events enable row level security;
create policy "workout_events_via_session" on public.workout_events for select using (
  exists (
    select 1 from public.workout_sessions s
    join public.users u on s.owner_id = u.id
    where s.id = workout_events.session_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);
```

### AI (Responses API compatible)
Stores user chat threads and messages for the iOS Assistant feature using provider‑neutral shapes aligned with OpenAI's Responses API (multi‑part content, tool calls, usage). Ownership by `owner_id`. Future sharing can reuse `resource_shares`.
```sql
-- Progress: Not yet implemented

-- Message roles (provider neutral, Responses-compatible)
create type if not exists ai_message_role as enum ('system', 'user', 'assistant', 'tool');

-- Threads group messages and hold model/configuration defaults
create table if not exists public.ai_threads (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  title text,
  instructions text,                -- optional system instructions for this thread
  default_model text,               -- e.g., 'gpt-4o-mini'
  default_temperature double precision,
  metadata jsonb not null default '{}'::jsonb,
  prompt_tokens_total integer not null default 0,
  completion_tokens_total integer not null default 0,
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Individual messages (multi-part content and usage aligned to Responses)
create table if not exists public.ai_messages (
  id uuid primary key,
  thread_id uuid not null references public.ai_threads(id) on delete cascade,
  role ai_message_role not null,
  content_text text,                 -- convenience text (first output_text or user text)
  content_parts jsonb not null default '[]'::jsonb, -- array of typed parts per Responses
  provider_response_id text,         -- upstream response id for assistant messages
  tool_calls jsonb not null default '[]'::jsonb,   -- [{type,name,arguments_json}]
  tool_results jsonb not null default '[]'::jsonb, -- [{tool_call_id,result_json}]
  usage_input_tokens integer not null default 0,
  usage_output_tokens integer not null default 0,
  latency_ms integer,
  status text,                       -- 'completed'|'errored'|... (optional)
  error jsonb,                       -- structured error when status=errored
  created_at timestamptz not null default now()
);

-- Attachments linked to a message, backed by Supabase Storage
create table if not exists public.ai_attachments (
  id uuid primary key,
  message_id uuid not null references public.ai_messages(id) on delete cascade,
  storage_path text not null,        -- e.g., 'assistant-attachments/<user>/<uuid>.bin'
  content_type text,
  byte_size integer,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- Daily usage aggregates for cost/rate limiting
create table if not exists public.ai_usage_daily (
  owner_id uuid not null references public.users(id) on delete cascade,
  on_date date not null,
  model text not null,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  responses_count bigint not null default 0,
  last_updated_at timestamptz not null default now(),
  primary key (owner_id, on_date, model)
);

-- Helpful indexes for fast loads
create index if not exists idx_ai_threads_owner_activity on public.ai_threads(owner_id, last_activity_at desc);
create index if not exists idx_ai_messages_thread_time on public.ai_messages(thread_id, created_at asc);
create index if not exists idx_ai_threads_not_deleted on public.ai_threads(owner_id, last_activity_at desc) where deleted_at is null;

-- RLS policies: owner-only access; messages/attachments authorized via thread ownership
alter table public.ai_threads enable row level security;
create policy if not exists "ai_threads_own_rows" on public.ai_threads for all using (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
) with check (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
);

alter table public.ai_messages enable row level security;
create policy if not exists "ai_messages_via_thread_owner" on public.ai_messages for all using (
  exists (
    select 1 from public.ai_threads t
    join public.users u on t.owner_id = u.id
    where t.id = ai_messages.thread_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
) with check (
  exists (
    select 1 from public.ai_threads t
    join public.users u on t.owner_id = u.id
    where t.id = ai_messages.thread_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

alter table public.ai_attachments enable row level security;
create policy if not exists "ai_attachments_via_message_owner" on public.ai_attachments for all using (
  exists (
    select 1 from public.ai_messages m
    join public.ai_threads t on m.thread_id = t.id
    join public.users u on t.owner_id = u.id
    where m.id = ai_attachments.message_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
) with check (
  exists (
    select 1 from public.ai_messages m
    join public.ai_threads t on m.thread_id = t.id
    join public.users u on t.owner_id = u.id
    where m.id = ai_attachments.message_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

-- Maintenance triggers
-- updated_at maintenance exists elsewhere; reuse it here
create trigger if not exists t_upd_ai_threads before update on public.ai_threads
for each row execute function set_updated_at();

-- Keep thread.last_activity_at fresh when a new message arrives and update daily usage
create or replace function touch_ai_thread() returns trigger as $$
begin
  update public.ai_threads
     set last_activity_at = now(), updated_at = now()
   where id = new.thread_id;
  -- upsert usage aggregates
  insert into public.ai_usage_daily(owner_id, on_date, model, input_tokens, output_tokens, responses_count, last_updated_at)
  select t.owner_id, (now() at time zone 'utc')::date, coalesce(t.default_model, 'unknown'), new.usage_input_tokens, new.usage_output_tokens, case when new.role = 'assistant' then 1 else 0 end, now()
  from public.ai_threads t where t.id = new.thread_id
  on conflict (owner_id, on_date, model)
  do update set
    input_tokens = public.ai_usage_daily.input_tokens + excluded.input_tokens,
    output_tokens = public.ai_usage_daily.output_tokens + excluded.output_tokens,
    responses_count = public.ai_usage_daily.responses_count + excluded.responses_count,
    last_updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger if not exists t_ai_messages_touch after insert on public.ai_messages
for each row execute function touch_ai_thread();
```

#### Assistant Access Patterns & Notes
- List threads: `select * from ai_threads where owner_id = $1 and deleted_at is null order by last_activity_at desc limit 50;`
- Load messages: `select * from ai_messages where thread_id = $1 order by created_at asc limit 200;`
- Storage: use a dedicated bucket (e.g., `ai-attachments`) with object paths prefixed by user id for RLS-friendly policies.
- Future sharing: reuse `resource_shares` to grant read access to specific threads without changing table ownership.

### Coaching & Feedback (Future‑Ready)
Allow senior officials to review a match (or workout) and leave structured feedback. Designed for opt‑in sharing.
```sql
-- Progress: Not yet implemented
-- Principals eligible to participate in coaching flows
create table if not exists public.coaches (
  id uuid primary key,                        -- FK to users.id or independent if needed
  user_id uuid unique references public.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Resource sharing entries grant access to a single resource instance
create type shared_resource_kind as enum ('match', 'workout');
create table if not exists public.resource_shares (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,  -- who created the share
  resource_kind shared_resource_kind not null,
  resource_id uuid not null,                                             -- matches.id or workout_sessions.id
  grantee_user_id uuid not null references public.users(id) on delete cascade,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (resource_kind, resource_id, grantee_user_id)
);

-- Feedback threads scoped to a resource, authored by a coach or the owner
create table if not exists public.feedback_threads (
  id uuid primary key,
  resource_kind shared_resource_kind not null,
  resource_id uuid not null,
  owner_id uuid not null references public.users(id) on delete cascade,   -- creator of the thread
  title text,
  created_at timestamptz not null default now()
);

-- Individual feedback messages/items within a thread
create table if not exists public.feedback_items (
  id uuid primary key,
  thread_id uuid not null references public.feedback_threads(id) on delete cascade,
  author_user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  body text not null,
  annotations jsonb                             -- optional: timeline markers, tags, severity
);

-- Optional: attachments linked via Storage
create table if not exists public.feedback_attachments (
  id uuid primary key,
  item_id uuid not null references public.feedback_items(id) on delete cascade,
  storage_path text not null,
  content_type text,
  byte_size integer,
  created_at timestamptz not null default now()
);
```

#### Coaching RLS & Permissions
- The resource owner can always read/write threads and feedback.
- Grantees in `resource_shares` gain read access to the specific resource and its feedback; write access only if designated.
```sql
-- Progress: Not yet implemented
alter table public.resource_shares enable row level security;
create policy "share_owner_manage" on public.resource_shares for all using (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
);

alter table public.feedback_threads enable row level security;
create policy "threads_owner_or_grantee_read" on public.feedback_threads for select using (
  -- Owner can read
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
  or exists (
    select 1 from public.resource_shares rs
    join public.users u on rs.grantee_user_id = u.id
    where rs.resource_kind = feedback_threads.resource_kind
      and rs.resource_id = feedback_threads.resource_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

alter table public.feedback_items enable row level security;
create policy "items_thread_read" on public.feedback_items for select using (
  exists (
    select 1 from public.feedback_threads t
    join public.users u on t.owner_id = u.id
    where t.id = feedback_items.thread_id
      and (
        u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
        or exists (
          select 1 from public.resource_shares rs
          join public.users ug on rs.grantee_user_id = ug.id
          where rs.resource_kind = t.resource_kind and rs.resource_id = t.resource_id
            and ug.clerk_user_id = current_setting('request.jwt.claim.sub', true)
        )
      )
  )
);
```

### Access Patterns & Indexing
- Upcoming vs past:
  - Upcoming: `select * from scheduled_matches where owner_id = $1 and kickoff_at >= now() order by kickoff_at asc limit 50;`
  - Past: `select * from matches where owner_id = $1 and completed_at is not null order by completed_at desc limit 50;`
- Filter by competition/venue: compound indexes on `(owner_id, competition_id)` and `(owner_id, venue_id)` if needed.
- Trends tab typically queries `match_metrics` by date range and aggregates locally; for heavier periods, `trend_snapshots` offers pre-rollups.

### RLS Policy Blueprint
All user-owned tables include `owner_id`. For tables like `match_events` lacking direct `owner_id`, policies join through the parent `matches` table.
```sql
-- Progress: Not yet implemented
alter table public.teams enable row level security;
create policy "teams_own_rows" on public.teams for all using (
  owner_id in (
    select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
) with check (
  owner_id in (
    select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

-- Example for events via parent match owner
alter table public.match_events enable row level security;
create policy "events_via_match_owner" on public.match_events for select using (
  exists (
    select 1 from public.matches m
    join public.users u on m.owner_id = u.id
    where m.id = match_events.match_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);
```

### Triggers
```sql
-- Progress: Not yet implemented
-- updated_at maintenance
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger t_upd_teams before update on public.teams
for each row execute function set_updated_at();
create trigger t_upd_competitions before update on public.competitions
for each row execute function set_updated_at();
create trigger t_upd_venues before update on public.venues
for each row execute function set_updated_at();
create trigger t_upd_scheduled before update on public.scheduled_matches
for each row execute function set_updated_at();
create trigger t_upd_matches before update on public.matches
for each row execute function set_updated_at();
create trigger t_upd_assess before update on public.match_assessments
for each row execute function set_updated_at();
create trigger t_upd_workouts before update on public.workout_sessions
for each row execute function set_updated_at();
create trigger t_upd_workout_presets before update on public.workout_presets
for each row execute function set_updated_at();
```

### Appendix — Example Event Payloads
Intentionally flexible `jsonb` to keep schema stable:
- goal: `{ "assist": "Name", "bodyPart": "head" }`
- card_yellow: `{ "reason": "dissent" }`
- substitution: `{ "out": "#9", "in": "#14" }`

### iOS Feature Coverage Checklist
- Start Match uses Library data: `teams`, `competitions`, `venues` supported via IDs or fallback names.
- Trends tab: supported via `match_metrics` and optional `trend_snapshots`.
- Full match cycle: `scheduled_matches` → `matches` + `match_periods`/`match_events` → `match_assessments`.
- Upcoming/Past lookups: indexed queries by `kickoff_at`, `started_at`, `completed_at`.
- Workouts: `workout_sessions` + `workout_segments`/`workout_events` + `workout_presets` mirror the watch app.
- Coaching: `resource_shares` + `feedback_threads`/`feedback_items` permit future coach feedback.
