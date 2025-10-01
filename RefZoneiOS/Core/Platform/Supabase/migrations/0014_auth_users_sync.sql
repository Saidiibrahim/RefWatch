--
-- 0014_auth_users_sync.sql
--
-- Adds automation to keep public.users in sync with Supabase auth.users so
-- foreign keys that reference public.users always have a matching profile row.
--

set check_function_bodies = off;

create or replace function public.sync_user_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  auth_user auth.users%rowtype;
  raw_user jsonb;
  raw_app jsonb;
  trimmed_display text;
  trimmed_avatar text;
  providers_json jsonb;
  custom_claims_json jsonb;
  email_verified_bool boolean;
  phone_verified_bool boolean;
begin
  if TG_OP = 'DELETE' then
    delete from public.users where id = OLD.id;
    return OLD;
  end if;

  auth_user := coalesce(NEW, OLD);
  raw_user := coalesce(auth_user.raw_user_meta_data, '{}'::jsonb);
  raw_app := coalesce(auth_user.raw_app_meta_data, '{}'::jsonb);

  providers_json := raw_app -> 'providers';
  if providers_json is null then
    providers_json := '[]'::jsonb;
  elsif jsonb_typeof(providers_json) <> 'array' then
    begin
      providers_json := (raw_app ->> 'providers')::jsonb;
      if providers_json is null or jsonb_typeof(providers_json) <> 'array' then
        providers_json := '[]'::jsonb;
      end if;
    exception when others then
      providers_json := '[]'::jsonb;
    end;
  end if;
  raw_app := jsonb_set(raw_app, '{providers}', providers_json, true);

  custom_claims_json := raw_user -> 'custom_claims';
  if custom_claims_json is null then
    custom_claims_json := '{}'::jsonb;
  elsif jsonb_typeof(custom_claims_json) <> 'object' then
    begin
      custom_claims_json := (raw_user ->> 'custom_claims')::jsonb;
      if custom_claims_json is null or jsonb_typeof(custom_claims_json) <> 'object' then
        custom_claims_json := '{}'::jsonb;
      end if;
    exception when others then
      custom_claims_json := '{}'::jsonb;
    end;
  end if;
  raw_user := jsonb_set(raw_user, '{custom_claims}', custom_claims_json, true);

  email_verified_bool := case
    when raw_user ? 'email_verified' then
      case
        when jsonb_typeof(raw_user -> 'email_verified') = 'boolean' then (raw_user ->> 'email_verified')::boolean
        when lower(coalesce(raw_user ->> 'email_verified', '')) in ('true','t','1','yes') then true
        when lower(coalesce(raw_user ->> 'email_verified', '')) in ('false','f','0','no') then false
        else auth_user.email_confirmed_at is not null
      end
    else auth_user.email_confirmed_at is not null
  end;

  phone_verified_bool := case
    when raw_user ? 'phone_verified' then
      case
        when jsonb_typeof(raw_user -> 'phone_verified') = 'boolean' then (raw_user ->> 'phone_verified')::boolean
        when lower(coalesce(raw_user ->> 'phone_verified', '')) in ('true','t','1','yes') then true
        when lower(coalesce(raw_user ->> 'phone_verified', '')) in ('false','f','0','no') then false
        else false
      end
    else false
  end;

  raw_user := jsonb_set(raw_user, '{email_verified}', to_jsonb(coalesce(email_verified_bool, false)), true);
  raw_user := jsonb_set(raw_user, '{phone_verified}', to_jsonb(coalesce(phone_verified_bool, false)), true);

  trimmed_display := nullif(trim(coalesce(
    raw_user ->> 'full_name',
    raw_user ->> 'name',
    raw_user ->> 'display_name',
    raw_user ->> 'username',
    auth_user.email
  )), '');

  trimmed_avatar := nullif(trim(coalesce(
    raw_user ->> 'avatar_url',
    raw_user ->> 'picture',
    raw_user ->> 'image'
  )), '');

  insert into public.users as u (
    id,
    email,
    display_name,
    avatar_url,
    email_verified,
    email_confirmed_at,
    is_sso_user,
    is_anonymous,
    last_sign_in_at,
    raw_app_metadata,
    raw_user_metadata,
    created_at,
    updated_at
  ) values (
    auth_user.id,
    auth_user.email,
    trimmed_display,
    trimmed_avatar,
    coalesce(email_verified_bool, auth_user.email_confirmed_at is not null),
    auth_user.email_confirmed_at,
    coalesce(auth_user.is_sso_user, false),
    coalesce(auth_user.is_anonymous, false),
    auth_user.last_sign_in_at,
    raw_app,
    raw_user,
    coalesce(auth_user.created_at, timezone('utc', now())),
    timezone('utc', now())
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = coalesce(nullif(excluded.display_name, ''), u.display_name),
    avatar_url = coalesce(nullif(excluded.avatar_url, ''), u.avatar_url),
    email_verified = excluded.email_verified,
    email_confirmed_at = excluded.email_confirmed_at,
    is_sso_user = excluded.is_sso_user,
    is_anonymous = excluded.is_anonymous,
    last_sign_in_at = coalesce(excluded.last_sign_in_at, u.last_sign_in_at),
    raw_app_metadata = excluded.raw_app_metadata,
    raw_user_metadata = excluded.raw_user_metadata,
    updated_at = excluded.updated_at;

  return auth_user;
end;
$$;

drop trigger if exists sync_public_users on auth.users;

create trigger sync_public_users
after insert or update or delete on auth.users
for each row execute function public.sync_user_from_auth();

grant execute on function public.sync_user_from_auth() to postgres, authenticated, service_role, supabase_auth_admin;
