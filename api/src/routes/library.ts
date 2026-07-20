import { and, eq, gt, inArray, isNull } from "drizzle-orm";
import { Hono, type Context } from "hono";
import { z } from "zod";
import { competitions, teamMembers, teamOfficials, teams, teamTags, venues } from "../db/schema";
import type { Env, Variables } from "../types";
import { parseISODate } from "../utils/dates";
import { snakeCaseJSON } from "../utils/json";
import { httpMutationContext } from "../services/mutationContext";
import { withMutation } from "../services/mutationLedger";

const member = z.object({ id: z.uuid(), team_id: z.uuid(), display_name: z.string().min(1), jersey_number: z.string().nullable().optional(), role: z.string().nullable().optional(), position: z.string().nullable().optional(), notes: z.string().nullable().optional(), created_at: z.iso.datetime().optional() });
const official = z.object({ id: z.uuid(), team_id: z.uuid(), display_name: z.string().min(1), role: z.string().min(1), phone: z.string().nullable().optional(), email: z.string().nullable().optional(), created_at: z.iso.datetime().optional() });
const teamInput = z.object({
  team: z.object({ id: z.uuid(), owner_id: z.string().optional(), name: z.string().min(1), short_name: z.string().nullable().optional(), division: z.string().nullable().optional(), color_primary: z.string().nullable().optional(), color_secondary: z.string().nullable().optional(), reference_key: z.string().nullable().optional() }),
  members: z.array(member).default([]), officials: z.array(official).default([]), tags: z.array(z.string().min(1)).default([]),
});

export const libraryRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

libraryRoutes.get("/teams", async (c) => {
  const ownerId = c.get("auth").appUserId; let after: Date | undefined;
  try { after = parseISODate(c.req.query("updatedAfter")); } catch { return c.json({ error: "invalid_updated_after" }, 422); }
  const filters = [eq(teams.ownerId, ownerId)]; if (after) filters.push(gt(teams.updatedAt, after)); else filters.push(isNull(teams.deletedAt));
  const teamRows = await c.get("db").select().from(teams).where(and(...filters)).orderBy(teams.updatedAt);
  if (!teamRows.length) return c.json([]);
  const ids = teamRows.map((row) => row.id);
  // connectDatabase intentionally gives each request one pg Client. Keep its
  // queries sequential; concurrent client.query calls are deprecated and will
  // be removed in pg 9.
  const members = await c.get("db").select().from(teamMembers).where(inArray(teamMembers.teamId, ids));
  const officials = await c.get("db").select().from(teamOfficials).where(inArray(teamOfficials.teamId, ids));
  const tags = await c.get("db").select().from(teamTags).where(inArray(teamTags.teamId, ids));
  return c.json(snakeCaseJSON(teamRows.map((team) => ({
    team, members: members.filter((x) => x.teamId === team.id), officials: officials.filter((x) => x.teamId === team.id), tags: tags.filter((x) => x.teamId === team.id),
  }))));
});

libraryRoutes.post("/teams", async (c) => {
  const parsed = teamInput.safeParse(await c.req.json().catch(() => null)); if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const p = parsed.data; const ownerId = c.get("auth").appUserId; const teamId = p.team.id;
  if ([...p.members, ...p.officials].some((x) => x.team_id !== teamId)) return c.json({ error: "nested_team_mismatch" }, 422);
  const row = await withMutation(c.get("db"), httpMutationContext(c, "/api/teams"), async (tx) => {
    const updateValues = { name: p.team.name, shortName: p.team.short_name ?? null, division: p.team.division ?? null, colorPrimary: p.team.color_primary ?? null, colorSecondary: p.team.color_secondary ?? null, referenceKey: p.team.reference_key ?? null, deletedAt: null, updatedAt: new Date() };
    const [saved] = await tx.insert(teams).values({ id: teamId, ownerId, ...updateValues }).onConflictDoUpdate({
      target: teams.id,
      set: updateValues,
      setWhere: eq(teams.ownerId, ownerId),
    }).returning();
    if (!saved) return null;
    await tx.delete(teamMembers).where(eq(teamMembers.teamId, teamId)); await tx.delete(teamOfficials).where(eq(teamOfficials.teamId, teamId)); await tx.delete(teamTags).where(eq(teamTags.teamId, teamId));
    if (p.members.length) await tx.insert(teamMembers).values(p.members.map((x) => ({ id: x.id, teamId, displayName: x.display_name, jerseyNumber: x.jersey_number ?? null, role: x.role ?? null, position: x.position ?? null, notes: x.notes ?? null, createdAt: x.created_at ? new Date(x.created_at) : new Date() })));
    if (p.officials.length) await tx.insert(teamOfficials).values(p.officials.map((x) => ({ id: x.id, teamId, displayName: x.display_name, role: x.role, phone: x.phone ?? null, email: x.email ?? null, createdAt: x.created_at ? new Date(x.created_at) : new Date() })));
    if (p.tags.length) await tx.insert(teamTags).values([...new Set(p.tags)].map((value) => ({ teamId, value })));
    return saved;
  });
  if (!row) return c.json({ error: "forbidden" }, 403);
  return c.json(snakeCaseJSON({ updated_at: row?.updatedAt ?? new Date() }));
});

