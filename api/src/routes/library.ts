import { and, eq, gte, inArray, isNull, notInArray, sql } from "drizzle-orm";
import { Hono, type Context } from "hono";
import { z } from "zod";
import { competitions, teamMembers, teamOfficials, teams, teamTags, venues } from "../db/schema";
import type { Env, Variables } from "../types";
import { parseISODate } from "../utils/dates";
import { snakeCaseJSON } from "../utils/json";
import {
  lockAndVersionEntity,
  normalizeEntityMutationId,
  type EntityMutationNamespace,
} from "../services/entityMutationVersion";
import { httpMutationContext } from "../services/mutationContext";
import { withMutation } from "../services/mutationLedger";

const member = z.object({ id: z.uuid(), team_id: z.uuid(), display_name: z.string().min(1), jersey_number: z.string().nullable().optional(), role: z.string().nullable().optional(), position: z.string().nullable().optional(), notes: z.string().nullable().optional(), created_at: z.iso.datetime().optional() });
const official = z.object({ id: z.uuid(), team_id: z.uuid(), display_name: z.string().min(1), role: z.string().min(1), phone: z.string().nullable().optional(), email: z.string().nullable().optional(), created_at: z.iso.datetime().optional() });
const MAX_TEAM_MEMBERS = 100;
const MAX_TEAM_OFFICIALS = 25;
const MAX_TEAM_TAGS = 50;
const teamInput = z.object({
  team: z.object({ id: z.uuid(), owner_id: z.string().optional(), name: z.string().min(1), short_name: z.string().nullable().optional(), division: z.string().nullable().optional(), color_primary: z.string().nullable().optional(), color_secondary: z.string().nullable().optional(), reference_key: z.string().nullable().optional() }),
  // These are authoritative replacement collections, so bound both request
  // parsing and the resulting bulk SQL to realistic roster-sized payloads.
  members: z.array(member).max(MAX_TEAM_MEMBERS).default([]),
  officials: z.array(official).max(MAX_TEAM_OFFICIALS).default([]),
  tags: z.array(z.string().min(1)).max(MAX_TEAM_TAGS).default([]),
});

export const libraryRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

