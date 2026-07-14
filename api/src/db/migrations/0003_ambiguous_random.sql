ALTER TABLE "reference_teams" DROP CONSTRAINT "reference_teams_competition_id_reference_competitions_id_fk";
--> statement-breakpoint
CREATE UNIQUE INDEX "reference_competitions_id_season_uq" ON "reference_competitions" USING btree ("id","season_year");--> statement-breakpoint
ALTER TABLE "reference_teams" ADD CONSTRAINT "reference_teams_competition_season_fk" FOREIGN KEY ("competition_id","season_year") REFERENCES "public"."reference_competitions"("id","season_year") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reference_competitions" ADD CONSTRAINT "reference_competitions_season_year_check" CHECK ("reference_competitions"."season_year" >= 2000);--> statement-breakpoint
ALTER TABLE "reference_competitions" ADD CONSTRAINT "reference_competitions_tier_check" CHECK ("reference_competitions"."tier" >= 1);--> statement-breakpoint
ALTER TABLE "reference_competitions" ADD CONSTRAINT "reference_competitions_gender_check" CHECK ("reference_competitions"."gender" in ('men', 'women', 'mixed'));--> statement-breakpoint
ALTER TABLE "reference_teams" ADD CONSTRAINT "reference_teams_season_year_check" CHECK ("reference_teams"."season_year" >= 2000);
