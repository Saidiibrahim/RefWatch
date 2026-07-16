CREATE TABLE "identity_reconciliation_receipts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"receipt_digest" text NOT NULL,
	"clerk_instance_id" text NOT NULL,
	"snapshot_captured_at" timestamp with time zone NOT NULL,
	"legacy_mapping_count" integer NOT NULL,
	"excluded_auth_count" integer NOT NULL,
	"mapping_hash" text NOT NULL,
	"status" text NOT NULL,
	"reviewed_at" timestamp with time zone NOT NULL,
	"activated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "identity_reconciliation_receipts_digest_check" CHECK ("identity_reconciliation_receipts"."receipt_digest" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "identity_reconciliation_receipts_mapping_hash_check" CHECK ("identity_reconciliation_receipts"."mapping_hash" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "identity_reconciliation_receipts_mapping_count_check" CHECK ("identity_reconciliation_receipts"."legacy_mapping_count" > 0),
	CONSTRAINT "identity_reconciliation_receipts_excluded_count_check" CHECK ("identity_reconciliation_receipts"."excluded_auth_count" >= 0),
	CONSTRAINT "identity_reconciliation_receipts_status_check" CHECK ("identity_reconciliation_receipts"."status" = 'verified')
);
--> statement-breakpoint
CREATE UNIQUE INDEX "identity_reconciliation_receipts_digest_uq" ON "identity_reconciliation_receipts" USING btree ("receipt_digest");--> statement-breakpoint
CREATE INDEX "identity_reconciliation_receipts_instance_idx" ON "identity_reconciliation_receipts" USING btree ("clerk_instance_id");