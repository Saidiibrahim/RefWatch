-- 0020_patch_reference_team_import_owner_resolution.sql
--
-- Purpose
--   Patch `import_reference_teams_for_current_user` so owner resolution works in both:
--   1) legacy schemas with `public.users.clerk_user_id`
--   2) auth-synced schemas where JWT subject matches `public.users.id`

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
  v_has_clerk_user_id boolean;
begin
  -- Resolve JWT subject from PostgREST request context.
  v_subject := nullif(current_setting('request.jwt.claim.sub', true), '');

  if v_subject is null then
    raise exception 'import_reference_teams_for_current_user requires an authenticated JWT subject';
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'clerk_user_id'
  )
  into v_has_clerk_user_id;

  if v_has_clerk_user_id then
    execute $sql$
      select u.id
      from public.users u
      where u.clerk_user_id = $1
         or u.id::text = $1
      order by case when u.clerk_user_id = $1 then 0 else 1 end
      limit 1
    $sql$
    into v_owner_id
    using v_subject;
  else
    select u.id
      into v_owner_id
    from public.users u
    where u.id::text = v_subject
    limit 1;
  end if;

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
      )::uuid,
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

revoke all on function public.import_reference_teams_for_current_user(integer, text[]) from public;
grant execute on function public.import_reference_teams_for_current_user(integer, text[]) to authenticated;
grant execute on function public.import_reference_teams_for_current_user(integer, text[]) to service_role;
