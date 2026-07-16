import { describe, expect, it } from "vitest";
import { computeCutoverDataSha256, computeSourceAuthSafeDigests, sourceTables, validateCutoverBundle } from "../scripts/cutover-bundle.mjs";

const userId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2a";
const authOnlyId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2b";
const digest = "a".repeat(64);

function validBundle(): any {
  const migratedUserIds = [userId, ...Array.from({ length: 41 }, (_, index) => `0190f8f4-5914-7b6c-9d6a-${(0x469a29f93000 + index).toString(16)}`)];
  const allAuthUserIds = [...migratedUserIds, authOnlyId];
  const sourceAuthUsers = allAuthUserIds.map((id, index) => ({
    id,
    email: id === authOnlyId ? "testing@refwatch.com" : index === 0 ? "owner@example.com" : `user${index}@example.com`,
    encrypted_password: index < 13 ? "$2a$10$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ01234" : null,
    password_hasher: index < 13 ? "bcrypt" : null,
    created_at: "2026-07-14T02:00:00Z",
    updated_at: "2026-07-14T02:00:00Z",
    email_confirmed_at: "2026-07-14T02:00:00Z",
    last_sign_in_at: null,
    banned_until: null,
    deleted_at: null,
    is_sso_user: false,
    is_anonymous: false,
  }));
  const identityFor = (id: string, user: any, provider: string, suffix: number) => ({
    id,
    user_id: user.id,
    provider,
    provider_id: `${provider}-${suffix}`,
    email: user.email,
    created_at: "2026-07-14T02:00:00Z",
    updated_at: "2026-07-14T02:00:00Z",
    last_sign_in_at: null,
  });
  const sourceAuthIdentities = [
    identityFor("0190f8f4-5914-7b6c-9d6a-469a29f92f40", sourceAuthUsers[0], "email", 0),
    identityFor("0190f8f4-5914-7b6c-9d6a-469a29f92f41", sourceAuthUsers[42], "google", 42),
    ...sourceAuthUsers.slice(1, 13).map((user, index) => identityFor(`0190f8f4-5914-7b6c-9d6a-${(0x469a29f94000 + index).toString(16)}`, user, "email", index + 1)),
    ...sourceAuthUsers.slice(13, 34).map((user, index) => identityFor(`0190f8f4-5914-7b6c-9d6a-${(0x469a29f95000 + index).toString(16)}`, user, "apple", index)),
    ...sourceAuthUsers.slice(34, 42).map((user, index) => identityFor(`0190f8f4-5914-7b6c-9d6a-${(0x469a29f96000 + index).toString(16)}`, user, "google", index)),
    identityFor("0190f8f4-5914-7b6c-9d6a-469a29f92f42", sourceAuthUsers[0], "apple", 99),
  ];
  const authOnlyDigests = computeSourceAuthSafeDigests(sourceAuthUsers[42], [sourceAuthIdentities[1]]);
  const bundle = {
    production_clerk_instance_id: "ins_production123",
    snapshot: {
      source: "supabase-secure-export",
      status: "final",
      final: true,
      eligible_for_import: true,
      writes_quiesced: true,
      final_export_complete: true,
      export_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f30",
      transaction_isolation: "repeatable read",
      read_only: true,
      captured_at_utc: "2026-07-14T03:00:00Z",
      completed_at_utc: "2026-07-14T03:00:01Z",
      source_project_ref: "muwuzfbtmqwvwacqnofc",
      query_sha256: digest,
      generator_sha256: digest,
      schema_contract_sha256: digest,
      rls_contract_sha256: digest,
      server_data_sha256: digest,
      local_data_sha256: digest,
      artifact: {
        encrypted: true,
        retention_owner: "migration-owner",
        retention_event: "verified observation-window closeout",
        deletion_verification_required: true,
      },
      quiescence: {
        write_mode_disabled: true,
        source_writes_stopped: true,
        provider_receipt_sha256: digest,
        ledger_receipt_sha256: digest,
        ledger_watermark: 0,
        write_guard_version_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f2c",
        required_through_utc: "2026-07-14T03:00:02Z",
      },
      auth_user_count: 43,
      auth_identity_count: 44,
      auth_password_digest_counts: { bcrypt_2a: 13, missing: 30 },
      auth_identity_provider_counts: { apple: 22, email: 13, google: 9 },
      auth_user_ids: allAuthUserIds,
      public_table_counts: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? 42 : 0])),
    },
    tables: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? migratedUserIds.map((id) => ({ id })) : []])),
    table_dispositions: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? "import" : "exclude_zero"])),
    clerk_mappings: migratedUserIds.map((id, index) => ({ app_user_id: id, clerk_user_id: `user_reviewed_subject_${index}` })),
    source_auth_users: sourceAuthUsers,
    source_auth_identities: sourceAuthIdentities,
    auth_only_users: [{
      auth_user_id: authOnlyId,
      action: "exclude",
      reason: "No application profile or owned data",
      normalized_email: "testing@refwatch.com",
      public_profile_present: false,
      owned_row_count: 0,
      provider_identity_count: 1,
      auth_user_safe_sha256: authOnlyDigests.authUserSha256,
      auth_identity_safe_sha256: authOnlyDigests.authIdentitiesSha256,
    }],
  };
  bundle.snapshot.local_data_sha256 = computeCutoverDataSha256(bundle.tables);
  bundle.snapshot.server_data_sha256 = bundle.snapshot.local_data_sha256;
  return bundle;
}

