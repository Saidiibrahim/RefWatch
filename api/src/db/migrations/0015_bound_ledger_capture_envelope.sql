CREATE OR REPLACE FUNCTION refwatch_capture_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  ledger_lock_key CONSTANT bigint := 593105010451970337;
  -- PostgreSQL jsonb text includes separator whitespace that the canonical
  -- Worker JSON omits. Keeping a further 16 KiB below the 256 KiB Worker
  -- ceiling also covers the generated identifiers, sequence/revision maxima,
  -- timestamp, and any serialization variance.
  maximum_capture_envelope_bytes CONSTANT integer := 245760;
  active_epoch mutation_ledger_epochs%ROWTYPE;
  row_data jsonb;
  entity_key_json jsonb := '{}'::jsonb;
  entity_key_value text;
  next_revision bigint;
  next_ordinal integer;
  context_value text;
  prospective_envelope jsonb;
  prospective_envelope_bytes integer;
  inserted_event_id uuid;
  i integer;
BEGIN
  PERFORM pg_advisory_xact_lock_shared(ledger_lock_key);
  SELECT * INTO active_epoch
  FROM mutation_ledger_epochs
  WHERE capture_enforced
  LIMIT 1;

  IF NOT FOUND THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;
  IF active_epoch.status <> 'open' THEN
    RAISE EXCEPTION 'mutation ledger epoch is %, writes are frozen', active_epoch.status;
  END IF;

  IF TG_OP = 'UPDATE' AND to_jsonb(OLD) = to_jsonb(NEW) THEN
    RETURN NEW;
  END IF;

  row_data := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
  IF TG_NARGS = 0 THEN
    RAISE EXCEPTION 'mutation capture trigger for % has no entity-key columns', TG_TABLE_NAME;
  END IF;
  FOR i IN 0..TG_NARGS - 1 LOOP
    IF NOT (row_data ? TG_ARGV[i]) THEN
      RAISE EXCEPTION 'mutation capture key % is absent from %', TG_ARGV[i], TG_TABLE_NAME;
    END IF;
    entity_key_json := entity_key_json || jsonb_build_object(TG_ARGV[i], row_data -> TG_ARGV[i]);
  END LOOP;
  entity_key_value := entity_key_json::text;

  context_value := nullif(current_setting('refwatch.mutation_group_id', true), '');
  IF context_value IS NULL THEN RAISE EXCEPTION 'missing refwatch.mutation_group_id'; END IF;
  next_ordinal := coalesce(nullif(current_setting('refwatch.group_ordinal', true), '')::integer, 0) + 1;

  prospective_envelope := jsonb_build_object(
    'schema_version', 1,
    'event_id', '00000000-0000-0000-0000-000000000000',
    'event_sequence', 9223372036854775807::bigint,
    'epoch_id', active_epoch.id,
    'mutation_group_id', context_value::uuid,
    'group_ordinal', next_ordinal,
    'entity_type', TG_TABLE_NAME,
    'entity_id', entity_key_value,
    'entity_revision', 9223372036854775807::bigint,
    'operation', lower(TG_OP),
    'before', CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    'after', CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
    'source_kind', nullif(current_setting('refwatch.source_kind', true), ''),
    'source_event_id', nullif(current_setting('refwatch.source_event_id', true), ''),
    'request_id', nullif(current_setting('refwatch.request_id', true), ''),
    'idempotency_key', nullif(current_setting('refwatch.idempotency_key', true), ''),
    'app_user_id', nullif(current_setting('refwatch.app_user_id', true), '')::uuid,
    'method', nullif(current_setting('refwatch.method', true), ''),
    'path', nullif(current_setting('refwatch.path', true), ''),
    'actor_id', nullif(current_setting('refwatch.actor_id', true), ''),
    'worker_version_id', nullif(current_setting('refwatch.worker_version_id', true), ''),
    'captured_at_utc', '9999-12-31T23:59:59.999Z'
  );
  prospective_envelope_bytes := octet_length(prospective_envelope::text);
  IF prospective_envelope_bytes > maximum_capture_envelope_bytes THEN
    RAISE EXCEPTION 'mutation ledger envelope exceeds transactional capture limit'
      USING ERRCODE = '22001';
  END IF;

  PERFORM set_config('refwatch.group_ordinal', next_ordinal::text, true);
  INSERT INTO mutation_entity_revisions (table_name, entity_key, revision)
  VALUES (TG_TABLE_NAME, entity_key_value, 1)
  ON CONFLICT (table_name, entity_key)
  DO UPDATE SET revision = mutation_entity_revisions.revision + 1
  RETURNING revision INTO next_revision;

  INSERT INTO mutation_outbox_events (
    epoch_id, mutation_group_id, group_ordinal, table_name, entity_key,
    entity_revision, operation, before_json, after_json, source_kind,
    source_event_id, request_id, idempotency_key, app_user_id, method, path,
    actor_id, worker_version_id
  ) VALUES (
    active_epoch.id,
    context_value::uuid,
    next_ordinal,
    TG_TABLE_NAME,
    entity_key_value,
    next_revision,
    lower(TG_OP),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
    nullif(current_setting('refwatch.source_kind', true), ''),
    nullif(current_setting('refwatch.source_event_id', true), ''),
    nullif(current_setting('refwatch.request_id', true), ''),
    nullif(current_setting('refwatch.idempotency_key', true), ''),
    nullif(current_setting('refwatch.app_user_id', true), '')::uuid,
    nullif(current_setting('refwatch.method', true), ''),
    nullif(current_setting('refwatch.path', true), ''),
    nullif(current_setting('refwatch.actor_id', true), ''),
    nullif(current_setting('refwatch.worker_version_id', true), '')
  ) RETURNING event_id INTO inserted_event_id;

  IF nullif(current_setting('refwatch.source_kind', true), '') IS NULL OR
     nullif(current_setting('refwatch.request_id', true), '') IS NULL OR
     nullif(current_setting('refwatch.worker_version_id', true), '') IS NULL THEN
    RAISE EXCEPTION 'incomplete mutation capture context';
  END IF;

  INSERT INTO mutation_outbox_deliveries (event_id) VALUES (inserted_event_id);
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;
