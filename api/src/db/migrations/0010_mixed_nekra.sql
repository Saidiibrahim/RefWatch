CREATE TABLE "mutation_entity_revisions" (
	"table_name" text NOT NULL,
	"entity_key" text NOT NULL,
	"revision" bigint DEFAULT 0 NOT NULL,
	CONSTRAINT "mutation_entity_revisions_table_name_entity_key_pk" PRIMARY KEY("table_name","entity_key")
);
--> statement-breakpoint
CREATE TABLE "mutation_ledger_epochs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"status" text DEFAULT 'preparing' NOT NULL,
	"capture_enforced" boolean DEFAULT false NOT NULL,
	"baseline_snapshot_id" text NOT NULL,
	"baseline_schema_hash" text NOT NULL,
	"baseline_data_hash" text NOT NULL,
	"opened_at" timestamp with time zone,
	"frozen_at" timestamp with time zone,
	"frozen_event_sequence" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mutation_ledger_epochs_status_check" CHECK ("mutation_ledger_epochs"."status" in ('preparing', 'open', 'frozen', 'archived')),
	CONSTRAINT "mutation_ledger_epochs_schema_hash_check" CHECK ("mutation_ledger_epochs"."baseline_schema_hash" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "mutation_ledger_epochs_data_hash_check" CHECK ("mutation_ledger_epochs"."baseline_data_hash" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE TABLE "mutation_outbox_deliveries" (
	"event_id" uuid PRIMARY KEY NOT NULL,
	"state" text DEFAULT 'pending' NOT NULL,
	"attempt_count" integer DEFAULT 0 NOT NULL,
	"lease_generation" bigint DEFAULT 0 NOT NULL,
	"leased_until" timestamp with time zone,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_error" text,
	"encrypted_envelope" text,
	"encryption_key_id" text,
	"encryption_nonce" text,
	"content_digest" text,
	"delivered_at" timestamp with time zone,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mutation_outbox_deliveries_state_check" CHECK ("mutation_outbox_deliveries"."state" in ('pending', 'leased', 'delivered', 'quarantined')),
	CONSTRAINT "mutation_outbox_deliveries_attempt_count_check" CHECK ("mutation_outbox_deliveries"."attempt_count" >= 0),
	CONSTRAINT "mutation_outbox_deliveries_lease_generation_check" CHECK ("mutation_outbox_deliveries"."lease_generation" >= 0)
);
--> statement-breakpoint
CREATE TABLE "mutation_outbox_events" (
	"event_id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"event_sequence" bigserial NOT NULL,
	"epoch_id" uuid NOT NULL,
	"mutation_group_id" uuid NOT NULL,
	"group_ordinal" integer NOT NULL,
	"table_name" text NOT NULL,
	"entity_key" text NOT NULL,
	"entity_revision" bigint NOT NULL,
	"operation" text NOT NULL,
	"before_json" jsonb,
	"after_json" jsonb,
	"source_kind" text NOT NULL,
	"source_event_id" text,
	"request_id" text NOT NULL,
	"idempotency_key" text,
	"app_user_id" uuid,
	"method" text,
	"path" text,
	"actor_id" text,
	"worker_version_id" text NOT NULL,
	"schema_version" integer DEFAULT 1 NOT NULL,
	"captured_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mutation_outbox_events_operation_check" CHECK ("mutation_outbox_events"."operation" in ('insert', 'update', 'delete')),
	CONSTRAINT "mutation_outbox_events_ordinal_check" CHECK ("mutation_outbox_events"."group_ordinal" > 0),
	CONSTRAINT "mutation_outbox_events_revision_check" CHECK ("mutation_outbox_events"."entity_revision" > 0),
	CONSTRAINT "mutation_outbox_events_schema_version_check" CHECK ("mutation_outbox_events"."schema_version" = 1)
);
--> statement-breakpoint
ALTER TABLE "mutation_outbox_deliveries" ADD CONSTRAINT "mutation_outbox_deliveries_event_id_mutation_outbox_events_event_id_fk" FOREIGN KEY ("event_id") REFERENCES "public"."mutation_outbox_events"("event_id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mutation_outbox_events" ADD CONSTRAINT "mutation_outbox_events_epoch_id_mutation_ledger_epochs_id_fk" FOREIGN KEY ("epoch_id") REFERENCES "public"."mutation_ledger_epochs"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "mutation_outbox_deliveries_dispatch_idx" ON "mutation_outbox_deliveries" USING btree ("state","next_attempt_at");--> statement-breakpoint
CREATE UNIQUE INDEX "mutation_outbox_events_sequence_uq" ON "mutation_outbox_events" USING btree ("event_sequence");--> statement-breakpoint
CREATE UNIQUE INDEX "mutation_outbox_events_group_ordinal_uq" ON "mutation_outbox_events" USING btree ("mutation_group_id","group_ordinal");--> statement-breakpoint
CREATE UNIQUE INDEX "mutation_outbox_events_entity_revision_uq" ON "mutation_outbox_events" USING btree ("table_name","entity_key","entity_revision");--> statement-breakpoint
CREATE INDEX "mutation_outbox_events_epoch_sequence_idx" ON "mutation_outbox_events" USING btree ("epoch_id","event_sequence");
--> statement-breakpoint
CREATE UNIQUE INDEX "mutation_ledger_epochs_enforced_uq"
ON "mutation_ledger_epochs" ((capture_enforced))
WHERE capture_enforced;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION refwatch_reject_mutation_event_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'mutation_outbox_events are immutable';
END;
$$;
--> statement-breakpoint
CREATE TRIGGER mutation_outbox_events_immutable
BEFORE UPDATE OR DELETE ON mutation_outbox_events
FOR EACH ROW EXECUTE FUNCTION refwatch_reject_mutation_event_changes();
--> statement-breakpoint
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
--> statement-breakpoint
CREATE TRIGGER mutation_ledger_epochs_protected
BEFORE UPDATE OR DELETE ON mutation_ledger_epochs
FOR EACH ROW EXECUTE FUNCTION refwatch_protect_ledger_epoch();
--> statement-breakpoint
CREATE OR REPLACE FUNCTION refwatch_capture_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  ledger_lock_key CONSTANT bigint := 593105010451970337;
  active_epoch mutation_ledger_epochs%ROWTYPE;
  row_data jsonb;
  entity_key_json jsonb := '{}'::jsonb;
  entity_key_value text;
  next_revision bigint;
  next_ordinal integer;
  context_value text;
  inserted_event_id uuid;
  i integer;
BEGIN
  -- The trigger itself participates in the freeze barrier. This makes capture and
  -- freeze enforcement apply to ordinary direct SQL, not only cooperative callers.
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
--> statement-breakpoint
CREATE TRIGGER app_users_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON app_users FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER clerk_user_deletion_tombstones_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON clerk_user_deletion_tombstones FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('clerk_instance_id', 'clerk_user_id');
CREATE TRIGGER user_devices_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON user_devices FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER teams_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON teams FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER team_members_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON team_members FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER team_officials_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON team_officials FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER team_tags_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON team_tags FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('team_id', 'value');
CREATE TRIGGER competitions_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON competitions FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER venues_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON venues FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER scheduled_matches_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON scheduled_matches FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER matches_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON matches FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER match_periods_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON match_periods FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER match_events_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON match_events FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER match_metrics_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON match_metrics FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('match_id');
CREATE TRIGGER match_assessments_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON match_assessments FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER pages_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON pages FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER workout_presets_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON workout_presets FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER workout_sessions_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON workout_sessions FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER ai_threads_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON ai_threads FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER ai_messages_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON ai_messages FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER ai_attachments_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON ai_attachments FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('id');
CREATE TRIGGER ai_usage_daily_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON ai_usage_daily FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('owner_id', 'on_date', 'model');