function validEvidence(bundle: any): any {
  const receipt = {
    source_project_ref: bundle.snapshot.source_project_ref,
    export_id: bundle.snapshot.export_id,
    query_sha256: bundle.snapshot.query_sha256,
    generator_sha256: bundle.snapshot.generator_sha256,
    write_guard_version_id: bundle.snapshot.quiescence.write_guard_version_id,
    write_mode_disabled: true,
    source_writes_stopped: true,
    ledger_watermark: bundle.snapshot.quiescence.ledger_watermark,
    quiescence_started_at_utc: "2026-07-14T02:59:59Z",
    quiescence_observed_through_utc: "2026-07-14T03:00:02Z",
  };
  return {
    verified: true,
    artifact: {
      cipher: "aes-256-gcm",
      sha256: digest,
      byteSize: 1024,
      mode: "0600",
      directoryMode: "0700",
      noSymlink: true,
      ownerVerified: true,
    },
    providerReceipt: { sha256: bundle.snapshot.quiescence.provider_receipt_sha256, data: receipt },
    ledgerReceipt: { sha256: bundle.snapshot.quiescence.ledger_receipt_sha256, data: receipt },
    creatorReceipt: {
      sha256: digest,
      data: {
        receipt_type: "encrypted-artifact-creation",
        export_id: bundle.snapshot.export_id,
        source_project_ref: bundle.snapshot.source_project_ref,
        query_sha256: bundle.snapshot.query_sha256,
        generator_sha256: bundle.snapshot.generator_sha256,
        cipher: "aes-256-gcm",
        artifact_sha256: digest,
        byte_size: 1024,
        manifest_sha256: digest,
        exclusive_create: true,
        fsync_file: true,
        fsync_directory: true,
        atomic_rename: true,
      },
    },
    manifestSha256: digest,
    releasePolicy: {
      querySha256: bundle.snapshot.query_sha256,
      generatorSha256: bundle.snapshot.generator_sha256,
      creatorReceiptSha256: digest,
      authPasswordDigestCounts: { bcrypt_2a: 13, missing: 30 },
      authIdentityProviderCounts: { apple: 22, email: 13, google: 9 },
    },
  };
}

function validate(bundle: any) {
  return validateCutoverBundle(bundle, validEvidence(bundle));
}

