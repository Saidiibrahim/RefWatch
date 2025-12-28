-- Progress: Implemented

create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create table if not exists public.users (
  id uuid primary key,
  clerk_user_id text unique not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_devices (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  platform text not null,
  model text,
  app_version text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_users_clerk_user_id on public.users(clerk_user_id);
create index if not exists idx_user_devices_user_id on public.user_devices(user_id);

alter table public.users enable row level security;

alter table public.user_devices enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_self'
  ) THEN
    CREATE POLICY "users_self" ON public.users
      FOR SELECT USING (
        clerk_user_id = current_setting('request.jwt.claim.sub', true)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_devices'
      AND policyname = 'user_devices_self'
  ) THEN
    CREATE POLICY "user_devices_self" ON public.user_devices
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM public.users u
          WHERE u.id = user_devices.user_id
            AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
        )
      ) WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.users u
          WHERE u.id = user_devices.user_id
            AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_users'
      AND tgrelid = 'public.users'::regclass
  ) THEN
    CREATE TRIGGER t_upd_users BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_user_devices'
      AND tgrelid = 'public.user_devices'::regclass
  ) THEN
    CREATE TRIGGER t_upd_user_devices BEFORE UPDATE ON public.user_devices
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
