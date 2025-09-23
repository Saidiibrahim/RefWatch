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
  event_type match_event_type not null,
  payload jsonb,
  team_id uuid references public.teams(id),
  team_member_id uuid references public.team_members(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_events_match_time on public.match_events(match_id, occurred_at);
create index if not exists idx_events_match_clock on public.match_events(match_id, period_index, clock_seconds);

alter table public.match_events enable row level security;
create policy if not exists "events_via_match_owner" on public.match_events for select using (
  exists (
    select 1 from public.matches m
    join public.users u on m.owner_id = u.id
    where m.id = match_events.match_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

create trigger if not exists t_upd_matches before update on public.matches
for each row execute function set_updated_at();


