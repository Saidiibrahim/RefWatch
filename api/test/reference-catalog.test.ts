import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { parseReferenceSeasonYear, referenceCatalogRoutes } from "../src/routes/referenceCatalog";
import type { Env } from "../src/types";

describe("reference catalog contract", () => {
  it("defaults to the current catalog year and accepts a bounded year", () => {
    expect(parseReferenceSeasonYear(undefined)).toBe(2026);
    expect(parseReferenceSeasonYear("2027")).toBe(2027);
  });

  it("rejects malformed or unbounded years", () => {
    expect(parseReferenceSeasonYear("not-a-year")).toBeNull();
    expect(parseReferenceSeasonYear("1999")).toBeNull();
    expect(parseReferenceSeasonYear("2101")).toBeNull();
  });

  it("returns validation errors before accessing the database", async () => {
    const response = await referenceCatalogRoutes.request(
      "/teams?seasonYear=not-a-year",
      {},
      {} as Env,
    );
    expect(response.status).toBe(422);
    await expect(response.json()).resolves.toEqual({ error: "invalid_season_year" });
  });

  it("ships the portable 2026 seed with five competitions and 54 teams", () => {
    const migration = readFileSync(
      new URL("../src/db/migrations/0002_crazy_yellowjacket.sql", import.meta.url),
      "utf8",
    );
    const competitionSeed = migration.slice(
      migration.indexOf("WITH competition_seed"),
      migration.indexOf("), competition_with_hash"),
    );
    const teamSeed = migration.slice(
      migration.indexOf("WITH team_seed"),
      migration.indexOf("), mapped AS"),
    );
    expect(competitionSeed.match(/^\s*\('[^']+'/gm)).toHaveLength(5);
    expect(teamSeed.match(/^\s*\('[^']+'/gm)).toHaveLength(54);
  });
});
