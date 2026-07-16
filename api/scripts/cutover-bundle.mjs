import { createHash } from "node:crypto";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const clerkInstancePattern = /^ins_[A-Za-z0-9]+$/;
const sha256Pattern = /^[0-9a-f]{64}$/;
const sourceProjectRefPattern = /^[a-z]{20}$/;
export const refWatchSupabaseProjectRef = "muwuzfbtmqwvwacqnofc";
const sourceAuthUserKeys = ["id", "email", "encrypted_password", "password_hasher", "created_at", "updated_at", "email_confirmed_at", "last_sign_in_at", "banned_until", "deleted_at", "is_sso_user", "is_anonymous"];
const sourceAuthIdentityKeys = ["id", "user_id", "provider", "provider_id", "email", "created_at", "updated_at", "last_sign_in_at"];
const reviewedPasswordDigestCounts = { bcrypt_2a: 13, missing: 30 };
const reviewedIdentityProviderCounts = { apple: 22, email: 13, google: 9 };

export const sourceTables = [
  "ai_attachments", "ai_messages", "ai_threads", "ai_usage_daily", "coaches",
  "coaching_sessions", "competitions", "feedback_attachments", "feedback_items",
  "feedback_threads", "match_assessments", "match_events", "match_metrics",
  "match_officials", "match_periods", "match_reports", "matches", "pages",
  "reference_competitions", "reference_disciplinary_codes",
  "reference_disciplinary_rules", "reference_teams", "resource_shares",
  "scheduled_matches", "team_members", "team_officials", "team_tags", "teams",
  "trend_snapshots", "user_devices", "users", "venues", "wellness_check_ins",
  "workout_events", "workout_intensity_profile", "workout_presets",
  "workout_segments", "workout_session_metrics", "workout_sessions",
];

export const importOrder = [
  "users", "reference_competitions", "reference_teams",
  "reference_disciplinary_codes", "reference_disciplinary_rules", "workout_presets",
  "competitions", "venues", "teams", "scheduled_matches", "matches",
  "match_periods", "match_events", "match_metrics", "match_assessments", "pages",
  "workout_sessions",
];

const importableTables = new Set(importOrder);
const seedReconcileTables = new Set([
  "reference_competitions", "reference_teams", "reference_disciplinary_codes",
  "reference_disciplinary_rules", "workout_presets",
]);

const ownerTables = [
  "competitions", "match_assessments", "match_metrics", "matches", "pages",
  "scheduled_matches", "teams", "venues", "workout_sessions",
];

function requireCondition(condition, message, errors) {
  if (!condition) errors.push(message);
}

function requireExactKeys(value, expected, label, errors) {
  const actual = value && typeof value === "object" && !Array.isArray(value)
    ? Object.keys(value).sort()
    : [];
  const wanted = [...expected].sort();
  requireCondition(
    actual.length === wanted.length && actual.every((key, index) => key === wanted[index]),
    `${label} keys must exactly match ${expected.length === 39 ? "the 39-table source contract" : "the reviewed field contract"}`,
    errors,
  );
}

function ids(rows) {
  return new Set(rows.map((row) => String(row.id).toLowerCase()));
}

