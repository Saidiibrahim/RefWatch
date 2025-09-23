-- Progress: Not yet implemented

create table if not exists public.scheduled_matches (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  status match_status not null default 'scheduled',
  kickoff_at timestamptz not null,
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
  source_device_id text,
  unique (owner_id, kickoff_at, home_team_name, away_team_name)
);

create index if not exists idx_sched_owner_kickoff on public.scheduled_matches(owner_id, kickoff_at);
create index if not exists idx_sched_status on public.scheduled_matches(status);

-- Trigger function for updated_at
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger if not exists t_upd_scheduled before update on public.scheduled_matches
for each row execute function set_updated_at();


