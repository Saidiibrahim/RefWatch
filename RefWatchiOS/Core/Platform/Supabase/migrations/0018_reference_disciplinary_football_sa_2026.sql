-- Progress: Implemented
--
-- 0018_reference_disciplinary_football_sa_2026.sql
--
-- Purpose
--   Create canonical disciplinary reference tables for Football SA 2026,
--   covering card codes + accumulation/suspension rules in a structured form.
--
-- Important handoff note
--   This migration includes a strong baseline for card codes and accumulation rules.
--   Because live MCP validation is blocked in this session, the next coding agent must
--   verify the seeded values against the official 2026 regulations and patch any drift.
--

-- -----------------------------------------------------------------------------
-- SECTION A: Code catalog table
-- -----------------------------------------------------------------------------

create table if not exists public.reference_disciplinary_codes (
  id uuid primary key,
  jurisdiction text not null,
  season_year integer not null check (season_year >= 2000),
  recipient_type text not null check (recipient_type in ('player', 'team_official', 'participant')),
  card_type text not null check (card_type in ('yellow', 'red', 'n/a')),
  code text not null,
  title text not null,
  regulation_ref text,
  minimum_suspension_matches integer,
  sort_order integer not null default 0,
  notes text,
  source_url text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_reference_disciplinary_codes_key
  on public.reference_disciplinary_codes(jurisdiction, season_year, recipient_type, code);

create index if not exists idx_reference_disciplinary_codes_lookup
  on public.reference_disciplinary_codes(jurisdiction, season_year, recipient_type, card_type, sort_order);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_reference_disciplinary_codes'
      AND tgrelid = 'public.reference_disciplinary_codes'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_reference_disciplinary_codes BEFORE UPDATE ON public.reference_disciplinary_codes
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION B: Rule catalog table
-- -----------------------------------------------------------------------------

create table if not exists public.reference_disciplinary_rules (
  id uuid primary key,
  jurisdiction text not null,
  season_year integer not null check (season_year >= 2000),
  rule_type text not null,
  recipient_type text not null check (recipient_type in ('player', 'team_official', 'participant')),
  applies_to_codes text[] not null default '{}'::text[],
  trigger_count integer,
  repeat_interval integer,
  suspension_matches integer,
  rule_text text not null,
  regulation_ref text,
  notes text,
  source_url text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_reference_disciplinary_rules_lookup
  on public.reference_disciplinary_rules(jurisdiction, season_year, recipient_type, rule_type);

-- Natural-key uniqueness prevents duplicate rule rows when wording/notes/source URL
-- are refined in future patch migrations. Rule semantics are keyed by
-- jurisdiction + season + rule_type + recipient_type.
create unique index if not exists idx_reference_disciplinary_rules_key
  on public.reference_disciplinary_rules(jurisdiction, season_year, rule_type, recipient_type);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_reference_disciplinary_rules'
      AND tgrelid = 'public.reference_disciplinary_rules'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_reference_disciplinary_rules BEFORE UPDATE ON public.reference_disciplinary_rules
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION C: RLS model
-- -----------------------------------------------------------------------------

alter table public.reference_disciplinary_codes enable row level security;
alter table public.reference_disciplinary_rules enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reference_disciplinary_codes'
      AND policyname = 'reference_disciplinary_codes_read_authenticated'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_disciplinary_codes_read_authenticated" ON public.reference_disciplinary_codes
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
      AND tablename = 'reference_disciplinary_rules'
      AND policyname = 'reference_disciplinary_rules_read_authenticated'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_disciplinary_rules_read_authenticated" ON public.reference_disciplinary_rules
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
      AND tablename = 'reference_disciplinary_codes'
      AND policyname = 'reference_disciplinary_codes_manage_service_role'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_disciplinary_codes_manage_service_role" ON public.reference_disciplinary_codes
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
      AND tablename = 'reference_disciplinary_rules'
      AND policyname = 'reference_disciplinary_rules_manage_service_role'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "reference_disciplinary_rules_manage_service_role" ON public.reference_disciplinary_rules
        FOR ALL TO service_role
        USING (true)
        WITH CHECK (true);
    $policy$;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION D: Seed disciplinary code catalog for Football SA 2026
-- -----------------------------------------------------------------------------

with code_seed(
  jurisdiction,
  season_year,
  recipient_type,
  card_type,
  code,
  title,
  regulation_ref,
  minimum_suspension_matches,
  sort_order,
  notes,
  source_url
) as (
  values
    -- Player yellow card codes (Y1..Y7)
    ('football_sa', 2026, 'player', 'yellow', 'Y1', 'Unsporting Behaviour', 'Table 1', null, 101, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'yellow', 'Y2', 'Dissent by Word or Action', 'Table 1', null, 102, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'yellow', 'Y3', 'Persistent Infringement', 'Table 1', null, 103, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'yellow', 'Y4', 'Delaying Restart of Play', 'Table 1', null, 104, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'yellow', 'Y5', 'Failure to Respect Required Distance', 'Table 1', null, 105, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'yellow', 'Y6', 'Entering/Re-entering Without Permission', 'Table 1', null, 106, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'yellow', 'Y7', 'Deliberately Leaving Field Without Permission', 'Table 1', null, 107, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),

    -- Player red card codes (R1..R7)
    ('football_sa', 2026, 'player', 'red', 'R1', 'Serious Foul Play', 'Table 2', 1, 201, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'red', 'R2', 'Violent Conduct', 'Table 2', 2, 202, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'red', 'R3', 'Spitting or Biting', 'Table 2', 6, 203, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'red', 'R4', 'DOGSO - Handball', 'Table 2', 1, 204, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'red', 'R5', 'DOGSO - Foul', 'Table 2', 1, 205, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'red', 'R6', 'Offensive/Insulting/Abusive Language or Gestures', 'Table 2', 2, 206, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'player', 'red', 'R7', 'Second Caution (Second Yellow)', 'Table 2', 1, 207, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),

    -- Team official caution/send-off baseline codes (used by watch + iOS reason templates)
    ('football_sa', 2026, 'team_official', 'yellow', 'YT1', 'Persistent Protests / Dissent', 'Table 3', null, 301, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'team_official', 'yellow', 'YT2', 'Delaying Restart', 'Table 3', null, 302, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'team_official', 'yellow', 'YT3', 'Entering Field of Play', 'Table 3', null, 303, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'team_official', 'yellow', 'YT4', 'Leaving Technical Area', 'Table 3', null, 304, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),

    ('football_sa', 2026, 'team_official', 'red', 'RT1', 'Violent Conduct', 'Table 3', 1, 401, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'team_official', 'red', 'RT2', 'Throwing Objects', 'Table 3', 1, 402, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'team_official', 'red', 'RT3', 'Offensive/Insulting/Abusive Language', 'Table 3', 1, 403, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'team_official', 'red', 'RT4', 'Entering Field Aggressively', 'Table 3', 1, 404, null, 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),

    -- Schedule 1 Table A/B baseline participant offences.
    -- NOTE FOR NEXT AGENT: verify minimum sanctions and wording against 2026 PDF table rows.
    ('football_sa', 2026, 'participant', 'n/a', '01-01', 'Offensive, insulting or abusive language', 'Schedule 1 Table A', 4, 501, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'participant', 'n/a', '01-02', 'Spitting at a person', 'Schedule 1 Table A', 6, 502, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'participant', 'n/a', '01-03', 'Violent conduct', 'Schedule 1 Table A', 2, 503, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'participant', 'n/a', '01-04', 'Serious foul play', 'Schedule 1 Table A', 1, 504, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),

    ('football_sa', 2026, 'participant', 'n/a', '02-01', 'Threatening a match official', 'Schedule 1 Table B', 8, 601, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'participant', 'n/a', '02-02', 'Assaulting a match official', 'Schedule 1 Table B', 10, 602, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'participant', 'n/a', '02-03', 'Discriminatory abuse', 'Schedule 1 Table B', 5, 603, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations'),
    ('football_sa', 2026, 'participant', 'n/a', '02-04', 'Bringing the game into disrepute', 'Schedule 1 Table B', 4, 604, 'Baseline seeded row - verify exact wording/suspension via MCP', 'https://www.footballsa.com.au/resources/policies-rules-and-regulations')
), with_hash as (
  select
    cs.*,
    md5(cs.jurisdiction || '|' || cs.season_year::text || '|' || cs.recipient_type || '|' || cs.code) as hash
  from code_seed cs
)
insert into public.reference_disciplinary_codes (
  id,
  jurisdiction,
  season_year,
  recipient_type,
  card_type,
  code,
  title,
  regulation_ref,
  minimum_suspension_matches,
  sort_order,
  notes,
  source_url
)
select
  (
    substr(hash, 1, 8) || '-' ||
    substr(hash, 9, 4) || '-' ||
    substr(hash, 13, 4) || '-' ||
    substr(hash, 17, 4) || '-' ||
    substr(hash, 21, 12)
  )::uuid,
  jurisdiction,
  season_year,
  recipient_type,
  card_type,
  code,
  title,
  regulation_ref,
  minimum_suspension_matches,
  sort_order,
  notes,
  source_url
from with_hash
on conflict (jurisdiction, season_year, recipient_type, code) do update
set
  card_type = excluded.card_type,
  title = excluded.title,
  regulation_ref = excluded.regulation_ref,
  minimum_suspension_matches = excluded.minimum_suspension_matches,
  sort_order = excluded.sort_order,
  notes = excluded.notes,
  source_url = excluded.source_url,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- SECTION E: Seed structured sanction/accumulation rules
-- -----------------------------------------------------------------------------

with rule_seed(
  jurisdiction,
  season_year,
  rule_type,
  recipient_type,
  applies_to_codes,
  trigger_count,
  repeat_interval,
  suspension_matches,
  rule_text,
  regulation_ref,
  notes,
  source_url
) as (
  values
    (
      'football_sa',
      2026,
      'yellow_accumulation',
      'player',
      array['Y1','Y2','Y3','Y4','Y5','Y6','Y7']::text[],
      5,
      2,
      1,
      'Players are suspended on the 5th caution and on each subsequent odd-number caution total.',
      'Regulation 19.3',
      'Interpretation captured from plan requirement; verify exact legal wording in 2026 PDF.',
      'https://www.footballsa.com.au/resources/policies-rules-and-regulations'
    ),
    (
      'football_sa',
      2026,
      'yellow_accumulation',
      'team_official',
      array['YT1','YT2','YT3','YT4']::text[],
      5,
      2,
      1,
      'Team officials are suspended on the 5th caution and on each subsequent odd-number caution total.',
      'Regulation 19.3',
      'Interpretation captured from plan requirement; verify exact legal wording in 2026 PDF.',
      'https://www.footballsa.com.au/resources/policies-rules-and-regulations'
    ),
    (
      'football_sa',
      2026,
      'serious_red_accumulation',
      'player',
      array['R1','R2','R3','R6']::text[],
      2,
      1,
      1,
      'Second and subsequent serious send-off offences attract an additional suspension.',
      'Regulation 19.3',
      'Baseline implementation from execution plan; verify against official matrix.',
      'https://www.footballsa.com.au/resources/policies-rules-and-regulations'
    )
), with_hash as (
  select
    rs.*,
    md5(
      rs.jurisdiction || '|' ||
      rs.season_year::text || '|' ||
      rs.rule_type || '|' ||
      rs.recipient_type || '|' ||
      coalesce(rs.trigger_count::text, 'null') || '|' ||
      coalesce(rs.repeat_interval::text, 'null') || '|' ||
      rs.rule_text
    ) as hash
  from rule_seed rs
)
insert into public.reference_disciplinary_rules (
  id,
  jurisdiction,
  season_year,
  rule_type,
  recipient_type,
  applies_to_codes,
  trigger_count,
  repeat_interval,
  suspension_matches,
  rule_text,
  regulation_ref,
  notes,
  source_url
)
select
  (
    substr(hash, 1, 8) || '-' ||
    substr(hash, 9, 4) || '-' ||
    substr(hash, 13, 4) || '-' ||
    substr(hash, 17, 4) || '-' ||
    substr(hash, 21, 12)
  )::uuid,
  jurisdiction,
  season_year,
  rule_type,
  recipient_type,
  applies_to_codes,
  trigger_count,
  repeat_interval,
  suspension_matches,
  rule_text,
  regulation_ref,
  notes,
  source_url
from with_hash
on conflict (jurisdiction, season_year, rule_type, recipient_type) do update
set
  applies_to_codes = excluded.applies_to_codes,
  trigger_count = excluded.trigger_count,
  repeat_interval = excluded.repeat_interval,
  suspension_matches = excluded.suspension_matches,
  rule_text = excluded.rule_text,
  regulation_ref = excluded.regulation_ref,
  notes = excluded.notes,
  source_url = excluded.source_url,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- SECTION F: Verification queries (for next coding agent using MCP)
-- -----------------------------------------------------------------------------
-- Query 1:
-- select recipient_type, card_type, code, minimum_suspension_matches
-- from public.reference_disciplinary_codes
-- where jurisdiction = 'football_sa' and season_year = 2026
-- order by recipient_type, sort_order, code;
--
-- Query 2:
-- select rule_type, recipient_type, trigger_count, repeat_interval, suspension_matches
-- from public.reference_disciplinary_rules
-- where jurisdiction = 'football_sa' and season_year = 2026
-- order by recipient_type, rule_type;
--
-- Query 3 (gap-check for Y7):
-- select count(*) from public.reference_disciplinary_codes
-- where jurisdiction = 'football_sa' and season_year = 2026 and recipient_type = 'player' and code = 'Y7';