libraryRoutes.get("/teams", async (c) => {
  const ownerId = c.get("auth").appUserId; let after: Date | undefined;
  try { after = parseISODate(c.req.query("updatedAfter")); } catch { return c.json({ error: "invalid_updated_after" }, 422); }
  const filters = [eq(teams.ownerId, ownerId)]; if (after) filters.push(gte(teams.updatedAt, after)); else filters.push(isNull(teams.deletedAt));
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
  const p = parsed.data; const ownerId = c.get("auth").appUserId; const teamId = normalizeUUID(p.team.id);
  if ([...p.members, ...p.officials].some((x) => normalizeUUID(x.team_id) !== teamId)) return c.json({ error: "nested_team_mismatch" }, 422);
  if (hasDuplicates(p.members.map((member) => member.id)) || hasDuplicates(p.officials.map((official) => official.id))) {
    return c.json({ error: "nested_team_mismatch" }, 422);
  }
  let row: typeof teams.$inferSelect | null;
  try {
    row = await withMutation(c.get("db"), httpMutationContext(c, "/api/teams"), async (tx) => {
      const version = await lockAndVersionEntity(tx, "team", teamId, async (id) => {
        const [existing] = await tx.select({
          ownerId: teams.ownerId,
          updatedAt: teams.updatedAt,
        }).from(teams).where(eq(teams.id, id)).limit(1);
        return existing;
      });
      const existingTeam = version.existing;
      if (existingTeam && existingTeam.ownerId !== ownerId) return null;

      const memberIds = p.members.map((member) => normalizeUUID(member.id));
      const officialIds = p.officials.map((official) => normalizeUUID(official.id));
      const existingMembers = memberIds.length
        ? await tx.select({ id: teamMembers.id, teamId: teamMembers.teamId }).from(teamMembers)
          .where(inArray(teamMembers.id, memberIds))
        : [];
      const existingOfficials = officialIds.length
        ? await tx.select({ id: teamOfficials.id, teamId: teamOfficials.teamId }).from(teamOfficials)
          .where(inArray(teamOfficials.id, officialIds))
        : [];
      if (
        existingMembers.some((member) => normalizeUUID(member.teamId) !== teamId)
        || existingOfficials.some((officialRow) => normalizeUUID(officialRow.teamId) !== teamId)
      ) {
        throw new NestedTeamMismatchError();
      }

      const updateValues = { name: p.team.name, shortName: p.team.short_name ?? null, division: p.team.division ?? null, colorPrimary: p.team.color_primary ?? null, colorSecondary: p.team.color_secondary ?? null, referenceKey: p.team.reference_key ?? null, deletedAt: null, updatedAt: version.updatedAt };
      const [saved] = await tx.insert(teams).values({ id: teamId, ownerId, ...updateValues }).onConflictDoUpdate({
        target: teams.id,
        set: updateValues,
        setWhere: eq(teams.ownerId, ownerId),
      }).returning();
      if (!saved) return null;

      if (p.members.length) {
        const retained = await tx.insert(teamMembers).values(p.members.map((memberRow) => ({
          id: normalizeUUID(memberRow.id),
          teamId,
          displayName: memberRow.display_name,
          jerseyNumber: memberRow.jersey_number ?? null,
          role: memberRow.role ?? null,
          position: memberRow.position ?? null,
          notes: memberRow.notes ?? null,
          createdAt: memberRow.created_at ? new Date(memberRow.created_at) : new Date(),
        }))).onConflictDoUpdate({
          target: teamMembers.id,
          set: {
            displayName: sql.raw("excluded.display_name"),
            jerseyNumber: sql.raw("excluded.jersey_number"),
            role: sql.raw("excluded.role"),
            position: sql.raw("excluded.position"),
            notes: sql.raw("excluded.notes"),
          },
          setWhere: eq(teamMembers.teamId, teamId),
        }).returning({ id: teamMembers.id });
        if (retained.length !== p.members.length) throw new NestedTeamMismatchError();
      }

      if (p.officials.length) {
        const retained = await tx.insert(teamOfficials).values(p.officials.map((officialRow) => ({
          id: normalizeUUID(officialRow.id),
          teamId,
          displayName: officialRow.display_name,
          role: officialRow.role,
          phone: officialRow.phone ?? null,
          email: officialRow.email ?? null,
          createdAt: officialRow.created_at ? new Date(officialRow.created_at) : new Date(),
        }))).onConflictDoUpdate({
          target: teamOfficials.id,
          set: {
            displayName: sql.raw("excluded.display_name"),
            role: sql.raw("excluded.role"),
            phone: sql.raw("excluded.phone"),
            email: sql.raw("excluded.email"),
          },
          setWhere: eq(teamOfficials.teamId, teamId),
        }).returning({ id: teamOfficials.id });
        if (retained.length !== p.officials.length) throw new NestedTeamMismatchError();
      }

      if (memberIds.length) {
        await tx.delete(teamMembers).where(and(
          eq(teamMembers.teamId, teamId),
          notInArray(teamMembers.id, memberIds),
        ));
      } else {
        await tx.delete(teamMembers).where(eq(teamMembers.teamId, teamId));
      }
      if (officialIds.length) {
        await tx.delete(teamOfficials).where(and(
          eq(teamOfficials.teamId, teamId),
          notInArray(teamOfficials.id, officialIds),
        ));
      } else {
        await tx.delete(teamOfficials).where(eq(teamOfficials.teamId, teamId));
      }

      const tagValues = [...new Set(p.tags)];
      if (tagValues.length) {
        await tx.delete(teamTags).where(and(
          eq(teamTags.teamId, teamId),
          notInArray(teamTags.value, tagValues),
        ));
        await tx.insert(teamTags).values(tagValues.map((value) => ({ teamId, value })))
          .onConflictDoNothing();
      } else {
        await tx.delete(teamTags).where(eq(teamTags.teamId, teamId));
      }
      return saved;
    });
  } catch (error) {
    if (error instanceof NestedTeamMismatchError) return c.json({ error: "nested_team_mismatch" }, 422);
    throw error;
  }
  if (!row) return c.json({ error: "forbidden" }, 403);
  return c.json(snakeCaseJSON({ updated_at: row?.updatedAt ?? new Date() }));
});

