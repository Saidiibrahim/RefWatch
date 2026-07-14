import { describe, expect, it } from "vitest";
import { sourceTables, validateCutoverBundle } from "../scripts/cutover-bundle.mjs";

const userId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2a";
const authOnlyId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2b";

function validBundle(): any {
  return {
    snapshot: {
      source: "supabase-mcp",
      transaction_isolation: "repeatable read",
      read_only: true,
      captured_at_utc: "2026-07-14T03:00:00Z",
      auth_user_count: 2,
      auth_user_ids: [userId, authOnlyId],
      public_table_counts: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? 1 : 0])),
    },
    tables: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? [{ id: userId }] : []])),
    table_dispositions: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? "import" : "exclude_zero"])),
    clerk_mappings: [{ app_user_id: userId, clerk_user_id: "user_reviewed_subject" }],
    auth_only_users: [{ auth_user_id: authOnlyId, action: "exclude", reason: "No application profile or owned data" }],
  };
}

describe("cutover bundle validation", () => {
  it("accepts a complete repeatable-read snapshot with reviewed identities", () => {
    const result = validateCutoverBundle(validBundle());
    expect(result.ok).toBe(true);
    expect(result.summary).toMatchObject({ publicTables: 39, publicUsers: 1, clerkMappings: 1, authOnlyUsers: 1 });
  });

  it("rejects missing or invented identity mappings", () => {
    const bundle = validBundle();
    bundle.clerk_mappings = [{ app_user_id: authOnlyId, clerk_user_id: "user_wrong" }];
    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain(`missing Clerk mapping for app user ${userId}`);
    expect(result.errors).toContain(`Clerk mapping references unknown app user ${authOnlyId}`);
  });

  it("rejects non-repeatable snapshots, count drift, and orphan ownership", () => {
    const bundle = validBundle();
    bundle.snapshot.transaction_isolation = "read committed";
    bundle.snapshot.public_table_counts.competitions = 1;
    bundle.tables.competitions = [{ id: authOnlyId, owner_id: authOnlyId }];
    bundle.table_dispositions.competitions = "import";
    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("snapshot must use repeatable read");
    expect(result.errors).toContain(`competitions.${authOnlyId}: unknown owner_id`);
  });

  it("requires explicit arrays even for zero-row source tables", () => {
    const bundle = validBundle();
    delete bundle.tables.coaches;
    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("missing exported row array for public.coaches");
  });

  it("rejects invented auth-only identities and migrated identity collisions", () => {
    const bundle = validBundle();
    bundle.auth_only_users = [{
      auth_user_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f2c",
      action: "migrate",
      reason: "review",
      app_user_id: userId,
      clerk_user_id: "user_other",
      migration_contract: "new_empty_app_user",
      new_app_user: { id: userId },
    }];
    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("auth-only disposition references unexpected source identity 0190f8f4-5914-7b6c-9d6a-469a29f92f2c");
    expect(result.errors).toContain(`migrated auth-only app_user_id collision: ${userId}`);
  });

  it("rejects unsupported import dispositions and imported relation orphans", () => {
    const bundle = validBundle();
    bundle.snapshot.public_table_counts.coaches = 1;
    bundle.tables.coaches = [{ id: authOnlyId, owner_id: authOnlyId }];
    bundle.table_dispositions.coaches = "import";
    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("public.coaches disposition must be blocked_pending_import_contract");
    expect(result.errors).toContain("public.coaches became non-empty and has no verified import contract; cutover is blocked");

    const relationBundle = validBundle();
    relationBundle.snapshot.public_table_counts.team_members = 1;
    relationBundle.tables.team_members = [{ id: authOnlyId, team_id: authOnlyId }];
    relationBundle.table_dispositions.team_members = "import";
    const relationResult = validateCutoverBundle(relationBundle);
    expect(relationResult.ok).toBe(false);
    expect(relationResult.errors).toContain("public.team_members disposition must be blocked_pending_import_contract");
    expect(relationResult.errors).toContain("public.team_members became non-empty and has no verified import contract; cutover is blocked");
    expect(relationResult.errors).toContain(`team_members.${authOnlyId}: unknown team_id`);
  });

  it("rejects composite reference-season mismatches and cross-owner pages", () => {
    const bundle = validBundle();
    const competitionId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2c";
    const teamId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2d";
    const matchId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2e";
    const otherUserId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2f";
    bundle.tables.users.push({ id: otherUserId });
    bundle.snapshot.public_table_counts.users = 2;
    bundle.snapshot.auth_user_ids.push(otherUserId);
    bundle.snapshot.auth_user_count = 3;
    bundle.clerk_mappings.push({ app_user_id: otherUserId, clerk_user_id: "user_other_owner" });
    bundle.tables.reference_competitions = [{ id: competitionId, season_year: 2026 }];
    bundle.snapshot.public_table_counts.reference_competitions = 1;
    bundle.table_dispositions.reference_competitions = "seed_reconcile";
    bundle.tables.reference_teams = [{ id: teamId, competition_id: competitionId, season_year: 2025 }];
    bundle.snapshot.public_table_counts.reference_teams = 1;
    bundle.table_dispositions.reference_teams = "seed_reconcile";
    bundle.tables.matches = [{ id: matchId, owner_id: userId }];
    bundle.snapshot.public_table_counts.matches = 1;
    bundle.table_dispositions.matches = "import";
    bundle.tables.pages = [{ id: teamId, owner_id: otherUserId, match_id: matchId }];
    bundle.snapshot.public_table_counts.pages = 1;
    bundle.table_dispositions.pages = "import";

    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain(`reference_teams.${teamId}: competition_id/season_year mismatch`);
    expect(result.errors).toContain(`pages.${teamId}: owner differs from match`);
  });

  it("requires user-owned workout presets to use the import contract", () => {
    const bundle = validBundle();
    const presetId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2c";
    bundle.tables.workout_presets = [{ id: presetId, created_by: userId }];
    bundle.snapshot.public_table_counts.workout_presets = 1;
    bundle.table_dispositions.workout_presets = "seed_reconcile";

    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("public.workout_presets disposition must be import");
  });

  it("requires exact non-overlapping partitions for mixed global and user-owned presets", () => {
    const bundle = validBundle();
    const globalId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2c";
    const ownedId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2d";
    bundle.tables.workout_presets = [{ id: globalId, created_by: null }, { id: ownedId, created_by: userId }];
    bundle.snapshot.public_table_counts.workout_presets = 2;
    bundle.table_dispositions.workout_presets = "mixed_seed_import";
    bundle.workout_preset_partitions = { seed_reconcile_ids: [globalId], import_ids: [globalId] };

    const result = validateCutoverBundle(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("workout preset import partition must exactly match user-owned rows");
    expect(result.errors).toContain("workout preset partitions must not overlap");

    bundle.workout_preset_partitions = { seed_reconcile_ids: [globalId, globalId], import_ids: [ownedId, ownedId] };
    const duplicateResult = validateCutoverBundle(bundle);
    expect(duplicateResult.errors).toContain("workout preset seed_reconcile partition contains duplicate IDs");
    expect(duplicateResult.errors).toContain("workout preset import partition contains duplicate IDs");
  });
});
