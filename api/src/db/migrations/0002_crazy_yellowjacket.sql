CREATE TABLE "reference_competitions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"code" text NOT NULL,
	"name" text NOT NULL,
	"season_year" integer NOT NULL,
	"federation" text NOT NULL,
	"tier" integer NOT NULL,
	"gender" text NOT NULL,
	"source_url" text NOT NULL,
	"source_published_at" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "reference_teams" (
	"id" uuid PRIMARY KEY NOT NULL,
	"competition_id" uuid NOT NULL,
	"name" text NOT NULL,
	"short_name" text,
	"reference_key" text NOT NULL,
	"season_year" integer NOT NULL,
	"source_url" text NOT NULL,
	"source_name_note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "reference_teams" ADD CONSTRAINT "reference_teams_competition_id_reference_competitions_id_fk" FOREIGN KEY ("competition_id") REFERENCES "public"."reference_competitions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "reference_competitions_code_uq" ON "reference_competitions" USING btree ("code");--> statement-breakpoint
CREATE INDEX "reference_competitions_federation_season_idx" ON "reference_competitions" USING btree ("federation","season_year");--> statement-breakpoint
CREATE UNIQUE INDEX "reference_teams_reference_key_uq" ON "reference_teams" USING btree ("reference_key");--> statement-breakpoint
CREATE UNIQUE INDEX "reference_teams_competition_name_uq" ON "reference_teams" USING btree ("competition_id","name");--> statement-breakpoint
CREATE INDEX "reference_teams_competition_idx" ON "reference_teams" USING btree ("competition_id");--> statement-breakpoint
CREATE INDEX "reference_teams_season_idx" ON "reference_teams" USING btree ("season_year");
--> statement-breakpoint
-- Portable 2026 Football SA reference catalog seed, ported from legacy migration 0017.
-- Deterministic UUIDs and conflict updates make the seed statements idempotent.
WITH competition_seed(code, name, season_year, federation, tier, gender, source_url, source_published_at) AS (
	VALUES
		('nplsa_men_2026', 'National Premier League South Australia', 2026, 'football_sa', 1, 'men', 'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures', date '2025-12-18'),
		('sl1_men_2026', 'State League 1 South Australia', 2026, 'football_sa', 2, 'men', 'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures', date '2025-12-18'),
		('sl2_north_men_2026', 'State League 2 North South Australia', 2026, 'football_sa', 3, 'men', 'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures', date '2025-12-18'),
		('sl2_south_men_2026', 'State League 2 South South Australia', 2026, 'football_sa', 3, 'men', 'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures', date '2025-12-18'),
		('wnplsa_women_2026', 'Apex Steel Women''s National Premier League South Australia', 2026, 'football_sa', 1, 'women', 'https://footballsa.com.au/news/2026-football-sa-senior-elite-competition-structures', date '2025-12-18')
), competition_with_hash AS (
	SELECT competition_seed.*, md5(code) AS hash FROM competition_seed
)
INSERT INTO "reference_competitions" ("id", "code", "name", "season_year", "federation", "tier", "gender", "source_url", "source_published_at")
SELECT
	(substr(hash, 1, 8) || '-' || substr(hash, 9, 4) || '-' || substr(hash, 13, 4) || '-' || substr(hash, 17, 4) || '-' || substr(hash, 21, 12))::uuid,
	code, name, season_year, federation, tier, gender, source_url, source_published_at
FROM competition_with_hash
ON CONFLICT ("code") DO UPDATE SET
	"name" = excluded."name",
	"season_year" = excluded."season_year",
	"federation" = excluded."federation",
	"tier" = excluded."tier",
	"gender" = excluded."gender",
	"source_url" = excluded."source_url",
	"source_published_at" = excluded."source_published_at",
	"updated_at" = now();
--> statement-breakpoint
WITH team_seed(competition_code, team_name, short_name, source_name_note) AS (
	VALUES
		('nplsa_men_2026', 'Adelaide City', null, null),
		('nplsa_men_2026', 'Adelaide Comets', null, null),
		('nplsa_men_2026', 'Adelaide United', null, null),
		('nplsa_men_2026', 'Campbelltown City', null, null),
		('nplsa_men_2026', 'Croydon FC', null, null),
		('nplsa_men_2026', 'FK Beograd', null, null),
		('nplsa_men_2026', 'MetroStars', null, null),
		('nplsa_men_2026', 'Para Hills Knights', null, null),
		('nplsa_men_2026', 'Playford City', null, null),
		('nplsa_men_2026', 'Sturt Lions', null, null),
		('nplsa_men_2026', 'West Adelaide', null, null),
		('nplsa_men_2026', 'West Torrens Birkalla', 'WT Birkalla', null),
		('sl1_men_2026', 'Adelaide Blue Eagles', null, null),
		('sl1_men_2026', 'Adelaide Cobras', null, null),
		('sl1_men_2026', 'Adelaide Olympic', null, null),
		('sl1_men_2026', 'Adelaide Raptors', null, null),
		('sl1_men_2026', 'Cumberland United', null, null),
		('sl1_men_2026', 'Fulham United', null, null),
		('sl1_men_2026', 'Modbury Jets', null, null),
		('sl1_men_2026', 'Salisbury Inter', null, null),
		('sl1_men_2026', 'South Adelaide Panthers', null, null),
		('sl1_men_2026', 'Vipers', null, null),
		('sl1_men_2026', 'White City', null, null),
		('sl1_men_2026', 'West Torrens Birkalla', 'WT Birkalla', null),
		('sl2_north_men_2026', 'Adelaide Titans', null, null),
		('sl2_north_men_2026', 'Eastern United', null, null),
		('sl2_north_men_2026', 'Elizabeth Downs', null, null),
		('sl2_north_men_2026', 'Ghan Kilburn City', null, null),
		('sl2_north_men_2026', 'Northern Demons', null, null),
		('sl2_north_men_2026', 'Old Ignatians', null, null),
		('sl2_north_men_2026', 'Pontian Eagles', null, null),
		('sl2_north_men_2026', 'Tea Tree Gully', null, null),
		('sl2_north_men_2026', 'University', null, null),
		('sl2_north_men_2026', 'Whyalla', null, null),
		('sl2_south_men_2026', 'Adelaide University', null, null),
		('sl2_south_men_2026', 'Atletico Adelaide', null, null),
		('sl2_south_men_2026', 'Cove', null, null),
		('sl2_south_men_2026', 'Flinders United', null, null),
		('sl2_south_men_2026', 'Marion', null, null),
		('sl2_south_men_2026', 'Mount Barker', null, null),
		('sl2_south_men_2026', 'Noarlunga United', null, null),
		('sl2_south_men_2026', 'Seaford Rangers', null, null),
		('sl2_south_men_2026', 'Western Strikers', null, null),
		('sl2_south_men_2026', 'Adelaide Hills Hawks', null, null),
		('wnplsa_women_2026', 'Adelaide Comets', null, null),
		('wnplsa_women_2026', 'Adelaide University', null, 'Source competition article spells this as ''Adeliade University''; canonicalized to Adelaide University.'),
		('wnplsa_women_2026', 'Campbelltown City', null, null),
		('wnplsa_women_2026', 'Flinders United', null, null),
		('wnplsa_women_2026', 'Football SA', null, null),
		('wnplsa_women_2026', 'MetroStars', null, null),
		('wnplsa_women_2026', 'Modbury Vista', null, null),
		('wnplsa_women_2026', 'Salisbury Inter', null, null),
		('wnplsa_women_2026', 'West Adelaide', null, null),
		('wnplsa_women_2026', 'WT Birkalla', null, null)
), mapped AS (
	SELECT
		rc."id" AS competition_id,
		rc."code" AS competition_code,
		team_seed.team_name,
		team_seed.short_name,
		team_seed.source_name_note,
		rc."season_year" AS season_year,
		rc."source_url" AS source_url,
		lower(regexp_replace(rc."code" || '_' || team_seed.team_name, '[^a-zA-Z0-9]+', '_', 'g')) AS reference_key,
		md5(rc."code" || '|' || team_seed.team_name || '|' || rc."season_year"::text) AS hash
	FROM team_seed
	JOIN "reference_competitions" rc ON rc."code" = team_seed.competition_code
)
INSERT INTO "reference_teams" ("id", "competition_id", "name", "short_name", "reference_key", "season_year", "source_url", "source_name_note")
SELECT
	(substr(hash, 1, 8) || '-' || substr(hash, 9, 4) || '-' || substr(hash, 13, 4) || '-' || substr(hash, 17, 4) || '-' || substr(hash, 21, 12))::uuid,
	competition_id, team_name, short_name, reference_key, season_year, source_url, source_name_note
FROM mapped
ON CONFLICT ("reference_key") DO UPDATE SET
	"competition_id" = excluded."competition_id",
	"name" = excluded."name",
	"short_name" = excluded."short_name",
	"season_year" = excluded."season_year",
	"source_url" = excluded."source_url",
	"source_name_note" = excluded."source_name_note",
	"updated_at" = now();
