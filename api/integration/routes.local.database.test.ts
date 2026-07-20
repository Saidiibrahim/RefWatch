import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app";
import { appUsers } from "../src/db/schema";
import type { SessionVerifier } from "../src/middleware/auth";
import type { Env } from "../src/types";

const ownerA = "0190f8f4-5914-7b6c-9d6a-469a29f94101";
const ownerB = "0190f8f4-5914-7b6c-9d6a-469a29f94102";
const teamA = "0190f8f4-5914-7b6c-9d6a-469a29f94201";
const teamB = "0190f8f4-5914-7b6c-9d6a-469a29f94202";
const memberA = "0190f8f4-5914-7b6c-9d6a-469a29f94301";
const officialA = "0190f8f4-5914-7b6c-9d6a-469a29f94302";
const competitionA = "0190f8f4-5914-7b6c-9d6a-469a29f94401";
const competitionB = "0190f8f4-5914-7b6c-9d6a-469a29f94402";
const venueA = "0190f8f4-5914-7b6c-9d6a-469a29f94501";
const venueB = "0190f8f4-5914-7b6c-9d6a-469a29f94502";
const scheduleA = "0190f8f4-5914-7b6c-9d6a-469a29f94601";
const clerkInstanceId = "ins_local_route_matrix";
const databaseURL = validatedLocalDatabaseURL();

let verifierCalls = 0;
const verifySession: SessionVerifier = async (request) => {
  verifierCalls += 1;
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (token === "session-a") return { clerkUserId: "user_local_route_a", clerkInstanceId };
  if (token === "session-b") return { clerkUserId: "user_local_route_b", clerkInstanceId };
  return null;
};

const app = createApp({ sessionVerifier: verifySession });
const pool = new Pool({ connectionString: databaseURL, max: 4 });
const db = drizzle(pool, { schema: { appUsers } });
const env = {
  CLERK_SECRET_KEY: "unused-local-secret",
  CLERK_PUBLISHABLE_KEY: "unused-local-publishable-key",
  CLERK_WEBHOOK_SIGNING_SECRET: "unused-local-webhook-secret",
  OPENAI_API_KEY: "unused-local-openai-key",
  CLERK_INSTANCE_ID: clerkInstanceId,
  DATABASE_URL: databaseURL,
  REFWATCH_ENV: "local-route-matrix",
  WRITE_MODE: "enabled",
  CF_VERSION_METADATA: { id: "11111111-1111-4111-8111-111111111111" },
} satisfies Env;

