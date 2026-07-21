import { and, eq, gte, isNull } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { matchAssessments, matches } from "../db/schema";
import type { Env, Variables } from "../types";
import { parseISODate } from "../utils/dates";
import { snakeCaseJSON } from "../utils/json";
import {
  acquireSortedAdvisoryLocks,
  assessmentOwnerMatchAdvisoryKey,
  lockAndVersionEntity,
} from "../services/entityMutationVersion";
import { httpMutationContext } from "../services/mutationContext";
import { withMutation } from "../services/mutationLedger";

const input = z.object({ id: z.uuid(), match_id: z.uuid(), owner_id: z.string().optional(), rating: z.number().int().min(1).max(5).nullable().optional(), overall: z.string().nullable().optional(), went_well: z.string().nullable().optional(), to_improve: z.string().nullable().optional(), created_at: z.iso.datetime().optional() });
export const matchAssessmentRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

matchAssessmentRoutes.get("/", async (c) => {
  let after: Date | undefined; try { after = parseISODate(c.req.query("updatedAfter")); } catch { return c.json({ error: "invalid_updated_after" }, 422); }
  const filters = [eq(matchAssessments.ownerId, c.get("auth").appUserId)]; if (after) filters.push(gte(matchAssessments.updatedAt, after)); else filters.push(isNull(matchAssessments.deletedAt));
  return c.json(snakeCaseJSON(await c.get("db").select().from(matchAssessments).where(and(...filters)).orderBy(matchAssessments.updatedAt)));
});

matchAssessmentRoutes.post("/", async (c) => {
  const parsed = input.safeParse(await c.req.json().catch(() => null)); if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const p = parsed.data; const ownerId = c.get("auth").appUserId;
  const result = await withMutation(c.get("db"), httpMutationContext(c, "/api/match-assessments"), async (tx) => {
    // Lock order is global ledger -> assessment ID -> sorted owner/match keys.
    // When an existing assessment moves matches, sorting the old and new
    // uniqueness keys keeps cross-ID swaps deadlock-free.
    const version = await lockAndVersionEntity(tx, "match-assessment", p.id, async (id) => {
      const [existing] = await tx.select({
        ownerId: matchAssessments.ownerId,
        matchId: matchAssessments.matchId,
        updatedAt: matchAssessments.updatedAt,
        deletedAt: matchAssessments.deletedAt,
      }).from(matchAssessments).where(eq(matchAssessments.id, id)).limit(1);
      return existing;
    });
    const existingAssessment = version.existing;
    if (existingAssessment && existingAssessment.ownerId !== ownerId) return { kind: "forbidden" as const };
    await acquireSortedAdvisoryLocks(tx, [
      assessmentOwnerMatchAdvisoryKey(ownerId, p.match_id),
      ...(existingAssessment
        ? [assessmentOwnerMatchAdvisoryKey(existingAssessment.ownerId, existingAssessment.matchId)]
        : []),
    ]);

    const [assessmentForMatch] = await tx.select({ id: matchAssessments.id })
      .from(matchAssessments)
      .where(and(eq(matchAssessments.matchId, p.match_id), eq(matchAssessments.ownerId, ownerId)))
      .limit(1);
    if (assessmentForMatch && assessmentForMatch.id !== version.id) return { kind: "conflict" as const };

    const [ownedMatch] = await tx.select({ id: matches.id }).from(matches)
      .where(and(eq(matches.id, p.match_id), eq(matches.ownerId, ownerId), isNull(matches.deletedAt)))
      .limit(1);
    if (!ownedMatch) return { kind: "match_not_found" as const };

    const values = {
      id: version.id,
      matchId: p.match_id,
      ownerId,
      rating: p.rating ?? null,
      overall: p.overall ?? null,
      wentWell: p.went_well ?? null,
      toImprove: p.to_improve ?? null,
      createdAt: p.created_at ? new Date(p.created_at) : new Date(),
      updatedAt: version.updatedAt,
      deletedAt: null,
    };
    const updateValues = {
      matchId: values.matchId,
      rating: values.rating,
      overall: values.overall,
      wentWell: values.wentWell,
      toImprove: values.toImprove,
      updatedAt: values.updatedAt,
      deletedAt: null,
    };
    if (existingAssessment) {
      const [saved] = await tx.update(matchAssessments).set(updateValues)
        .where(and(eq(matchAssessments.id, version.id), eq(matchAssessments.ownerId, ownerId)))
        .returning();
      return saved ? { kind: "saved" as const, row: saved } : { kind: "forbidden" as const };
    }

    const [saved] = await tx.insert(matchAssessments).values(values)
      .onConflictDoNothing()
      .returning();
    if (saved) return { kind: "saved" as const, row: saved };

    // A writer outside this mounted route may not take the advisory lock.
    // Classify the resulting uniqueness race without aborting the transaction.
    const [conflictingId] = await tx.select({ ownerId: matchAssessments.ownerId })
      .from(matchAssessments).where(eq(matchAssessments.id, version.id)).limit(1);
    if (conflictingId && conflictingId.ownerId !== ownerId) return { kind: "forbidden" as const };
    return { kind: "conflict" as const };
  });
  if (result.kind === "forbidden") return c.json({ error: "forbidden" }, 403);
  if (result.kind === "conflict") return c.json({ error: "assessment_conflict" }, 409);
  if (result.kind === "match_not_found") return c.json({ error: "match_not_found" }, 404);
  return c.json(snakeCaseJSON(result.row));
});

matchAssessmentRoutes.delete("/:id", async (c) => {
  const id = z.uuid().safeParse(c.req.param("id")); if (!id.success) return c.json({ error: "invalid_id" }, 422);
  const rows = await withMutation(c.get("db"), httpMutationContext(c, "/api/match-assessments/:id"), async (tx) => {
    const version = await lockAndVersionEntity(tx, "match-assessment", id.data, async (normalizedId) => {
      const [existing] = await tx.select({
        ownerId: matchAssessments.ownerId,
        matchId: matchAssessments.matchId,
        updatedAt: matchAssessments.updatedAt,
        deletedAt: matchAssessments.deletedAt,
      }).from(matchAssessments).where(eq(matchAssessments.id, normalizedId)).limit(1);
      return existing;
    });
    if (
      !version.existing
      || version.existing.ownerId !== c.get("auth").appUserId
      || version.existing.deletedAt
    ) {
      return [];
    }
    await acquireSortedAdvisoryLocks(tx, [
      assessmentOwnerMatchAdvisoryKey(version.existing.ownerId, version.existing.matchId),
    ]);
    return tx.update(matchAssessments).set({
      deletedAt: version.updatedAt,
      updatedAt: version.updatedAt,
    }).where(and(
      eq(matchAssessments.id, version.id),
      eq(matchAssessments.ownerId, c.get("auth").appUserId),
      isNull(matchAssessments.deletedAt),
    )).returning({ id: matchAssessments.id });
  });
  return rows.length ? c.body(null, 204) : c.json({ error: "not_found" }, 404);
});