function validateReferences(tables, errors) {
  const userIds = ids(tables.users ?? []);
  const matchIds = ids(tables.matches ?? []);
  const teamIds = ids(tables.teams ?? []);
  const competitionIds = ids(tables.competitions ?? []);
  const venueIds = ids(tables.venues ?? []);
  const scheduleIds = ids(tables.scheduled_matches ?? []);
  const presetIds = ids(tables.workout_presets ?? []);
  const memberIds = ids(tables.team_members ?? []);
  const referenceCompetitionIds = ids(tables.reference_competitions ?? []);
  const referenceCompetitionSeasons = new Set((tables.reference_competitions ?? []).map((row) => `${String(row.id).toLowerCase()}:${row.season_year}`));
  const threadIds = ids(tables.ai_threads ?? []);
  const messageIds = ids(tables.ai_messages ?? []);
  const ownerByTeam = new Map((tables.teams ?? []).map((row) => [String(row.id).toLowerCase(), String(row.owner_id).toLowerCase()]));
  const ownerByCompetition = new Map((tables.competitions ?? []).map((row) => [String(row.id).toLowerCase(), String(row.owner_id).toLowerCase()]));
  const ownerByVenue = new Map((tables.venues ?? []).map((row) => [String(row.id).toLowerCase(), String(row.owner_id).toLowerCase()]));
  const ownerBySchedule = new Map((tables.scheduled_matches ?? []).map((row) => [String(row.id).toLowerCase(), String(row.owner_id).toLowerCase()]));
  const ownerByMatch = new Map((tables.matches ?? []).map((row) => [String(row.id).toLowerCase(), String(row.owner_id).toLowerCase()]));
  const teamByMember = new Map((tables.team_members ?? []).map((row) => [String(row.id).toLowerCase(), String(row.team_id).toLowerCase()]));

  for (const table of ownerTables) {
    for (const row of tables[table] ?? []) {
      requireCondition(userIds.has(String(row.owner_id).toLowerCase()), `${table}.${row.id ?? row.match_id}: unknown owner_id`, errors);
    }
  }
  for (const row of tables.workout_presets ?? []) {
    if (row.created_by) requireCondition(userIds.has(String(row.created_by).toLowerCase()), `workout_presets.${row.id}: unknown created_by`, errors);
  }
  for (const table of ["team_members", "team_officials", "team_tags"]) {
    for (const row of tables[table] ?? []) {
      requireCondition(teamIds.has(String(row.team_id).toLowerCase()), `${table}.${row.id ?? row.value}: unknown team_id`, errors);
    }
  }
  for (const row of tables.reference_teams ?? []) {
    requireCondition(referenceCompetitionIds.has(String(row.competition_id).toLowerCase()), `reference_teams.${row.id}: unknown competition_id`, errors);
    requireCondition(referenceCompetitionSeasons.has(`${String(row.competition_id).toLowerCase()}:${row.season_year}`), `reference_teams.${row.id}: competition_id/season_year mismatch`, errors);
  }
  for (const row of tables.user_devices ?? []) {
    requireCondition(userIds.has(String(row.user_id).toLowerCase()), `user_devices.${row.id}: unknown user_id`, errors);
  }
  for (const table of ["match_periods", "match_events", "match_assessments"]) {
    for (const row of tables[table] ?? []) {
      requireCondition(matchIds.has(String(row.match_id).toLowerCase()), `${table}.${row.id}: unknown match_id`, errors);
    }
  }
  for (const row of tables.match_metrics ?? []) {
    requireCondition(matchIds.has(String(row.match_id).toLowerCase()), `match_metrics.${row.match_id}: unknown match_id`, errors);
    if (ownerByMatch.has(String(row.match_id).toLowerCase())) requireCondition(ownerByMatch.get(String(row.match_id).toLowerCase()) === String(row.owner_id).toLowerCase(), `match_metrics.${row.match_id}: owner differs from match`, errors);
  }
  for (const row of tables.matches ?? []) {
    const ownerId = String(row.owner_id).toLowerCase();
    if (row.scheduled_match_id) {
      const id = String(row.scheduled_match_id).toLowerCase();
      requireCondition(scheduleIds.has(id), `matches.${row.id}: unknown scheduled_match_id`, errors);
      if (ownerBySchedule.has(id)) requireCondition(ownerBySchedule.get(id) === ownerId, `matches.${row.id}: scheduled_match owner mismatch`, errors);
    }
    for (const [field, set, owners] of [["competition_id", competitionIds, ownerByCompetition], ["venue_id", venueIds, ownerByVenue], ["home_team_id", teamIds, ownerByTeam], ["away_team_id", teamIds, ownerByTeam]]) {
      if (row[field]) {
        const id = String(row[field]).toLowerCase();
        requireCondition(set.has(id), `matches.${row.id}: unknown ${field}`, errors);
        if (owners.has(id)) requireCondition(owners.get(id) === ownerId, `matches.${row.id}: ${field} owner mismatch`, errors);
      }
    }
  }
  for (const row of tables.scheduled_matches ?? []) {
    const ownerId = String(row.owner_id).toLowerCase();
    for (const [field, set, owners] of [["competition_id", competitionIds, ownerByCompetition], ["venue_id", venueIds, ownerByVenue], ["home_team_id", teamIds, ownerByTeam], ["away_team_id", teamIds, ownerByTeam]]) {
      if (row[field]) {
        const id = String(row[field]).toLowerCase();
        requireCondition(set.has(id), `scheduled_matches.${row.id}: unknown ${field}`, errors);
        if (owners.has(id)) requireCondition(owners.get(id) === ownerId, `scheduled_matches.${row.id}: ${field} owner mismatch`, errors);
      }
    }
  }
  for (const row of tables.match_assessments ?? []) {
    const id = String(row.match_id).toLowerCase();
    if (ownerByMatch.has(id)) requireCondition(ownerByMatch.get(id) === String(row.owner_id).toLowerCase(), `match_assessments.${row.id}: owner differs from match`, errors);
  }
  for (const row of tables.match_events ?? []) {
    const match = (tables.matches ?? []).find((candidate) => String(candidate.id).toLowerCase() === String(row.match_id).toLowerCase());
    const participating = new Set([match?.home_team_id, match?.away_team_id].filter(Boolean).map((id) => String(id).toLowerCase()));
    if (row.team_id) {
      const teamId = String(row.team_id).toLowerCase();
      requireCondition(teamIds.has(teamId), `match_events.${row.id}: unknown team_id`, errors);
      requireCondition(participating.has(teamId), `match_events.${row.id}: team_id is not a participating team`, errors);
    }
    if (row.team_member_id) {
      const memberId = String(row.team_member_id).toLowerCase();
      requireCondition(memberIds.has(memberId), `match_events.${row.id}: unknown team_member_id`, errors);
      const memberTeam = teamByMember.get(memberId);
      if (memberTeam) {
        requireCondition(participating.has(memberTeam), `match_events.${row.id}: team member is not on a participating team`, errors);
        if (row.team_id) requireCondition(memberTeam === String(row.team_id).toLowerCase(), `match_events.${row.id}: team/member mismatch`, errors);
      }
    }
  }
  for (const row of tables.pages ?? []) {
    if (row.match_id) {
      const matchId = String(row.match_id).toLowerCase();
      requireCondition(matchIds.has(matchId), `pages.${row.id}: unknown match_id`, errors);
      if (ownerByMatch.has(matchId)) requireCondition(ownerByMatch.get(matchId) === String(row.owner_id).toLowerCase(), `pages.${row.id}: owner differs from match`, errors);
    }
  }
  for (const row of tables.workout_sessions ?? []) {
    if (row.preset_id) requireCondition(presetIds.has(String(row.preset_id).toLowerCase()), `workout_sessions.${row.id}: unknown preset_id`, errors);
  }
  for (const row of tables.ai_threads ?? []) {
    requireCondition(userIds.has(String(row.owner_id).toLowerCase()), `ai_threads.${row.id}: unknown owner_id`, errors);
  }
  for (const row of tables.ai_messages ?? []) {
    requireCondition(threadIds.has(String(row.thread_id).toLowerCase()), `ai_messages.${row.id}: unknown thread_id`, errors);
  }
  for (const row of tables.ai_attachments ?? []) {
    requireCondition(messageIds.has(String(row.message_id).toLowerCase()), `ai_attachments.${row.id}: unknown message_id`, errors);
  }
  for (const row of tables.ai_usage_daily ?? []) {
    requireCondition(userIds.has(String(row.owner_id).toLowerCase()), `ai_usage_daily.${row.owner_id}: unknown owner_id`, errors);
  }
}