libraryRoutes.delete("/teams/:id", async (c) => softDelete(c, teams, c.req.param("id"), "/api/teams/:id"));

const competitionInput = z.object({ id: z.uuid(), owner_id: z.string().optional(), name: z.string().min(1), level: z.string().nullable().optional() });
libraryRoutes.get("/competitions", async (c) => listSimple(c, competitions));
libraryRoutes.post("/competitions", async (c) => {
  const parsed = competitionInput.safeParse(await c.req.json().catch(() => null)); if (!parsed.success) return c.json({ error: "validation_error", details: parsed.error.flatten() }, 422);
  const p = parsed.data; const ownerId = c.get("auth").appUserId;
  const row = await withMutation(c.get("db"), httpMutationContext(c, "/api/competitions"), async (tx) => {
    const version = await lockAndVersionEntity(tx, "competition", p.id, async (id) => {
      const [existing] = await tx.select({
        ownerId: competitions.ownerId,
        updatedAt: competitions.updatedAt,
      }).from(competitions).where(eq(competitions.id, id)).limit(1);
      return existing;
    });
    if (version.existing && version.existing.ownerId !== ownerId) return undefined;
    const updateValues = { name: p.name, level: p.level ?? null, deletedAt: null, updatedAt: version.updatedAt };
    const [saved] = await tx.insert(competitions).values({ id: version.id, ownerId, ...updateValues }).onConflictDoUpdate({
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
  const row = await withMutation(c.get("db"), httpMutationContext(c, "/api/venues"), async (tx) => {
    const version = await lockAndVersionEntity(tx, "venue", p.id, async (id) => {
      const [existing] = await tx.select({
        ownerId: venues.ownerId,
        updatedAt: venues.updatedAt,
      }).from(venues).where(eq(venues.id, id)).limit(1);
      return existing;
    });
    if (version.existing && version.existing.ownerId !== ownerId) return undefined;
    const updateValues = { name: p.name, city: p.city ?? null, country: p.country ?? null, latitude: p.latitude ?? null, longitude: p.longitude ?? null, deletedAt: null, updatedAt: version.updatedAt };
    const [saved] = await tx.insert(venues).values({ id: version.id, ownerId, ...updateValues }).onConflictDoUpdate({
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
  const filters = [eq(table.ownerId, ownerId)]; if (after) filters.push(gte(table.updatedAt, after)); else filters.push(isNull(table.deletedAt));
  return c.json(snakeCaseJSON(await c.get("db").select().from(table).where(and(...filters)).orderBy(table.updatedAt)));
}

async function softDelete(c: APIContext, table: typeof teams | SimpleTable, rawId: string, routeTemplate: string) {
  const id = z.uuid().safeParse(rawId); if (!id.success) return c.json({ error: "invalid_id" }, 422);
  const namespace = simpleEntityNamespace(table);
  const rows = await withMutation(c.get("db"), httpMutationContext(c, routeTemplate), async (tx) => {
    const version = await lockAndVersionEntity(tx, namespace, id.data, async (normalizedId) => {
      const [existing] = await tx.select({
        ownerId: table.ownerId,
        updatedAt: table.updatedAt,
        deletedAt: table.deletedAt,
      }).from(table).where(eq(table.id, normalizedId)).limit(1);
      return existing;
    });
    if (
      !version.existing
      || version.existing.ownerId !== c.get("auth").appUserId
      || version.existing.deletedAt
    ) {
      return [];
    }
    return tx.update(table).set({
      deletedAt: version.updatedAt,
      updatedAt: version.updatedAt,
    }).where(and(
      eq(table.id, version.id),
      eq(table.ownerId, c.get("auth").appUserId),
      isNull(table.deletedAt),
    )).returning({ id: table.id });
  });
  return rows.length ? c.body(null, 204) : c.json({ error: "not_found" }, 404);
}

function hasDuplicates(values: string[]): boolean {
  return new Set(values.map(normalizeUUID)).size !== values.length;
}

function normalizeUUID(value: string): string {
  return normalizeEntityMutationId(value);
}

function simpleEntityNamespace(table: typeof teams | SimpleTable): EntityMutationNamespace {
  if (table === teams) return "team";
  if (table === competitions) return "competition";
  return "venue";
}

class NestedTeamMismatchError extends Error {}
