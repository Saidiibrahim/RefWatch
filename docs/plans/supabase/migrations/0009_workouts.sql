-- Progress: Implemented

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
  zone workout_intensity_zone not null,
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
  description text,
  segments jsonb not null,
  default_zones workout_intensity_zone[] not null default '{}'::workout_intensity_zone[],
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, title)
);

alter table public.workout_sessions enable row level security;
alter table public.workout_events enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'workout_sessions'
      AND policyname = 'workouts_own_rows'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "workouts_own_rows" ON public.workout_sessions
        FOR ALL USING (
          owner_id IN (
            SELECT id FROM public.users
            WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        )
        WITH CHECK (
          owner_id IN (
            SELECT id FROM public.users
            WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        );
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'workout_events'
      AND policyname = 'workout_events_via_session'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "workout_events_via_session" ON public.workout_events
        FOR SELECT USING (
          EXISTS (
            SELECT 1 FROM public.workout_sessions s
            JOIN public.users u ON s.owner_id = u.id
            WHERE s.id = workout_events.session_id
              AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        );
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_workouts'
      AND tgrelid = 'public.workout_sessions'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_workouts BEFORE UPDATE ON public.workout_sessions
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_workout_presets'
      AND tgrelid = 'public.workout_presets'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_workout_presets BEFORE UPDATE ON public.workout_presets
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;
