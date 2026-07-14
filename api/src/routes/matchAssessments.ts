import { and, eq, gt, isNull } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { matchAssessments, matches } from "../db/schema";
import type { Env, Variables } from "../types";
import { parseISODate } from "../utils/dates";
import { snakeCaseJSON } from "../utils/json";

const input = z.object({ id: z.uuid(), match_id: z.uuid(), owner_id: z.string().optional(), rating: z.number().int().min(1).max(5).nullable().optional(), overall: z.string().nullable().optional(), went_well: z.string().nullable().optional(), to_improve: z.string().nullable().optional(), created_at: z.iso.datetime().optional() });
export const matchAssessmentRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

matchAssessmentRoutes.get("/", async (c) => {
  let after: Date | undefined; try { after = parseISODate(c.req.query("updatedAfter")); } catch { return c.json({ error: "invalid_updated_after" }, 422); }
  const filters = [eq(matchAssessments.ownerId, c.get("auth").appUserId)]; if (after) filters.push(gt(matchAssessments.updatedAt, after)); else filters.push(isNull(matchAssessments.deletedAt));
  return c.json(snakeCaseJSON(await c.get("db").select().from(matchAssessments).where(and(...filters)).orderBy(matchAssessments.updatedAt)));
});

matchAssessmentRoutes.post("/", async (c) => {
  const parsed = input.safeParse(await c.req.json().catch(() => null)); if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const p = parsed.data; const ownerId = c.get("auth").appUserId;
  const [existingAssessment] = await c.get("db").select({ ownerId: matchAssessments.ownerId }).from(matchAssessments).where(eq(matchAssessments.id, p.id)).limit(1);
  if (existingAssessment && existingAssessment.ownerId !== ownerId) return c.json({ error: "forbidden" }, 403);
  const [assessmentForMatch] = await c.get("db").select({ id: matchAssessments.id }).from(matchAssessments).where(and(eq(matchAssessments.matchId, p.match_id), eq(matchAssessments.ownerId, ownerId))).limit(1);
  if (assessmentForMatch && assessmentForMatch.id !== p.id) return c.json({ error: "assessment_conflict" }, 409);
  const [ownedMatch] = await c.get("db").select({ id: matches.id }).from(matches).where(and(eq(matches.id, p.match_id), eq(matches.ownerId, ownerId))).limit(1);
  if (!ownedMatch) return c.json({ error: "match_not_found" }, 404);
  const values = { id: p.id, matchId: p.match_id, ownerId, rating: p.rating ?? null, overall: p.overall ?? null, wentWell: p.went_well ?? null, toImprove: p.to_improve ?? null, createdAt: p.created_at ? new Date(p.created_at) : new Date(), updatedAt: new Date(), deletedAt: null };
  const [row] = await c.get("db").insert(matchAssessments).values(values).onConflictDoUpdate({
    target: matchAssessments.id,
    set: { matchId: values.matchId, rating: values.rating, overall: values.overall, wentWell: values.wentWell, toImprove: values.toImprove, updatedAt: values.updatedAt, deletedAt: null },
    setWhere: eq(matchAssessments.ownerId, ownerId),
  }).returning();
  if (!row) return c.json({ error: "forbidden" }, 403);
  return c.json(snakeCaseJSON(row));
});

matchAssessmentRoutes.delete("/:id", async (c) => {
  const id = z.uuid().safeParse(c.req.param("id")); if (!id.success) return c.json({ error: "invalid_id" }, 422);
  const rows = await c.get("db").update(matchAssessments).set({ deletedAt: new Date(), updatedAt: new Date() }).where(and(eq(matchAssessments.id, id.data), eq(matchAssessments.ownerId, c.get("auth").appUserId), isNull(matchAssessments.deletedAt))).returning({ id: matchAssessments.id });
  return rows.length ? c.body(null, 204) : c.json({ error: "not_found" }, 404);
});
