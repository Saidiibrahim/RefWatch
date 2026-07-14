import { describe, expect, it } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";
import { findInvalidEventReference } from "../src/routes/matches";

const homeTeam = "0190f8f4-5914-7b6c-9d6a-469a29f92f2b";
const awayTeam = "0190f8f4-5914-7b6c-9d6a-469a29f92f2c";
const otherTeam = "0190f8f4-5914-7b6c-9d6a-469a29f92f2d";
const member = "0190f8f4-5914-7b6c-9d6a-469a29f92f2e";

function database(ownedTeams: string[], members: Array<{ id: string; teamId: string }>) {
  let selectCalls = 0;
  const queries: Array<{ sql: string; params: unknown[] }> = [];
  const dialect = new PgDialect();
  const db = {
    select(selection: Record<string, unknown>) {
      selectCalls += 1;
      const rows = "teamId" in selection ? members : ownedTeams.map((id) => ({ id }));
      const builder = {
        from() { return builder; },
        innerJoin() { return builder; },
        where(condition: Parameters<PgDialect["sqlToQuery"]>[0]) {
          queries.push(dialect.sqlToQuery(condition));
          return Promise.resolve(rows);
        },
      };
      return builder;
    },
  };
  return { db, queries, selectCalls: () => selectCalls };
}

function event(teamId: string | null, memberId: string | null = null) {
  return { team_id: teamId, team_member_id: memberId };
}

const match = { home_team_id: homeTeam, away_team_id: awayTeam };

describe("match event reference authorization", () => {
  it("accepts uppercase Swift UUIDs and batches repeated references into two lookups", async () => {
    const fixture = database([homeTeam], [{ id: member, teamId: homeTeam }]);
    const repeated = Array.from({ length: 50 }, () => event(homeTeam.toUpperCase(), member.toUpperCase()));

    await expect(findInvalidEventReference(fixture.db as never, "owner", match as never, repeated as never))
      .resolves.toBeNull();
    expect(fixture.selectCalls()).toBe(2);
    expect(fixture.queries).toHaveLength(2);
    for (const query of fixture.queries) {
      expect(query.sql).toContain('"teams"."owner_id" =');
      expect(query.params.filter((value) => value === "owner")).toHaveLength(1);
    }
    expect(fixture.queries[0]?.params.filter((value) => value === homeTeam)).toHaveLength(1);
    expect(fixture.queries[1]?.params.filter((value) => value === member)).toHaveLength(1);
  });

  it("rejects missing/cross-tenant and non-participating owned teams", async () => {
    const missing = database([], []);
    await expect(findInvalidEventReference(missing.db as never, "owner", match as never, [event(homeTeam)] as never))
      .resolves.toBe("events.0.team_id");

    const unrelated = database([otherTeam], []);
    await expect(findInvalidEventReference(unrelated.db as never, "owner", match as never, [event(otherTeam)] as never))
      .resolves.toBe("events.0.team_id");
  });

  it("rejects a member whose team does not match the referenced participating team", async () => {
    const fixture = database([homeTeam, awayTeam], [{ id: member, teamId: awayTeam }]);
    await expect(findInvalidEventReference(fixture.db as never, "owner", match as never, [event(homeTeam, member)] as never))
      .resolves.toBe("events.0.team_member_id");
  });
});
