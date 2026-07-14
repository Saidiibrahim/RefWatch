CREATE TABLE "ai_attachments" (
	"id" uuid PRIMARY KEY NOT NULL,
	"message_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"storage_key" text,
	"metadata" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ai_messages" (
	"id" uuid PRIMARY KEY NOT NULL,
	"thread_id" uuid NOT NULL,
	"role" text NOT NULL,
	"content" jsonb NOT NULL,
	"model" text,
	"usage_input_tokens" integer,
	"usage_output_tokens" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ai_threads" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"title" text,
	"default_model" text,
	"last_activity_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ai_usage_daily" (
	"owner_id" uuid NOT NULL,
	"on_date" date NOT NULL,
	"model" text NOT NULL,
	"input_tokens" integer DEFAULT 0 NOT NULL,
	"output_tokens" integer DEFAULT 0 NOT NULL,
	"responses_count" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ai_usage_daily_owner_id_on_date_model_pk" PRIMARY KEY("owner_id","on_date","model")
);
--> statement-breakpoint
CREATE TABLE "app_users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"clerk_user_id" text NOT NULL,
	"email" text,
	"display_name" text,
	"avatar_url" text,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "competitions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"name" text NOT NULL,
	"level" text,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "idempotency_keys" (
	"owner_id" uuid NOT NULL,
	"key" text NOT NULL,
	"request_hash" text NOT NULL,
	"response_body" jsonb NOT NULL,
	"status_code" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone DEFAULT now() + interval '24 hours' NOT NULL,
	CONSTRAINT "idempotency_keys_owner_id_key_pk" PRIMARY KEY("owner_id","key")
);
--> statement-breakpoint
CREATE TABLE "match_assessments" (
	"id" uuid PRIMARY KEY NOT NULL,
	"match_id" uuid NOT NULL,
	"owner_id" uuid NOT NULL,
	"rating" integer,
	"overall" text,
	"went_well" text,
	"to_improve" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "match_events" (
	"id" uuid PRIMARY KEY NOT NULL,
	"match_id" uuid NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"period_index" integer NOT NULL,
	"clock_seconds" integer NOT NULL,
	"match_time_label" text NOT NULL,
	"event_type" text NOT NULL,
	"payload" jsonb,
	"team_side" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "match_metrics" (
	"match_id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"regulation_minutes" integer,
	"half_time_minutes" integer,
	"extra_time_minutes" integer,
	"penalties_enabled" boolean DEFAULT false NOT NULL,
	"total_goals" integer DEFAULT 0 NOT NULL,
	"total_cards" integer DEFAULT 0 NOT NULL,
	"total_penalties" integer DEFAULT 0 NOT NULL,
	"yellow_cards" integer DEFAULT 0 NOT NULL,
	"red_cards" integer DEFAULT 0 NOT NULL,
	"home_cards" integer DEFAULT 0 NOT NULL,
	"away_cards" integer DEFAULT 0 NOT NULL,
	"home_substitutions" integer DEFAULT 0 NOT NULL,
	"away_substitutions" integer DEFAULT 0 NOT NULL,
	"penalties_scored" integer DEFAULT 0 NOT NULL,
	"penalties_missed" integer DEFAULT 0 NOT NULL,
	"avg_added_time_seconds" integer DEFAULT 0 NOT NULL,
	"generated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "match_periods" (
	"id" uuid PRIMARY KEY NOT NULL,
	"match_id" uuid NOT NULL,
	"index" integer NOT NULL,
	"regulation_seconds" integer NOT NULL,
	"added_time_seconds" integer DEFAULT 0 NOT NULL,
	"result" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "matches" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"scheduled_match_id" uuid,
	"status" text DEFAULT 'completed' NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"completed_at" timestamp with time zone,
	"duration_seconds" integer,
	"number_of_periods" integer DEFAULT 2 NOT NULL,
	"regulation_minutes" integer,
	"half_time_minutes" integer,
	"competition_id" uuid,
	"competition_name" text,
	"venue_id" uuid,
	"venue_name" text,
	"home_team_id" uuid,
	"home_team_name" text NOT NULL,
	"away_team_id" uuid,
	"away_team_name" text NOT NULL,
	"extra_time_enabled" boolean DEFAULT false NOT NULL,
	"extra_time_half_minutes" integer,
	"penalties_enabled" boolean DEFAULT false NOT NULL,
	"penalty_initial_rounds" integer DEFAULT 5 NOT NULL,
	"home_score" integer DEFAULT 0 NOT NULL,
	"away_score" integer DEFAULT 0 NOT NULL,
	"final_score" jsonb,
	"source_device_id" text,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "scheduled_matches" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"home_team_name" text NOT NULL,
	"away_team_name" text NOT NULL,
	"kickoff_at" timestamp with time zone NOT NULL,
	"status" text DEFAULT 'scheduled' NOT NULL,
	"competition_id" uuid,
	"competition_name" text,
	"venue_id" uuid,
	"venue_name" text,
	"home_team_id" uuid,
	"away_team_id" uuid,
	"home_match_sheet" jsonb,
	"away_match_sheet" jsonb,
	"notes" text,
	"source_device_id" text,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "team_members" (
	"id" uuid PRIMARY KEY NOT NULL,
	"team_id" uuid NOT NULL,
	"display_name" text NOT NULL,
	"jersey_number" text,
	"role" text,
	"position" text,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "team_officials" (
	"id" uuid PRIMARY KEY NOT NULL,
	"team_id" uuid NOT NULL,
	"display_name" text NOT NULL,
	"role" text NOT NULL,
	"phone" text,
	"email" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "team_tags" (
	"team_id" uuid NOT NULL,
	"value" text NOT NULL,
	CONSTRAINT "team_tags_team_id_value_pk" PRIMARY KEY("team_id","value")
);
--> statement-breakpoint
CREATE TABLE "teams" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"name" text NOT NULL,
	"short_name" text,
	"division" text,
	"color_primary" text,
	"color_secondary" text,
	"reference_key" text,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_devices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"platform" text NOT NULL,
	"model" text,
	"app_version" text,
	"last_seen_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "venues" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"name" text NOT NULL,
	"city" text,
	"country" text,
	"latitude" text,
	"longitude" text,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "ai_attachments" ADD CONSTRAINT "ai_attachments_message_id_ai_messages_id_fk" FOREIGN KEY ("message_id") REFERENCES "public"."ai_messages"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ai_messages" ADD CONSTRAINT "ai_messages_thread_id_ai_threads_id_fk" FOREIGN KEY ("thread_id") REFERENCES "public"."ai_threads"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ai_threads" ADD CONSTRAINT "ai_threads_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ai_usage_daily" ADD CONSTRAINT "ai_usage_daily_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "competitions" ADD CONSTRAINT "competitions_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "idempotency_keys" ADD CONSTRAINT "idempotency_keys_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "match_assessments" ADD CONSTRAINT "match_assessments_match_id_matches_id_fk" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "match_assessments" ADD CONSTRAINT "match_assessments_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "match_events" ADD CONSTRAINT "match_events_match_id_matches_id_fk" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "match_metrics" ADD CONSTRAINT "match_metrics_match_id_matches_id_fk" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "match_metrics" ADD CONSTRAINT "match_metrics_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "match_periods" ADD CONSTRAINT "match_periods_match_id_matches_id_fk" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "matches" ADD CONSTRAINT "matches_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "matches" ADD CONSTRAINT "matches_scheduled_match_id_scheduled_matches_id_fk" FOREIGN KEY ("scheduled_match_id") REFERENCES "public"."scheduled_matches"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "matches" ADD CONSTRAINT "matches_competition_id_competitions_id_fk" FOREIGN KEY ("competition_id") REFERENCES "public"."competitions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "matches" ADD CONSTRAINT "matches_venue_id_venues_id_fk" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "matches" ADD CONSTRAINT "matches_home_team_id_teams_id_fk" FOREIGN KEY ("home_team_id") REFERENCES "public"."teams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "matches" ADD CONSTRAINT "matches_away_team_id_teams_id_fk" FOREIGN KEY ("away_team_id") REFERENCES "public"."teams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "scheduled_matches" ADD CONSTRAINT "scheduled_matches_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "scheduled_matches" ADD CONSTRAINT "scheduled_matches_competition_id_competitions_id_fk" FOREIGN KEY ("competition_id") REFERENCES "public"."competitions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "scheduled_matches" ADD CONSTRAINT "scheduled_matches_venue_id_venues_id_fk" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "scheduled_matches" ADD CONSTRAINT "scheduled_matches_home_team_id_teams_id_fk" FOREIGN KEY ("home_team_id") REFERENCES "public"."teams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "scheduled_matches" ADD CONSTRAINT "scheduled_matches_away_team_id_teams_id_fk" FOREIGN KEY ("away_team_id") REFERENCES "public"."teams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "team_members" ADD CONSTRAINT "team_members_team_id_teams_id_fk" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "team_officials" ADD CONSTRAINT "team_officials_team_id_teams_id_fk" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "team_tags" ADD CONSTRAINT "team_tags_team_id_teams_id_fk" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "teams" ADD CONSTRAINT "teams_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_devices" ADD CONSTRAINT "user_devices_user_id_app_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "venues" ADD CONSTRAINT "venues_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "app_users_clerk_user_id_uq" ON "app_users" USING btree ("clerk_user_id");--> statement-breakpoint
CREATE INDEX "competitions_owner_updated_idx" ON "competitions" USING btree ("owner_id","updated_at");--> statement-breakpoint
CREATE UNIQUE INDEX "match_assessments_match_owner_uq" ON "match_assessments" USING btree ("match_id","owner_id");--> statement-breakpoint
CREATE INDEX "match_events_match_time_idx" ON "match_events" USING btree ("match_id","occurred_at");--> statement-breakpoint
CREATE UNIQUE INDEX "match_periods_match_index_uq" ON "match_periods" USING btree ("match_id","index");--> statement-breakpoint
CREATE INDEX "matches_owner_updated_idx" ON "matches" USING btree ("owner_id","updated_at");--> statement-breakpoint
CREATE INDEX "scheduled_matches_owner_updated_idx" ON "scheduled_matches" USING btree ("owner_id","updated_at");--> statement-breakpoint
CREATE INDEX "teams_owner_updated_idx" ON "teams" USING btree ("owner_id","updated_at");--> statement-breakpoint
CREATE INDEX "user_devices_user_id_idx" ON "user_devices" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "venues_owner_updated_idx" ON "venues" USING btree ("owner_id","updated_at");