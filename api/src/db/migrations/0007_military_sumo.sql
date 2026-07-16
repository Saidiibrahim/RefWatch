CREATE TABLE "clerk_user_deletion_tombstones" (
	"clerk_instance_id" text NOT NULL,
	"clerk_user_id" text NOT NULL,
	"webhook_event_id" text,
	"deleted_at" timestamp with time zone NOT NULL,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "clerk_user_deletion_tombstones_clerk_instance_id_clerk_user_id_pk" PRIMARY KEY("clerk_instance_id","clerk_user_id")
);
--> statement-breakpoint
CREATE TABLE "identity_reconciliation_activations" (
	"receipt_digest" text PRIMARY KEY NOT NULL,
	"clerk_instance_id" text NOT NULL,
	"activated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "identity_reconciliation_legacy_mappings" (
	"clerk_instance_id" text NOT NULL,
	"clerk_user_id" text NOT NULL,
	"app_user_id" uuid NOT NULL,
	"receipt_digest" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "identity_reconciliation_legacy_mappings_clerk_instance_id_clerk_user_id_pk" PRIMARY KEY("clerk_instance_id","clerk_user_id")
);
--> statement-breakpoint
ALTER TABLE "identity_reconciliation_activations" ADD CONSTRAINT "identity_reconciliation_activations_receipt_digest_identity_reconciliation_receipts_receipt_digest_fk" FOREIGN KEY ("receipt_digest") REFERENCES "public"."identity_reconciliation_receipts"("receipt_digest") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity_reconciliation_legacy_mappings" ADD CONSTRAINT "identity_reconciliation_legacy_mappings_app_user_id_app_users_id_fk" FOREIGN KEY ("app_user_id") REFERENCES "public"."app_users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity_reconciliation_legacy_mappings" ADD CONSTRAINT "identity_reconciliation_legacy_mappings_receipt_digest_identity_reconciliation_receipts_receipt_digest_fk" FOREIGN KEY ("receipt_digest") REFERENCES "public"."identity_reconciliation_receipts"("receipt_digest") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "identity_reconciliation_legacy_instance_app_uq" ON "identity_reconciliation_legacy_mappings" USING btree ("clerk_instance_id","app_user_id");--> statement-breakpoint
CREATE INDEX "identity_reconciliation_legacy_receipt_idx" ON "identity_reconciliation_legacy_mappings" USING btree ("receipt_digest");