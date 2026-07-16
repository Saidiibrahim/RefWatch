CREATE OR REPLACE FUNCTION refwatch_protect_delivery_envelope()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.encrypted_envelope IS NOT NULL AND (
    NEW.encrypted_envelope IS DISTINCT FROM OLD.encrypted_envelope OR
    NEW.encryption_key_id IS DISTINCT FROM OLD.encryption_key_id OR
    NEW.encryption_nonce IS DISTINCT FROM OLD.encryption_nonce OR
    NEW.content_digest IS DISTINCT FROM OLD.content_digest
  ) THEN
    RAISE EXCEPTION 'materialized mutation delivery envelope is immutable';
  END IF;
  IF (NEW.encrypted_envelope IS NULL) <> (NEW.encryption_key_id IS NULL) OR
     (NEW.encrypted_envelope IS NULL) <> (NEW.encryption_nonce IS NULL) OR
     (NEW.encrypted_envelope IS NULL) <> (NEW.content_digest IS NULL) THEN
    RAISE EXCEPTION 'mutation delivery envelope fields must be set together';
  END IF;
  IF NEW.content_digest IS NOT NULL AND NEW.content_digest !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'mutation delivery content digest must be SHA-256 hex';
  END IF;
  RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER mutation_outbox_deliveries_envelope_immutable
BEFORE UPDATE ON mutation_outbox_deliveries
FOR EACH ROW EXECUTE FUNCTION refwatch_protect_delivery_envelope();
