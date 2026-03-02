-- Progress: Implemented
--
-- 0019_import_reference_teams_into_user_library.sql
--
-- Purpose
--   1) Extend owner-scoped `public.teams` with `reference_key` linkage to canonical teams.
--   2) Add an RPC function to import SA 2026 reference teams into the signed-in user's library.
--
-- Why this is separate from 0017
--   0017 defines global canonical data.
--   0019 defines how a user opts into importing that data into their own editable team library.
--
-- Handoff notes for next coding agent
--   1) Apply after 0017 and 0018.
--   2) Verify idempotency by calling the RPC twice and confirming no duplicates.
--   3) If `users` identity model has shifted from `clerk_user_id`, adjust owner resolution logic.
--

-- -----------------------------------------------------------------------------
-- SECTION A: Team table extension for canonical linkage
-- -----------------------------------------------------------------------------

alter table public.teams
  add column if not exists reference_key text;

-- Each owner can import a reference team at most once.
create unique index if not exists idx_teams_owner_reference_key
  on public.teams(owner_id, reference_key)
  where reference_key is not null;

create index if not exists idx_teams_reference_key
  on public.teams(reference_key)
  where reference_key is not null;

-- -----------------------------------------------------------------------------
-- SECTION B: RPC to import canonical teams into current user library
-- -----------------------------------------------------------------------------

create or replace function public.import_reference_teams_for_current_user(
  p_season_year integer default 2026,
  p_competition_codes text[] default null
)
returns table(
  imported_count integer,
  updated_count integer,
  skipped_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject text;
  v_owner_id uuid;
begin
  -- Resolve JWT subject from PostgREST request context.
  v_subject := nullif(current_setting('request.jwt.claim.sub', true), '');

  if v_subject is null then
    raise exception 'import_reference_teams_for_current_user requires an authenticated JWT subject';
  end if;

  -- Owner resolution strategy:
  --   1) Preferred: users.clerk_user_id = JWT subject (legacy/current app contract)
  --   2) Fallback: users.id textual match (for environments where subject is UUID)
  select u.id
    into v_owner_id
  from public.users u
  where u.clerk_user_id = v_subject
     or u.id::text = v_subject
  order by case when u.clerk_user_id = v_subject then 0 else 1 end
  limit 1;

  if v_owner_id is null then
    raise exception 'No public.users row found for subject=%', v_subject;
  end if;

  return query
  with selected_reference as (
    select
      rt.reference_key,
      rt.name,
      rt.short_name,
      rc.name as division_name,
      md5(v_owner_id::text || '|' || rt.reference_key) as hash
    from public.reference_teams rt
    join public.reference_competitions rc
      on rc.id = rt.competition_id
    where rc.season_year = p_season_year
      and (
        p_competition_codes is null
        or cardinality(p_competition_codes) = 0
        or rc.code = any(p_competition_codes)
      )
  ), upserted as (
    insert into public.teams (
      id,
      owner_id,
      name,
      short_name,
      division,
      color_primary,
      color_secondary,
      reference_key,
      created_at,
      updated_at
    )
    select
      (
        substr(sr.hash, 1, 8) || '-' ||
        substr(sr.hash, 9, 4) || '-' ||
        substr(sr.hash, 13, 4) || '-' ||
        substr(sr.hash, 17, 4) || '-' ||
        substr(sr.hash, 21, 12)
      )::uuid as id,
      v_owner_id,
      sr.name,
      sr.short_name,
      sr.division_name,
      null,
      null,
      sr.reference_key,
      now(),
      now()
    from selected_reference sr
    on conflict (owner_id, reference_key) do update
    set
      name = excluded.name,
      short_name = excluded.short_name,
      division = excluded.division,
      updated_at = now()
    returning (xmax = 0) as was_insert
  ), aggregate_counts as (
    select
      coalesce(sum(case when was_insert then 1 else 0 end), 0)::integer as imported_count,
      coalesce(sum(case when was_insert then 0 else 1 end), 0)::integer as updated_count,
      0::integer as skipped_count
    from upserted
  )
  select
    aggregate_counts.imported_count,
    aggregate_counts.updated_count,
    aggregate_counts.skipped_count
  from aggregate_counts;
end;
$$;

-- Keep function invocation scoped to authenticated clients and service-role automation.
revoke all on function public.import_reference_teams_for_current_user(integer, text[]) from public;
grant execute on function public.import_reference_teams_for_current_user(integer, text[]) to authenticated;
grant execute on function public.import_reference_teams_for_current_user(integer, text[]) to service_role;

-- -----------------------------------------------------------------------------
-- SECTION C: Verification snippets (for next coding agent using MCP)
-- -----------------------------------------------------------------------------
-- Example call:
-- select * from public.import_reference_teams_for_current_user(
--   2026,
--   array['nplsa_men_2026','sl1_men_2026','sl2_north_men_2026','sl2_south_men_2026','wnplsa_women_2026']
-- );
--
-- Idempotency check:
--   Run the call twice. Second call should report imported_count = 0.
--
-- Duplicate safety check:
-- select owner_id, reference_key, count(*)
-- from public.teams
-- where reference_key is not null
-- group by owner_id, reference_key
-- having count(*) > 1;
