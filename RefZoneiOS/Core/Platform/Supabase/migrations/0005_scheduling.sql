-- Progress: Implemented

create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

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
  source_device_id text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, kickoff_at, home_team_name, away_team_name)
);

create index if not exists idx_sched_owner_kickoff on public.scheduled_matches(owner_id, kickoff_at);
create index if not exists idx_sched_status on public.scheduled_matches(status);

alter table public.scheduled_matches enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'scheduled_matches'
      AND policyname = 'scheduled_matches_own_rows'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "scheduled_matches_own_rows" ON public.scheduled_matches
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
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_scheduled'
      AND tgrelid = 'public.scheduled_matches'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_scheduled BEFORE UPDATE ON public.scheduled_matches
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;
