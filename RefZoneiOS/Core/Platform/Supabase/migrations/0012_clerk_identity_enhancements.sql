-- Progress: Implemented

-- Ensure user UUIDs are generated server-side when omitted.
alter table public.users
  alter column id set default gen_random_uuid();

-- Extend the users table with Clerk profile + sync metadata.
alter table public.users
  add column if not exists primary_email text,
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists display_name text,
  add column if not exists image_url text,
  add column if not exists public_metadata jsonb not null default '{}'::jsonb,
  add column if not exists private_metadata jsonb not null default '{}'::jsonb,
  add column if not exists unsafe_metadata jsonb not null default '{}'::jsonb,
  add column if not exists clerk_created_at timestamptz,
  add column if not exists clerk_updated_at timestamptz,
  add column if not exists clerk_last_synced_at timestamptz not null default now(),
  add column if not exists last_active_at timestamptz,
  add column if not exists status text not null default 'active',
  add column if not exists deleted_at timestamptz,
  add column if not exists clerk_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists auth_methods jsonb not null default '[]'::jsonb;

-- Constrain status values to a known set.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_status_check'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_status_check CHECK (status in ('active', 'inactive', 'suspended'));
  END IF;
END $$;

-- Helpful indexes for profile lookups and stale user cleanup.
create index if not exists idx_users_primary_email on public.users(primary_email);
create index if not exists idx_users_last_active_at on public.users(last_active_at);
create index if not exists idx_users_status on public.users(status);

-- Rename legacy last_seen_at column to last_active_at if required.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_devices'
      AND column_name = 'last_seen_at'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_devices'
      AND column_name = 'last_active_at'
  ) THEN
    EXECUTE 'ALTER TABLE public.user_devices RENAME COLUMN last_seen_at TO last_active_at';
  END IF;
END $$;

-- Extend device tracking with Clerk session + client metadata.
alter table public.user_devices
  add column if not exists session_id text,
  add column if not exists client_name text,
  add column if not exists client_version text,
  add column if not exists ip_address inet,
  add column if not exists location jsonb not null default '{}'::jsonb,
  add column if not exists user_agent text,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

-- Backfill NULL session identifiers with generated values before enforcing NOT NULL.
update public.user_devices
set session_id = gen_random_uuid()::text
where session_id is null;

alter table public.user_devices
  alter column session_id set not null;

create unique index if not exists idx_user_devices_session_id on public.user_devices(session_id);
create index if not exists idx_user_devices_last_active_at on public.user_devices(last_active_at);

-- Allow authenticated clients to insert/update their own user rows directly.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_self_insert'
  ) THEN
    CREATE POLICY "users_self_insert" ON public.users
      FOR INSERT
      WITH CHECK (
        clerk_user_id = current_setting('request.jwt.claim.sub', true)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_self_update'
  ) THEN
    CREATE POLICY "users_self_update" ON public.users
      FOR UPDATE USING (
        clerk_user_id = current_setting('request.jwt.claim.sub', true)
      ) WITH CHECK (
        clerk_user_id = current_setting('request.jwt.claim.sub', true)
      );
  END IF;
END $$;

-- RPC helper: upsert a user row from Clerk profile payload.
create or replace function public.upsert_user_from_clerk(payload jsonb)
returns public.users
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub text := current_setting('request.jwt.claim.sub', true);
  v_payload jsonb := coalesce(jsonb_strip_nulls(payload), '{}'::jsonb);
  v_clerk_user_id text := coalesce(v_payload->>'clerk_user_id', v_payload->>'id');
  v_status text := coalesce(nullif(v_payload->>'status', ''), 'active');
  v_synced_at timestamptz := coalesce(nullif(v_payload->>'clerk_last_synced_at', '')::timestamptz, now());
  v_user public.users;
