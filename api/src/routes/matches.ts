import { and, eq, gt, inArray, isNull, lt } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { competitions, idempotencyKeys, matchEvents, matchMetrics, matchPeriods, matches, scheduledMatches, teamMembers, teams, venues } from "../db/schema";
import type { Env, Variables } from "../types";
import { parseISODate } from "../utils/dates";
import { snakeCaseJSON } from "../utils/json";
import { httpMutationContext } from "../services/mutationContext";
import { withMutation } from "../services/mutationLedger";

const uuid = z.uuid();
const matchInput = z.object({
  id: uuid, owner_id: z.string().optional(), scheduled_match_id: uuid.nullable().optional(), status: z.string().default("completed"),
  started_at: z.iso.datetime().nullable().optional(), completed_at: z.iso.datetime(), duration_seconds: z.number().int().nullable().optional(),
  number_of_periods: z.number().int().positive(), regulation_minutes: z.number().int().nullable().optional(), half_time_minutes: z.number().int().nullable().optional(),
  competition_id: uuid.nullable().optional(), competition_name: z.string().nullable().optional(), venue_id: uuid.nullable().optional(), venue_name: z.string().nullable().optional(),
  home_team_id: uuid.nullable().optional(), home_team_name: z.string().min(1), away_team_id: uuid.nullable().optional(), away_team_name: z.string().min(1),
  extra_time_enabled: z.boolean().default(false), extra_time_half_minutes: z.number().int().nullable().optional(), penalties_enabled: z.boolean().default(false),
  penalty_initial_rounds: z.number().int().nonnegative(), home_score: z.number().int().nonnegative(), away_score: z.number().int().nonnegative(),
  final_score: z.unknown().nullable().optional(), source_device_id: z.string().nullable().optional(),
});
const periodInput = z.object({ id: uuid, match_id: uuid, index: z.number().int().nonnegative(), regulation_seconds: z.number().int().nonnegative(), added_time_seconds: z.number().int().nonnegative().default(0), result: z.unknown().nullable().optional() });
const eventInput = z.object({ id: uuid, match_id: uuid, occurred_at: z.iso.datetime(), period_index: z.number().int().nonnegative(), clock_seconds: z.number().int().nonnegative(), match_time_label: z.string().min(1), event_type: z.string().min(1), payload: z.unknown().nullable().optional(), team_side: z.string().nullable().optional(), team_id: uuid.nullable().optional(), team_member_id: uuid.nullable().optional() });
const metricsInput = z.object({ match_id: uuid, owner_id: z.string().optional(), regulation_minutes: z.number().int().nullable().optional(), half_time_minutes: z.number().int().nullable().optional(), extra_time_minutes: z.number().int().nullable().optional(), penalties_enabled: z.boolean().default(false), total_goals: z.number().int().default(0), total_cards: z.number().int().default(0), total_penalties: z.number().int().default(0), yellow_cards: z.number().int().default(0), red_cards: z.number().int().default(0), home_cards: z.number().int().default(0), away_cards: z.number().int().default(0), home_substitutions: z.number().int().default(0), away_substitutions: z.number().int().default(0), penalties_scored: z.number().int().default(0), penalties_missed: z.number().int().default(0), avg_added_time_seconds: z.number().int().default(0) });
export const matchBundleInput = z.object({ match: matchInput, periods: z.array(periodInput).max(20).default([]), events: z.array(eventInput).max(500).default([]), metrics: metricsInput.nullable().optional() });

export const matchRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

matchRoutes.get("/", async (c) => {
  const ownerId = c.get("auth").appUserId; let after: Date | undefined;
  try { after = parseISODate(c.req.query("updatedAfter")); } catch { return c.json({ error: "invalid_updated_after" }, 422); }
  const filters = [eq(matches.ownerId, ownerId)];
  if (after) filters.push(gt(matches.updatedAt, after)); else filters.push(isNull(matches.deletedAt));
  const rows = await c.get("db").select().from(matches).where(and(...filters)).orderBy(matches.updatedAt);
  if (!rows.length) return c.json([]);
  const ids = rows.map((x) => x.id);
  const periodRows = await c.get("db").select().from(matchPeriods).where(inArray(matchPeriods.matchId, ids));
  const eventRows = await c.get("db").select().from(matchEvents).where(inArray(matchEvents.matchId, ids));
  const metricRows = await c.get("db").select().from(matchMetrics).where(and(
    inArray(matchMetrics.matchId, ids), eq(matchMetrics.ownerId, ownerId),
  ));
  return c.json(snakeCaseJSON(rows.map((match) => ({ match, periods: periodRows.filter((x) => x.matchId === match.id), events: eventRows.filter((x) => x.matchId === match.id), metrics: metricRows.find((x) => x.matchId === match.id) ?? null }))));
});

