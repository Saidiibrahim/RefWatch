-- Progress: Implemented

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'workout_state'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.workout_state AS ENUM (''planned'', ''active'', ''paused'', ''ended'', ''aborted'')';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'workout_kind'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.workout_kind AS ENUM (
      ''outdoorRun'', ''outdoorWalk'', ''indoorRun'', ''indoorCycle'', ''strength'', ''mobility'', ''refereeDrill'', ''custom''
    )';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'workout_segment_purpose'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.workout_segment_purpose AS ENUM (''warmup'', ''work'', ''recovery'', ''cooldown'', ''free'')';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'workout_metric_kind'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.workout_metric_kind AS ENUM (
      ''distance'', ''duration'', ''averagePace'', ''averageSpeed'', ''averageHeartRate'', ''maximumHeartRate'', ''calories'', ''elevationGain'', ''cadence'', ''power'', ''perceivedExertion''
    )';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'workout_metric_unit'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.workout_metric_unit AS ENUM (
      ''meters'', ''kilometers'', ''seconds'', ''minutes'', ''minutesPerKilometer'', ''kilometersPerHour'', ''beatsPerMinute'', ''kilocalories'', ''metersClimbed'', ''stepsPerMinute'', ''watts'', ''ratingOfPerceivedExertion''
    )';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'workout_intensity_zone'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.workout_intensity_zone AS ENUM (''recovery'', ''aerobic'', ''tempo'', ''threshold'', ''anaerobic'')';
  END IF;
END $$;
