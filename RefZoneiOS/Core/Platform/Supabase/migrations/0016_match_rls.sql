-- Progress: Implemented
-- Purpose: Enforce row level security on match lifecycle tables and add supporting indexes.

alter table if exists public.matches enable row level security;
alter table if exists public.match_periods enable row level security;
alter table if exists public.match_metrics enable row level security;

-- Owner-based policies for matches
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'matches'
      AND policyname = 'match_owner_select'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "match_owner_select" ON public.matches
        FOR SELECT USING (owner_id = auth.uid());
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'matches'
      AND policyname = 'match_owner_modify'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "match_owner_modify" ON public.matches
        FOR ALL USING (owner_id = auth.uid())
        WITH CHECK (owner_id = auth.uid());
    $policy$;
  END IF;
END $$;

-- Policies for match_periods deriving ownership from parent match
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'match_periods'
      AND policyname = 'periods_via_match_owner'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "periods_via_match_owner" ON public.match_periods
        FOR SELECT USING (
          EXISTS (
            SELECT 1
            FROM public.matches m
            WHERE m.id = match_periods.match_id
              AND m.owner_id = auth.uid()
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
      AND tablename = 'match_periods'
      AND policyname = 'periods_via_match_owner_modify'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "periods_via_match_owner_modify" ON public.match_periods
        FOR ALL USING (
          EXISTS (
            SELECT 1
            FROM public.matches m
            WHERE m.id = match_periods.match_id
              AND m.owner_id = auth.uid()
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM public.matches m
            WHERE m.id = match_periods.match_id
              AND m.owner_id = auth.uid()
          )
        );
    $policy$;
  END IF;
END $$;

-- Policies for match_metrics deriving ownership from related match
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'match_metrics'
      AND policyname = 'metrics_owner_select'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "metrics_owner_select" ON public.match_metrics
        FOR SELECT USING (owner_id = auth.uid());
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'match_metrics'
      AND policyname = 'metrics_owner_modify'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "metrics_owner_modify" ON public.match_metrics
        FOR ALL USING (owner_id = auth.uid())
        WITH CHECK (owner_id = auth.uid());
    $policy$;
  END IF;
END $$;

-- Supporting indexes for sync flows
create index if not exists idx_matches_owner_updated on public.matches(owner_id, updated_at desc);
create index if not exists idx_match_periods_match_created on public.match_periods(match_id, created_at desc);
create index if not exists idx_match_metrics_owner_generated on public.match_metrics(owner_id, generated_at desc);
