-- Progress: Implemented

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'shared_resource_kind'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.shared_resource_kind AS ENUM (''match'', ''workout'')';
  END IF;
END $$;