begin
  IF v_sub IS NULL OR v_sub = '' THEN
    RAISE EXCEPTION 'Missing Clerk subject (sub) in JWT context';
  END IF;

  IF v_clerk_user_id IS NULL THEN
    v_clerk_user_id := v_sub;
  END IF;

  IF v_clerk_user_id <> v_sub THEN
    RAISE EXCEPTION 'Clerk user id % does not match JWT subject %', v_clerk_user_id, v_sub;
  END IF;

  IF NOT (v_status = 'active' OR v_status = 'inactive' OR v_status = 'suspended') THEN
    RAISE EXCEPTION 'Invalid user status value: %', v_status;
  END IF;

  INSERT INTO public.users AS u (
    clerk_user_id,
    primary_email,
    first_name,
    last_name,
    display_name,
    image_url,
    public_metadata,
    private_metadata,
    unsafe_metadata,
    clerk_created_at,
    clerk_updated_at,
    clerk_last_synced_at,
    last_active_at,
    status,
    deleted_at,
    clerk_snapshot,
    auth_methods
  ) VALUES (
    v_clerk_user_id,
    nullif(v_payload->>'primary_email', ''),
    nullif(v_payload->>'first_name', ''),
    nullif(v_payload->>'last_name', ''),
    nullif(v_payload->>'display_name', ''),
    nullif(v_payload->>'image_url', ''),
    coalesce(v_payload->'public_metadata', '{}'::jsonb),
    coalesce(v_payload->'private_metadata', '{}'::jsonb),
    coalesce(v_payload->'unsafe_metadata', '{}'::jsonb),
    nullif(v_payload->>'clerk_created_at', '')::timestamptz,
    nullif(v_payload->>'clerk_updated_at', '')::timestamptz,
    v_synced_at,
    nullif(v_payload->>'last_active_at', '')::timestamptz,
    v_status,
    nullif(v_payload->>'deleted_at', '')::timestamptz,
    coalesce(v_payload->'clerk_snapshot', v_payload),
    coalesce(v_payload->'auth_methods', '[]'::jsonb)
  )
  ON CONFLICT (clerk_user_id) DO UPDATE
    SET primary_email = excluded.primary_email,
        first_name = excluded.first_name,
        last_name = excluded.last_name,
        display_name = excluded.display_name,
        image_url = excluded.image_url,
        public_metadata = excluded.public_metadata,
        private_metadata = excluded.private_metadata,
        unsafe_metadata = excluded.unsafe_metadata,
        clerk_created_at = coalesce(excluded.clerk_created_at, public.users.clerk_created_at),
        clerk_updated_at = coalesce(excluded.clerk_updated_at, public.users.clerk_updated_at),
        clerk_last_synced_at = excluded.clerk_last_synced_at,
        last_active_at = coalesce(excluded.last_active_at, public.users.last_active_at),
        status = excluded.status,
        deleted_at = excluded.deleted_at,
        clerk_snapshot = excluded.clerk_snapshot,
        auth_methods = excluded.auth_methods
  RETURNING u.* INTO v_user;

  RETURN v_user;
END;
$$;

revoke all on function public.upsert_user_from_clerk(jsonb) from public;
grant execute on function public.upsert_user_from_clerk(jsonb) to authenticated;
grant execute on function public.upsert_user_from_clerk(jsonb) to service_role;

-- RPC helper: upsert a Clerk session/device mapping.
create or replace function public.upsert_user_device_from_clerk(payload jsonb)
returns public.user_devices
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub text := current_setting('request.jwt.claim.sub', true);
  v_payload jsonb := coalesce(jsonb_strip_nulls(payload), '{}'::jsonb);
  v_session_id text := nullif(v_payload->>'session_id', '');
  v_device_id uuid := coalesce(nullif(v_payload->>'id', '')::uuid, gen_random_uuid());
  v_user_id uuid;
  v_record public.user_devices;
begin
  IF v_sub IS NULL OR v_sub = '' THEN
    RAISE EXCEPTION 'Missing Clerk subject (sub) in JWT context';
  END IF;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'Device payload requires a session_id';
  END IF;

  SELECT id INTO v_user_id
  FROM public.users
  WHERE clerk_user_id = v_sub
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No user row exists for Clerk id %', v_sub;
  END IF;

  INSERT INTO public.user_devices AS d (
    id,
    user_id,
    platform,
    model,
    app_version,
    client_name,
    client_version,
    session_id,
    ip_address,
    location,
    user_agent,
    last_active_at,
    metadata
  ) VALUES (
    v_device_id,
    v_user_id,
    nullif(v_payload->>'platform', ''),
    nullif(v_payload->>'model', ''),
    nullif(v_payload->>'app_version', ''),
    nullif(v_payload->>'client_name', ''),
    nullif(v_payload->>'client_version', ''),
    v_session_id,
    nullif(v_payload->>'ip_address', '')::inet,
    coalesce(v_payload->'location', '{}'::jsonb),
    nullif(v_payload->>'user_agent', ''),
    coalesce(nullif(v_payload->>'last_active_at', '')::timestamptz, now()),
    coalesce(v_payload->'metadata', '{}'::jsonb)
  )
  ON CONFLICT (session_id) DO UPDATE
    SET platform = excluded.platform,
        model = excluded.model,
        app_version = excluded.app_version,
        client_name = excluded.client_name,
        client_version = excluded.client_version,
        ip_address = excluded.ip_address,
        location = excluded.location,
        user_agent = excluded.user_agent,
        last_active_at = coalesce(excluded.last_active_at, public.user_devices.last_active_at),
        metadata = excluded.metadata,
        user_id = v_user_id
  RETURNING d.* INTO v_record;

  RETURN v_record;
END;
$$;

revoke all on function public.upsert_user_device_from_clerk(jsonb) from public;
grant execute on function public.upsert_user_device_from_clerk(jsonb) to authenticated;
grant execute on function public.upsert_user_device_from_clerk(jsonb) to service_role;
