import { drizzle } from "drizzle-orm/node-postgres";
import { Hono } from "hono";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { appUsers, teams } from "../src/db/schema";
import { matchRoutes } from "../src/routes/matches";
import type { Env, Variables } from "../src/types";

const ownerA = "0190f8f4-5914-7b6c-9d6a-469a29f93101";
const ownerB = "0190f8f4-5914-7b6c-9d6a-469a29f93102";
const teamA = "0190f8f4-5914-7b6c-9d6a-469a29f93201";
const teamB = "0190f8f4-5914-7b6c-9d6a-469a29f93202";
const matchId = "0190f8f4-5914-7b6c-9d6a-469a29f93301";
const rejectedMatchId = "0190f8f4-5914-7b6c-9d6a-469a29f93302";
const expectedDisposableBranchId = "ng9tgmy4pyi5";
const databaseURL = validatedIntegrationDatabaseURL();

describe("matches against a real Postgres branch", () => {
  const pool = new Pool({ connectionString: databaseURL, max: 4 });
  const db = drizzle(pool, { schema: { appUsers, teams } });

  beforeAll(async () => {
    await pool.query("delete from app_users where id = any($1::uuid[])", [[ownerA, ownerB]]);
    await db.insert(appUsers).values([
      { id: ownerA, clerkUserId: "integration_owner_a" },
      { id: ownerB, clerkUserId: "integration_owner_b" },
    ]);
    await db.insert(teams).values([
      { id: teamA, ownerId: ownerA, name: "Integration A" },
      { id: teamB, ownerId: ownerB, name: "Integration B" },
    ]);
  });

  afterAll(async () => {
    await pool.query("delete from app_users where id = any($1::uuid[])", [[ownerA, ownerB]]);
    await pool.end();
  });

  function appFor(appUserId: string) {
    const app = new Hono<{ Bindings: Env; Variables: Variables }>();
    app.use("*", async (c, next) => {
      c.set("auth", { appUserId, clerkUserId: `clerk_${appUserId}` });
      c.set("db", db as Variables["db"]);
      c.set("dbClient", pool as unknown as Variables["dbClient"]);
      await next();
    });
    app.route("/", matchRoutes);
    return app;
  }

  function bundle(id = matchId, homeTeamId = teamA, homeScore = 1) {
    return {
      match: {
        id,
        owner_id: ownerB,
        completed_at: "2026-07-14T00:00:00.000Z",
        number_of_periods: 2,
        home_team_id: homeTeamId,
        home_team_name: "Home",
        away_team_name: "Away",
        penalty_initial_rounds: 5,
        home_score: homeScore,
        away_score: 0,
      },
      periods: [], events: [], metrics: null,
    };
  }

  it("rejects a cross-tenant reference despite a client-supplied owner", async () => {
    const response = await appFor(ownerA).request("/ingest", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify(bundle(rejectedMatchId, teamB)),
    });
    expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({ error: "forbidden_reference", field: "home_team_id" });
  });

  it("serializes concurrent idempotency claims and rejects key reuse with another body", async () => {
    const app = appFor(ownerA);
    const request = (body: unknown) => app.request("/ingest", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Idempotency-Key": "integration-match-ingest" },
      body: JSON.stringify(body),
    });
    const [first, second] = await Promise.all([request(bundle()), request(bundle())]);
    expect([first.status, second.status]).toEqual([200, 200]);
    expect(await first.json()).toEqual(await second.json());
    const conflict = await request(bundle(matchId, teamA, 2));
    expect(conflict.status).toBe(409);
    expect(await conflict.json()).toMatchObject({ error: "idempotency_conflict" });
  });

  it("scopes reads and deletes to the resolved server owner", async () => {
    const foreignList = await appFor(ownerB).request("/");
    expect(foreignList.status).toBe(200);
    expect(await foreignList.json()).toEqual([]);
    const foreignDelete = await appFor(ownerB).request(`/${matchId}`, { method: "DELETE" });
    expect(foreignDelete.status).toBe(404);
    const ownerList = await appFor(ownerA).request("/");
    expect(ownerList.status).toBe(200);
    const rows = await ownerList.json() as Array<{ match: { id: string; owner_id: string } }>;
    expect(rows).toHaveLength(1);
    expect(rows[0]?.match).toMatchObject({ id: matchId, owner_id: ownerA });
  });
});

function validatedIntegrationDatabaseURL(): string {
  const value = process.env.REFWATCH_INTEGRATION_DATABASE_URL;
  if (!value || process.env.REFWATCH_ALLOW_DESTRUCTIVE_INTEGRATION_TESTS !== "1") {
    throw new Error("Database integration requires the managed ephemeral-role runner and explicit destructive-test opt-in");
  }
  const parsed = new URL(value);
  const username = decodeURIComponent(parsed.username);
  if (parsed.protocol !== "postgresql:" || !username.startsWith("pscale_api_") || !username.endsWith(`.${expectedDisposableBranchId}`)) {
    throw new Error("Database integration URL does not target the expected disposable PlanetScale branch");
  }
  if (parsed.searchParams.get("sslmode") !== "verify-full") {
    throw new Error("Database integration requires sslmode=verify-full");
  }
  return value;
}
