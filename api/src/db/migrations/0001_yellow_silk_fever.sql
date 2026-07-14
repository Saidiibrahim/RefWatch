ALTER TABLE "idempotency_keys" ALTER COLUMN "response_body" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "idempotency_keys" ALTER COLUMN "status_code" SET DEFAULT 0;--> statement-breakpoint
ALTER TABLE "match_assessments" ADD COLUMN "deleted_at" timestamp with time zone;