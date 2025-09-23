-- Progress: Not yet implemented

create table if not exists public.teams (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  short_name text,
  color_primary text,
  color_secondary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.team_members (
  id uuid primary key,
  team_id uuid not null references public.teams(id) on delete cascade,
  display_name text not null,
  jersey_number text,
  role text,
  created_at timestamptz not null default now()
);

create table if not exists public.team_tags (
  team_id uuid not null references public.teams(id) on delete cascade,
  tag text not null,
  primary key (team_id, tag)
);

create table if not exists public.competitions (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  level text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.venues (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  city text,
  country text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.teams enable row level security;
create policy if not exists "teams_own_rows" on public.teams for all using (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
) with check (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
);