matchRoutes.post("/ingest", async (c) => {
  const raw = await c.req.json().catch(() => null); const parsed = matchBundleInput.safeParse(raw);
  if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const bundle = parsed.data; const matchId = bundle.match.id; const ownerId = c.get("auth").appUserId;
  if (bundle.periods.some((x) => x.match_id !== matchId)) return c.json({ error: "invalid_period_match" }, 422);
  if (bundle.events.some((x) => x.match_id !== matchId)) return c.json({ error: "invalid_event_match" }, 422);
  if (bundle.metrics && bundle.metrics.match_id !== matchId) return c.json({ error: "invalid_metrics_match" }, 422);

  const key = c.req.header("Idempotency-Key")?.trim(); const requestHash = await hashJSON(raw);
  if (key && key.length > 200) return c.json({ error: "invalid_idempotency_key" }, 422);
  const [existing] = await c.get("db").select({ ownerId: matches.ownerId }).from(matches).where(eq(matches.id, matchId)).limit(1);
  if (existing && existing.ownerId !== ownerId) return c.json({ error: "forbidden" }, 403);
  const invalidReference = await findForeignReference(c.get("db"), ownerId, bundle.match);
  if (invalidReference) return c.json({ error: "forbidden_reference", field: invalidReference }, 403);
  const invalidEventReference = await findInvalidEventReference(c.get("db"), ownerId, bundle.match, bundle.events);
  if (invalidEventReference) return c.json({ error: "forbidden_reference", field: invalidEventReference }, 403);

  const result = await withMutation(c.get("db"), httpMutationContext(c, "/api/matches/ingest"), async (tx) => {
    if (key) {
      await tx.delete(idempotencyKeys).where(and(
        eq(idempotencyKeys.ownerId, ownerId), eq(idempotencyKeys.key, key), lt(idempotencyKeys.expiresAt, new Date()),
      ));
      const claimed = await tx.insert(idempotencyKeys).values({
        ownerId, key, requestHash, responseBody: null, statusCode: 0,
      }).onConflictDoNothing().returning({ key: idempotencyKeys.key });
      if (!claimed.length) {
        const [cached] = await tx.select().from(idempotencyKeys).where(and(
          eq(idempotencyKeys.ownerId, ownerId), eq(idempotencyKeys.key, key),
        )).limit(1);
        if (!cached || cached.requestHash !== requestHash) return { kind: "conflict" as const };
        if (cached.statusCode === 200 && cached.responseBody) return { kind: "cached" as const, body: cached.responseBody as { match_id: string; updated_at: string } };
        // This can only survive from manually-corrupted state; normal failures roll back the claim.
        return { kind: "pending" as const };
      }
    }
    const m = bundle.match; const updatedAt = new Date();
    const values = {
      id: m.id, ownerId, scheduledMatchId: m.scheduled_match_id ?? null, status: m.status,
      startedAt: new Date(m.started_at ?? m.completed_at), completedAt: new Date(m.completed_at), durationSeconds: m.duration_seconds ?? null,
      numberOfPeriods: m.number_of_periods, regulationMinutes: m.regulation_minutes ?? null, halfTimeMinutes: m.half_time_minutes ?? null,
      competitionId: m.competition_id ?? null, competitionName: m.competition_name ?? null, venueId: m.venue_id ?? null, venueName: m.venue_name ?? null,
      homeTeamId: m.home_team_id ?? null, homeTeamName: m.home_team_name, awayTeamId: m.away_team_id ?? null, awayTeamName: m.away_team_name,
      extraTimeEnabled: m.extra_time_enabled, extraTimeHalfMinutes: m.extra_time_half_minutes ?? null, penaltiesEnabled: m.penalties_enabled,
      penaltyInitialRounds: m.penalty_initial_rounds, homeScore: m.home_score, awayScore: m.away_score, finalScore: m.final_score ?? null,
      sourceDeviceId: m.source_device_id ?? null, deletedAt: null, updatedAt,
    };
    const { id: _id, ownerId: _ownerId, ...updateValues } = values;
    const saved = await tx.insert(matches).values(values).onConflictDoUpdate({
      target: matches.id,
      set: updateValues,
      setWhere: eq(matches.ownerId, ownerId),
    }).returning({ id: matches.id });
    if (!saved.length) return { kind: "forbidden" as const };
    await tx.delete(matchPeriods).where(eq(matchPeriods.matchId, matchId)); await tx.delete(matchEvents).where(eq(matchEvents.matchId, matchId)); await tx.delete(matchMetrics).where(and(eq(matchMetrics.matchId, matchId), eq(matchMetrics.ownerId, ownerId)));
    if (bundle.periods.length) await tx.insert(matchPeriods).values(bundle.periods.map((x) => ({ id: x.id, matchId, index: x.index, regulationSeconds: x.regulation_seconds, addedTimeSeconds: x.added_time_seconds, result: x.result ?? null })));
    if (bundle.events.length) await tx.insert(matchEvents).values(bundle.events.map((x) => ({ id: x.id, matchId, occurredAt: new Date(x.occurred_at), periodIndex: x.period_index, clockSeconds: x.clock_seconds, matchTimeLabel: x.match_time_label, eventType: x.event_type, payload: x.payload ?? null, teamSide: x.team_side ?? null, teamId: x.team_id ?? null, teamMemberId: x.team_member_id ?? null })));
    if (bundle.metrics) { const x = bundle.metrics; await tx.insert(matchMetrics).values({ matchId, ownerId, regulationMinutes: x.regulation_minutes ?? null, halfTimeMinutes: x.half_time_minutes ?? null, extraTimeMinutes: x.extra_time_minutes ?? null, penaltiesEnabled: x.penalties_enabled, totalGoals: x.total_goals, totalCards: x.total_cards, totalPenalties: x.total_penalties, yellowCards: x.yellow_cards, redCards: x.red_cards, homeCards: x.home_cards, awayCards: x.away_cards, homeSubstitutions: x.home_substitutions, awaySubstitutions: x.away_substitutions, penaltiesScored: x.penalties_scored, penaltiesMissed: x.penalties_missed, avgAddedTimeSeconds: x.avg_added_time_seconds, generatedAt: updatedAt }); }
    const body = { match_id: matchId, updated_at: updatedAt.toISOString() };
    if (key) await tx.update(idempotencyKeys).set({ responseBody: body, statusCode: 200 }).where(and(
      eq(idempotencyKeys.ownerId, ownerId), eq(idempotencyKeys.key, key), eq(idempotencyKeys.requestHash, requestHash),
    ));
    return { kind: "created" as const, body };
  });
  if (result.kind === "conflict") return c.json({ error: "idempotency_conflict" }, 409);
  if (result.kind === "pending") return c.json({ error: "idempotency_in_progress" }, 409);
  if (result.kind === "forbidden") return c.json({ error: "forbidden" }, 403);
  return c.json(result.body);
});

