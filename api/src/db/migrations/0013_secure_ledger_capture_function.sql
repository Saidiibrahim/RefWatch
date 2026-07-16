ALTER FUNCTION refwatch_capture_mutation() SECURITY DEFINER;
--> statement-breakpoint
ALTER FUNCTION refwatch_capture_mutation() SET search_path = public, pg_temp;
