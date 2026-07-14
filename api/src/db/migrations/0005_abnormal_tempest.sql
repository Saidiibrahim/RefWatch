ALTER TABLE "venues" ALTER COLUMN "latitude" SET DATA TYPE double precision USING NULLIF(BTRIM("latitude"), '')::double precision;--> statement-breakpoint
ALTER TABLE "venues" ALTER COLUMN "longitude" SET DATA TYPE double precision USING NULLIF(BTRIM("longitude"), '')::double precision;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "email_verified" boolean;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "last_sign_in_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "raw_app_metadata" jsonb;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "raw_user_metadata" jsonb;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "is_sso_user" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "is_anonymous" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "primary_provider" text;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "provider_list" text[] DEFAULT '{}'::text[] NOT NULL;--> statement-breakpoint
ALTER TABLE "app_users" ADD COLUMN "email_confirmed_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "match_events" ADD COLUMN "team_id" uuid;--> statement-breakpoint
ALTER TABLE "match_events" ADD COLUMN "team_member_id" uuid;--> statement-breakpoint
ALTER TABLE "match_events" ADD CONSTRAINT "match_events_team_id_teams_id_fk" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "match_events" ADD CONSTRAINT "match_events_team_member_id_team_members_id_fk" FOREIGN KEY ("team_member_id") REFERENCES "public"."team_members"("id") ON DELETE set null ON UPDATE no action;
