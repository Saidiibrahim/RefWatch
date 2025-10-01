-- Progress: Implemented

create table if not exists public.teams (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  short_name text,
  division text,
  color_primary text,
  color_secondary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.team_members (
  id uuid primary key,
  team_id uuid not null references public.teams(id) on delete cascade,
  display_name text not null,
  jersey_number text,
  role text,
  position text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.team_tags (
  team_id uuid not null references public.teams(id) on delete cascade,
  tag text not null,
  primary key (team_id, tag)
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'team_official_role'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.team_official_role AS ENUM (
      ''Manager'', ''Assistant Manager'', ''Coach'', ''Physio'', ''Doctor''
    )';
  END IF;
END $$;

create table if not exists public.team_officials (
  id uuid primary key,
  team_id uuid not null references public.teams(id) on delete cascade,
  display_name text not null,
  role team_official_role not null,
  phone text,
  email text,
  created_at timestamptz not null default now()
);

create table if not exists public.competitions (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  level text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

create index if not exists idx_team_members_team_id on public.team_members(team_id);
create index if not exists idx_team_officials_team_id on public.team_officials(team_id);
create index if not exists idx_team_tags_team_id on public.team_tags(team_id);
create index if not exists idx_competitions_owner_id on public.competitions(owner_id);
create index if not exists idx_venues_owner_id on public.venues(owner_id);
create index if not exists idx_teams_owner_id on public.teams(owner_id);

alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_tags enable row level security;
alter table public.team_officials enable row level security;
alter table public.competitions enable row level security;
alter table public.venues enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'teams'
      AND policyname = 'teams_own_rows'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "teams_own_rows" ON public.teams
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
      AND tablename = 'team_members'
      AND policyname = 'team_members_team_owner'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "team_members_team_owner" ON public.team_members
        FOR ALL USING (
          EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.id = team_members.team_id
              AND t.owner_id IN (
                SELECT id FROM public.users
                WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
              )
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.id = team_members.team_id
              AND t.owner_id IN (
                SELECT id FROM public.users
                WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
              )
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
      AND tablename = 'team_tags'
      AND policyname = 'team_tags_team_owner'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "team_tags_team_owner" ON public.team_tags
        FOR ALL USING (
          EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.id = team_tags.team_id
              AND t.owner_id IN (
                SELECT id FROM public.users
                WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
              )
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.id = team_tags.team_id
              AND t.owner_id IN (
                SELECT id FROM public.users
                WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
              )
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
      AND tablename = 'team_officials'
      AND policyname = 'team_officials_team_owner'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "team_officials_team_owner" ON public.team_officials
        FOR ALL USING (
          EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.id = team_officials.team_id
              AND t.owner_id IN (
                SELECT id FROM public.users
                WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
              )
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.id = team_officials.team_id
              AND t.owner_id IN (
                SELECT id FROM public.users
                WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
              )
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
      AND tablename = 'competitions'
      AND policyname = 'competitions_own_rows'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "competitions_own_rows" ON public.competitions
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
      AND tablename = 'venues'
      AND policyname = 'venues_own_rows'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "venues_own_rows" ON public.venues
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
    WHERE tgname = 't_upd_teams'
      AND tgrelid = 'public.teams'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_teams BEFORE UPDATE ON public.teams
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_competitions'
      AND tgrelid = 'public.competitions'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_competitions BEFORE UPDATE ON public.competitions
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_venues'
      AND tgrelid = 'public.venues'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_venues BEFORE UPDATE ON public.venues
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;
