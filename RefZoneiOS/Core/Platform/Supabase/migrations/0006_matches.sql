-- Progress: Implemented

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
  home_score integer default 0,
  away_score integer default 0,
  final_score jsonb,
  source_device_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_matches_owner_completed on public.matches(owner_id, completed_at desc);
create index if not exists idx_matches_owner_started on public.matches(owner_id, started_at desc);

create table if not exists public.match_officials (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role official_role not null,
  primary key (match_id, user_id)
);

create table if not exists public.match_periods (
  id uuid primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  index integer not null,
  regulation_seconds integer not null,
  added_time_seconds integer default 0,
  result jsonb,
  created_at timestamptz not null default now()
);
create unique index if not exists idx_period_unique on public.match_periods(match_id, index);

create table if not exists public.match_events (
  id uuid primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  occurred_at timestamptz not null,
  period_index integer not null,
  clock_seconds integer not null,
  match_time_label text not null,
  event_type match_event_type not null,
  payload jsonb,
  team_id uuid references public.teams(id),
  team_member_id uuid references public.team_members(id),
  team_side match_team_side,
  created_at timestamptz not null default now()
);
create index if not exists idx_events_match_time on public.match_events(match_id, occurred_at);
create index if not exists idx_events_match_clock on public.match_events(match_id, period_index, clock_seconds);

alter table public.match_events enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'match_events'
      AND policyname = 'events_via_match_owner'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "events_via_match_owner" ON public.match_events
        FOR SELECT USING (
          EXISTS (
            SELECT 1
            FROM public.matches m
            JOIN public.users u ON m.owner_id = u.id
            WHERE m.id = match_events.match_id
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
    WHERE tgname = 't_upd_matches'
      AND tgrelid = 'public.matches'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_matches BEFORE UPDATE ON public.matches
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;