matchRoutes.delete("/:id", async (c) => {
  const id = uuid.safeParse(c.req.param("id")); if (!id.success) return c.json({ error: "invalid_id" }, 422);
  const result = await withMutation(c.get("db"), httpMutationContext(c, "/api/matches/:id"), (tx) => tx.update(matches).set({ deletedAt: new Date(), updatedAt: new Date() }).where(and(eq(matches.id, id.data), eq(matches.ownerId, c.get("auth").appUserId), isNull(matches.deletedAt))).returning({ id: matches.id }));
  return result.length ? c.body(null, 204) : c.json({ error: "not_found" }, 404);
});

async function hashJSON(value: unknown): Promise<string> {
  const data = new TextEncoder().encode(JSON.stringify(value)); const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

async function findForeignReference(db: Variables["db"], ownerId: string, match: z.infer<typeof matchInput>): Promise<string | null> {
  const checks: Array<[string, string | null | undefined, typeof scheduledMatches | typeof teams | typeof competitions | typeof venues]> = [
    ["scheduled_match_id", match.scheduled_match_id, scheduledMatches], ["home_team_id", match.home_team_id, teams], ["away_team_id", match.away_team_id, teams], ["competition_id", match.competition_id, competitions], ["venue_id", match.venue_id, venues],
  ];
  for (const [field, id, table] of checks) {
    if (!id) continue;
    const row = await db.select({ id: table.id }).from(table).where(and(eq(table.id, id), eq(table.ownerId, ownerId))).limit(1);
    if (!row.length) return field;
  }
  return null;
}

export async function findInvalidEventReference(
  db: Variables["db"],
  ownerId: string,
  match: z.infer<typeof matchInput>,
  events: Array<z.infer<typeof eventInput>>,
): Promise<string | null> {
  const normalizeUUID = (id: string) => id.toLowerCase();
  const teamIds = [...new Set(events.flatMap((event) => event.team_id ? [normalizeUUID(event.team_id)] : []))];
  const memberIds = [...new Set(events.flatMap((event) => event.team_member_id ? [normalizeUUID(event.team_member_id)] : []))];
  const ownedTeams = teamIds.length
    ? await db.select({ id: teams.id }).from(teams).where(and(inArray(teams.id, teamIds), eq(teams.ownerId, ownerId)))
    : [];
  const ownedMembers = memberIds.length
    ? await db.select({ id: teamMembers.id, teamId: teamMembers.teamId }).from(teamMembers)
      .innerJoin(teams, eq(teamMembers.teamId, teams.id))
      .where(and(inArray(teamMembers.id, memberIds), eq(teams.ownerId, ownerId)))
    : [];
  const ownedTeamIds = new Set(ownedTeams.map((team) => normalizeUUID(team.id)));
  const ownedMemberTeams = new Map(ownedMembers.map((member) => [normalizeUUID(member.id), normalizeUUID(member.teamId)]));
  const participatingTeamIds = new Set(
    [match.home_team_id, match.away_team_id].flatMap((id) => id ? [normalizeUUID(id)] : []),
  );

  for (const [index, event] of events.entries()) {
    const eventTeamId = event.team_id ? normalizeUUID(event.team_id) : null;
    if (eventTeamId && (!ownedTeamIds.has(eventTeamId) || !participatingTeamIds.has(eventTeamId))) {
      return `events.${index}.team_id`;
    }
    if (event.team_member_id) {
      const memberTeamId = ownedMemberTeams.get(normalizeUUID(event.team_member_id));
      if (!memberTeamId || !participatingTeamIds.has(memberTeamId) || (eventTeamId && memberTeamId !== eventTeamId)) {
        return `events.${index}.team_member_id`;
      }
    }
  }
  return null;
}
