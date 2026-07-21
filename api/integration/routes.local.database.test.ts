import { drizzle } from "drizzle-orm/node-postgres";
import { Pool, type PoolClient } from "pg";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app";
import * as schema from "../src/db/schema";
import { identityReconciliationReceipts } from "../src/db/schema";
import type { SessionVerifier } from "../src/middleware/auth";
import {
  EMPTY_IDENTITY_MAPPING_HASH,
  GREENFIELD_AUTHORIZATION_DIGEST,
  GREENFIELD_AUTHORIZATION_PROFILE,
  GREENFIELD_ONBOARDING_MODE,
  GREENFIELD_RECONCILIATION_PROFILE,
  GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
  PRODUCTION_CLERK_DOMAIN,
  PRODUCTION_CLERK_INSTANCE_ID,
  PRODUCTION_CLERK_ISSUER,
} from "../src/services/identityProfiles";
import {
  activateIdentityReconciliationReceipt,
  greenfieldReconciliationActivationExpectation,
  recordClerkUserDeletion,
} from "../src/services/userOnboarding";
import { entityMutationAdvisoryKey } from "../src/services/entityMutationVersion";
import type { Env } from "../src/types";

const clerkSubjectA = "user_local_route_a";
const clerkSubjectB = "user_local_route_b";
const tombstonedClerkSubject = "user_local_route_tombstoned";

const teamA = "0190f8f4-5914-7b6c-9d6a-469a29f94201";
const teamB = "0190f8f4-5914-7b6c-9d6a-469a29f94202";
const awayTeamA = "0190f8f4-5914-7b6c-9d6a-469a29f94203";
const deletedTeamA = "0190f8f4-5914-7b6c-9d6a-469a29f94204";
const memberA = "0190f8f4-5914-7b6c-9d6a-469a29f94301";
const memberB = "0190f8f4-5914-7b6c-9d6a-469a29f94302";
const awayMemberA = "0190f8f4-5914-7b6c-9d6a-469a29f94303";
const officialA = "0190f8f4-5914-7b6c-9d6a-469a29f94311";
const competitionA = "0190f8f4-5914-7b6c-9d6a-469a29f94401";
const competitionB = "0190f8f4-5914-7b6c-9d6a-469a29f94402";
const deletedCompetitionA = "0190f8f4-5914-7b6c-9d6a-469a29f94403";
const venueA = "0190f8f4-5914-7b6c-9d6a-469a29f94501";
const venueB = "0190f8f4-5914-7b6c-9d6a-469a29f94502";
const deletedVenueA = "0190f8f4-5914-7b6c-9d6a-469a29f94503";
const scheduleA = "0190f8f4-5914-7b6c-9d6a-469a29f94601";
const scheduleB = "0190f8f4-5914-7b6c-9d6a-469a29f94602";
const deletedScheduleA = "0190f8f4-5914-7b6c-9d6a-469a29f94603";
const matchA = "0190f8f4-5914-7b6c-9d6a-469a29f94701";
const matchB = "0190f8f4-5914-7b6c-9d6a-469a29f94702";
const foreignReferenceMatch = "0190f8f4-5914-7b6c-9d6a-469a29f94703";
const idempotentMatchA = "0190f8f4-5914-7b6c-9d6a-469a29f94704";
const assessmentMatchA = "0190f8f4-5914-7b6c-9d6a-469a29f94705";
const concurrentAssessmentMatchA = "0190f8f4-5914-7b6c-9d6a-469a29f94706";
const periodA1 = "0190f8f4-5914-7b6c-9d6a-469a29f94801";
const periodA2 = "0190f8f4-5914-7b6c-9d6a-469a29f94802";
const eventA = "0190f8f4-5914-7b6c-9d6a-469a29f94901";
const assessmentA = "0190f8f4-5914-7b6c-9d6a-469a29f94a01";
const assessmentConflictA = "0190f8f4-5914-7b6c-9d6a-469a29f94a02";
const assessmentB = "0190f8f4-5914-7b6c-9d6a-469a29f94a03";
const concurrentAssessmentA1 = "0190f8f4-5914-7b6c-9d6a-469a29f94a04";
const concurrentAssessmentA2 = "0190f8f4-5914-7b6c-9d6a-469a29f94a05";
const monotonicCompetitionA = "0190f8f4-5914-7b6c-9d6a-469a29f94b01";
const monotonicVenueA = "0190f8f4-5914-7b6c-9d6a-469a29f94b02";

const databaseURL = validatedLocalDatabaseURL();
const pool = new Pool({ connectionString: databaseURL, max: 12 });
const db = drizzle(pool, { schema });
let ownerA = "";
let ownerB = "";
let verifierCalls = 0;

const verifySession: SessionVerifier = async (request) => {
  verifierCalls += 1;
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (token === "session-a") {
    return { clerkUserId: clerkSubjectA, clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID };
  }
  if (token === "session-b") {
    return { clerkUserId: clerkSubjectB, clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID };
  }
  if (token === "session-tombstoned") {
    return { clerkUserId: tombstonedClerkSubject, clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID };
  }
  return null;
};

const app = createApp({ sessionVerifier: verifySession });
const env = {
  CLERK_SECRET_KEY: "unused-local-secret",
  CLERK_PUBLISHABLE_KEY: "unused-local-publishable-key",
  CLERK_WEBHOOK_SIGNING_SECRET: "unused-local-webhook-secret",
  OPENAI_API_KEY: "server-only-openai-key",
  CLERK_INSTANCE_ID: PRODUCTION_CLERK_INSTANCE_ID,
  CLERK_ISSUER: PRODUCTION_CLERK_ISSUER,
  DATABASE_URL: databaseURL,
  REFWATCH_ENV: "local-route-matrix",
  WRITE_MODE: "enabled",
  NEW_USER_ONBOARDING_MODE: GREENFIELD_ONBOARDING_MODE,
  IDENTITY_RECONCILIATION_RECEIPT: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
  IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST: GREENFIELD_AUTHORIZATION_DIGEST,
  CF_VERSION_METADATA: { id: "11111111-1111-4111-8111-111111111111" },
} satisfies Env;

