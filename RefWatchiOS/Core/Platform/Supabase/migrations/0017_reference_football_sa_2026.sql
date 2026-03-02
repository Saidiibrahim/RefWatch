-- Progress: Implemented
--
-- 0017_reference_football_sa_2026.sql
--
-- Purpose
--   Create canonical, read-only reference tables for Football SA 2026 competitions/teams,
--   including men's NPL + State Leagues and Apex Steel WNPL.
--
-- Why this migration exists
--   The existing `public.teams` table is owner-scoped user data. We need a federation-owned
--   reference catalog that can be imported into user libraries without mixing ownership models.
--
-- Operational notes for next coding agent
--   1) This migration is intentionally verbose and heavily commented for handoff safety.
--   2) Apply this migration first, then 0018 (discipline), then 0019 (import function).
--   3) After applying via MCP, run the verification queries in this file and compare counts.
--

-- -----------------------------------------------------------------------------
-- SECTION A: Canonical competition reference table
-- -----------------------------------------------------------------------------

create table if not exists public.reference_competitions (
  id uuid primary key,
  code text not null,
  name text not null,
  season_year integer not null check (season_year >= 2000),
  federation text not null,
  tier integer not null check (tier >= 1),
  gender text not null check (gender in ('men', 'women', 'mixed')),
  source_url text not null,
  source_published_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_reference_competitions_code
  on public.reference_competitions(code);

create index if not exists idx_reference_competitions_federation_season
  on public.reference_competitions(federation, season_year);

-- Keep updated_at semantics consistent with the rest of the schema.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_reference_competitions'
      AND tgrelid = 'public.reference_competitions'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_reference_competitions BEFORE UPDATE ON public.reference_competitions
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION B: Canonical team reference table
-- -----------------------------------------------------------------------------

create table if not exists public.reference_teams (
  id uuid primary key,
  competition_id uuid not null references public.reference_competitions(id) on delete cascade,
  name text not null,
  short_name text,
  reference_key text not null,
  season_year integer not null check (season_year >= 2000),
  source_url text not null,
  source_name_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_reference_teams_reference_key
  on public.reference_teams(reference_key);

create unique index if not exists idx_reference_teams_competition_name
  on public.reference_teams(competition_id, name);

create index if not exists idx_reference_teams_competition
  on public.reference_teams(competition_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_reference_teams'
      AND tgrelid = 'public.reference_teams'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_reference_teams BEFORE UPDATE ON public.reference_teams
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION C: RLS model (read-only for authenticated users; write by service role)
-- -----------------------------------------------------------------------------

alter table public.reference_competitions enable row level security;
alter table public.reference_teams enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reference_competitions'
      AND policyname = 'reference_competitions_read_authenticated'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_competitions_read_authenticated" ON public.reference_competitions
        FOR SELECT TO authenticated
        USING (true);
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reference_teams'
      AND policyname = 'reference_teams_read_authenticated'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_teams_read_authenticated" ON public.reference_teams
        FOR SELECT TO authenticated
        USING (true);
    $policy$;
  END IF;
END $$;

-- Service-role policy is explicit for clarity even though service role often bypasses RLS.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reference_competitions'
      AND policyname = 'reference_competitions_manage_service_role'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_competitions_manage_service_role" ON public.reference_competitions
        FOR ALL TO service_role
        USING (true)
        WITH CHECK (true);
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reference_teams'
      AND policyname = 'reference_teams_manage_service_role'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_teams_manage_service_role" ON public.reference_teams
        FOR ALL TO service_role
        USING (true)
        WITH CHECK (true);
    $policy$;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION D: Seed 2026 Football SA competition catalog
-- -----------------------------------------------------------------------------

-- NOTE:
--   We generate deterministic UUIDs from hashes so re-runs are idempotent and
--   migration behavior is predictable in environments without uuid extensions.

with competition_seed(code, name, season_year, federation, tier, gender, source_url, source_published_at) as (
  values
    (
      'nplsa_men_2026',
      'National Premier League South Australia',
      2026,
      'football_sa',
      1,
      'men',
      'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures',
      date '2025-12-18'
    ),
    (
      'sl1_men_2026',
      'State League 1 South Australia',
      2026,
      'football_sa',
      2,
      'men',
      'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures',
      date '2025-12-18'
    ),
    (
      'sl2_north_men_2026',
      'State League 2 North South Australia',
      2026,
      'football_sa',
      3,
      'men',
      'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures',
      date '2025-12-18'
    ),
    (
      'sl2_south_men_2026',
      'State League 2 South South Australia',
      2026,
      'football_sa',
      3,
      'men',
      'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures',
      date '2025-12-18'
    ),
    (
      'wnplsa_women_2026',
      'Apex Steel Women''s National Premier League South Australia',
      2026,
      'football_sa',
      1,
      'women',
      'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures',
      date '2025-12-18'
    )
), competition_with_hash as (
  select
    cs.*,
    md5(cs.code) as hash
  from competition_seed cs
)
insert into public.reference_competitions (
  id,
  code,
  name,
  season_year,
  federation,
  tier,
  gender,
  source_url,
  source_published_at
)
select
  (
    substr(hash, 1, 8) || '-' ||
    substr(hash, 9, 4) || '-' ||
    substr(hash, 13, 4) || '-' ||
    substr(hash, 17, 4) || '-' ||
    substr(hash, 21, 12)
  )::uuid as id,
  code,
  name,
  season_year,
  federation,
  tier,
  gender,
  source_url,
  source_published_at
from competition_with_hash
on conflict (code) do update
set
  name = excluded.name,
  season_year = excluded.season_year,
  federation = excluded.federation,
  tier = excluded.tier,
  gender = excluded.gender,
  source_url = excluded.source_url,
  source_published_at = excluded.source_published_at,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- SECTION E: Seed 2026 Football SA team catalog (Men + State Leagues + WNPL)
-- -----------------------------------------------------------------------------

-- Expected seed totals after this section:
--   nplsa_men_2026      = 12
--   sl1_men_2026        = 12
--   sl2_north_men_2026  = 10
--   sl2_south_men_2026  = 10
--   wnplsa_women_2026   = 10
--   TOTAL               = 54

with team_seed(competition_code, team_name, short_name, source_name_note) as (
  values
    -- NPL SA Men (12)
    ('nplsa_men_2026', 'Adelaide City', null, null),
    ('nplsa_men_2026', 'Adelaide Comets', null, null),
    ('nplsa_men_2026', 'Adelaide United', null, null),
    ('nplsa_men_2026', 'Campbelltown City', null, null),
    ('nplsa_men_2026', 'Croydon FC', null, null),
    ('nplsa_men_2026', 'FK Beograd', null, null),
    ('nplsa_men_2026', 'MetroStars', null, null),
    ('nplsa_men_2026', 'Para Hills Knights', null, null),
    ('nplsa_men_2026', 'Playford City', null, null),
    ('nplsa_men_2026', 'Sturt Lions', null, null),
    ('nplsa_men_2026', 'West Adelaide', null, null),
    ('nplsa_men_2026', 'West Torrens Birkalla', 'WT Birkalla', null),

    -- State League 1 Men (12)
    ('sl1_men_2026', 'Adelaide Blue Eagles', null, null),
    ('sl1_men_2026', 'Adelaide Cobras', null, null),
    ('sl1_men_2026', 'Adelaide Olympic', null, null),
    ('sl1_men_2026', 'Adelaide Raptors', null, null),
    ('sl1_men_2026', 'Cumberland United', null, null),
    ('sl1_men_2026', 'Fulham United', null, null),
    ('sl1_men_2026', 'Modbury Jets', null, null),
    ('sl1_men_2026', 'Salisbury Inter', null, null),
    ('sl1_men_2026', 'South Adelaide Panthers', null, null),
    ('sl1_men_2026', 'Vipers', null, null),
    ('sl1_men_2026', 'White City', null, null),
    ('sl1_men_2026', 'West Torrens Birkalla', 'WT Birkalla', null),

    -- State League 2 North Men (10)
    ('sl2_north_men_2026', 'Adelaide Titans', null, null),
    ('sl2_north_men_2026', 'Eastern United', null, null),
    ('sl2_north_men_2026', 'Elizabeth Downs', null, null),
    ('sl2_north_men_2026', 'Ghan Kilburn City', null, null),
    ('sl2_north_men_2026', 'Northern Demons', null, null),
    ('sl2_north_men_2026', 'Old Ignatians', null, null),
    ('sl2_north_men_2026', 'Pontian Eagles', null, null),
    ('sl2_north_men_2026', 'Tea Tree Gully', null, null),
    ('sl2_north_men_2026', 'University', null, null),
    ('sl2_north_men_2026', 'Whyalla', null, null),

    -- State League 2 South Men (10)
    ('sl2_south_men_2026', 'Adelaide University', null, null),
    ('sl2_south_men_2026', 'Atletico Adelaide', null, null),
    ('sl2_south_men_2026', 'Cove', null, null),
    ('sl2_south_men_2026', 'Flinders United', null, null),
    ('sl2_south_men_2026', 'Marion', null, null),
    ('sl2_south_men_2026', 'Mount Barker', null, null),
    ('sl2_south_men_2026', 'Noarlunga United', null, null),
    ('sl2_south_men_2026', 'Seaford Rangers', null, null),
    ('sl2_south_men_2026', 'Western Strikers', null, null),
    ('sl2_south_men_2026', 'Adelaide Hills Hawks', null, null),

    -- WNPL SA Women (10)
    ('wnplsa_women_2026', 'Adelaide Comets', null, null),
    ('wnplsa_women_2026', 'Adelaide University', null,
      'Source competition article spells this as ''Adeliade University''; canonicalized to Adelaide University.'),
    ('wnplsa_women_2026', 'Campbelltown City', null, null),
    ('wnplsa_women_2026', 'Flinders United', null, null),
    ('wnplsa_women_2026', 'Football SA', null, null),
    ('wnplsa_women_2026', 'MetroStars', null, null),
    ('wnplsa_women_2026', 'Modbury Vista', null, null),
    ('wnplsa_women_2026', 'Salisbury Inter', null, null),
    ('wnplsa_women_2026', 'West Adelaide', null, null),
    ('wnplsa_women_2026', 'WT Birkalla', null, null)
), mapped as (
  select
    rc.id as competition_id,
    rc.code as competition_code,
    ts.team_name,
    ts.short_name,
    ts.source_name_note,
    rc.season_year,
    rc.source_url,
    lower(regexp_replace(rc.code || '_' || ts.team_name, '[^a-zA-Z0-9]+', '_', 'g')) as reference_key,
    md5(rc.code || '|' || ts.team_name || '|' || rc.season_year::text) as hash
  from team_seed ts
  join public.reference_competitions rc
    on rc.code = ts.competition_code
)
insert into public.reference_teams (
  id,
  competition_id,
  name,
  short_name,
  reference_key,
  season_year,
  source_url,
  source_name_note
)
select
  (
    substr(hash, 1, 8) || '-' ||
    substr(hash, 9, 4) || '-' ||
    substr(hash, 13, 4) || '-' ||
    substr(hash, 17, 4) || '-' ||
    substr(hash, 21, 12)
  )::uuid as id,
  competition_id,
  team_name,
  short_name,
  reference_key,
  season_year,
  source_url,
  source_name_note
from mapped
on conflict (reference_key) do update
set
  competition_id = excluded.competition_id,
  name = excluded.name,
  short_name = excluded.short_name,
  season_year = excluded.season_year,
  source_url = excluded.source_url,
  source_name_note = excluded.source_name_note,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- SECTION F: Verification queries (for next coding agent using MCP)
-- -----------------------------------------------------------------------------
-- Query 1:
-- select code, count(*)
-- from public.reference_teams rt
-- join public.reference_competitions rc on rc.id = rt.competition_id
-- where rc.season_year = 2026
-- group by code
-- order by code;
--
-- Query 2:
-- select count(*) as total_teams_2026
-- from public.reference_teams rt
-- join public.reference_competitions rc on rc.id = rt.competition_id
-- where rc.season_year = 2026;
-- Expected total_teams_2026 = 54.
