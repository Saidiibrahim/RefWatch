CREATE TYPE "public"."assessment_mood" AS ENUM('calm', 'focused', 'stressed', 'fatigued');--> statement-breakpoint
CREATE TYPE "public"."page_status" AS ENUM('draft', 'submitted');--> statement-breakpoint
CREATE TYPE "public"."page_type" AS ENUM('match_report', 'training_plan', 'fitness_assessment', 'general_note');--> statement-breakpoint
CREATE TYPE "public"."session_context" AS ENUM('match_prep', 'recovery', 'maintenance', 'test_prep');--> statement-breakpoint
CREATE TYPE "public"."workout_kind" AS ENUM('outdoorRun', 'outdoorWalk', 'indoorRun', 'indoorCycle', 'strength', 'mobility', 'refereeDrill', 'custom');--> statement-breakpoint
CREATE TYPE "public"."workout_state" AS ENUM('planned', 'active', 'paused', 'ended', 'aborted');--> statement-breakpoint
CREATE TABLE "pages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_id" uuid NOT NULL,
	"page_type" "page_type" NOT NULL,
	"title" text,
	"content_jsonb" jsonb DEFAULT '{"type":"doc","content":[]}'::jsonb NOT NULL,
	"content_html" text,
	"content_text" text,
	"icon" text,
	"tags" text[] DEFAULT '{}'::text[],
	"status" "page_status" DEFAULT 'draft' NOT NULL,
	"is_favorite" boolean DEFAULT false,
	"match_id" uuid,
	"submitted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "reference_disciplinary_codes" (
	"id" uuid PRIMARY KEY NOT NULL,
	"jurisdiction" text NOT NULL,
	"season_year" integer NOT NULL,
	"recipient_type" text NOT NULL,
	"card_type" text NOT NULL,
	"code" text NOT NULL,
	"title" text NOT NULL,
	"regulation_ref" text,
	"minimum_suspension_matches" integer,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"notes" text,
	"source_url" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "reference_disciplinary_codes_season_year_check" CHECK ("reference_disciplinary_codes"."season_year" >= 2000),
	CONSTRAINT "reference_disciplinary_codes_recipient_type_check" CHECK ("reference_disciplinary_codes"."recipient_type" in ('player', 'team_official', 'participant')),
	CONSTRAINT "reference_disciplinary_codes_card_type_check" CHECK ("reference_disciplinary_codes"."card_type" in ('yellow', 'red', 'n/a'))
);
--> statement-breakpoint
CREATE TABLE "reference_disciplinary_rules" (
	"id" uuid PRIMARY KEY NOT NULL,
	"jurisdiction" text NOT NULL,
	"season_year" integer NOT NULL,
	"rule_type" text NOT NULL,
	"recipient_type" text NOT NULL,
	"applies_to_codes" text[] DEFAULT '{}'::text[] NOT NULL,
	"trigger_count" integer,
	"repeat_interval" integer,
	"suspension_matches" integer,
	"rule_text" text NOT NULL,
	"regulation_ref" text,
	"notes" text,
	"source_url" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "reference_disciplinary_rules_season_year_check" CHECK ("reference_disciplinary_rules"."season_year" >= 2000),
	CONSTRAINT "reference_disciplinary_rules_recipient_type_check" CHECK ("reference_disciplinary_rules"."recipient_type" in ('player', 'team_official', 'participant'))
);
--> statement-breakpoint
CREATE TABLE "workout_presets" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text NOT NULL,
	"description" text,
	"kind" text NOT NULL,
	"estimated_duration" integer,
	"exercises" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"intensity_level" integer,
	"tags" text[] DEFAULT '{}'::text[],
	"is_public" boolean DEFAULT true NOT NULL,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "workout_presets_intensity_level_check" CHECK ("workout_presets"."intensity_level" is null or ("workout_presets"."intensity_level" >= 1 and "workout_presets"."intensity_level" <= 10))
);
--> statement-breakpoint
CREATE TABLE "workout_sessions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner_id" uuid NOT NULL,
	"state" "workout_state" NOT NULL,
	"kind" "workout_kind" NOT NULL,
	"title" text NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"ended_at" timestamp with time zone,
	"perceived_exertion" integer,
	"preset_id" uuid,
	"notes" text,
	"metadata" jsonb DEFAULT '{}'::jsonb,
	"summary" jsonb,
	"session_context" "session_context",
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "match_assessments" ADD COLUMN "mood" "assessment_mood";--> statement-breakpoint
ALTER TABLE "pages" ADD CONSTRAINT "pages_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pages" ADD CONSTRAINT "pages_match_id_matches_id_fk" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_presets" ADD CONSTRAINT "workout_presets_created_by_app_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_owner_id_app_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."app_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "pages_owner_id_idx" ON "pages" USING btree ("owner_id");--> statement-breakpoint
CREATE INDEX "pages_page_type_idx" ON "pages" USING btree ("page_type");--> statement-breakpoint
CREATE INDEX "pages_status_idx" ON "pages" USING btree ("status");--> statement-breakpoint
CREATE INDEX "pages_updated_at_idx" ON "pages" USING btree ("updated_at");--> statement-breakpoint
CREATE INDEX "pages_match_id_idx" ON "pages" USING btree ("match_id") WHERE "pages"."match_id" is not null;--> statement-breakpoint
CREATE UNIQUE INDEX "reference_disciplinary_codes_key_uq" ON "reference_disciplinary_codes" USING btree ("jurisdiction","season_year","recipient_type","code");--> statement-breakpoint
CREATE INDEX "reference_disciplinary_codes_lookup_idx" ON "reference_disciplinary_codes" USING btree ("jurisdiction","season_year","recipient_type","card_type","sort_order");--> statement-breakpoint
CREATE UNIQUE INDEX "reference_disciplinary_rules_key_uq" ON "reference_disciplinary_rules" USING btree ("jurisdiction","season_year","rule_type","recipient_type");--> statement-breakpoint
CREATE INDEX "reference_disciplinary_rules_lookup_idx" ON "reference_disciplinary_rules" USING btree ("jurisdiction","season_year","recipient_type","rule_type");--> statement-breakpoint
CREATE INDEX "workout_presets_created_by_idx" ON "workout_presets" USING btree ("created_by") WHERE "workout_presets"."created_by" is not null;--> statement-breakpoint
CREATE INDEX "workout_presets_kind_idx" ON "workout_presets" USING btree ("kind");--> statement-breakpoint
CREATE INDEX "workout_presets_public_idx" ON "workout_presets" USING btree ("is_public") WHERE "workout_presets"."is_public" = true;--> statement-breakpoint
CREATE INDEX "workout_sessions_owner_started_idx" ON "workout_sessions" USING btree ("owner_id","started_at");--> statement-breakpoint
ALTER TABLE "match_assessments" ADD CONSTRAINT "match_assessments_rating_check" CHECK ("match_assessments"."rating" is null or ("match_assessments"."rating" >= 1 and "match_assessments"."rating" <= 5));