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
begin
  if TG_OP = 'DELETE' then
    delete from public.users where id = OLD.id;
    return OLD;
  end if;

  auth_user := coalesce(NEW, OLD);
  raw_user := coalesce(auth_user.raw_user_meta_data, '{}'::jsonb);
  raw_app := coalesce(auth_user.raw_app_meta_data, '{}'::jsonb);

  trimmed_display := nullif(trim(coalesce(
    raw_user ->> 'full_name',
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
    auth_user.email_confirmed_at is not null,
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