export function validateCutoverBundle(bundle, verifiedEvidence = null) {
  const errors = [];
  const snapshot = bundle?.snapshot ?? {};
  const tables = bundle?.tables ?? {};
  const counts = snapshot.public_table_counts ?? {};
  const mappings = bundle?.clerk_mappings ?? [];
  const dispositions = bundle?.table_dispositions ?? {};
  const authOnly = bundle?.auth_only_users ?? [];
  const productionClerkInstanceId = bundle?.production_clerk_instance_id;
  const sourceAuthUsers = bundle?.source_auth_users ?? [];
  const sourceAuthIdentities = bundle?.source_auth_identities ?? [];
  const artifact = snapshot.artifact ?? {};
  const quiescence = snapshot.quiescence ?? {};
  const verifiedArtifact = verifiedEvidence?.artifact ?? {};
  const verifiedProviderReceipt = verifiedEvidence?.providerReceipt ?? {};
  const verifiedLedgerReceipt = verifiedEvidence?.ledgerReceipt ?? {};
  const verifiedCreatorReceipt = verifiedEvidence?.creatorReceipt ?? {};
  const releasePolicy = verifiedEvidence?.releasePolicy ?? {};

  requireCondition(snapshot.source === "supabase-secure-export", "snapshot.source must be supabase-secure-export", errors);
  requireCondition(snapshot.status === "final", "snapshot.status must be final", errors);
  requireCondition(snapshot.final === true, "snapshot.final must be true", errors);
  requireCondition(snapshot.eligible_for_import === true, "snapshot must be eligible_for_import", errors);
  requireCondition(snapshot.writes_quiesced === true, "snapshot must prove writes_quiesced", errors);
  requireCondition(snapshot.final_export_complete === true, "snapshot must prove final_export_complete", errors);
  requireCondition(snapshot.transaction_isolation === "repeatable read", "snapshot must use repeatable read", errors);
  requireCondition(snapshot.read_only === true, "snapshot must be read only", errors);
  requireCondition(typeof snapshot.captured_at_utc === "string" && !Number.isNaN(Date.parse(snapshot.captured_at_utc)), "snapshot.captured_at_utc must be an ISO timestamp", errors);
  requireCondition(typeof snapshot.completed_at_utc === "string" && !Number.isNaN(Date.parse(snapshot.completed_at_utc)), "snapshot.completed_at_utc must be an ISO timestamp", errors);
  if (!Number.isNaN(Date.parse(snapshot.captured_at_utc)) && !Number.isNaN(Date.parse(snapshot.completed_at_utc))) {
    requireCondition(Date.parse(snapshot.completed_at_utc) >= Date.parse(snapshot.captured_at_utc), "snapshot completion must not precede capture", errors);
  }
  requireCondition(sourceProjectRefPattern.test(snapshot.source_project_ref ?? "") && snapshot.source_project_ref === refWatchSupabaseProjectRef, "snapshot.source_project_ref must be the reviewed RefWatch Supabase project", errors);
  for (const field of ["query_sha256", "generator_sha256", "schema_contract_sha256", "rls_contract_sha256", "server_data_sha256", "local_data_sha256"]) {
    requireCondition(sha256Pattern.test(snapshot[field] ?? ""), `snapshot.${field} must be SHA-256`, errors);
  }
  const recomputedDataSha256 = computeCutoverDataSha256(tables);
  requireCondition(snapshot.local_data_sha256 === recomputedDataSha256, "snapshot local data digest does not match exported rows", errors);
  requireCondition(snapshot.server_data_sha256 === snapshot.local_data_sha256, "snapshot server/local data digests must match", errors);
  requireCondition(uuidPattern.test(snapshot.export_id ?? ""), "snapshot.export_id is invalid", errors);
  requireCondition(verifiedEvidence?.verified === true, "encrypted artifact and quiescence evidence must be independently verified", errors);
  requireCondition(snapshot.query_sha256 === releasePolicy.querySha256, "snapshot query digest is not approved by the release packet", errors);
  requireCondition(snapshot.generator_sha256 === releasePolicy.generatorSha256, "snapshot generator digest is not approved by the release packet", errors);
  requireCondition(artifact.encrypted === true, "snapshot artifact must be encrypted", errors);
  requireCondition(typeof artifact.retention_owner === "string" && artifact.retention_owner.trim().length > 0, "snapshot retention owner is required", errors);
  requireCondition(typeof artifact.retention_event === "string" && artifact.retention_event.trim().length > 0, "snapshot retention event is required", errors);
  requireCondition(artifact.deletion_verification_required === true, "snapshot deletion verification must be required", errors);
  requireCondition(verifiedCreatorReceipt.sha256 === releasePolicy.creatorReceiptSha256, "artifact creator receipt digest is not approved by the release packet", errors);
  requireCondition(typeof verifiedArtifact.cipher === "string" && verifiedArtifact.cipher.length > 0, "verified artifact cipher is required", errors);
  requireCondition(sha256Pattern.test(verifiedArtifact.sha256 ?? ""), "verified artifact SHA-256 is required", errors);
  requireCondition(Number.isInteger(verifiedArtifact.byteSize) && verifiedArtifact.byteSize > 0, "verified artifact byte size is invalid", errors);
  requireCondition(verifiedArtifact.mode === "0600", "verified artifact mode must be 0600", errors);
  requireCondition(verifiedArtifact.directoryMode === "0700", "verified artifact directory mode must be 0700", errors);
  requireCondition(verifiedArtifact.noSymlink === true, "encrypted artifact path must be verified without symlinks", errors);
  requireCondition(verifiedArtifact.ownerVerified === true, "encrypted artifact ownership must be verified", errors);
  requireCondition(verifiedCreatorReceipt.data?.receipt_type === "encrypted-artifact-creation", "artifact creator receipt type is invalid", errors);
  requireCondition(verifiedCreatorReceipt.data?.export_id === snapshot.export_id, "artifact creator receipt export ID does not match snapshot", errors);
  requireCondition(verifiedCreatorReceipt.data?.source_project_ref === refWatchSupabaseProjectRef, "artifact creator receipt source project is invalid", errors);
  requireCondition(verifiedCreatorReceipt.data?.query_sha256 === releasePolicy.querySha256 && verifiedCreatorReceipt.data?.generator_sha256 === releasePolicy.generatorSha256, "artifact creator receipt is not bound to the reviewed exporter", errors);
  requireCondition(verifiedCreatorReceipt.data?.cipher === verifiedArtifact.cipher, "artifact creator receipt cipher does not match ciphertext", errors);
  requireCondition(verifiedCreatorReceipt.data?.artifact_sha256 === verifiedArtifact.sha256 && verifiedCreatorReceipt.data?.byte_size === verifiedArtifact.byteSize, "artifact creator receipt does not match ciphertext digest/size", errors);
  requireCondition(verifiedCreatorReceipt.data?.manifest_sha256 === verifiedEvidence?.manifestSha256, "artifact creator receipt does not match detached manifest", errors);
  requireCondition(verifiedCreatorReceipt.data?.exclusive_create === true && verifiedCreatorReceipt.data?.fsync_file === true && verifiedCreatorReceipt.data?.fsync_directory === true && verifiedCreatorReceipt.data?.atomic_rename === true, "artifact creator receipt must prove exclusive create, fsync, and atomic rename", errors);
  requireCondition(quiescence.write_mode_disabled === true, "snapshot quiescence must prove write mode disabled", errors);
  requireCondition(quiescence.source_writes_stopped === true, "snapshot quiescence must prove source writes stopped", errors);
  requireCondition(sha256Pattern.test(quiescence.provider_receipt_sha256 ?? ""), "snapshot quiescence provider receipt is required", errors);
  requireCondition(sha256Pattern.test(quiescence.ledger_receipt_sha256 ?? ""), "snapshot quiescence ledger receipt is required", errors);
  requireCondition(Number.isInteger(quiescence.ledger_watermark) && quiescence.ledger_watermark >= 0, "snapshot quiescence ledger watermark is invalid", errors);
  requireCondition(uuidPattern.test(quiescence.write_guard_version_id ?? ""), "snapshot quiescence write guard version is invalid", errors);
  requireCondition(!Number.isNaN(Date.parse(quiescence.required_through_utc ?? "")) && Date.parse(quiescence.required_through_utc) >= Date.parse(snapshot.completed_at_utc), "snapshot quiescence required-through time must cover export completion", errors);
  requireCondition(quiescence.provider_receipt_sha256 === verifiedProviderReceipt.sha256, "provider receipt digest does not match verified file", errors);
  requireCondition(quiescence.ledger_receipt_sha256 === verifiedLedgerReceipt.sha256, "ledger receipt digest does not match verified file", errors);
  for (const receipt of [verifiedProviderReceipt.data, verifiedLedgerReceipt.data]) {
    requireCondition(receipt?.source_project_ref === snapshot.source_project_ref, "quiescence receipt source project does not match snapshot", errors);
    requireCondition(receipt?.export_id === snapshot.export_id, "quiescence receipt export ID does not match snapshot", errors);
    requireCondition(receipt?.query_sha256 === snapshot.query_sha256, "quiescence receipt query digest does not match snapshot", errors);
    requireCondition(receipt?.generator_sha256 === snapshot.generator_sha256, "quiescence receipt generator digest does not match snapshot", errors);
    requireCondition(receipt?.write_guard_version_id === quiescence.write_guard_version_id, "quiescence receipt write guard does not match snapshot", errors);
    requireCondition(receipt?.write_mode_disabled === true && receipt?.source_writes_stopped === true, "quiescence receipt must prove both write gates", errors);
    requireCondition(Number.isInteger(receipt?.ledger_watermark) && receipt.ledger_watermark === quiescence.ledger_watermark, "quiescence receipt ledger watermark does not match snapshot", errors);
    requireCondition(Date.parse(receipt?.quiescence_started_at_utc ?? "") <= Date.parse(snapshot.captured_at_utc), "quiescence must begin before snapshot capture", errors);
    requireCondition(Date.parse(receipt?.quiescence_observed_through_utc ?? "") >= Date.parse(quiescence.required_through_utc), "quiescence receipt does not cover the required interval", errors);
  }
  requireCondition(clerkInstancePattern.test(productionClerkInstanceId ?? ""), "production_clerk_instance_id must identify the reviewed production Clerk instance", errors);
  requireCondition(Array.isArray(sourceAuthUsers), "source_auth_users must be an encrypted array", errors);
  requireCondition(Array.isArray(sourceAuthIdentities), "source_auth_identities must be an encrypted array", errors);

  requireExactKeys(counts, sourceTables, "snapshot.public_table_counts", errors);
  requireExactKeys(tables, sourceTables, "tables", errors);
  requireExactKeys(dispositions, sourceTables, "table_dispositions", errors);

  for (const table of sourceTables) {
    requireCondition(Number.isInteger(counts[table]) && counts[table] >= 0, `missing count for public.${table}`, errors);
    requireCondition(Object.hasOwn(tables, table), `missing exported row array for public.${table}`, errors);
    const rows = tables[table];
    requireCondition(Array.isArray(rows), `tables.${table} must be an array`, errors);
    if (Number.isInteger(counts[table]) && Array.isArray(rows)) requireCondition(rows.length === counts[table], `public.${table} count mismatch: snapshot=${counts[table]} export=${rows.length}`, errors);
    const presetRows = table === "workout_presets" && Array.isArray(tables.workout_presets) ? tables.workout_presets : [];
    const hasUserOwnedPresets = presetRows.some((row) => row.created_by != null);
    const hasGlobalPresets = presetRows.some((row) => row.created_by == null);
    const expectedDisposition = counts[table] === 0
      ? "exclude_zero"
      : table === "workout_presets" && hasUserOwnedPresets && hasGlobalPresets ? "mixed_seed_import"
        : seedReconcileTables.has(table) && !hasUserOwnedPresets ? "seed_reconcile"
          : importableTables.has(table) ? "import" : "blocked_pending_import_contract";
    requireCondition(dispositions[table] === expectedDisposition, `public.${table} disposition must be ${expectedDisposition}`, errors);
    if (expectedDisposition === "blocked_pending_import_contract") errors.push(`public.${table} became non-empty and has no verified import contract; cutover is blocked`);
    if (expectedDisposition === "mixed_seed_import") {
      const partitions = bundle?.workout_preset_partitions ?? {};
      const expectedSeedIds = new Set(presetRows.filter((row) => row.created_by == null).map((row) => String(row.id).toLowerCase()));
      const expectedImportIds = new Set(presetRows.filter((row) => row.created_by != null).map((row) => String(row.id).toLowerCase()));
      const seedIdList = Array.isArray(partitions.seed_reconcile_ids) ? partitions.seed_reconcile_ids.map((id) => String(id).toLowerCase()) : [];
      const importIdList = Array.isArray(partitions.import_ids) ? partitions.import_ids.map((id) => String(id).toLowerCase()) : [];
      const seedIds = new Set(seedIdList);
      const importIds = new Set(importIdList);
      requireCondition(seedIds.size === seedIdList.length, "workout preset seed_reconcile partition contains duplicate IDs", errors);
      requireCondition(importIds.size === importIdList.length, "workout preset import partition contains duplicate IDs", errors);
      requireCondition(seedIds.size === expectedSeedIds.size && [...expectedSeedIds].every((id) => seedIds.has(id)), "workout preset seed_reconcile partition must exactly match global rows", errors);
      requireCondition(importIds.size === expectedImportIds.size && [...expectedImportIds].every((id) => importIds.has(id)), "workout preset import partition must exactly match user-owned rows", errors);
      requireCondition([...seedIds].every((id) => !importIds.has(id)), "workout preset partitions must not overlap", errors);
    }
    if (table === "workout_presets" && expectedDisposition !== "mixed_seed_import") requireCondition(bundle?.workout_preset_partitions == null, "workout_preset_partitions is only valid for mixed_seed_import", errors);
  }

  const userRows = tables.users ?? [];
  const userIds = ids(userRows);
  const mappedAppIds = new Set();
  const clerkSubjects = new Set();
  for (const mapping of mappings) {
    const appId = String(mapping.app_user_id ?? "").toLowerCase();
    const subject = mapping.clerk_user_id;
    requireCondition(uuidPattern.test(appId), "each clerk mapping needs a valid app_user_id UUID", errors);
    requireCondition(typeof subject === "string" && subject.length > 0, `mapping ${appId || "<missing>"} needs an opaque Clerk subject`, errors);
    requireCondition(!mappedAppIds.has(appId), `duplicate app_user_id mapping: ${appId}`, errors);
    requireCondition(!clerkSubjects.has(subject), `duplicate Clerk subject mapping: ${subject}`, errors);
    mappedAppIds.add(appId);
    clerkSubjects.add(subject);
  }
  requireCondition(mappedAppIds.size === userIds.size, `Clerk mapping cardinality mismatch: users=${userIds.size} mappings=${mappedAppIds.size}`, errors);
  for (const userId of userIds) requireCondition(mappedAppIds.has(userId), `missing Clerk mapping for app user ${userId}`, errors);
  for (const mappedId of mappedAppIds) requireCondition(userIds.has(mappedId), `Clerk mapping references unknown app user ${mappedId}`, errors);

  const authIdsFromSource = snapshot.auth_user_ids;
  requireCondition(Array.isArray(authIdsFromSource), "snapshot.auth_user_ids must be an array", errors);
  const authIdSet = new Set();
  for (const id of Array.isArray(authIdsFromSource) ? authIdsFromSource : []) {
    requireCondition(uuidPattern.test(id), `invalid source auth user UUID: ${id}`, errors);
    requireCondition(!authIdSet.has(String(id).toLowerCase()), `duplicate source auth user UUID: ${id}`, errors);
    authIdSet.add(String(id).toLowerCase());
  }
  const authCount = snapshot.auth_user_count;
  requireCondition(Number.isInteger(authCount) && authCount === authIdSet.size && authCount >= userRows.length, "snapshot.auth_user_count/auth_user_ids is invalid", errors);
  requireCondition(sourceAuthUsers.length === authCount, "source_auth_users must exactly match snapshot.auth_user_count", errors);
  requireCondition(Number.isInteger(snapshot.auth_identity_count) && sourceAuthIdentities.length === snapshot.auth_identity_count, "source_auth_identities must exactly match snapshot.auth_identity_count", errors);
  const sourceAuthUserById = new Map();
  const actualPasswordDigestCounts = { bcrypt_2a: 0, missing: 0 };
  for (const authUser of sourceAuthUsers) {
    requireExactKeys(authUser, sourceAuthUserKeys, `source_auth_users.${authUser?.id ?? "<missing>"}`, errors);
    const authUserId = String(authUser?.id ?? "").toLowerCase();
    requireCondition(uuidPattern.test(authUserId) && authIdSet.has(authUserId), `source auth user ${authUserId || "<missing>"} is not in the final Auth ID set`, errors);
    requireCondition(!sourceAuthUserById.has(authUserId), `duplicate source auth user ${authUserId}`, errors);
    requireCondition(typeof authUser.email === "string" && authUser.email === authUser.email.trim().toLowerCase() && authUser.email.includes("@"), `source auth user ${authUserId} needs a normalized email`, errors);
    if (authUser.encrypted_password == null || authUser.encrypted_password === "") {
      requireCondition(authUser.password_hasher == null, `source auth user ${authUserId} without a digest must not declare a password hasher`, errors);
      actualPasswordDigestCounts.missing += 1;
    } else {
      requireCondition(/^\$2a\$(?:0[4-9]|[12]\d|3[01])\$[./A-Za-z0-9]{53}$/.test(authUser.encrypted_password), `source auth user ${authUserId} has an unsupported password digest`, errors);
      requireCondition(authUser.password_hasher === "bcrypt", `source auth user ${authUserId} password hasher must be bcrypt`, errors);
      actualPasswordDigestCounts.bcrypt_2a += 1;
    }
    sourceAuthUserById.set(authUserId, authUser);
  }
  for (const authId of authIdSet) requireCondition(sourceAuthUserById.has(authId), `missing encrypted source auth user ${authId}`, errors);
  const sourceIdentitiesByUser = new Map();
  const sourceIdentityIds = new Set();
  const actualIdentityProviderCounts = { apple: 0, email: 0, google: 0 };
  for (const identity of sourceAuthIdentities) {
    requireExactKeys(identity, sourceAuthIdentityKeys, `source_auth_identities.${identity?.id ?? "<missing>"}`, errors);
    const identityId = String(identity?.id ?? "").toLowerCase();
    const sourceUserId = String(identity?.user_id ?? "").toLowerCase();
    requireCondition(uuidPattern.test(identityId) && !sourceIdentityIds.has(identityId), `source auth identity ${identityId || "<missing>"} is invalid or duplicated`, errors);
    requireCondition(sourceAuthUserById.has(sourceUserId), `source auth identity ${identityId} references an unknown Auth user`, errors);
    requireCondition(["apple", "email", "google"].includes(identity?.provider), `source auth identity ${identityId} has an unreviewed provider`, errors);
    requireCondition(typeof identity?.provider_id === "string" && identity.provider_id.length > 0, `source auth identity ${identityId} needs provider_id`, errors);
    const parentEmail = sourceAuthUserById.get(sourceUserId)?.email;
    requireCondition(typeof identity?.email === "string" && identity.email === parentEmail, `source auth identity ${identityId} email must exactly match its Auth user`, errors);
    if (Object.hasOwn(actualIdentityProviderCounts, identity?.provider)) actualIdentityProviderCounts[identity.provider] += 1;
    sourceIdentityIds.add(identityId);
    const identities = sourceIdentitiesByUser.get(sourceUserId) ?? [];
    identities.push(identity);
    sourceIdentitiesByUser.set(sourceUserId, identities);
  }
  for (const key of Object.keys(reviewedPasswordDigestCounts)) {
    requireCondition(snapshot.auth_password_digest_counts?.[key] === actualPasswordDigestCounts[key], `snapshot Auth password ${key} count does not match encrypted source`, errors);
    requireCondition(releasePolicy.authPasswordDigestCounts?.[key] === actualPasswordDigestCounts[key], `Auth password ${key} count is not approved by the release packet`, errors);
    requireCondition(actualPasswordDigestCounts[key] === reviewedPasswordDigestCounts[key], `Auth password ${key} count drifted from the reviewed production contract`, errors);
  }
  for (const key of Object.keys(reviewedIdentityProviderCounts)) {
    requireCondition(snapshot.auth_identity_provider_counts?.[key] === actualIdentityProviderCounts[key], `snapshot Auth identity ${key} count does not match encrypted source`, errors);
    requireCondition(releasePolicy.authIdentityProviderCounts?.[key] === actualIdentityProviderCounts[key], `Auth identity ${key} count is not approved by the release packet`, errors);
    requireCondition(actualIdentityProviderCounts[key] === reviewedIdentityProviderCounts[key], `Auth identity ${key} count drifted from the reviewed production contract`, errors);
  }
  for (const authId of authIdSet) requireCondition((sourceIdentitiesByUser.get(authId)?.length ?? 0) > 0, `source auth user ${authId} has no provider identity`, errors);
  for (const userId of userIds) requireCondition(authIdSet.has(userId), `public user ${userId} is absent from source auth IDs`, errors);
  const expectedAuthOnlyIds = new Set([...authIdSet].filter((id) => !userIds.has(id)));
  requireCondition(expectedAuthOnlyIds.size === 1, "final source must contain exactly the one reviewed auth-only identity", errors);
  requireCondition(authOnly.length === expectedAuthOnlyIds.size, `auth-only cardinality mismatch: expected=${expectedAuthOnlyIds.size} actual=${authOnly.length}`, errors);
  const authIds = new Set();
  for (const entry of authOnly) {
    requireCondition(uuidPattern.test(entry.auth_user_id ?? ""), "each auth-only disposition needs auth_user_id", errors);
    requireCondition(entry.action === "exclude", `auth-only action for ${entry.auth_user_id ?? "<missing>"} must be exclude`, errors);
    requireCondition(entry.normalized_email === "testing@refwatch.com", `auth-only disposition ${entry.auth_user_id ?? "<missing>"} must bind the approved normalized email`, errors);
    requireCondition(entry.public_profile_present === false, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} must prove no public profile`, errors);
    requireCondition(entry.owned_row_count === 0, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} must prove zero owned/referenced rows`, errors);
    requireCondition(Number.isInteger(entry.provider_identity_count) && entry.provider_identity_count > 0, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} must prove provider identity linkage`, errors);
    requireCondition(sha256Pattern.test(entry.auth_user_safe_sha256 ?? ""), `auth-only disposition ${entry.auth_user_id ?? "<missing>"} needs a safe Auth-user digest`, errors);
    requireCondition(sha256Pattern.test(entry.auth_identity_safe_sha256 ?? ""), `auth-only disposition ${entry.auth_user_id ?? "<missing>"} needs a safe Auth-identity digest`, errors);
    requireCondition(typeof entry.reason === "string" && entry.reason.trim().length > 0, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} needs a reason`, errors);
    const normalizedAuthId = String(entry.auth_user_id).toLowerCase();
    const encryptedAuthUser = sourceAuthUserById.get(normalizedAuthId);
    const encryptedIdentities = sourceIdentitiesByUser.get(normalizedAuthId) ?? [];
    requireCondition(entry.normalized_email === encryptedAuthUser?.email, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} email does not match the encrypted Auth source`, errors);
    requireCondition(entry.provider_identity_count === encryptedIdentities.length, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} identity count does not match the encrypted Auth source`, errors);
    const safeDigests = computeSourceAuthSafeDigests(encryptedAuthUser, encryptedIdentities);
    requireCondition(entry.auth_user_safe_sha256 === safeDigests.authUserSha256, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} Auth-user digest does not match`, errors);
    requireCondition(entry.auth_identity_safe_sha256 === safeDigests.authIdentitiesSha256, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} identity digest does not match`, errors);
    requireCondition(!authIds.has(normalizedAuthId), `duplicate auth-only disposition ${entry.auth_user_id}`, errors);
    requireCondition(expectedAuthOnlyIds.has(normalizedAuthId), `auth-only disposition references unexpected source identity ${entry.auth_user_id}`, errors);
    authIds.add(normalizedAuthId);
  }
  for (const expectedId of expectedAuthOnlyIds) requireCondition(authIds.has(expectedId), `missing auth-only disposition for source identity ${expectedId}`, errors);

  validateReferences(tables, errors);

  const normalizedMappings = mappings.map((mapping) => ({
    app_user_id: String(mapping.app_user_id ?? "").toLowerCase(),
    clerk_user_id: String(mapping.clerk_user_id ?? ""),
  })).sort((a, b) => a.app_user_id.localeCompare(b.app_user_id));
  const excludedAuthIds = authOnly.filter((entry) => entry.action === "exclude")
    .map((entry) => String(entry.auth_user_id ?? "").toLowerCase()).sort();
  const mappingHash = sha256(JSON.stringify(normalizedMappings));
  const identityReceiptDigest = sha256(JSON.stringify({
    version: 1,
    source: snapshot.source ?? null,
    captured_at_utc: snapshot.captured_at_utc ?? null,
    auth_user_ids: [...authIdSet].sort(),
    clerk_instance_id: productionClerkInstanceId ?? null,
    mapping_hash: mappingHash,
    legacy_mapping_count: mappings.length,
    excluded_auth_ids: excludedAuthIds,
  }));

  return {
    ok: errors.length === 0,
    errors,
    summary: {
      capturedAtUTC: snapshot.captured_at_utc ?? null,
      publicTables: sourceTables.length,
      exportedRows: sourceTables.reduce((sum, table) => sum + (tables[table]?.length ?? 0), 0),
      publicUsers: userRows.length,
      clerkMappings: mappings.length,
      authOnlyUsers: authOnly.length,
      identityReconciliation: {
        clerkInstanceId: productionClerkInstanceId ?? null,
        receiptDigest: identityReceiptDigest,
        mappingHash,
        legacyMappingCount: mappings.length,
        excludedAuthCount: excludedAuthIds.length,
      },
      importOrder,
    },
  };
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

export function computeCutoverDataSha256(tables) {
  const tableDigests = sourceTables.map((table) => {
    const rows = Array.isArray(tables?.[table]) ? tables[table].map(canonicalJson).sort() : [];
    const framed = rows.map((row) => `${Buffer.byteLength(row, "utf8")}:${row}`).join("");
    return [table, sha256(framed)];
  });
  return sha256(canonicalJson(Object.fromEntries(tableDigests)));
}

export function computeSourceAuthSafeDigests(authUser, identities) {
  const safeAuthUser = authUser
    ? Object.fromEntries(Object.entries(authUser).filter(([key]) => key !== "encrypted_password" && key !== "password_hasher"))
    : null;
  const sortedIdentities = Array.isArray(identities)
    ? [...identities].sort((left, right) => String(left?.id ?? "").localeCompare(String(right?.id ?? "")))
    : [];
  return {
    authUserSha256: sha256(canonicalJson(safeAuthUser)),
    authIdentitiesSha256: sha256(canonicalJson(sortedIdentities)),
  };
}
