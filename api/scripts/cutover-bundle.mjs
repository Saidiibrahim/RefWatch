const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

export function validateCutoverBundle(bundle) {
  const errors = [];
  const snapshot = bundle?.snapshot ?? {};
  const tables = bundle?.tables ?? {};
  const counts = snapshot.public_table_counts ?? {};
  const mappings = bundle?.clerk_mappings ?? [];
  const dispositions = bundle?.table_dispositions ?? {};
  const authOnly = bundle?.auth_only_users ?? [];

  requireCondition(snapshot.source === "supabase-mcp", "snapshot.source must be supabase-mcp", errors);
  requireCondition(snapshot.transaction_isolation === "repeatable read", "snapshot must use repeatable read", errors);
  requireCondition(snapshot.read_only === true, "snapshot must be read only", errors);
  requireCondition(typeof snapshot.captured_at_utc === "string" && !Number.isNaN(Date.parse(snapshot.captured_at_utc)), "snapshot.captured_at_utc must be an ISO timestamp", errors);

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
  for (const userId of userIds) requireCondition(authIdSet.has(userId), `public user ${userId} is absent from source auth IDs`, errors);
  const expectedAuthOnlyIds = new Set([...authIdSet].filter((id) => !userIds.has(id)));
  requireCondition(authOnly.length === expectedAuthOnlyIds.size, `auth-only cardinality mismatch: expected=${expectedAuthOnlyIds.size} actual=${authOnly.length}`, errors);
  const authIds = new Set();
  const migratedAppIds = new Set(mappedAppIds);
  const migratedClerkSubjects = new Set(clerkSubjects);
  for (const entry of authOnly) {
    requireCondition(uuidPattern.test(entry.auth_user_id ?? ""), "each auth-only disposition needs auth_user_id", errors);
    requireCondition(["archive", "exclude", "migrate"].includes(entry.action), `invalid auth-only action for ${entry.auth_user_id ?? "<missing>"}`, errors);
    requireCondition(typeof entry.reason === "string" && entry.reason.trim().length > 0, `auth-only disposition ${entry.auth_user_id ?? "<missing>"} needs a reason`, errors);
    const normalizedAuthId = String(entry.auth_user_id).toLowerCase();
    requireCondition(!authIds.has(normalizedAuthId), `duplicate auth-only disposition ${entry.auth_user_id}`, errors);
    requireCondition(expectedAuthOnlyIds.has(normalizedAuthId), `auth-only disposition references unexpected source identity ${entry.auth_user_id}`, errors);
    authIds.add(normalizedAuthId);
    if (entry.action === "migrate") {
      requireCondition(uuidPattern.test(entry.app_user_id ?? ""), `migrated auth-only ${entry.auth_user_id} needs reviewed app_user_id`, errors);
      requireCondition(typeof entry.clerk_user_id === "string" && entry.clerk_user_id.length > 0, `migrated auth-only ${entry.auth_user_id} needs Clerk subject`, errors);
      requireCondition(["new_empty_app_user", "merge_into_existing_app_user"].includes(entry.migration_contract), `migrated auth-only ${entry.auth_user_id} needs an explicit migration_contract`, errors);
      const appId = String(entry.app_user_id ?? "").toLowerCase();
      if (entry.migration_contract === "new_empty_app_user") {
        requireCondition(!migratedAppIds.has(appId), `migrated auth-only app_user_id collision: ${appId}`, errors);
        requireCondition(!migratedClerkSubjects.has(entry.clerk_user_id), `migrated auth-only Clerk subject collision: ${entry.clerk_user_id}`, errors);
        requireCondition(entry.new_app_user?.id?.toLowerCase() === appId, `migrated auth-only ${entry.auth_user_id} needs matching new_app_user payload`, errors);
        migratedAppIds.add(appId);
        migratedClerkSubjects.add(entry.clerk_user_id);
      } else if (entry.migration_contract === "merge_into_existing_app_user") {
        const reviewed = mappings.find((mapping) => String(mapping.app_user_id).toLowerCase() === appId);
        requireCondition(Boolean(reviewed), `merged auth-only ${entry.auth_user_id} references unknown existing app user`, errors);
        requireCondition(reviewed?.clerk_user_id === entry.clerk_user_id, `merged auth-only ${entry.auth_user_id} must use the existing reviewed Clerk subject`, errors);
        requireCondition(typeof entry.reviewed_merge_reason === "string" && entry.reviewed_merge_reason.trim().length > 0, `merged auth-only ${entry.auth_user_id} needs reviewed_merge_reason`, errors);
      }
    }
  }
  for (const expectedId of expectedAuthOnlyIds) requireCondition(authIds.has(expectedId), `missing auth-only disposition for source identity ${expectedId}`, errors);

  validateReferences(tables, errors);

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
      importOrder,
    },
  };
}
