CREATE TABLE "clerk_webhook_delivery_receipts" (
	"clerk_instance_id" text NOT NULL,
	"svix_id" text NOT NULL,
	"event_type" text NOT NULL,
	"clerk_user_id" text NOT NULL,
	"payload_hash" text NOT NULL,
	"processed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "clerk_webhook_delivery_receipts_clerk_instance_id_svix_id_pk" PRIMARY KEY("clerk_instance_id","svix_id"),
	CONSTRAINT "clerk_webhook_delivery_receipts_event_type_check" CHECK ("clerk_webhook_delivery_receipts"."event_type" in ('user.created', 'user.updated', 'user.deleted')),
	CONSTRAINT "clerk_webhook_delivery_receipts_payload_hash_check" CHECK ("clerk_webhook_delivery_receipts"."payload_hash" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE FUNCTION protect_clerk_webhook_delivery_receipt()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'processed Clerk webhook delivery receipts are immutable';
END;
$$;--> statement-breakpoint
CREATE TRIGGER clerk_webhook_delivery_receipts_immutable
BEFORE UPDATE OR DELETE ON clerk_webhook_delivery_receipts
FOR EACH ROW EXECUTE FUNCTION protect_clerk_webhook_delivery_receipt();--> statement-breakpoint
CREATE TRIGGER clerk_webhook_delivery_receipts_mutation_capture AFTER INSERT OR UPDATE OR DELETE ON clerk_webhook_delivery_receipts FOR EACH ROW EXECUTE FUNCTION refwatch_capture_mutation('clerk_instance_id', 'svix_id');--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" DROP CONSTRAINT "identity_reconciliation_receipts_mapping_count_check";--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" ADD COLUMN "reconciliation_profile" text DEFAULT 'stateful_migration_v1' NOT NULL;--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" ADD COLUMN "authorization_profile" text;--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" ADD COLUMN "authorization_digest" text;--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" ADD COLUMN "clerk_issuer" text;--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" ADD COLUMN "clerk_domain" text;--> statement-breakpoint
CREATE UNIQUE INDEX "identity_reconciliation_activations_instance_uq" ON "identity_reconciliation_activations" USING btree ("clerk_instance_id");--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" ADD CONSTRAINT "identity_reconciliation_receipts_authorization_digest_check" CHECK ("identity_reconciliation_receipts"."authorization_digest" is null or "identity_reconciliation_receipts"."authorization_digest" ~ '^[0-9a-f]{64}$');--> statement-breakpoint
ALTER TABLE "identity_reconciliation_receipts" ADD CONSTRAINT "identity_reconciliation_receipts_profile_check" CHECK ((
      "identity_reconciliation_receipts"."reconciliation_profile" = 'stateful_migration_v1'
      and "identity_reconciliation_receipts"."legacy_mapping_count" > 0
      and "identity_reconciliation_receipts"."excluded_auth_count" >= 0
      and "identity_reconciliation_receipts"."authorization_profile" is null
      and "identity_reconciliation_receipts"."authorization_digest" is null
      and "identity_reconciliation_receipts"."clerk_issuer" is null
      and "identity_reconciliation_receipts"."clerk_domain" is null
    ) or (
      "identity_reconciliation_receipts"."reconciliation_profile" = 'greenfield_zero_legacy_v1'
      and "identity_reconciliation_receipts"."receipt_digest" = '27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18'
      and "identity_reconciliation_receipts"."clerk_instance_id" = 'ins_3GWFGUd1rI6hx5lWlUxMYAkxdac'
      and "identity_reconciliation_receipts"."authorization_profile" = 'refwatch.greenfield-authorization.v1'
      and "identity_reconciliation_receipts"."authorization_digest" = '17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b'
      and "identity_reconciliation_receipts"."clerk_issuer" = 'https://clerk.refwatch.ibby.ai'
      and "identity_reconciliation_receipts"."clerk_domain" = 'refwatch.ibby.ai'
      and "identity_reconciliation_receipts"."legacy_mapping_count" = 0
      and "identity_reconciliation_receipts"."excluded_auth_count" = 0
      and "identity_reconciliation_receipts"."mapping_hash" = '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945'
    ));--> statement-breakpoint
CREATE FUNCTION protect_activated_identity_reconciliation_receipt()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || OLD.clerk_instance_id, 0));
  IF EXISTS (
    SELECT 1
    FROM identity_reconciliation_activations
    WHERE receipt_digest = OLD.receipt_digest
  ) THEN
    RAISE EXCEPTION 'activated identity reconciliation receipts are immutable';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;--> statement-breakpoint