describe("cutover bundle validation", () => {
  it("accepts a complete repeatable-read snapshot with reviewed identities", () => {
    const bundle = validBundle();
    const result = validate(bundle);
    expect(result.ok).toBe(true);
    expect(result.summary).toMatchObject({ publicTables: 39, publicUsers: 42, clerkMappings: 42, authOnlyUsers: 1 });
    expect(result.summary.identityReconciliation).toMatchObject({
      clerkInstanceId: "ins_production123",
      legacyMappingCount: 42,
      excludedAuthCount: 1,
    });
    expect(result.summary.identityReconciliation.receiptDigest).toMatch(/^[0-9a-f]{64}$/);
    expect(result.summary.identityReconciliation.mappingHash).toMatch(/^[0-9a-f]{64}$/);
    expect(result.summary.identityReconciliation).not.toHaveProperty("legacyMappings");
  });

  it("rejects a final bundle without independently verified files and receipts", () => {
    const result = validateCutoverBundle(validBundle());
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("encrypted artifact and quiescence evidence must be independently verified");
  });

  it("rejects the wrong source project or an exporter outside the release packet", () => {
    const wrongProject = validBundle();
    wrongProject.snapshot.source_project_ref = "abcdefghijklmnopqrst";
    expect(validate(wrongProject).errors).toContain("snapshot.source_project_ref must be the reviewed RefWatch Supabase project");

    const wrongExporter = validBundle();
    const evidence = validEvidence(wrongExporter);
    evidence.releasePolicy.querySha256 = "b".repeat(64);
    evidence.releasePolicy.generatorSha256 = "c".repeat(64);
    const errors = validateCutoverBundle(wrongExporter, evidence).errors;
    expect(errors).toContain("snapshot query digest is not approved by the release packet");
    expect(errors).toContain("snapshot generator digest is not approved by the release packet");
  });

  it("rejects quiescence receipts that do not cover the required interval", () => {
    const bundle = validBundle();
    const evidence = validEvidence(bundle);
    evidence.providerReceipt.data.quiescence_observed_through_utc = "2026-07-14T03:00:01Z";
    evidence.ledgerReceipt.data.quiescence_observed_through_utc = "2026-07-14T03:00:01Z";
    const errors = validateCutoverBundle(bundle, evidence).errors;
    expect(errors.filter((error) => error === "quiescence receipt does not cover the required interval")).toHaveLength(2);
  });

  it("binds the receipt to production Clerk and the approved exclude action", () => {
    const missingInstance = validBundle();
    delete missingInstance.production_clerk_instance_id;
    expect(validate(missingInstance).errors).toContain(
      "production_clerk_instance_id must identify the reviewed production Clerk instance",
    );

    const archived = validBundle();
    archived.auth_only_users[0].action = "archive";
    expect(validate(archived).errors).toContain(
      `auth-only action for ${authOnlyId} must be exclude`,
    );
  });

  it("rejects candidate snapshots and unproved encrypted/quiesced exports", () => {
    const candidate = validBundle();
    Object.assign(candidate.snapshot, {
      source: "supabase-mcp-sanitized-readback",
      status: "candidate",
      final: false,
      eligible_for_import: false,
      writes_quiesced: false,
      final_export_complete: false,
    });
    const candidateResult = validate(candidate);
    expect(candidateResult.errors).toContain("snapshot.source must be supabase-secure-export");
    expect(candidateResult.errors).toContain("snapshot.status must be final");
    expect(candidateResult.errors).toContain("snapshot must be eligible_for_import");

    const weakArtifact = validBundle();
    weakArtifact.snapshot.artifact.encrypted = false;
    weakArtifact.snapshot.quiescence.source_writes_stopped = false;
    weakArtifact.snapshot.local_data_sha256 = "b".repeat(64);
    const weakResult = validate(weakArtifact);
    expect(weakResult.errors).toContain("snapshot artifact must be encrypted");
    expect(weakResult.errors).toContain("snapshot quiescence must prove source writes stopped");
    expect(weakResult.errors).toContain("snapshot server/local data digests must match");
  });

  it("rejects extra source count, row-array, or disposition keys", () => {
    const bundle = validBundle();
    bundle.snapshot.public_table_counts.invented_table = 0;
    bundle.tables.invented_table = [];
    bundle.table_dispositions.invented_table = "exclude_zero";
    const result = validate(bundle);
    expect(result.errors).toContain("snapshot.public_table_counts keys must exactly match the 39-table source contract");
    expect(result.errors).toContain("tables keys must exactly match the 39-table source contract");
    expect(result.errors).toContain("table_dispositions keys must exactly match the 39-table source contract");
  });

  it("rejects missing or invented identity mappings", () => {
    const bundle = validBundle();
    bundle.clerk_mappings = [{ app_user_id: authOnlyId, clerk_user_id: "user_wrong" }];
    const result = validate(bundle);
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
    const result = validate(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("snapshot must use repeatable read");
    expect(result.errors).toContain(`competitions.${authOnlyId}: unknown owner_id`);
  });

  it("requires explicit arrays even for zero-row source tables", () => {
    const bundle = validBundle();
    delete bundle.tables.coaches;
    const result = validate(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("missing exported row array for public.coaches");
  });

  it("rejects an invented or non-approved auth-only identity", () => {
    const bundle = validBundle();
    bundle.auth_only_users = [{
      auth_user_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f2c",
      action: "migrate",
      reason: "review",
      normalized_email: "someone@example.com",
      public_profile_present: false,
      owned_row_count: 0,
      provider_identity_count: 1,
      auth_user_safe_sha256: digest,
      auth_identity_safe_sha256: digest,
    }];
    const result = validate(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("auth-only disposition references unexpected source identity 0190f8f4-5914-7b6c-9d6a-469a29f92f2c");
    expect(result.errors).toContain("auth-only disposition 0190f8f4-5914-7b6c-9d6a-469a29f92f2c must bind the approved normalized email");
  });

  it("rejects unsupported password digests, provider types, and Auth-source drift", () => {
    const bundle = validBundle();
    bundle.source_auth_users[0].encrypted_password = "not-a-bcrypt-digest";
    bundle.source_auth_identities[0].provider = "github";
    bundle.source_auth_identities[1].email = "different@example.com";
    const errors = validate(bundle).errors;
    expect(errors).toContain(`source auth user ${userId} has an unsupported password digest`);
    expect(errors).toContain("source auth identity 0190f8f4-5914-7b6c-9d6a-469a29f92f40 has an unreviewed provider");
    expect(errors).toContain("source auth identity 0190f8f4-5914-7b6c-9d6a-469a29f92f41 email must exactly match its Auth user");
    expect(errors).toContain(`auth-only disposition ${authOnlyId} identity digest does not match`);
  });

  it("rejects migrated-user identity email mismatch and Auth aggregate drift", () => {
    const bundle = validBundle();
    bundle.source_auth_identities[0].email = "other@example.com";
    bundle.snapshot.auth_password_digest_counts.bcrypt_2a = 2;
    bundle.snapshot.auth_identity_provider_counts.email = 2;
    const evidence = validEvidence(bundle);
    evidence.releasePolicy.authPasswordDigestCounts.bcrypt_2a = 2;
    evidence.releasePolicy.authIdentityProviderCounts.email = 2;
    const errors = validateCutoverBundle(bundle, evidence).errors;
    expect(errors).toContain("source auth identity 0190f8f4-5914-7b6c-9d6a-469a29f92f40 email must exactly match its Auth user");
    expect(errors).toContain("snapshot Auth password bcrypt_2a count does not match encrypted source");
    expect(errors).toContain("Auth password bcrypt_2a count is not approved by the release packet");
    expect(errors).toContain("snapshot Auth identity email count does not match encrypted source");
    expect(errors).toContain("Auth identity email count is not approved by the release packet");
  });

  it("rejects non-2a bcrypt variants and out-of-range costs", () => {
    for (const digestValue of [
      "$2b$10$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ01234",
      "$2a$03$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ01234",
      "$2a$32$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ01234",
    ]) {
      const bundle = validBundle();
      bundle.source_auth_users[0].encrypted_password = digestValue;
      expect(validate(bundle).errors).toContain(`source auth user ${userId} has an unsupported password digest`);
    }
  });

  it("rejects unsupported import dispositions and imported relation orphans", () => {
    const bundle = validBundle();
    bundle.snapshot.public_table_counts.coaches = 1;
    bundle.tables.coaches = [{ id: authOnlyId, owner_id: authOnlyId }];
    bundle.table_dispositions.coaches = "import";
    const result = validate(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("public.coaches disposition must be blocked_pending_import_contract");
    expect(result.errors).toContain("public.coaches became non-empty and has no verified import contract; cutover is blocked");

    const relationBundle = validBundle();
    relationBundle.snapshot.public_table_counts.team_members = 1;
    relationBundle.tables.team_members = [{ id: authOnlyId, team_id: authOnlyId }];
    relationBundle.table_dispositions.team_members = "import";
    const relationResult = validate(relationBundle);
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
    const otherUserId = bundle.tables.users[1].id;
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

    const result = validate(bundle);
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

    const result = validate(bundle);
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

    const result = validate(bundle);
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("workout preset import partition must exactly match user-owned rows");
    expect(result.errors).toContain("workout preset partitions must not overlap");

    bundle.workout_preset_partitions = { seed_reconcile_ids: [globalId, globalId], import_ids: [ownedId, ownedId] };
    const duplicateResult = validate(bundle);
    expect(duplicateResult.errors).toContain("workout preset seed_reconcile partition contains duplicate IDs");
    expect(duplicateResult.errors).toContain("workout preset import partition contains duplicate IDs");
  });
});
