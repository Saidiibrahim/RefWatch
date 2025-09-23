-- Progress: Not yet implemented

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
create policy if not exists "share_owner_manage" on public.resource_shares for all using (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
);

alter table public.feedback_threads enable row level security;
create policy if not exists "threads_owner_or_grantee_read" on public.feedback_threads for select using (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
  or exists (
    select 1 from public.resource_shares rs
    join public.users u on rs.grantee_user_id = u.id
    where rs.resource_kind = feedback_threads.resource_kind
      and rs.resource_id = feedback_threads.resource_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

alter table public.feedback_items enable row level security;
create policy if not exists "items_thread_read" on public.feedback_items for select using (
  exists (
    select 1 from public.feedback_threads t
    join public.users u on t.owner_id = u.id
    where t.id = feedback_items.thread_id
      and (
        u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
        or exists (
          select 1 from public.resource_shares rs
          join public.users ug on rs.grantee_user_id = ug.id
          where rs.resource_kind = t.resource_kind and rs.resource_id = t.resource_id
            and ug.clerk_user_id = current_setting('request.jwt.claim.sub', true)
        )
      )
  )
);


