-- Progress: Implemented

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'match_status'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.match_status AS ENUM (
      ''scheduled'',
      ''in_progress'',
      ''completed'',
      ''canceled''
    )';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'official_role'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.official_role AS ENUM (''center'', ''assistant_1'', ''assistant_2'', ''fourth'')';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'match_event_type'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.match_event_type AS ENUM (
      ''kick_off'',
      ''period_start'', ''period_end'',
      ''half_time'',
      ''match_end'',
      ''stoppage_start'', ''stoppage_end'',
      ''goal'', ''goal_overruled'',
      ''card_yellow'', ''card_red'', ''card_second_yellow'',
      ''penalty_awarded'', ''penalty_scored'', ''penalty_missed'',
      ''penalties_start'', ''penalty_attempt'', ''penalties_end'',
      ''injury'', ''substitution'',
      ''note''
    )';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'match_team_side'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.match_team_side AS ENUM (''home'', ''away'')';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'assessment_mood'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.assessment_mood AS ENUM (''calm'', ''focused'', ''stressed'', ''fatigued'')';
  END IF;
END $$;
