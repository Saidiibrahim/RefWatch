-- Progress: Implemented

create table if not exists public.match_assessments (
  id uuid primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  mood assessment_mood,
  rating integer check (rating between 1 and 5),
  overall text,
  went_well text,
  to_improve text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, owner_id)
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_assess'
      AND tgrelid = 'public.match_assessments'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_assess BEFORE UPDATE ON public.match_assessments
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;
