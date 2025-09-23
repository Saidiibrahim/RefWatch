-- Progress: Not yet implemented

create table if not exists public.workout_sessions (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  state workout_state not null,
  kind workout_kind not null,
  title text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  perceived_exertion integer,
  preset_id uuid,
  notes text,
  metadata jsonb default '{}'::jsonb,
  summary jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_workouts_owner_started on public.workout_sessions(owner_id, started_at desc);

create table if not exists public.workout_session_metrics (
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  kind workout_metric_kind not null,
  unit workout_metric_unit not null,
  value double precision not null,
  primary key (session_id, kind)
);

create table if not exists public.workout_intensity_profile (
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  zone_index integer not null,
  label text,
  lower_bound double precision,
  upper_bound double precision,
  time_seconds integer,
  primary key (session_id, zone_index)
);

create table if not exists public.workout_segments (
  id uuid primary key,
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  name text not null,
  purpose workout_segment_purpose not null,
  planned_duration_seconds integer,
  planned_distance_meters double precision,
  target jsonb,
  notes text
);
create index if not exists idx_workout_segments_session on public.workout_segments(session_id);

create table if not exists public.workout_events (
  id uuid primary key,
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  occurred_at timestamptz not null,
  event_type text not null,
  payload jsonb not null
);
create index if not exists idx_workout_events_time on public.workout_events(session_id, occurred_at);

create table if not exists public.workout_presets (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  kind workout_kind not null,
  title text not null,
  segments jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, title)
);

alter table public.workout_sessions enable row level security;
create policy if not exists "workouts_own_rows" on public.workout_sessions for all using (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
) with check (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
);

alter table public.workout_events enable row level security;
create policy if not exists "workout_events_via_session" on public.workout_events for select using (
  exists (
    select 1 from public.workout_sessions s
    join public.users u on s.owner_id = u.id
    where s.id = workout_events.session_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

create trigger if not exists t_upd_workouts before update on public.workout_sessions
for each row execute function set_updated_at();
create trigger if not exists t_upd_workout_presets before update on public.workout_presets
for each row execute function set_updated_at();


