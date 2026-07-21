import { and, eq, gte, isNull } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { competitions, scheduledMatches, teams, venues } from "../db/schema";
import type { Env, Variables } from "../types";
import { snakeCaseJSON } from "../utils/json";
import { parseISODate } from "../utils/dates";
import { lockAndVersionEntity } from "../services/entityMutationVersion";
import { httpMutationContext } from "../services/mutationContext";
import { withMutation } from "../services/mutationLedger";

const input = z.object({
  id: z.uuid(), owner_id: z.string().optional(), home_team_name: z.string().min(1), away_team_name: z.string().min(1),
  kickoff_at: z.iso.datetime(), status: z.string().default("scheduled"), competition_id: z.uuid().nullable().optional(),
  competition_name: z.string().nullable().optional(), venue_id: z.uuid().nullable().optional(), venue_name: z.string().nullable().optional(),
  home_team_id: z.uuid().nullable().optional(), away_team_id: z.uuid().nullable().optional(), home_match_sheet: z.unknown().nullable().optional(),
  away_match_sheet: z.unknown().nullable().optional(), notes: z.string().nullable().optional(), source_device_id: z.string().nullable().optional(),
});

export const scheduledMatchRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

scheduledMatchRoutes.get("/", async (c) => {
  const { appUserId } = c.get("auth");
  let updatedAfter: Date | undefined;
  try { updatedAfter = parseISODate(c.req.query("updatedAfter")); } catch { return c.json({ error: "invalid_updated_after" }, 422); }
  const filters = [eq(scheduledMatches.ownerId, appUserId)];
  if (!updatedAfter) filters.push(isNull(scheduledMatches.deletedAt));
  if (updatedAfter) filters.push(gte(scheduledMatches.updatedAt, updatedAfter));
  const rows = await c.get("db").select().from(scheduledMatches).where(and(...filters)).orderBy(scheduledMatches.updatedAt);
  return c.json(snakeCaseJSON(rows));
});

scheduledMatchRoutes.post("/", async (c) => {
  const parsed = input.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const p = parsed.data; const ownerId = c.get("auth").appUserId;
  const invalidReference = await findForeignScheduleReference(c.get("db"), ownerId, p);
  if (invalidReference) return c.json({ error: "forbidden_reference", field: invalidReference }, 403);
  const row = await withMutation(c.get("db"), httpMutationContext(c, "/api/scheduled-matches"), async (tx) => {
    const version = await lockAndVersionEntity(tx, "scheduled-match", p.id, async (id) => {
      const [existing] = await tx.select({
        ownerId: scheduledMatches.ownerId,
        updatedAt: scheduledMatches.updatedAt,
      }).from(scheduledMatches).where(eq(scheduledMatches.id, id)).limit(1);
      return existing;
    });
    if (version.existing && version.existing.ownerId !== ownerId) return undefined;
    const updateValues = {
      homeTeamName: p.home_team_name, awayTeamName: p.away_team_name, kickoffAt: new Date(p.kickoff_at),
      status: p.status, competitionId: p.competition_id ?? null, competitionName: p.competition_name ?? null,
      venueId: p.venue_id ?? null, venueName: p.venue_name ?? null, homeTeamId: p.home_team_id ?? null, awayTeamId: p.away_team_id ?? null,
      homeMatchSheet: p.home_match_sheet ?? null, awayMatchSheet: p.away_match_sheet ?? null, notes: p.notes ?? null,
      sourceDeviceId: p.source_device_id ?? null, deletedAt: null, updatedAt: version.updatedAt,
    };
    const [saved] = await tx.insert(scheduledMatches).values({ id: version.id, ownerId, ...updateValues }).onConflictDoUpdate({
      target: scheduledMatches.id,
      set: updateValues,
      setWhere: eq(scheduledMatches.ownerId, ownerId),
    }).returning();
    return saved;
  });
  return row ? c.json(snakeCaseJSON(row), 200) : c.json({ error: "forbidden" }, 403);
});

async function findForeignScheduleReference(db: Variables["db"], ownerId: string, value: z.infer<typeof input>): Promise<string | null> {
  const checks: Array<[string, string | null | undefined, typeof teams | typeof competitions | typeof venues]> = [
    ["home_team_id", value.home_team_id, teams],
    ["away_team_id", value.away_team_id, teams],
    ["competition_id", value.competition_id, competitions],
    ["venue_id", value.venue_id, venues],
  ];
  for (const [field, id, table] of checks) {
    if (!id) continue;
    const row = await db.select({ id: table.id }).from(table).where(and(
      eq(table.id, id), eq(table.ownerId, ownerId), isNull(table.deletedAt),
    )).limit(1);
    if (!row.length) return field;
  }
  return null;
}

scheduledMatchRoutes.delete("/:id", async (c) => {
  const id = z.uuid().safeParse(c.req.param("id")); if (!id.success) return c.json({ error: "invalid_id" }, 422);
  const rows = await withMutation(c.get("db"), httpMutationContext(c, "/api/scheduled-matches/:id"), async (tx) => {
    const version = await lockAndVersionEntity(tx, "scheduled-match", id.data, async (normalizedId) => {
      const [existing] = await tx.select({
        ownerId: scheduledMatches.ownerId,
        updatedAt: scheduledMatches.updatedAt,
        deletedAt: scheduledMatches.deletedAt,
      }).from(scheduledMatches).where(eq(scheduledMatches.id, normalizedId)).limit(1);
      return existing;
    });
    if (
      !version.existing
      || version.existing.ownerId !== c.get("auth").appUserId
      || version.existing.deletedAt
    ) {
      return [];
    }
    return tx.update(scheduledMatches).set({
      deletedAt: version.updatedAt,
      updatedAt: version.updatedAt,
    }).where(and(
      eq(scheduledMatches.id, version.id),
      eq(scheduledMatches.ownerId, c.get("auth").appUserId),
      isNull(scheduledMatches.deletedAt),
    )).returning({ id: scheduledMatches.id });
  });
  return rows.length ? c.body(null, 204) : c.json({ error: "not_found" }, 404);
});