describe("mounted authenticated routes against hermetic local Postgres", () => {
  beforeAll(async () => {
    await db.insert(appUsers).values([
      { id: ownerA, clerkUserId: "user_local_route_a", email: "a@example.invalid", displayName: "Owner A" },
      { id: ownerB, clerkUserId: "user_local_route_b", email: "b@example.invalid", displayName: "Owner B" },
    ]);
  });

  afterAll(async () => {
    await pool.query("delete from app_users where id = any($1::uuid[])", [[ownerA, ownerB]]);
    await pool.end();
  });

  it("fails closed before session verification when WRITE_MODE is absent", async () => {
    const callsBefore = verifierCalls;
    const response = await app.request("/api/teams", {
      method: "POST",
      headers: { Authorization: "Bearer session-a", "Content-Type": "application/json" },
      body: "{}",
    }, { ...env, WRITE_MODE: undefined });
    expect(response.status).toBe(503);
    expect(verifierCalls).toBe(callsBefore);
  });

  it("mounts authentication and resolves the opaque Clerk subject through /api/me", async () => {
    const missing = await app.request("/api/me", {}, env);
    expect(missing.status).toBe(401);

    const mapped = await requestAs("session-a", "/api/me");
    expect(mapped.status).toBe(200);
    await expect(mapped.json()).resolves.toEqual({
      appUserId: ownerA,
      clerkUserId: "user_local_route_a",
      email: "a@example.invalid",
      displayName: "Owner A",
    });
  });

  it("reads the migrated global 2026 reference catalog through authenticated routes", async () => {
    const competitions = await requestAs("session-a", "/api/reference-catalog/competitions?seasonYear=2026");
    const teams = await requestAs("session-a", "/api/reference-catalog/teams?seasonYear=2026");
    expect(competitions.status).toBe(200);
    expect(teams.status).toBe(200);
    expect(await competitions.json()).toHaveLength(5);
    expect(await teams.json()).toHaveLength(54);
  });

  it("keeps team, competition, venue, and schedule upserts owner-atomic", async () => {
    expect((await postAs("session-a", "/api/teams", teamBody({
      id: teamA, ownerId: ownerB, name: "Owner A Team", memberId: memberA, officialId: officialA,
    }))).status).toBe(200);
    expect((await postAs("session-b", "/api/teams", teamBody({
      id: teamB, ownerId: ownerA, name: "Owner B Team",
    }))).status).toBe(200);

    const ownerATeams = await requestAs("session-a", "/api/teams");
    const ownerBTeams = await requestAs("session-b", "/api/teams");
    expect(await ownerATeams.json()).toMatchObject([{
      team: { id: teamA, owner_id: ownerA, name: "Owner A Team" },
      members: [{ id: memberA, team_id: teamA, display_name: "Member A" }],
      officials: [{ id: officialA, team_id: teamA, display_name: "Official A" }],
      tags: [{ team_id: teamA, value: "primary" }],
    }]);
    expect(await ownerBTeams.json()).toMatchObject([{ team: { id: teamB, owner_id: ownerB } }]);

    const foreignTeamUpsert = await postAs("session-b", "/api/teams", teamBody({
      id: teamA, ownerId: ownerB, name: "Hijacked Team",
    }));
    expect(foreignTeamUpsert.status).toBe(403);
    await expect(foreignTeamUpsert.json()).resolves.toEqual({ error: "forbidden" });
    expect((await pool.query("select owner_id, name from teams where id = $1", [teamA])).rows[0]).toMatchObject({
      owner_id: ownerA,
      name: "Owner A Team",
    });
    expect((await pool.query("select display_name from team_members where id = $1", [memberA])).rows[0]?.display_name).toBe("Member A");
    expect((await pool.query("select display_name from team_officials where id = $1", [officialA])).rows[0]?.display_name).toBe("Official A");
    expect((await pool.query("select value from team_tags where team_id = $1", [teamA])).rows).toEqual([{ value: "primary" }]);

    for (const [token, path, body] of [
      ["session-a", "/api/competitions", { id: competitionA, owner_id: ownerB, name: "Owner A Competition", level: "state" }],
      ["session-b", "/api/competitions", { id: competitionB, owner_id: ownerA, name: "Owner B Competition", level: "state" }],
      ["session-a", "/api/venues", { id: venueA, owner_id: ownerB, name: "Owner A Venue", latitude: -34.9, longitude: 138.6 }],
      ["session-b", "/api/venues", { id: venueB, owner_id: ownerA, name: "Owner B Venue", latitude: -33.8, longitude: 151.2 }],
    ] as const) {
      expect((await postAs(token, path, body)).status).toBe(200);
    }

    expect((await postAs("session-b", "/api/competitions", {
      id: competitionA, owner_id: ownerB, name: "Hijacked Competition",
    })).status).toBe(403);
    expect((await postAs("session-b", "/api/venues", {
      id: venueA, owner_id: ownerB, name: "Hijacked Venue",
    })).status).toBe(403);
    expect((await pool.query("select owner_id, name from competitions where id = $1", [competitionA])).rows[0]).toMatchObject({ owner_id: ownerA, name: "Owner A Competition" });
    expect((await pool.query("select owner_id, name from venues where id = $1", [venueA])).rows[0]).toMatchObject({ owner_id: ownerA, name: "Owner A Venue" });

    const foreignReference = await postAs("session-a", "/api/scheduled-matches", scheduleBody({
      id: scheduleA, ownerId: ownerB, teamId: teamB, competitionId: competitionA, venueId: venueA,
    }));
    expect(foreignReference.status).toBe(403);
    await expect(foreignReference.json()).resolves.toEqual({ error: "forbidden_reference", field: "home_team_id" });

    expect((await postAs("session-a", "/api/scheduled-matches", scheduleBody({
      id: scheduleA, ownerId: ownerB, teamId: teamA, competitionId: competitionA, venueId: venueA,
    }))).status).toBe(200);
    const foreignScheduleUpsert = await postAs("session-b", "/api/scheduled-matches", scheduleBody({
      id: scheduleA, ownerId: ownerB, teamId: teamB, competitionId: competitionB, venueId: venueB,
    }));
    expect(foreignScheduleUpsert.status).toBe(403);
    expect((await pool.query("select owner_id, home_team_id from scheduled_matches where id = $1", [scheduleA])).rows[0]).toMatchObject({
      owner_id: ownerA,
      home_team_id: teamA,
    });

    expect((await requestAs("session-b", `/api/scheduled-matches/${scheduleA}`, { method: "DELETE" })).status).toBe(404);
    expect((await requestAs("session-a", `/api/scheduled-matches/${scheduleA}`, { method: "DELETE" })).status).toBe(204);
    expect(await (await requestAs("session-a", "/api/scheduled-matches")).json()).toEqual([]);
    const tombstones = await requestAs("session-a", "/api/scheduled-matches?updatedAfter=2020-01-01T00:00:00.000Z");
    expect(await tombstones.json()).toMatchObject([{ id: scheduleA, owner_id: ownerA }]);
  });
});

function requestAs(token: string, path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${token}`);
  return app.request(path, { ...init, headers }, env);
}

function postAs(token: string, path: string, body: unknown) {
  return requestAs(token, path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function teamBody(input: { id: string; ownerId: string; name: string; memberId?: string; officialId?: string }) {
  return {
    team: { id: input.id, owner_id: input.ownerId, name: input.name },
    members: input.memberId ? [{ id: input.memberId, team_id: input.id, display_name: "Member A" }] : [],
    officials: input.officialId ? [{ id: input.officialId, team_id: input.id, display_name: "Official A", role: "coach" }] : [],
    tags: input.memberId ? ["primary"] : [],
  };
}

function scheduleBody(input: { id: string; ownerId: string; teamId: string; competitionId: string; venueId: string }) {
  return {
    id: input.id,
    owner_id: input.ownerId,
    home_team_name: "Home",
    away_team_name: "Away",
    kickoff_at: "2026-07-18T10:00:00.000Z",
    home_team_id: input.teamId,
    competition_id: input.competitionId,
    venue_id: input.venueId,
  };
}

function validatedLocalDatabaseURL(): string {
  const value = process.env.REFWATCH_LOCAL_ROUTE_DATABASE_URL;
  if (!value || process.env.REFWATCH_ALLOW_LOCAL_ROUTE_TESTS !== "1") {
    throw new Error("Local route tests require the hermetic runner and explicit opt-in");
  }
  const parsed = new URL(value);
  if (parsed.protocol !== "postgresql:" || parsed.hostname !== "127.0.0.1" || parsed.pathname !== "/refwatch_local_routes") {
    throw new Error("Local route tests refuse non-loopback or unexpected databases");
  }
  if (parsed.searchParams.get("sslmode") !== "disable") {
    throw new Error("Local route tests require the temporary loopback server");
  }
  return value;
}