describe("mounted authenticated routes against hermetic local Postgres", () => {
  beforeAll(async () => {
    const initial = await pool.query("select count(*)::int as count from app_users");
    expect(initial.rows[0]?.count).toBe(0);
    await db.insert(identityReconciliationReceipts).values(exactGreenfieldReceipt());
    await expect(activateIdentityReconciliationReceipt(
      db,
      GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
      PRODUCTION_CLERK_INSTANCE_ID,
      greenfieldReconciliationActivationExpectation(),
    )).resolves.toBe(true);
  });

  afterAll(async () => {
    vi.unstubAllGlobals();
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
    expect((await pool.query("select count(*)::int as count from app_users")).rows[0]?.count).toBe(0);
  });

  it("bootstraps a new production-bound subject once across eight mounted /api/me requests and rejects a tombstoned subject", async () => {
    const responses = await Promise.all(Array.from({ length: 8 }, () => requestAs("session-a", "/api/me")));
    expect(responses.map((response) => response.status)).toEqual(Array(8).fill(200));
    const identities = await Promise.all(responses.map((response) => response.json() as Promise<MeResponse>));
    expect(new Set(identities.map((identity) => identity.appUserId))).toHaveLength(1);
    expect(identities.every((identity) => identity.clerkUserId === clerkSubjectA)).toBe(true);
    ownerA = identities[0]!.appUserId;
    expect(ownerA).toMatch(/^[0-9a-f-]{36}$/);

    const ownerBResponse = await requestAs("session-b", "/api/me");
    expect(ownerBResponse.status).toBe(200);
    ownerB = ((await ownerBResponse.json()) as MeResponse).appUserId;
    expect(ownerB).toMatch(/^[0-9a-f-]{36}$/);
    expect(ownerB).not.toBe(ownerA);

    await recordClerkUserDeletion(db, {
      clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
      clerkUserId: tombstonedClerkSubject,
      webhookEventId: "svix_local_route_tombstone",
      deletedAt: new Date("2026-07-20T00:00:00.000Z"),
    });
    const tombstoned = await requestAs("session-tombstoned", "/api/me");
    expect(tombstoned.status).toBe(403);
    await expect(tombstoned.json()).resolves.toMatchObject({ error: "account_mapping_required" });

    const users = await pool.query(
      "select clerk_user_id, count(*)::int as count from app_users group by clerk_user_id order by clerk_user_id",
    );
    expect(users.rows).toEqual([
      { clerk_user_id: clerkSubjectA, count: 1 },
      { clerk_user_id: clerkSubjectB, count: 1 },
    ]);
  });

  it("mounts fail-closed authentication and reads the deterministic 2026 reference catalog", async () => {
    const missing = await app.request("/api/me", {}, env);
    expect(missing.status).toBe(401);

    const invalid = await requestAs("not-a-session", "/api/me");
    expect(invalid.status).toBe(401);

    const mapped = await requestAs("session-a", "/api/me");
    expect(mapped.status).toBe(200);
    await expect(mapped.json()).resolves.toMatchObject({
      appUserId: ownerA,
      clerkUserId: clerkSubjectA,
      email: null,
      displayName: null,
    });

    const competitions = await requestAs("session-a", "/api/reference-catalog/competitions?seasonYear=2026");
    const teams = await requestAs("session-a", "/api/reference-catalog/teams?seasonYear=2026");
    expect(competitions.status).toBe(200);
    expect(teams.status).toBe(200);
    expect(await competitions.json()).toHaveLength(5);
    expect(await teams.json()).toHaveLength(54);
  });

  it("rejects team replacement collections above the bounded roster and tag limits", async () => {
    const oversizedCases = [
      {
        teamId: crypto.randomUUID(),
        field: "members",
        count: 101,
        row: (teamId: string) => ({
          id: crypto.randomUUID(),
          team_id: teamId,
          display_name: "Member",
        }),
      },
      {
        teamId: crypto.randomUUID(),
        field: "officials",
        count: 26,
        row: (teamId: string) => ({
          id: crypto.randomUUID(),
          team_id: teamId,
          display_name: "Official",
          role: "coach",
        }),
      },
      {
        teamId: crypto.randomUUID(),
        field: "tags",
        count: 51,
        row: (_teamId: string, index: number) => `tag-${index}`,
      },
    ] as const;

    for (const oversized of oversizedCases) {
      const body = {
        team: { id: oversized.teamId, name: "Oversized team" },
        members: [] as unknown[],
        officials: [] as unknown[],
        tags: [] as unknown[],
      };
      body[oversized.field] = Array.from(
        { length: oversized.count },
        (_, index) => oversized.row(oversized.teamId, index));
      const response = await postAs("session-a", "/api/teams", body);
      expect(response.status, oversized.field).toBe(422);
      await expect(response.json()).resolves.toMatchObject({ error: "validation_error" });
      expect((await pool.query(
        "select count(*)::int as count from teams where id = $1",
        [oversized.teamId],
      )).rows[0]?.count).toBe(0);
    }
  });

  it("serializes same-clock competition update contention with strictly monotonic versions", async () => {
    const fixedClock = new Date("2026-07-20T04:00:00.000Z");
    vi.setSystemTime(fixedClock);
    const created = await postAs("session-a", "/api/competitions", {
      id: monotonicCompetitionA,
      name: "Initial monotonic competition",
    });
    expect(created.status).toBe(200);
    const initial = (await created.json()) as VersionedPayload;
    expect(new Date(initial.updated_at).getTime()).toBe(fixedClock.getTime());
    const blocker = await holdEntityMutationLock(
      entityMutationAdvisoryKey("competition", monotonicCompetitionA));

    try {
      const firstPromise = postAs("session-a", "/api/competitions", {
        id: monotonicCompetitionA,
        name: "Contender one",
      });
      await waitForAdvisoryWaiters(1);
      const secondPromise = postAs("session-a", "/api/competitions", {
        id: monotonicCompetitionA.toUpperCase(),
        name: "Contender two",
      });
      await waitForAdvisoryWaiters(2);
      await blocker.query("commit");

      const [firstResponse, secondResponse] = await Promise.all([firstPromise, secondPromise]);
      expect(firstResponse.status).toBe(200);
      expect(secondResponse.status).toBe(200);
      const receipts = [
        { name: "Contender one", row: (await firstResponse.json()) as VersionedPayload },
        { name: "Contender two", row: (await secondResponse.json()) as VersionedPayload },
      ];
      const receiptTimes = receipts.map(({ row }) => new Date(row.updated_at).getTime());
      expect(new Set(receiptTimes)).toHaveLength(2);
      expect(receiptTimes.sort((left, right) => left - right)).toEqual([
        fixedClock.getTime() + 1,
        fixedClock.getTime() + 2,
      ]);

      const latestReceipt = receipts.reduce((latest, current) =>
        new Date(current.row.updated_at) > new Date(latest.row.updated_at) ? current : latest);
      const final = (await pool.query(
        "select name, updated_at from competitions where id = $1",
        [monotonicCompetitionA],
      )).rows[0] as { name: string; updated_at: Date };
      expect(final.name).toBe(latestReceipt.name);
      expect(final.updated_at.getTime()).toBe(new Date(latestReceipt.row.updated_at).getTime());
    } finally {
      await blocker.query("rollback").catch(() => undefined);
      blocker.release();
      vi.useRealTimers();
    }
  });

  it("orders same-clock venue delete then resurrection contention and preserves the max payload", async () => {
    const fixedClock = new Date("2026-07-20T04:30:00.000Z");
    vi.setSystemTime(fixedClock);
    const created = await postAs("session-a", "/api/venues", {
      id: monotonicVenueA,
      name: "Initial monotonic venue",
    });
    expect(created.status).toBe(200);
    const initial = (await created.json()) as VersionedPayload;
    expect(new Date(initial.updated_at).getTime()).toBe(fixedClock.getTime());
    const key = entityMutationAdvisoryKey("venue", monotonicVenueA);
    const blocker = await holdEntityMutationLock(key);
    const observer = await pool.connect();
    await observer.query("begin");

    try {
      const deletePromise = requestAs("session-a", `/api/venues/${monotonicVenueA}`, {
        method: "DELETE",
      });
      await waitForAdvisoryWaiters(1);

      const observerLockPromise = observer.query(
        "select pg_advisory_xact_lock(hashtextextended($1, 0))",
        [key],
      );
      await waitForAdvisoryWaiters(2);

      const resurrectionPromise = postAs("session-a", "/api/venues", {
        id: monotonicVenueA.toUpperCase(),
        name: "Resurrected monotonic venue",
        city: "Adelaide",
      });
      await waitForAdvisoryWaiters(3);
      await blocker.query("commit");

      const deleted = await deletePromise;
      expect(deleted.status).toBe(204);
      await observerLockPromise;
      const tombstone = (await observer.query(
        "select deleted_at, updated_at from venues where id = $1",
        [monotonicVenueA],
      )).rows[0] as { deleted_at: Date; updated_at: Date };
      expect(tombstone.deleted_at.getTime()).toBe(tombstone.updated_at.getTime());
      expect(tombstone.updated_at.getTime()).toBe(fixedClock.getTime() + 1);
      await observer.query("commit");

      const resurrected = await resurrectionPromise;
      expect(resurrected.status).toBe(200);
      const resurrectionReceipt = (await resurrected.json()) as VersionedPayload;
      expect(new Date(resurrectionReceipt.updated_at).getTime()).toBe(fixedClock.getTime() + 2);
      const final = (await pool.query(
        "select name, city, deleted_at, updated_at from venues where id = $1",
        [monotonicVenueA],
      )).rows[0] as {
        name: string;
        city: string;
        deleted_at: Date | null;
        updated_at: Date;
      };
      expect(final).toMatchObject({
        name: "Resurrected monotonic venue",
        city: "Adelaide",
        deleted_at: null,
      });
      expect(final.updated_at.getTime()).toBe(new Date(resurrectionReceipt.updated_at).getTime());
    } finally {
      await blocker.query("rollback").catch(() => undefined);
      blocker.release();
      await observer.query("rollback").catch(() => undefined);
      observer.release();
      vi.useRealTimers();
    }
  });

  it("derives ownership for team, competition, and venue writes and rejects cross-owner replacement", async () => {
    const uppercaseRetry = teamBody({
      id: teamA,
      ownerId: ownerB,
      name: "Owner A Team",
      memberId: memberA,
      officialId: officialA,
    });
    uppercaseRetry.team.id = uppercaseRetry.team.id.toUpperCase();
    uppercaseRetry.members[0]!.id = uppercaseRetry.members[0]!.id.toUpperCase();
    uppercaseRetry.members[0]!.team_id = uppercaseRetry.members[0]!.team_id.toUpperCase();
    uppercaseRetry.officials[0]!.id = uppercaseRetry.officials[0]!.id.toUpperCase();
    uppercaseRetry.officials[0]!.team_id = uppercaseRetry.officials[0]!.team_id.toUpperCase();
    expect((await postAs("session-a", "/api/teams", uppercaseRetry)).status).toBe(200);
    expect((await postAs("session-a", "/api/teams", teamBody({
      id: awayTeamA,
      ownerId: ownerB,
      name: "Owner A Away",
      memberId: awayMemberA,
    }))).status).toBe(200);
    expect((await postAs("session-b", "/api/teams", teamBody({
      id: teamB,
      ownerId: ownerA,
      name: "Owner B Team",
      memberId: memberB,
    }))).status).toBe(200);

    const nestedSpoof = await postAs("session-a", "/api/teams", {
      ...teamBody({ id: teamA, ownerId: ownerB, name: "Nested mismatch" }),
      members: [{ id: memberA, team_id: teamB, display_name: "Wrong parent" }],
    });
    expect(nestedSpoof.status).toBe(422);
    await expect(nestedSpoof.json()).resolves.toEqual({ error: "nested_team_mismatch" });

    const caseVariantDuplicate = await postAs("session-a", "/api/teams", {
      ...teamBody({ id: teamA, ownerId: ownerB, name: "Duplicate nested IDs" }),
      members: [
        { id: memberA, team_id: teamA, display_name: "Member" },
        { id: memberA.toUpperCase(), team_id: teamA.toUpperCase(), display_name: "Duplicate" },
      ],
    });
    expect(caseVariantDuplicate.status).toBe(422);
    await expect(caseVariantDuplicate.json()).resolves.toEqual({ error: "nested_team_mismatch" });

    const ownerATeams = (await (await requestAs("session-a", "/api/teams")).json()) as TeamEnvelope[];
    const ownerBTeams = (await (await requestAs("session-b", "/api/teams")).json()) as TeamEnvelope[];
    expect(ownerATeams.map((row) => row.team.id).sort()).toEqual([awayTeamA, teamA].sort());
    expect(ownerATeams.find((row) => row.team.id === teamA)).toMatchObject({
      team: { id: teamA, owner_id: ownerA, name: "Owner A Team" },
      members: [{ id: memberA, team_id: teamA, display_name: "Member" }],
      officials: [{ id: officialA, team_id: teamA, display_name: "Official" }],
      tags: [{ team_id: teamA, value: "primary" }],
    });
    expect(ownerBTeams).toMatchObject([{ team: { id: teamB, owner_id: ownerB, name: "Owner B Team" } }]);

    const foreignTeamUpsert = await postAs("session-b", "/api/teams", teamBody({
      id: teamA,
      ownerId: ownerB,
      name: "Hijacked Team",
    }));
    expect(foreignTeamUpsert.status).toBe(403);
    await expect(foreignTeamUpsert.json()).resolves.toEqual({ error: "forbidden" });

    const nestedIdentityConflict = await postAs("session-a", "/api/teams", {
      ...teamBody({ id: teamA, ownerId: ownerB, name: "Must Roll Back" }),
      members: [{ id: memberB, team_id: teamA, display_name: "Foreign member" }],
    });
    expect(nestedIdentityConflict.status).toBe(422);
    await expect(nestedIdentityConflict.json()).resolves.toEqual({ error: "nested_team_mismatch" });
    expect((await pool.query("select owner_id, name from teams where id = $1", [teamA])).rows[0]).toMatchObject({
      owner_id: ownerA,
      name: "Owner A Team",
    });
    expect((await pool.query("select team_id from team_members where id = $1", [memberB])).rows[0]?.team_id).toBe(teamB);

    for (const [token, path, body] of [
      ["session-a", "/api/competitions", { id: competitionA, owner_id: ownerB, name: "Owner A Competition", level: "state" }],
      ["session-b", "/api/competitions", { id: competitionB, owner_id: ownerA, name: "Owner B Competition", level: "state" }],
      ["session-a", "/api/venues", { id: venueA, owner_id: ownerB, name: "Owner A Venue", latitude: -34.9, longitude: 138.6 }],
      ["session-b", "/api/venues", { id: venueB, owner_id: ownerA, name: "Owner B Venue", latitude: -33.8, longitude: 151.2 }],
    ] as const) {
      expect((await postAs(token, path, body)).status).toBe(200);
    }

    expect((await postAs("session-b", "/api/competitions", {
      id: competitionA,
      owner_id: ownerB,
      name: "Hijacked Competition",
    })).status).toBe(403);
    expect((await postAs("session-b", "/api/venues", {
      id: venueA,
      owner_id: ownerB,
      name: "Hijacked Venue",
    })).status).toBe(403);

    expect((await pool.query("select owner_id, name from teams where id = $1", [teamA])).rows[0]).toMatchObject({
      owner_id: ownerA,
      name: "Owner A Team",
    });
    expect((await pool.query("select owner_id, name from competitions where id = $1", [competitionA])).rows[0]).toMatchObject({
      owner_id: ownerA,
      name: "Owner A Competition",
    });
    expect((await pool.query("select owner_id, name from venues where id = $1", [venueA])).rows[0]).toMatchObject({
      owner_id: ownerA,
      name: "Owner A Venue",
    });
  });

  it("synchronizes owner-scoped team, competition, and venue tombstones", async () => {
    expect((await postAs("session-a", "/api/teams", teamBody({
      id: deletedTeamA,
      ownerId: ownerB,
      name: "Delete Team",
    }))).status).toBe(200);
    expect((await postAs("session-a", "/api/competitions", {
      id: deletedCompetitionA,
      owner_id: ownerB,
      name: "Delete Competition",
    })).status).toBe(200);
    expect((await postAs("session-a", "/api/venues", {
      id: deletedVenueA,
      owner_id: ownerB,
      name: "Delete Venue",
    })).status).toBe(200);

    for (const [path, id] of [
      ["/api/teams", deletedTeamA],
      ["/api/competitions", deletedCompetitionA],
      ["/api/venues", deletedVenueA],
    ] as const) {
      expect((await requestAs("session-b", `${path}/${id}`, { method: "DELETE" })).status).toBe(404);
      expect((await requestAs("session-a", `${path}/${id}`, { method: "DELETE" })).status).toBe(204);

      const active = (await (await requestAs("session-a", path)).json()) as Array<Record<string, unknown>>;
      expect(extractIDs(active)).not.toContain(id);
      const changes = (await (await requestAs(
        "session-a",
        `${path}?updatedAfter=2020-01-01T00:00:00.000Z`,
      )).json()) as Array<Record<string, unknown>>;
      expect(extractIDs(changes)).toContain(id);
      const tombstone = findByID(changes, id);
      expect(tombstone).toMatchObject({ deleted_at: expect.any(String), updated_at: expect.any(String) });
      const exactBoundary = (await (await requestAs(
        "session-a",
        `${path}?updatedAfter=${encodeURIComponent(String(tombstone?.updated_at))}`,
      )).json()) as Array<Record<string, unknown>>;
      expect(extractIDs(exactBoundary)).toContain(id);

      const foreignChanges = (await (await requestAs(
        "session-b",
        `${path}?updatedAfter=${encodeURIComponent(String(tombstone?.updated_at))}`,
      )).json()) as Array<Record<string, unknown>>;
      expect(extractIDs(foreignChanges)).not.toContain(id);
    }
  });

  it("validates every scheduled-match foreign reference, ignores owner spoofing, and synchronizes deletes", async () => {
    const foreignReferenceCases: Array<[string, Partial<ScheduleInput>]> = [
      ["home_team_id", { home_team_id: teamB }],
      ["away_team_id", { away_team_id: teamB }],
      ["competition_id", { competition_id: competitionB }],
      ["venue_id", { venue_id: venueB }],
      ["home_team_id", { home_team_id: deletedTeamA }],
      ["competition_id", { competition_id: deletedCompetitionA }],
      ["venue_id", { venue_id: deletedVenueA }],
    ];
    for (const [field, override] of foreignReferenceCases) {
      const response = await postAs("session-a", "/api/scheduled-matches", {
        ...scheduleBody({
          id: deletedScheduleA,
          ownerId: ownerB,
          homeTeamId: teamA,
          awayTeamId: awayTeamA,
          competitionId: competitionA,
          venueId: venueA,
        }),
        ...override,
      });
      expect(response.status, field).toBe(403);
      await expect(response.json()).resolves.toEqual({ error: "forbidden_reference", field });
    }

    expect((await postAs("session-a", "/api/scheduled-matches", scheduleBody({
      id: scheduleA,
      ownerId: ownerB,
      homeTeamId: teamA,
      awayTeamId: awayTeamA,
      competitionId: competitionA,
      venueId: venueA,
    }))).status).toBe(200);
    expect((await postAs("session-b", "/api/scheduled-matches", scheduleBody({
      id: scheduleB,
      ownerId: ownerA,
      homeTeamId: teamB,
      awayTeamId: teamB,
      competitionId: competitionB,
      venueId: venueB,
    }))).status).toBe(200);
    expect((await postAs("session-a", "/api/scheduled-matches", scheduleBody({
      id: deletedScheduleA,
      ownerId: ownerB,
      homeTeamId: teamA,
      awayTeamId: awayTeamA,
      competitionId: competitionA,
      venueId: venueA,
    }))).status).toBe(200);

    const foreignUpsert = await postAs("session-b", "/api/scheduled-matches", scheduleBody({
      id: scheduleA,
      ownerId: ownerB,
      homeTeamId: teamB,
      awayTeamId: teamB,
      competitionId: competitionB,
      venueId: venueB,
    }));
    expect(foreignUpsert.status).toBe(403);
    await expect(foreignUpsert.json()).resolves.toEqual({ error: "forbidden" });

    const ownerARows = (await (await requestAs("session-a", "/api/scheduled-matches")).json()) as ScheduleRow[];
    const ownerBRows = (await (await requestAs("session-b", "/api/scheduled-matches")).json()) as ScheduleRow[];
    expect(ownerARows.map((row) => row.id).sort()).toEqual([deletedScheduleA, scheduleA].sort());
    expect(ownerARows.find((row) => row.id === scheduleA)).toMatchObject({
      id: scheduleA,
      owner_id: ownerA,
      home_team_id: teamA,
      away_team_id: awayTeamA,
      competition_id: competitionA,
      venue_id: venueA,
    });
    expect(ownerBRows).toMatchObject([{ id: scheduleB, owner_id: ownerB }]);

    expect((await requestAs("session-b", `/api/scheduled-matches/${deletedScheduleA}`, { method: "DELETE" })).status).toBe(404);
    expect((await requestAs("session-a", `/api/scheduled-matches/${deletedScheduleA}`, { method: "DELETE" })).status).toBe(204);
    expect((await requestAs("session-a", `/api/scheduled-matches/${deletedScheduleA}`, { method: "DELETE" })).status).toBe(404);
    const active = (await (await requestAs("session-a", "/api/scheduled-matches")).json()) as ScheduleRow[];
    expect(active.map((row) => row.id)).not.toContain(deletedScheduleA);
    const changes = (await (await requestAs(
      "session-a",
      "/api/scheduled-matches?updatedAfter=2020-01-01T00:00:00.000Z",
    )).json()) as ScheduleRow[];
    const tombstone = changes.find((row) => row.id === deletedScheduleA);
    expect(tombstone).toMatchObject({
      id: deletedScheduleA,
      owner_id: ownerA,
      deleted_at: expect.any(String),
      updated_at: expect.any(String),
    });
    const exactBoundary = (await (await requestAs(
      "session-a",
      `/api/scheduled-matches?updatedAfter=${encodeURIComponent(String(tombstone?.updated_at))}`,
    )).json()) as ScheduleRow[];
    expect(exactBoundary.map((row) => row.id)).toContain(deletedScheduleA);
    const foreignBoundary = (await (await requestAs(
      "session-b",
      `/api/scheduled-matches?updatedAfter=${encodeURIComponent(String(tombstone?.updated_at))}`,
    )).json()) as ScheduleRow[];
    expect(foreignBoundary.map((row) => row.id)).not.toContain(deletedScheduleA);
  });

  it("rejects every foreign or tombstoned match reference, including event team/member references", async () => {
    const valid = matchBody({
      id: foreignReferenceMatch,
      ownerId: ownerB,
      scheduledMatchId: scheduleA,
      homeTeamId: teamA,
      awayTeamId: awayTeamA,
      competitionId: competitionA,
      venueId: venueA,
    });
    const referenceCases: Array<[string, MatchBundle]> = [
      ["scheduled_match_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, scheduledMatchId: scheduleB })],
      ["home_team_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, homeTeamId: teamB })],
      ["away_team_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, awayTeamId: teamB })],
      ["competition_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, competitionId: competitionB })],
      ["venue_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, venueId: venueB })],
      ["scheduled_match_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, scheduledMatchId: deletedScheduleA })],
      ["home_team_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, homeTeamId: deletedTeamA })],
      ["away_team_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, awayTeamId: deletedTeamA })],
      ["competition_id", matchBody({
        id: foreignReferenceMatch,
        ownerId: ownerB,
        competitionId: deletedCompetitionA,
      })],
      ["venue_id", matchBody({ id: foreignReferenceMatch, ownerId: ownerB, venueId: deletedVenueA })],
      ["events.0.team_id", {
        ...valid,
        events: [eventBody({
          id: eventA,
          matchId: foreignReferenceMatch,
          teamId: teamB,
          memberId: memberB,
        })],
      }],
      ["events.0.team_member_id", {
        ...valid,
        events: [eventBody({
          id: eventA,
          matchId: foreignReferenceMatch,
          teamId: teamA,
          memberId: memberB,
        })],
      }],
      ["events.0.team_member_id", {
        ...valid,
        events: [eventBody({
          id: eventA,
          matchId: foreignReferenceMatch,
          teamId: teamA,
          memberId: awayMemberA,
        })],
      }],
    ];
    for (const [field, body] of referenceCases) {
      const response = await postAs("session-a", "/api/matches/ingest", body);
      expect(response.status, field).toBe(403);
      await expect(response.json()).resolves.toEqual({ error: "forbidden_reference", field });
    }
    expect((await pool.query("select count(*)::int as count from matches where id = $1", [foreignReferenceMatch])).rows[0]?.count).toBe(0);
  });

  it("round-trips a full match bundle with periods, events, metrics, authoritative ownership, and tenant isolation", async () => {
    const body = fullMatchBody(matchA, ownerB);
    const created = await postAs("session-a", "/api/matches/ingest", body);
    expect(created.status).toBe(200);
    await expect(created.json()).resolves.toMatchObject({ match_id: matchA, updated_at: expect.any(String) });

    const ownerARows = (await (await requestAs("session-a", "/api/matches")).json()) as MatchEnvelope[];
    const ownerBRows = (await (await requestAs("session-b", "/api/matches")).json()) as MatchEnvelope[];
    const saved = ownerARows.find((row) => row.match.id === matchA);
    expect(saved).toMatchObject({
      match: {
        id: matchA,
        owner_id: ownerA,
        scheduled_match_id: scheduleA,
        home_team_id: teamA,
        away_team_id: awayTeamA,
        competition_id: competitionA,
        venue_id: venueA,
        home_score: 2,
        away_score: 1,
      },
      periods: [
        { id: periodA1, match_id: matchA, index: 0, regulation_seconds: 2700 },
        { id: periodA2, match_id: matchA, index: 1, regulation_seconds: 2700 },
      ],
      events: [{
        id: eventA,
        match_id: matchA,
        event_type: "goal",
        team_id: teamA,
        team_member_id: memberA,
      }],
      metrics: {
        match_id: matchA,
        owner_id: ownerA,
        total_goals: 3,
        total_cards: 2,
      },
    });
    expect(ownerBRows.map((row) => row.match.id)).not.toContain(matchA);

    const foreignUpsert = await postAs("session-b", "/api/matches/ingest", {
      ...body,
      match: {
        ...body.match,
        owner_id: ownerB,
        scheduled_match_id: scheduleB,
        home_team_id: teamB,
        away_team_id: teamB,
        competition_id: competitionB,
        venue_id: venueB,
      },
      events: [],
    });
    expect(foreignUpsert.status).toBe(403);
    await expect(foreignUpsert.json()).resolves.toEqual({ error: "forbidden" });
    expect((await pool.query("select owner_id, home_score from matches where id = $1", [matchA])).rows[0]).toMatchObject({
      owner_id: ownerA,
      home_score: 2,
    });
  });

  it("preserves historical match-event member linkage across retained team retries and nulls it only on explicit removal", async () => {
    expect((await pool.query(
      "select team_member_id from match_events where id = $1",
      [eventA],
    )).rows[0]?.team_member_id).toBe(memberA);

    expect((await postAs("session-a", "/api/teams", teamBody({
      id: teamA,
      ownerId: ownerB,
      name: "Owner A Team",
      memberId: memberA,
      officialId: officialA,
    }))).status).toBe(200);
    expect((await pool.query(
      "select team_member_id from match_events where id = $1",
      [eventA],
    )).rows[0]?.team_member_id).toBe(memberA);

    const updatedTeam = teamBody({
      id: teamA,
      ownerId: ownerB,
      name: "Owner A Team",
      memberId: memberA,
      officialId: officialA,
    });
    updatedTeam.members[0]!.display_name = "Member Updated";
    expect((await postAs("session-a", "/api/teams", updatedTeam)).status).toBe(200);
    expect((await pool.query(
      "select team_member_id from match_events where id = $1",
      [eventA],
    )).rows[0]?.team_member_id).toBe(memberA);
    expect((await pool.query(
      "select display_name from team_members where id = $1",
      [memberA],
    )).rows[0]?.display_name).toBe("Member Updated");

    expect((await postAs("session-a", "/api/teams", teamBody({
      id: teamA,
      ownerId: ownerB,
      name: "Owner A Team",
      officialId: officialA,
    }))).status).toBe(200);
    expect((await pool.query(
      "select team_member_id from match_events where id = $1",
      [eventA],
    )).rows[0]?.team_member_id).toBeNull();
    expect((await pool.query(
      "select id from team_officials where id = $1",
      [officialA],
    )).rows[0]?.id).toBe(officialA);
  });

  it("serializes identical concurrent match retries, rejects changed payloads, and scopes idempotency keys by owner", async () => {
    const bodyA = matchBody({ id: idempotentMatchA, ownerId: ownerB });
    const key = "local-concurrent-match-key";
    const concurrent = await Promise.all([
      postAs("session-a", "/api/matches/ingest", bodyA, { "Idempotency-Key": key }),
      postAs("session-a", "/api/matches/ingest", bodyA, { "Idempotency-Key": key }),
    ]);
    expect(concurrent.map((response) => response.status).sort()).toEqual([200, 200]);
    const concurrentBodies = await Promise.all(concurrent.map((response) => response.json()));
    expect(concurrentBodies[0]).toEqual(concurrentBodies[1]);
    expect(concurrentBodies[0]).toMatchObject({ match_id: idempotentMatchA });

    const changed = await postAs("session-a", "/api/matches/ingest", {
      ...bodyA,
      match: { ...bodyA.match, home_score: 9 },
    }, { "Idempotency-Key": key });
    expect(changed.status).toBe(409);
    await expect(changed.json()).resolves.toEqual({ error: "idempotency_conflict" });

    const ownerBResponse = await postAs("session-b", "/api/matches/ingest", matchBody({
      id: matchB,
      ownerId: ownerA,
    }), { "Idempotency-Key": key });
    expect(ownerBResponse.status).toBe(200);
    expect((await pool.query(
      "select count(*)::int as count from idempotency_keys where key = $1",
      [key],
    )).rows[0]?.count).toBe(2);
    expect((await pool.query(
      "select owner_id from matches where id = any($1::uuid[]) order by owner_id",
      [[idempotentMatchA, matchB]],
    )).rows.map((row) => row.owner_id).sort()).toEqual([ownerA, ownerB].sort());
  });

  it("keeps match deletion owner-scoped and returns the full soft-deleted bundle for incremental synchronization", async () => {
    expect((await requestAs("session-b", `/api/matches/${matchA}`, { method: "DELETE" })).status).toBe(404);
    expect((await requestAs("session-a", `/api/matches/${matchA}`, { method: "DELETE" })).status).toBe(204);
    expect((await requestAs("session-a", `/api/matches/${matchA}`, { method: "DELETE" })).status).toBe(404);

    const active = (await (await requestAs("session-a", "/api/matches")).json()) as MatchEnvelope[];
    expect(active.map((row) => row.match.id)).not.toContain(matchA);
    const changes = (await (await requestAs(
      "session-a",
      "/api/matches?updatedAfter=2020-01-01T00:00:00.000Z",
    )).json()) as MatchEnvelope[];
    const tombstone = changes.find((row) => row.match.id === matchA);
    expect(tombstone).toMatchObject({
      match: { id: matchA, owner_id: ownerA, deleted_at: expect.any(String) },
      periods: [{ id: periodA1 }, { id: periodA2 }],
      events: [{ id: eventA }],
      metrics: { match_id: matchA, owner_id: ownerA },
    });
    const exactBoundary = (await (await requestAs(
      "session-a",
      `/api/matches?updatedAfter=${encodeURIComponent(String(tombstone?.match.updated_at))}`,
    )).json()) as MatchEnvelope[];
    expect(exactBoundary.map((row) => row.match.id)).toContain(matchA);
    const foreignChanges = (await (await requestAs(
      "session-b",
      `/api/matches?updatedAfter=${encodeURIComponent(String(tombstone?.match.updated_at))}`,
    )).json()) as MatchEnvelope[];
    expect(foreignChanges.map((row) => row.match.id)).not.toContain(matchA);
  });

  it("creates, updates, isolates, conflicts, and tombstones match assessments through mounted routes", async () => {
    expect((await postAs("session-a", "/api/matches/ingest", matchBody({
      id: assessmentMatchA,
      ownerId: ownerB,
    }))).status).toBe(200);
    expect((await postAs("session-a", "/api/matches/ingest", matchBody({
      id: concurrentAssessmentMatchA,
      ownerId: ownerB,
    }))).status).toBe(200);

    const created = await postAs("session-a", "/api/match-assessments", assessmentBody({
      id: assessmentA,
      matchId: assessmentMatchA,
      ownerId: ownerB,
      rating: 4,
      overall: "Initial",
    }));
    expect(created.status).toBe(200);
    await expect(created.json()).resolves.toMatchObject({
      id: assessmentA,
      match_id: assessmentMatchA,
      owner_id: ownerA,
      rating: 4,
      overall: "Initial",
    });

    const updated = await postAs("session-a", "/api/match-assessments", assessmentBody({
      id: assessmentA,
      matchId: assessmentMatchA,
      ownerId: ownerB,
      rating: 5,
      overall: "Updated",
    }));
    expect(updated.status).toBe(200);
    await expect(updated.json()).resolves.toMatchObject({ id: assessmentA, rating: 5, overall: "Updated" });

    const ownerARows = (await (await requestAs("session-a", "/api/match-assessments")).json()) as AssessmentRow[];
    const ownerBRows = (await (await requestAs("session-b", "/api/match-assessments")).json()) as AssessmentRow[];
    expect(ownerARows.find((row) => row.id === assessmentA)).toMatchObject({ owner_id: ownerA, rating: 5 });
    expect(ownerBRows.map((row) => row.id)).not.toContain(assessmentA);

    const foreignID = await postAs("session-b", "/api/match-assessments", assessmentBody({
      id: assessmentA,
      matchId: matchB,
      ownerId: ownerB,
    }));
    expect(foreignID.status).toBe(403);
    await expect(foreignID.json()).resolves.toEqual({ error: "forbidden" });

    const foreignMatch = await postAs("session-a", "/api/match-assessments", assessmentBody({
      id: assessmentConflictA,
      matchId: matchB,
      ownerId: ownerB,
    }));
    expect(foreignMatch.status).toBe(404);
    await expect(foreignMatch.json()).resolves.toEqual({ error: "match_not_found" });

    const deletedMatch = await postAs("session-a", "/api/match-assessments", assessmentBody({
      id: assessmentConflictA,
      matchId: matchA,
      ownerId: ownerB,
    }));
    expect(deletedMatch.status).toBe(404);
    await expect(deletedMatch.json()).resolves.toEqual({ error: "match_not_found" });

    const conflict = await postAs("session-a", "/api/match-assessments", assessmentBody({
      id: assessmentConflictA,
      matchId: assessmentMatchA,
      ownerId: ownerB,
    }));
    expect(conflict.status).toBe(409);
    await expect(conflict.json()).resolves.toEqual({ error: "assessment_conflict" });

    const ownerBAssessment = await postAs("session-b", "/api/match-assessments", assessmentBody({
      id: assessmentB,
      matchId: matchB,
      ownerId: ownerA,
      rating: 3,
    }));
    expect(ownerBAssessment.status).toBe(200);
    await expect(ownerBAssessment.json()).resolves.toMatchObject({ owner_id: ownerB });

    expect((await requestAs("session-b", `/api/match-assessments/${assessmentA}`, { method: "DELETE" })).status).toBe(404);
    expect((await requestAs("session-a", `/api/match-assessments/${assessmentA}`, { method: "DELETE" })).status).toBe(204);
    expect((await requestAs("session-a", `/api/match-assessments/${assessmentA}`, { method: "DELETE" })).status).toBe(404);
    const active = (await (await requestAs("session-a", "/api/match-assessments")).json()) as AssessmentRow[];
    expect(active.map((row) => row.id)).not.toContain(assessmentA);
    const changes = (await (await requestAs(
      "session-a",
      "/api/match-assessments?updatedAfter=2020-01-01T00:00:00.000Z",
    )).json()) as AssessmentRow[];
    const tombstone = changes.find((row) => row.id === assessmentA);
    expect(tombstone).toMatchObject({
      id: assessmentA,
      owner_id: ownerA,
      deleted_at: expect.any(String),
      updated_at: expect.any(String),
    });
    const exactBoundary = (await (await requestAs(
      "session-a",
      `/api/match-assessments?updatedAfter=${encodeURIComponent(String(tombstone?.updated_at))}`,
    )).json()) as AssessmentRow[];
    expect(exactBoundary.map((row) => row.id)).toContain(assessmentA);
    const foreignBoundary = (await (await requestAs(
      "session-b",
      `/api/match-assessments?updatedAfter=${encodeURIComponent(String(tombstone?.updated_at))}`,
    )).json()) as AssessmentRow[];
    expect(foreignBoundary.map((row) => row.id)).not.toContain(assessmentA);
  });

  it("serializes different-ID assessment creates to one 200 and one documented 409 without a generic 500", async () => {
    const responses = await Promise.all([
      postAs("session-a", "/api/match-assessments", assessmentBody({
        id: concurrentAssessmentA1,
        matchId: concurrentAssessmentMatchA,
        ownerId: ownerB,
        rating: 4,
      })),
      postAs("session-a", "/api/match-assessments", assessmentBody({
        id: concurrentAssessmentA2,
        matchId: concurrentAssessmentMatchA,
        ownerId: ownerB,
        rating: 5,
      })),
    ]);
    expect(responses.map((response) => response.status).sort()).toEqual([200, 409]);
    const bodies = await Promise.all(responses.map((response) => response.json()));
    expect(bodies.find((_, index) => responses[index]!.status === 409)).toEqual({
      error: "assessment_conflict",
    });
    expect(responses.some((response) => response.status === 500)).toBe(false);

    const rows = await pool.query(
      "select id, owner_id from match_assessments where match_id = $1 and deleted_at is null",
      [concurrentAssessmentMatchA],
    );
    expect(rows.rows).toHaveLength(1);
    expect([concurrentAssessmentA1, concurrentAssessmentA2]).toContain(rows.rows[0]?.id);
    expect(rows.rows[0]?.owner_id).toBe(ownerA);
  });

  it("mounts assistant SSE with a strict local upstream stub and keeps the server key out of the request body", async () => {
    const calls: UpstreamCall[] = [];
    await withStrictOpenAIStub(calls, async (_url, init) => {
      const headers = new Headers(init?.headers);
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      expect(headers.get("authorization")).toBe(`Bearer ${env.OPENAI_API_KEY}`);
      expect(headers.get("authorization")).not.toContain("session-a");
      expect(body).toMatchObject({
        model: "gpt-5.4-mini",
        input: [{ role: "user", content: "hello" }],
        stream: true,
        store: false,
      });
      expect(JSON.stringify(body)).not.toContain(env.OPENAI_API_KEY);
      return new Response("event: response.output_text.delta\ndata: {\"delta\":\"hello\"}\n\n", {
        status: 200,
        headers: { "Content-Type": "text/event-stream", "x-request-id": "req_local_assistant" },
      });
    }, async () => {
      const response = await postAs("session-a", "/api/assistant/responses", {
        messages: [{ role: "user", content: "hello" }],
        stream: false,
        store: true,
      });
      expect(response.status).toBe(200);
      expect(response.headers.get("content-type")).toContain("text/event-stream");
      expect(response.headers.get("cache-control")).toBe("no-store");
      expect(response.headers.get("x-request-id")).toBe("req_local_assistant");
      expect(await response.text()).toContain("\"delta\":\"hello\"");
    });
    expect(calls.map((call) => call.url)).toEqual(["https://api.openai.com/v1/responses"]);
  });

  it("mounts match-sheet parsing with a strict local upstream stub and enforces non-streaming, non-storing upstream behavior", async () => {
    const calls: UpstreamCall[] = [];
    await withStrictOpenAIStub(calls, async (_url, init) => {
      const headers = new Headers(init?.headers);
      const body = JSON.parse(String(init?.body)) as {
        stream: boolean;
        store: boolean;
        input: Array<{ content: Array<Record<string, unknown>> }>;
      };
      expect(headers.get("authorization")).toBe(`Bearer ${env.OPENAI_API_KEY}`);
      expect(body.stream).toBe(false);
      expect(body.store).toBe(false);
      expect(body.input[0]?.content.some((part) => part.type === "input_image")).toBe(true);
      expect(JSON.stringify(body)).not.toContain(env.OPENAI_API_KEY);
      const structured = {
        extractedTeamName: "Owner A Team",
        warnings: [],
        parsedSheet: {
          starters: [{ displayName: "Player One", shirtNumber: 9, position: "FW", notes: null }],
          substitutes: [],
          staff: [],
          otherMembers: [],
        },
      };
      return Response.json({
        status: "completed",
        output_text: JSON.stringify(structured),
      }, {
        status: 200,
        headers: { "x-request-id": "req_local_match_sheet" },
      });
    }, async () => {
      const response = await postAs("session-a", "/api/match-sheet/parse", {
        side: "home",
        expected_team_name: "Owner A Team",
        images: [{ image_url: "data:image/jpeg;base64,AA==", detail: "low" }],
      });
      expect(response.status).toBe(200);
      expect(response.headers.get("cache-control")).toBe("no-store");
      expect(response.headers.get("x-request-id")).toBe("req_local_match_sheet");
      await expect(response.json()).resolves.toMatchObject({
        extractedTeamName: "Owner A Team",
        terminalStatus: "completed",
        parsedSheet: {
          status: "draft",
          starters: [{ displayName: "Player One", shirtNumber: 9, sortOrder: 0 }],
        },
      });
    });
    expect(calls.map((call) => call.url)).toEqual(["https://api.openai.com/v1/responses"]);
  });

  it("completes normal mounted writes without any ledger runtime binding or outbox delivery", async () => {
    expect(env).not.toHaveProperty("MUTATION_LEDGER");
    expect(env).not.toHaveProperty("MUTATION_LEDGER_QUEUE");
    expect(env).not.toHaveProperty("MUTATION_LEDGER_ENCRYPTION_KEY");
    const counts = await pool.query(`
      select
        (select count(*)::int from mutation_ledger_epochs where status in ('open', 'frozen')) as active_epochs,
        (select count(*)::int from mutation_outbox_events) as outbox_events,
        (select count(*)::int from mutation_outbox_deliveries) as outbox_deliveries
    `);
    expect(counts.rows[0]).toEqual({
      active_epochs: 0,
      outbox_events: 0,
      outbox_deliveries: 0,
    });
  });
});

function requestAs(token: string, path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${token}`);
  return app.request(path, { ...init, headers }, env);
}

function postAs(
  token: string,
  path: string,
  body: unknown,
  headers: Record<string, string> = {},
) {
  return requestAs(token, path, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

async function holdEntityMutationLock(key: string): Promise<PoolClient> {
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query(
      "select pg_advisory_xact_lock(hashtextextended($1, 0))",
      [key],
    );
    return client;
  } catch (error) {
    client.release();
    throw error;
  }
}

async function waitForAdvisoryWaiters(expected: number, timeoutMilliseconds = 3_000): Promise<void> {
  const deadline = performance.now() + timeoutMilliseconds;
  while (performance.now() < deadline) {
    const result = await pool.query(
      "select count(*)::int as count from pg_locks where locktype = 'advisory' and not granted",
    );
    if ((result.rows[0]?.count ?? 0) >= expected) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for ${expected} advisory-lock waiter(s)`);
}

function teamBody(input: {
  id: string;
  ownerId: string;
  name: string;
  memberId?: string;
  officialId?: string;
}) {
  return {
    team: { id: input.id, owner_id: input.ownerId, name: input.name },
    members: input.memberId
      ? [{ id: input.memberId, team_id: input.id, display_name: "Member" }]
      : [],
    officials: input.officialId
      ? [{
        id: input.officialId,
        team_id: input.id,
        display_name: "Official",
        role: "coach",
      }]
      : [],
    tags: input.memberId ? ["primary"] : [],
  };
}

interface ScheduleInput {
  id: string;
  owner_id: string;
  home_team_name: string;
  away_team_name: string;
  kickoff_at: string;
  home_team_id: string;
  away_team_id: string;
  competition_id: string;
  venue_id: string;
}

function scheduleBody(input: {
  id: string;
  ownerId: string;
  homeTeamId: string;
  awayTeamId: string;
  competitionId: string;
  venueId: string;
}): ScheduleInput {
  return {
    id: input.id,
    owner_id: input.ownerId,
    home_team_name: "Home",
    away_team_name: "Away",
    kickoff_at: "2026-07-20T10:00:00.000Z",
    home_team_id: input.homeTeamId,
    away_team_id: input.awayTeamId,
    competition_id: input.competitionId,
    venue_id: input.venueId,
  };
}

interface MatchBundle {
  match: {
    id: string;
    owner_id: string;
    scheduled_match_id?: string;
    status: string;
    completed_at: string;
    number_of_periods: number;
    regulation_minutes: number;
    half_time_minutes: number;
    competition_id?: string;
    venue_id?: string;
    home_team_id?: string;
    home_team_name: string;
    away_team_id?: string;
    away_team_name: string;
    extra_time_enabled: boolean;
    penalties_enabled: boolean;
    penalty_initial_rounds: number;
    home_score: number;
    away_score: number;
  };
  periods: Array<Record<string, unknown>>;
  events: Array<Record<string, unknown>>;
  metrics: Record<string, unknown> | null;
}

function matchBody(input: {
  id: string;
  ownerId: string;
  scheduledMatchId?: string;
  homeTeamId?: string;
  awayTeamId?: string;
  competitionId?: string;
  venueId?: string;
}): MatchBundle {
  return {
    match: {
      id: input.id,
      owner_id: input.ownerId,
      ...(input.scheduledMatchId ? { scheduled_match_id: input.scheduledMatchId } : {}),
      status: "completed",
      completed_at: "2026-07-20T12:00:00.000Z",
      number_of_periods: 2,
      regulation_minutes: 90,
      half_time_minutes: 15,
      ...(input.competitionId ? { competition_id: input.competitionId } : {}),
      ...(input.venueId ? { venue_id: input.venueId } : {}),
      ...(input.homeTeamId ? { home_team_id: input.homeTeamId } : {}),
      home_team_name: "Home",
      ...(input.awayTeamId ? { away_team_id: input.awayTeamId } : {}),
      away_team_name: "Away",
      extra_time_enabled: false,
      penalties_enabled: false,
      penalty_initial_rounds: 5,
      home_score: 1,
      away_score: 0,
    },
    periods: [],
    events: [],
    metrics: null,
  };
}

function fullMatchBody(id: string, spoofedOwnerId: string): MatchBundle {
  const base = matchBody({
    id,
    ownerId: spoofedOwnerId,
    scheduledMatchId: scheduleA,
    homeTeamId: teamA,
    awayTeamId: awayTeamA,
    competitionId: competitionA,
    venueId: venueA,
  });
  return {
    ...base,
    match: { ...base.match, home_score: 2, away_score: 1 },
    periods: [
      {
        id: periodA1,
        match_id: id,
        index: 0,
        regulation_seconds: 2700,
        added_time_seconds: 60,
        result: { home: 1, away: 0 },
      },
      {
        id: periodA2,
        match_id: id,
        index: 1,
        regulation_seconds: 2700,
        added_time_seconds: 120,
        result: { home: 1, away: 1 },
      },
    ],
    events: [eventBody({
      id: eventA,
      matchId: id,
      teamId: teamA,
      memberId: memberA,
    })],
    metrics: {
      match_id: id,
      owner_id: spoofedOwnerId,
      regulation_minutes: 90,
      half_time_minutes: 15,
      extra_time_minutes: 0,
      penalties_enabled: false,
      total_goals: 3,
      total_cards: 2,
      total_penalties: 0,
      yellow_cards: 2,
      red_cards: 0,
      home_cards: 1,
      away_cards: 1,
      home_substitutions: 3,
      away_substitutions: 2,
      penalties_scored: 0,
      penalties_missed: 0,
      avg_added_time_seconds: 90,
    },
  };
}

function eventBody(input: {
  id: string;
  matchId: string;
  teamId: string;
  memberId: string;
}) {
  return {
    id: input.id,
    match_id: input.matchId,
    occurred_at: "2026-07-20T11:15:00.000Z",
    period_index: 0,
    clock_seconds: 900,
    match_time_label: "15:00",
    event_type: "goal",
    payload: { score: "1-0" },
    team_side: "home",
    team_id: input.teamId,
    team_member_id: input.memberId,
  };
}

function assessmentBody(input: {
  id: string;
  matchId: string;
  ownerId: string;
  rating?: number;
  overall?: string;
}) {
  return {
    id: input.id,
    match_id: input.matchId,
    owner_id: input.ownerId,
    rating: input.rating ?? 4,
    overall: input.overall ?? "Assessment",
    went_well: "Positioning",
    to_improve: "Advantage timing",
  };
}

function exactGreenfieldReceipt() {
  const recordedAt = new Date("2026-07-20T00:00:00.000Z");
  return {
    receiptDigest: GREENFIELD_RECONCILIATION_RECEIPT_DIGEST,
    clerkInstanceId: PRODUCTION_CLERK_INSTANCE_ID,
    reconciliationProfile: GREENFIELD_RECONCILIATION_PROFILE,
    authorizationProfile: GREENFIELD_AUTHORIZATION_PROFILE,
    authorizationDigest: GREENFIELD_AUTHORIZATION_DIGEST,
    clerkIssuer: PRODUCTION_CLERK_ISSUER,
    clerkDomain: PRODUCTION_CLERK_DOMAIN,
    snapshotCapturedAt: recordedAt,
    legacyMappingCount: 0,
    excludedAuthCount: 0,
    mappingHash: EMPTY_IDENTITY_MAPPING_HASH,
    status: "verified",
    reviewedAt: recordedAt,
  };
}

interface UpstreamCall {
  url: string;
  init?: RequestInit;
}

async function withStrictOpenAIStub(
  calls: UpstreamCall[],
  handler: (url: string, init?: RequestInit) => Promise<Response>,
  work: () => Promise<void>,
) {
  const stub = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string"
      ? input
      : input instanceof URL
        ? input.toString()
        : input.url;
    if (url !== "https://api.openai.com/v1/responses") {
      throw new Error(`Unexpected network request: ${url}`);
    }
    calls.push({ url, init });
    return handler(url, init);
  });
  vi.stubGlobal("fetch", stub);
  try {
    await work();
    expect(stub).toHaveBeenCalledTimes(1);
  } finally {
    vi.unstubAllGlobals();
  }
}

function extractIDs(rows: Array<Record<string, unknown>>): string[] {
  return rows.flatMap((row) => {
    if (typeof row.id === "string") return [row.id];
    if (
      row.team
      && typeof row.team === "object"
      && "id" in row.team
      && typeof row.team.id === "string"
    ) {
      return [row.team.id];
    }
    return [];
  });
}

function findByID(rows: Array<Record<string, unknown>>, id: string): Record<string, unknown> | undefined {
  const row = rows.find((candidate) => {
    if (candidate.id === id) return true;
    return candidate.team
      && typeof candidate.team === "object"
      && "id" in candidate.team
      && candidate.team.id === id;
  });
  if (
    row?.team
    && typeof row.team === "object"
    && "id" in row.team
  ) {
    return row.team as Record<string, unknown>;
  }
  return row;
}

interface MeResponse {
  appUserId: string;
  clerkUserId: string;
}

interface VersionedPayload {
  updated_at: string;
}

interface TeamEnvelope {
  team: { id: string; owner_id: string; name: string };
  members: Array<Record<string, unknown>>;
  officials: Array<Record<string, unknown>>;
  tags: Array<Record<string, unknown>>;
}

interface ScheduleRow {
  id: string;
  owner_id: string;
  home_team_id: string | null;
  away_team_id: string | null;
  competition_id: string | null;
  venue_id: string | null;
  deleted_at?: string | null;
  updated_at: string;
}

interface MatchEnvelope {
  match: { id: string; owner_id: string; deleted_at?: string | null; updated_at: string };
  periods: Array<Record<string, unknown>>;
  events: Array<Record<string, unknown>>;
  metrics: Record<string, unknown> | null;
}

interface AssessmentRow {
  id: string;
  owner_id: string;
  rating: number | null;
  deleted_at?: string | null;
  updated_at: string;
}

function validatedLocalDatabaseURL(): string {
  const value = process.env.REFWATCH_LOCAL_ROUTE_DATABASE_URL;
  if (!value || process.env.REFWATCH_ALLOW_LOCAL_ROUTE_TESTS !== "1") {
    throw new Error("Local route tests require the hermetic runner and explicit opt-in");
  }
  const parsed = new URL(value);
  if (
    parsed.protocol !== "postgresql:"
    || parsed.hostname !== "127.0.0.1"
    || parsed.pathname !== "/refwatch_local_routes"
    || parsed.searchParams.get("sslmode") !== "disable"
  ) {
    throw new Error("Local route tests refuse non-loopback or unexpected databases");
  }
  return value;
}