CREATE TRIGGER identity_reconciliation_receipts_activated_immutable
BEFORE UPDATE OR DELETE ON identity_reconciliation_receipts
FOR EACH ROW EXECUTE FUNCTION protect_activated_identity_reconciliation_receipt();--> statement-breakpoint
CREATE FUNCTION guard_greenfield_app_user_bootstrap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(
    hashtextextended('reconciliation:ins_3GWFGUd1rI6hx5lWlUxMYAkxdac', 0)
  );
  IF EXISTS (
    SELECT 1
    FROM identity_reconciliation_receipts
    WHERE receipt_digest = '27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18'
      AND clerk_instance_id = 'ins_3GWFGUd1rI6hx5lWlUxMYAkxdac'
      AND reconciliation_profile = 'greenfield_zero_legacy_v1'
      AND status = 'verified'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM identity_reconciliation_activations
      WHERE receipt_digest = '27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18'
        AND clerk_instance_id = 'ins_3GWFGUd1rI6hx5lWlUxMYAkxdac'
    ) THEN
      RAISE EXCEPTION 'greenfield app users require an activated zero-legacy receipt';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;--> statement-breakpoint
CREATE TRIGGER app_users_greenfield_bootstrap_guard
BEFORE INSERT ON app_users
FOR EACH ROW EXECUTE FUNCTION guard_greenfield_app_user_bootstrap();--> statement-breakpoint
CREATE OR REPLACE FUNCTION protect_activated_identity_registry()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || NEW.clerk_instance_id, 0));
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || OLD.clerk_instance_id, 0));
  ELSIF OLD.clerk_instance_id <= NEW.clerk_instance_id THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || OLD.clerk_instance_id, 0));
    IF NEW.clerk_instance_id IS DISTINCT FROM OLD.clerk_instance_id THEN
      PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || NEW.clerk_instance_id, 0));
    END IF;
  ELSE
    PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || NEW.clerk_instance_id, 0));
    PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || OLD.clerk_instance_id, 0));
  END IF;

  IF TG_OP <> 'DELETE' AND EXISTS (
    SELECT 1
    FROM identity_reconciliation_receipts
    WHERE receipt_digest = NEW.receipt_digest
      AND reconciliation_profile = 'greenfield_zero_legacy_v1'
  ) THEN
    RAISE EXCEPTION 'greenfield zero-legacy receipts cannot have legacy mappings';
  END IF;

  IF (
    TG_OP <> 'INSERT'
    AND EXISTS (
      SELECT 1
      FROM identity_reconciliation_activations activations
      INNER JOIN identity_reconciliation_receipts receipts
        ON receipts.receipt_digest = activations.receipt_digest
      WHERE activations.clerk_instance_id = OLD.clerk_instance_id
        AND receipts.reconciliation_profile = 'greenfield_zero_legacy_v1'
    )
  ) OR (
    TG_OP <> 'DELETE'
    AND EXISTS (
      SELECT 1
      FROM identity_reconciliation_activations activations
      INNER JOIN identity_reconciliation_receipts receipts
        ON receipts.receipt_digest = activations.receipt_digest
      WHERE activations.clerk_instance_id = NEW.clerk_instance_id
        AND receipts.reconciliation_profile = 'greenfield_zero_legacy_v1'
    )
  ) THEN
    RAISE EXCEPTION 'activated greenfield instances cannot have legacy mappings';
  END IF;

  IF (
    TG_OP <> 'INSERT'
    AND EXISTS (
      SELECT 1 FROM identity_reconciliation_activations
      WHERE receipt_digest = OLD.receipt_digest
    )
  ) OR (
    TG_OP <> 'DELETE'
    AND EXISTS (
      SELECT 1 FROM identity_reconciliation_activations
      WHERE receipt_digest = NEW.receipt_digest
    )
  ) THEN
    RAISE EXCEPTION 'activated identity reconciliation mappings are immutable';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;--> statement-breakpoint
