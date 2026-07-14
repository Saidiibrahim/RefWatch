import { and, asc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { referenceCompetitions, referenceTeams } from "../db/schema";
import type { Env, Variables } from "../types";
import { snakeCaseJSON } from "../utils/json";

const seasonYearSchema = z.coerce.number().int().min(2000).max(2100).default(2026);

export function parseReferenceSeasonYear(value: string | undefined): number | null {
  const parsed = seasonYearSchema.safeParse(value);
  return parsed.success ? parsed.data : null;
}

export const referenceCatalogRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

referenceCatalogRoutes.get("/competitions", async (c) => {
  const seasonYear = parseReferenceSeasonYear(c.req.query("seasonYear"));
  if (seasonYear == null) return c.json({ error: "invalid_season_year" }, 422);

  const rows = await c.get("db")
    .select({
      id: referenceCompetitions.id,
      code: referenceCompetitions.code,
      name: referenceCompetitions.name,
      seasonYear: referenceCompetitions.seasonYear,
    })
    .from(referenceCompetitions)
    .where(eq(referenceCompetitions.seasonYear, seasonYear))
    .orderBy(asc(referenceCompetitions.name));
  return c.json(snakeCaseJSON(rows));
});

referenceCatalogRoutes.get("/teams", async (c) => {
  const seasonYear = parseReferenceSeasonYear(c.req.query("seasonYear"));
  if (seasonYear == null) return c.json({ error: "invalid_season_year" }, 422);

  const rows = await c.get("db")
    .select({
      id: referenceTeams.id,
      referenceKey: referenceTeams.referenceKey,
      name: referenceTeams.name,
      shortName: referenceTeams.shortName,
      competitionCode: referenceCompetitions.code,
      competitionName: referenceCompetitions.name,
      seasonYear: referenceTeams.seasonYear,
    })
    .from(referenceTeams)
    .innerJoin(referenceCompetitions, eq(referenceTeams.competitionId, referenceCompetitions.id))
    .where(and(
      eq(referenceTeams.seasonYear, seasonYear),
      eq(referenceCompetitions.seasonYear, seasonYear),
    ))
    .orderBy(asc(referenceCompetitions.name), asc(referenceTeams.name));
  return c.json(snakeCaseJSON(rows));
});