libraryRoutes.delete("/teams/:id", async (c) => softDelete(c, teams, c.req.param("id"), "/api/teams/:id"));

const competitionInput = z.object({ id: z.uuid(), owner_id: z.string().optional(), name: z.string().min(1), level: z.string().nullable().optional() });
libraryRoutes.get("/competitions", async (c) => listSimple(c, competitions));
libraryRoutes.post("/competitions", async (c) => {
  const parsed = competitionInput.safeParse(await c.req.json().catch(() => null)); if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const p = parsed.data; const ownerId = c.get("auth").appUserId;
  const updateValues = { name: p.name, level: p.level ?? null, deletedAt: null, updatedAt: new Date() };
  const row = await withMutation(c.get("db"), httpMutationContext(c, "/api/competitions"), async (tx) => {
    const [saved] = await tx.insert(competitions).values({ id: p.id, ownerId, ...updateValues }).onConflictDoUpdate({
      target: competitions.id,
      set: updateValues,
      setWhere: eq(competitions.ownerId, ownerId),
    }).returning();
    return saved;
  });
  return row ? c.json(snakeCaseJSON(row)) : c.json({ error: "forbidden" }, 403);
});
libraryRoutes.delete("/competitions/:id", async (c) => softDelete(c, competitions, c.req.param("id"), "/api/competitions/:id"));

const coordinate = (minimum: number, maximum: number) => z.preprocess(
  (value) => typeof value === "string" && value.trim() !== "" ? Number(value) : value,
  z.number().finite().min(minimum).max(maximum).nullable().optional(),
);
const venueInput = z.object({ id: z.uuid(), owner_id: z.string().optional(), name: z.string().min(1), city: z.string().nullable().optional(), country: z.string().nullable().optional(), latitude: coordinate(-90, 90), longitude: coordinate(-180, 180) });
libraryRoutes.get("/venues", async (c) => listSimple(c, venues));
libraryRoutes.post("/venues", async (c) => {
  const parsed = venueInput.safeParse(await c.req.json().catch(() => null)); if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const p = parsed.data; const ownerId = c.get("auth").appUserId;
  const updateValues = { name: p.name, city: p.city ?? null, country: p.country ?? null, latitude: p.latitude ?? null, longitude: p.longitude ?? null, deletedAt: null, updatedAt: new Date() };
  const row = await withMutation(c.get("db"), httpMutationContext(c, "/api/venues"), async (tx) => {
    const [saved] = await tx.insert(venues).values({ id: p.id, ownerId, ...updateValues }).onConflictDoUpdate({
      target: venues.id,
      set: updateValues,
      setWhere: eq(venues.ownerId, ownerId),
    }).returning();
    return saved;
  });
  return row ? c.json(snakeCaseJSON(row)) : c.json({ error: "forbidden" }, 403);
});
libraryRoutes.delete("/venues/:id", async (c) => softDelete(c, venues, c.req.param("id"), "/api/venues/:id"));

type SimpleTable = typeof competitions | typeof venues;
type APIContext = Context<{ Bindings: Env; Variables: Variables }>;
async function listSimple(c: APIContext, table: SimpleTable) {
  const ownerId = c.get("auth").appUserId; let after: Date | undefined; try { after = parseISODate(c.req.query("updatedAfter")); } catch { return c.json({ error: "invalid_updated_after" }, 422); }
  const filters = [eq(table.ownerId, ownerId)]; if (after) filters.push(gt(table.updatedAt, after)); else filters.push(isNull(table.deletedAt));
  return c.json(snakeCaseJSON(await c.get("db").select().from(table).where(and(...filters)).orderBy(table.updatedAt)));
}

async function softDelete(c: APIContext, table: typeof teams | SimpleTable, rawId: string, routeTemplate: string) {
  const id = z.uuid().safeParse(rawId); if (!id.success) return c.json({ error: "invalid_id" }, 422);
  const rows = await withMutation(c.get("db"), httpMutationContext(c, routeTemplate), (tx) => tx.update(table).set({ deletedAt: new Date(), updatedAt: new Date() }).where(and(eq(table.id, id.data), eq(table.ownerId, c.get("auth").appUserId), isNull(table.deletedAt))).returning({ id: table.id }));
  return rows.length ? c.body(null, 204) : c.json({ error: "not_found" }, 404);
}
