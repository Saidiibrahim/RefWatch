-- Progress: Implemented

create table if not exists public.match_metrics (
  match_id uuid primary key references public.matches(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  regulation_minutes integer,
  half_time_minutes integer,
  extra_time_minutes integer,
  penalties_enabled boolean not null default false,
  total_goals integer not null default 0,
  total_cards integer not null default 0,
  total_penalties integer not null default 0,
  yellow_cards integer not null default 0,
  red_cards integer not null default 0,
  home_cards integer not null default 0,
  away_cards integer not null default 0,
  home_substitutions integer not null default 0,
  away_substitutions integer not null default 0,
  penalties_scored integer not null default 0,
  penalties_missed integer not null default 0,
  avg_added_time_seconds integer default 0,
  generated_at timestamptz not null default now()
);
create index if not exists idx_metrics_owner on public.match_metrics(owner_id);

create table if not exists public.trend_snapshots (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  metrics jsonb not null,
  generated_at timestamptz not null default now(),
  unique (owner_id, period_start, period_end)
);
