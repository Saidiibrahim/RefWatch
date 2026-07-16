CREATE FUNCTION protect_activated_identity_registry()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  target_receipt text;
BEGIN
  target_receipt := CASE WHEN TG_OP = 'DELETE' THEN OLD.receipt_digest ELSE NEW.receipt_digest END;
  IF EXISTS (
    SELECT 1 FROM identity_reconciliation_activations
    WHERE receipt_digest = target_receipt
  ) THEN
    RAISE EXCEPTION 'activated identity reconciliation mappings are immutable';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER identity_reconciliation_legacy_mappings_immutable
BEFORE INSERT OR UPDATE OR DELETE ON identity_reconciliation_legacy_mappings
FOR EACH ROW EXECUTE FUNCTION protect_activated_identity_registry();
--> statement-breakpoint
CREATE FUNCTION protect_activated_legacy_app_user_identity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (
    TG_OP = 'DELETE'
    OR NEW.id IS DISTINCT FROM OLD.id
    OR NEW.clerk_user_id IS DISTINCT FROM OLD.clerk_user_id
  ) AND EXISTS (
    SELECT 1
    FROM identity_reconciliation_legacy_mappings mappings
    INNER JOIN identity_reconciliation_activations activations
      ON activations.receipt_digest = mappings.receipt_digest
    WHERE mappings.app_user_id = OLD.id
  ) THEN
    RAISE EXCEPTION 'activated legacy app user identity is immutable';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER app_users_activated_legacy_identity_immutable
BEFORE UPDATE OR DELETE ON app_users
FOR EACH ROW EXECUTE FUNCTION protect_activated_legacy_app_user_identity();
