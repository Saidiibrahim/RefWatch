CREATE OR REPLACE FUNCTION protect_activated_identity_registry()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || OLD.clerk_instance_id, 0));
  END IF;
  IF TG_OP <> 'DELETE' AND (TG_OP = 'INSERT' OR NEW.clerk_instance_id IS DISTINCT FROM OLD.clerk_instance_id) THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || NEW.clerk_instance_id, 0));
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
$$;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION protect_activated_legacy_app_user_identity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  mapping record;
BEGIN
  IF TG_OP = 'DELETE' OR NEW.id IS DISTINCT FROM OLD.id OR NEW.clerk_user_id IS DISTINCT FROM OLD.clerk_user_id THEN
    FOR mapping IN
      SELECT mappings.clerk_instance_id, mappings.receipt_digest
      FROM identity_reconciliation_legacy_mappings mappings
      WHERE mappings.app_user_id = OLD.id
      ORDER BY mappings.clerk_instance_id
    LOOP
      PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || mapping.clerk_instance_id, 0));
      IF EXISTS (
        SELECT 1 FROM identity_reconciliation_activations
        WHERE receipt_digest = mapping.receipt_digest
      ) THEN
        RAISE EXCEPTION 'activated legacy app user identity is immutable';
      END IF;
    END LOOP;
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;
--> statement-breakpoint
CREATE FUNCTION validate_and_protect_identity_activation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  receipt identity_reconciliation_receipts%ROWTYPE;
  registry_count bigint;
  mismatched_count bigint;
  canonical_mappings text;
  current_mapping_hash text;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'identity reconciliation activations are immutable';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('reconciliation:' || NEW.clerk_instance_id, 0));
  SELECT * INTO receipt
  FROM identity_reconciliation_receipts
  WHERE receipt_digest = NEW.receipt_digest
    AND clerk_instance_id = NEW.clerk_instance_id
    AND status = 'verified';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'identity reconciliation activation has no matching verified receipt';
  END IF;

  SELECT count(*), count(*) FILTER (WHERE users.id IS NULL OR users.clerk_user_id IS DISTINCT FROM mappings.clerk_user_id)
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
  RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER identity_reconciliation_activations_validated_immutable
BEFORE INSERT OR UPDATE OR DELETE ON identity_reconciliation_activations
FOR EACH ROW EXECUTE FUNCTION validate_and_protect_identity_activation();
