--
-- 0015_user_metadata_normalization.sql
--
-- Normalizes provider metadata and auth flags in public.users so downstream
-- queries can rely on typed columns and JSON structures.
--

begin;

alter table public.users
  add column if not exists is_sso_user boolean not null default false,
  add column if not exists is_anonymous boolean not null default false,
  add column if not exists primary_provider text,
  add column if not exists provider_list text[] not null default '{}'::text[],
  add column if not exists email_confirmed_at timestamptz;

create or replace function public.normalize_user_provider_metadata()
returns trigger
language plpgsql
as $$
declare
  providers_json jsonb := coalesce(NEW.raw_app_metadata -> 'providers', '[]'::jsonb);
  cleaned text[] := array[]::text[];
  provider text;
begin
  if TG_OP = 'UPDATE' and NEW.raw_app_metadata is not distinct from OLD.raw_app_metadata then
    return NEW;
  end if;

  if jsonb_typeof(providers_json) <> 'array' then
    begin
      providers_json := (NEW.raw_app_metadata ->> 'providers')::jsonb;
      if providers_json is null or jsonb_typeof(providers_json) <> 'array' then
        providers_json := '[]'::jsonb;
      end if;
    exception when others then
      providers_json := '[]'::jsonb;
    end;
  end if;

  for provider in
    select lower(btrim(value))
    from jsonb_array_elements_text(providers_json) as e(value)
  loop
    if provider <> '' and provider <> 'null' and not provider = any(cleaned) then
      cleaned := array_append(cleaned, provider);
    end if;
  end loop;

  NEW.provider_list := cleaned;
  NEW.primary_provider := case when array_length(cleaned, 1) >= 1 then cleaned[1] else null end;
  NEW.raw_app_metadata := jsonb_set(
    coalesce(NEW.raw_app_metadata, '{}'::jsonb),
    '{providers}',
    to_jsonb(cleaned),
    true
  );

  return NEW;
end;
$$;

drop trigger if exists trg_normalize_user_provider_metadata on public.users;

create trigger trg_normalize_user_provider_metadata
  before insert or update of raw_app_metadata on public.users
  for each row execute function public.normalize_user_provider_metadata();

with normalized as (
  select
    id,
    case
      when jsonb_typeof(raw_app_metadata -> 'providers') = 'array' then raw_app_metadata -> 'providers'
      when coalesce(raw_app_metadata ->> 'providers', '') ~ '^\\s*\[' then (raw_app_metadata ->> 'providers')::jsonb
      else '[]'::jsonb
    end as providers_json,
    case
      when jsonb_typeof(raw_user_metadata -> 'custom_claims') = 'object' then raw_user_metadata -> 'custom_claims'
      when coalesce(raw_user_metadata ->> 'custom_claims', '') ~ '^\\s*\{' then (raw_user_metadata ->> 'custom_claims')::jsonb
      else '{}'::jsonb
    end as custom_claims_json,
    coalesce(raw_user_metadata ->> 'email_verified', '') as email_verified_text,
    coalesce(raw_user_metadata ->> 'phone_verified', '') as phone_verified_text
  from public.users
)
update public.users as u
set raw_app_metadata = jsonb_set(
      coalesce(u.raw_app_metadata, '{}'::jsonb),
      '{providers}',
      coalesce(n.providers_json, '[]'::jsonb),
      true
    ),
    raw_user_metadata = jsonb_set(
      jsonb_set(
        jsonb_set(
          coalesce(u.raw_user_metadata, '{}'::jsonb),
          '{custom_claims}',
          coalesce(n.custom_claims_json, '{}'::jsonb),
          true
        ),
        '{email_verified}',
        to_jsonb(
          coalesce(
            case
              when lower(nullif(n.email_verified_text, '')) in ('true','t','1','yes') then true
              when lower(nullif(n.email_verified_text, '')) in ('false','f','0','no') then false
              else null
            end,
            false
          )
        ),
        true
      ),
      '{phone_verified}',
      to_jsonb(
        coalesce(
          case
            when lower(nullif(n.phone_verified_text, '')) in ('true','t','1','yes') then true
            when lower(nullif(n.phone_verified_text, '')) in ('false','f','0','no') then false
            else null
          end,
          false
        )
      ),
      true
    )
from normalized n
where u.id = n.id;

update public.users
set raw_app_metadata = raw_app_metadata;

update public.users as u
set is_sso_user = coalesce(a.is_sso_user, false),
    is_anonymous = coalesce(a.is_anonymous, false),
    email_confirmed_at = a.email_confirmed_at
from auth.users as a
where u.id = a.id;

alter table public.users drop constraint if exists users_raw_app_metadata_providers_is_array;
alter table public.users drop constraint if exists users_raw_user_metadata_custom_claims_is_object;
alter table public.users drop constraint if exists users_raw_user_metadata_email_verified_is_boolean;
alter table public.users drop constraint if exists users_raw_user_metadata_phone_verified_is_boolean;

alter table public.users
  add constraint users_raw_app_metadata_providers_is_array
    check (
      not (raw_app_metadata ? 'providers')
      or jsonb_typeof(raw_app_metadata -> 'providers') = 'array'
    ),
  add constraint users_raw_user_metadata_custom_claims_is_object
    check (
      not (raw_user_metadata ? 'custom_claims')
      or jsonb_typeof(raw_user_metadata -> 'custom_claims') = 'object'
    ),
  add constraint users_raw_user_metadata_email_verified_is_boolean
    check (
      not (raw_user_metadata ? 'email_verified')
      or jsonb_typeof(raw_user_metadata -> 'email_verified') = 'boolean'
    ),
  add constraint users_raw_user_metadata_phone_verified_is_boolean
    check (
      not (raw_user_metadata ? 'phone_verified')
      or jsonb_typeof(raw_user_metadata -> 'phone_verified') = 'boolean'
    );

commit;
