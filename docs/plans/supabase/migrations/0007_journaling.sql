-- Progress: Not yet implemented

create table if not exists public.match_assessments (
  id uuid primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  mood assessment_mood,
  rating integer check (rating between 1 and 10),
  notes text,
  incidents text,
  fitness text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, owner_id)
);

create trigger if not exists t_upd_assess before update on public.match_assessments
for each row execute function set_updated_at();