CREATE OR REPLACE FUNCTION validate_and_protect_identity_activation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  receipt identity_reconciliation_receipts%ROWTYPE;
  registry_count bigint;
  mismatched_count bigint;
  canonical_mappings text;
  current_mapping_hash text;
  instance_mapping_count bigint;
  app_user_count bigint;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'identity reconciliation activations are immutable';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || NEW.clerk_instance_id, 0));
  IF EXISTS (
    SELECT 1
    FROM identity_reconciliation_activations
    WHERE receipt_digest = NEW.receipt_digest
      AND clerk_instance_id = NEW.clerk_instance_id
  ) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO receipt
  FROM identity_reconciliation_receipts
  WHERE receipt_digest = NEW.receipt_digest
    AND clerk_instance_id = NEW.clerk_instance_id
    AND status = 'verified';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'identity reconciliation activation has no matching verified receipt';
  END IF;

  IF receipt.reconciliation_profile = 'stateful_migration_v1' THEN
    SELECT count(*), count(*) FILTER (
      WHERE users.id IS NULL OR users.clerk_user_id IS DISTINCT FROM mappings.clerk_user_id
    )
    INTO registry_count, mismatched_count
    FROM identity_reconciliation_legacy_mappings mappings
    LEFT JOIN app_users users ON users.id = mappings.app_user_id
    WHERE mappings.receipt_digest = NEW.receipt_digest
      AND mappings.clerk_instance_id = NEW.clerk_instance_id;
    IF registry_count <> receipt.legacy_mapping_count OR mismatched_count <> 0 THEN
      RAISE EXCEPTION 'identity reconciliation activation registry is incomplete or mismatched';
    END IF;

    SELECT '[' || COALESCE(string_agg(
      '{"app_user_id":' || to_json(mappings.app_user_id::text)::text
        || ',"clerk_user_id":' || to_json(mappings.clerk_user_id)::text || '}',
      ',' ORDER BY mappings.app_user_id
    ), '') || ']'
    INTO canonical_mappings
    FROM identity_reconciliation_legacy_mappings mappings
    WHERE mappings.receipt_digest = NEW.receipt_digest
      AND mappings.clerk_instance_id = NEW.clerk_instance_id;
    current_mapping_hash := encode(sha256(convert_to(canonical_mappings, 'UTF8')), 'hex');
    IF current_mapping_hash IS DISTINCT FROM receipt.mapping_hash THEN
      RAISE EXCEPTION 'identity reconciliation activation mapping hash mismatch';
    END IF;
  ELSIF receipt.reconciliation_profile = 'greenfield_zero_legacy_v1' THEN
    IF receipt.receipt_digest IS DISTINCT FROM '27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18'
      OR receipt.clerk_instance_id IS DISTINCT FROM 'ins_3GWFGUd1rI6hx5lWlUxMYAkxdac'
      OR receipt.authorization_profile IS DISTINCT FROM 'refwatch.greenfield-authorization.v1'
      OR receipt.authorization_digest IS DISTINCT FROM '17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b'
      OR receipt.clerk_issuer IS DISTINCT FROM 'https://clerk.refwatch.ibby.ai'
      OR receipt.clerk_domain IS DISTINCT FROM 'refwatch.ibby.ai'
      OR receipt.legacy_mapping_count IS DISTINCT FROM 0
      OR receipt.excluded_auth_count IS DISTINCT FROM 0
      OR receipt.mapping_hash IS DISTINCT FROM '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945'
    THEN
      RAISE EXCEPTION 'greenfield identity reconciliation activation provenance is invalid';
    END IF;

    SELECT count(*) INTO instance_mapping_count
    FROM identity_reconciliation_legacy_mappings
    WHERE clerk_instance_id = NEW.clerk_instance_id;
    IF instance_mapping_count <> 0 THEN
      RAISE EXCEPTION 'greenfield identity reconciliation activation requires zero legacy mappings';
    END IF;

    canonical_mappings := '[]';
    current_mapping_hash := encode(sha256(convert_to(canonical_mappings, 'UTF8')), 'hex');
    IF current_mapping_hash IS DISTINCT FROM receipt.mapping_hash THEN
      RAISE EXCEPTION 'greenfield identity reconciliation activation mapping hash mismatch';
    END IF;

    SELECT count(*) INTO app_user_count FROM app_users;
    IF app_user_count <> 0 THEN
      RAISE EXCEPTION 'greenfield identity reconciliation activation requires zero app users';
    END IF;
  ELSE
    RAISE EXCEPTION 'identity reconciliation activation profile is unsupported';
  END IF;

  RETURN NEW;
END;
$$;
