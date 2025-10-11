-- Progress: Implemented

create table if not exists public.coaches (
  id uuid primary key,
  user_id uuid unique references public.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.resource_shares (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  resource_kind shared_resource_kind not null,
  resource_id uuid not null,
  grantee_user_id uuid not null references public.users(id) on delete cascade,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (resource_kind, resource_id, grantee_user_id)
);

create table if not exists public.feedback_threads (
  id uuid primary key,
  resource_kind shared_resource_kind not null,
  resource_id uuid not null,
  owner_id uuid not null references public.users(id) on delete cascade,
  title text,
  created_at timestamptz not null default now()
);

create table if not exists public.feedback_items (
  id uuid primary key,
  thread_id uuid not null references public.feedback_threads(id) on delete cascade,
  author_user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  body text not null,
  annotations jsonb
);

create table if not exists public.feedback_attachments (
  id uuid primary key,
  item_id uuid not null references public.feedback_items(id) on delete cascade,
  storage_path text not null,
  content_type text,
  byte_size integer,
  created_at timestamptz not null default now()
);

alter table public.resource_shares enable row level security;
alter table public.feedback_threads enable row level security;
alter table public.feedback_items enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'resource_shares'
      AND policyname = 'share_owner_manage'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "share_owner_manage" ON public.resource_shares
        FOR ALL USING (
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
      AND tablename = 'feedback_threads'
      AND policyname = 'threads_owner_or_grantee_read'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "threads_owner_or_grantee_read" ON public.feedback_threads
        FOR SELECT USING (
          owner_id IN (
            SELECT id FROM public.users
            WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
          OR EXISTS (
            SELECT 1
            FROM public.resource_shares rs
            JOIN public.users u ON rs.grantee_user_id = u.id
            WHERE rs.resource_kind = feedback_threads.resource_kind
              AND rs.resource_id = feedback_threads.resource_id
              AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
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
      AND tablename = 'feedback_items'
      AND policyname = 'items_thread_read'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "items_thread_read" ON public.feedback_items
        FOR SELECT USING (
          EXISTS (
            SELECT 1
            FROM public.feedback_threads t
            JOIN public.users u ON t.owner_id = u.id
            WHERE t.id = feedback_items.thread_id
              AND (
                u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
                OR EXISTS (
                  SELECT 1
                  FROM public.resource_shares rs
                  JOIN public.users ug ON rs.grantee_user_id = ug.id
                  WHERE rs.resource_kind = t.resource_kind
                    AND rs.resource_id = t.resource_id
                    AND ug.clerk_user_id = current_setting('request.jwt.claim.sub', true)
                )
              )
          )
        );
    $policy$;
  END IF;
END $$;
