CREATE OR REPLACE FUNCTION refwatch_protect_ledger_epoch()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'mutation ledger epochs cannot be deleted';
  END IF;
  IF OLD.status IN ('open', 'frozen', 'archived') AND (
    NEW.baseline_snapshot_id IS DISTINCT FROM OLD.baseline_snapshot_id OR
    NEW.baseline_schema_hash IS DISTINCT FROM OLD.baseline_schema_hash OR
    NEW.baseline_data_hash IS DISTINCT FROM OLD.baseline_data_hash OR
    NEW.opened_at IS DISTINCT FROM OLD.opened_at OR
    (OLD.capture_enforced AND NOT NEW.capture_enforced AND NOT (OLD.status = 'frozen' AND NEW.status = 'archived'))
  ) THEN
    RAISE EXCEPTION 'opened mutation ledger epoch baseline is immutable';
  END IF;
  IF OLD.status = 'open' AND NEW.status NOT IN ('open', 'frozen') THEN
    RAISE EXCEPTION 'open mutation ledger epoch can only transition to frozen';
  END IF;
  IF OLD.status = 'frozen' AND NEW.status NOT IN ('frozen', 'archived') THEN
    RAISE EXCEPTION 'frozen mutation ledger epoch can only transition to archived';
  END IF;
  IF OLD.status = 'frozen' AND NEW.status = 'archived' AND NEW.capture_enforced THEN
    RAISE EXCEPTION 'archiving a mutation ledger epoch must disable capture enforcement';
  END IF;
  IF OLD.status = 'archived' AND NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION 'archived mutation ledger epoch is immutable';
  END IF;
  RETURN NEW;
END;
$$;
