import {
  bigint,
  bigserial,
  boolean,
  check,
  date,
  doublePrecision,
  foreignKey,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
};

export const assessmentMood = pgEnum("assessment_mood", ["calm", "focused", "stressed", "fatigued"]);
export const pageType = pgEnum("page_type", ["match_report", "training_plan", "fitness_assessment", "general_note"]);
export const pageStatus = pgEnum("page_status", ["draft", "submitted"]);
export const workoutState = pgEnum("workout_state", ["planned", "active", "paused", "ended", "aborted"]);
export const workoutKind = pgEnum("workout_kind", ["outdoorRun", "outdoorWalk", "indoorRun", "indoorCycle", "strength", "mobility", "refereeDrill", "custom"]);
export const sessionContext = pgEnum("session_context", ["match_prep", "recovery", "maintenance", "test_prep"]);

export const appUsers = pgTable("app_users", {
  id: uuid("id").primaryKey().defaultRandom(),
  clerkUserId: text("clerk_user_id").notNull(),
  email: text("email"),
  displayName: text("display_name"),
  avatarUrl: text("avatar_url"),
  emailVerified: boolean("email_verified"),
  lastSignInAt: timestamp("last_sign_in_at", { withTimezone: true }),
  rawAppMetadata: jsonb("raw_app_metadata"),
  rawUserMetadata: jsonb("raw_user_metadata"),
  isSSOUser: boolean("is_sso_user").notNull().default(false),
  isAnonymous: boolean("is_anonymous").notNull().default(false),
  primaryProvider: text("primary_provider"),
  providerList: text("provider_list").array().notNull().default(sql`'{}'::text[]`),
  emailConfirmedAt: timestamp("email_confirmed_at", { withTimezone: true }),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
  ...timestamps,
}, (table) => [uniqueIndex("app_users_clerk_user_id_uq").on(table.clerkUserId)]);

export const identityReconciliationReceipts = pgTable("identity_reconciliation_receipts", {
  id: uuid("id").primaryKey().defaultRandom(),
  receiptDigest: text("receipt_digest").notNull(),
  clerkInstanceId: text("clerk_instance_id").notNull(),
  snapshotCapturedAt: timestamp("snapshot_captured_at", { withTimezone: true }).notNull(),
  legacyMappingCount: integer("legacy_mapping_count").notNull(),
  excludedAuthCount: integer("excluded_auth_count").notNull(),
  mappingHash: text("mapping_hash").notNull(),
  status: text("status").notNull(),
  reviewedAt: timestamp("reviewed_at", { withTimezone: true }).notNull(),
  activatedAt: timestamp("activated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  uniqueIndex("identity_reconciliation_receipts_digest_uq").on(table.receiptDigest),
  index("identity_reconciliation_receipts_instance_idx").on(table.clerkInstanceId),
  check("identity_reconciliation_receipts_digest_check", sql`${table.receiptDigest} ~ '^[0-9a-f]{64}$'`),
  check("identity_reconciliation_receipts_mapping_hash_check", sql`${table.mappingHash} ~ '^[0-9a-f]{64}$'`),
  check("identity_reconciliation_receipts_mapping_count_check", sql`${table.legacyMappingCount} > 0`),
  check("identity_reconciliation_receipts_excluded_count_check", sql`${table.excludedAuthCount} >= 0`),
  check("identity_reconciliation_receipts_status_check", sql`${table.status} = 'verified'`),
]);

export const identityReconciliationActivations = pgTable("identity_reconciliation_activations", {
  receiptDigest: text("receipt_digest").primaryKey().references(
    () => identityReconciliationReceipts.receiptDigest,
    { onDelete: "restrict" },
  ),
  clerkInstanceId: text("clerk_instance_id").notNull(),
  activatedAt: timestamp("activated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const identityReconciliationLegacyMappings = pgTable("identity_reconciliation_legacy_mappings", {
  clerkInstanceId: text("clerk_instance_id").notNull(),
  clerkUserId: text("clerk_user_id").notNull(),
  appUserId: uuid("app_user_id").notNull().references(() => appUsers.id, { onDelete: "restrict" }),
  receiptDigest: text("receipt_digest").notNull().references(
    () => identityReconciliationReceipts.receiptDigest,
    { onDelete: "restrict" },
  ),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  primaryKey({ columns: [table.clerkInstanceId, table.clerkUserId] }),
  uniqueIndex("identity_reconciliation_legacy_instance_app_uq").on(table.clerkInstanceId, table.appUserId),
  index("identity_reconciliation_legacy_receipt_idx").on(table.receiptDigest),
]);

export const clerkUserDeletionTombstones = pgTable("clerk_user_deletion_tombstones", {
  clerkInstanceId: text("clerk_instance_id").notNull(),
  clerkUserId: text("clerk_user_id").notNull(),
  webhookEventId: text("webhook_event_id"),
  deletedAt: timestamp("deleted_at", { withTimezone: true }).notNull(),
  receivedAt: timestamp("received_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [primaryKey({ columns: [table.clerkInstanceId, table.clerkUserId] })]);

export const userDevices = pgTable("user_devices", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  platform: text("platform").notNull(),
  model: text("model"),
  appVersion: text("app_version"),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
  ...timestamps,
}, (table) => [index("user_devices_user_id_idx").on(table.userId)]);

export const teams = pgTable("teams", {
  id: uuid("id").primaryKey(),
  ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  name: text("name").notNull(), shortName: text("short_name"), division: text("division"),
  colorPrimary: text("color_primary"), colorSecondary: text("color_secondary"), referenceKey: text("reference_key"),
  deletedAt: timestamp("deleted_at", { withTimezone: true }), ...timestamps,
}, (t) => [index("teams_owner_updated_idx").on(t.ownerId, t.updatedAt)]);

export const teamMembers = pgTable("team_members", {
  id: uuid("id").primaryKey(), teamId: uuid("team_id").notNull().references(() => teams.id, { onDelete: "cascade" }),
  displayName: text("display_name").notNull(), jerseyNumber: text("jersey_number"), role: text("role"),
  position: text("position"), notes: text("notes"), createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
export const teamOfficials = pgTable("team_officials", {
  id: uuid("id").primaryKey(), teamId: uuid("team_id").notNull().references(() => teams.id, { onDelete: "cascade" }),
  displayName: text("display_name").notNull(), role: text("role").notNull(), phone: text("phone"), email: text("email"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
export const teamTags = pgTable("team_tags", {
  teamId: uuid("team_id").notNull().references(() => teams.id, { onDelete: "cascade" }), value: text("value").notNull(),
}, (t) => [primaryKey({ columns: [t.teamId, t.value] })]);

export const competitions = pgTable("competitions", {
  id: uuid("id").primaryKey(), ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  name: text("name").notNull(), level: text("level"), deletedAt: timestamp("deleted_at", { withTimezone: true }), ...timestamps,
}, (t) => [index("competitions_owner_updated_idx").on(t.ownerId, t.updatedAt)]);
export const venues = pgTable("venues", {
  id: uuid("id").primaryKey(), ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  name: text("name").notNull(), city: text("city"), country: text("country"), latitude: doublePrecision("latitude"), longitude: doublePrecision("longitude"),
  deletedAt: timestamp("deleted_at", { withTimezone: true }), ...timestamps,
}, (t) => [index("venues_owner_updated_idx").on(t.ownerId, t.updatedAt)]);

export const referenceCompetitions = pgTable("reference_competitions", {
  id: uuid("id").primaryKey(),
  code: text("code").notNull(),
  name: text("name").notNull(),
  seasonYear: integer("season_year").notNull(),
  federation: text("federation").notNull(),
  tier: integer("tier").notNull(),
  gender: text("gender").notNull(),
  sourceUrl: text("source_url").notNull(),
  sourcePublishedAt: date("source_published_at"),
  ...timestamps,
}, (t) => [
  uniqueIndex("reference_competitions_code_uq").on(t.code),
  uniqueIndex("reference_competitions_id_season_uq").on(t.id, t.seasonYear),
  index("reference_competitions_federation_season_idx").on(t.federation, t.seasonYear),
  check("reference_competitions_season_year_check", sql`${t.seasonYear} >= 2000`),
  check("reference_competitions_tier_check", sql`${t.tier} >= 1`),
  check("reference_competitions_gender_check", sql`${t.gender} in ('men', 'women', 'mixed')`),
]);

export const referenceTeams = pgTable("reference_teams", {
  id: uuid("id").primaryKey(),
  competitionId: uuid("competition_id").notNull(),
  name: text("name").notNull(),
  shortName: text("short_name"),
  referenceKey: text("reference_key").notNull(),
  seasonYear: integer("season_year").notNull(),
  sourceUrl: text("source_url").notNull(),
  sourceNameNote: text("source_name_note"),
  ...timestamps,
}, (t) => [
  uniqueIndex("reference_teams_reference_key_uq").on(t.referenceKey),
  uniqueIndex("reference_teams_competition_name_uq").on(t.competitionId, t.name),
  index("reference_teams_competition_idx").on(t.competitionId),
  index("reference_teams_season_idx").on(t.seasonYear),
  check("reference_teams_season_year_check", sql`${t.seasonYear} >= 2000`),
  foreignKey({
    columns: [t.competitionId, t.seasonYear],
    foreignColumns: [referenceCompetitions.id, referenceCompetitions.seasonYear],
    name: "reference_teams_competition_season_fk",
  }).onDelete("cascade"),
]);

export const scheduledMatches = pgTable("scheduled_matches", {
  id: uuid("id").primaryKey(), ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  homeTeamName: text("home_team_name").notNull(), awayTeamName: text("away_team_name").notNull(),
  kickoffAt: timestamp("kickoff_at", { withTimezone: true }).notNull(), status: text("status").notNull().default("scheduled"),
  competitionId: uuid("competition_id").references(() => competitions.id), competitionName: text("competition_name"),
  venueId: uuid("venue_id").references(() => venues.id), venueName: text("venue_name"),
  homeTeamId: uuid("home_team_id").references(() => teams.id), awayTeamId: uuid("away_team_id").references(() => teams.id),
  homeMatchSheet: jsonb("home_match_sheet"), awayMatchSheet: jsonb("away_match_sheet"), notes: text("notes"),
  sourceDeviceId: text("source_device_id"), deletedAt: timestamp("deleted_at", { withTimezone: true }), ...timestamps,
}, (t) => [index("scheduled_matches_owner_updated_idx").on(t.ownerId, t.updatedAt)]);

export const matches = pgTable("matches", {
  id: uuid("id").primaryKey(), ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  scheduledMatchId: uuid("scheduled_match_id").references(() => scheduledMatches.id, { onDelete: "set null" }),
  status: text("status").notNull().default("completed"), startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
  completedAt: timestamp("completed_at", { withTimezone: true }), durationSeconds: integer("duration_seconds"),
  numberOfPeriods: integer("number_of_periods").notNull().default(2), regulationMinutes: integer("regulation_minutes"), halfTimeMinutes: integer("half_time_minutes"),
  competitionId: uuid("competition_id").references(() => competitions.id), competitionName: text("competition_name"),
  venueId: uuid("venue_id").references(() => venues.id), venueName: text("venue_name"),
  homeTeamId: uuid("home_team_id").references(() => teams.id), homeTeamName: text("home_team_name").notNull(),
  awayTeamId: uuid("away_team_id").references(() => teams.id), awayTeamName: text("away_team_name").notNull(),
  extraTimeEnabled: boolean("extra_time_enabled").notNull().default(false), extraTimeHalfMinutes: integer("extra_time_half_minutes"),
  penaltiesEnabled: boolean("penalties_enabled").notNull().default(false), penaltyInitialRounds: integer("penalty_initial_rounds").notNull().default(5),
  homeScore: integer("home_score").notNull().default(0), awayScore: integer("away_score").notNull().default(0), finalScore: jsonb("final_score"),
  sourceDeviceId: text("source_device_id"), deletedAt: timestamp("deleted_at", { withTimezone: true }), ...timestamps,
}, (t) => [index("matches_owner_updated_idx").on(t.ownerId, t.updatedAt)]);

export const matchPeriods = pgTable("match_periods", {
  id: uuid("id").primaryKey(), matchId: uuid("match_id").notNull().references(() => matches.id, { onDelete: "cascade" }),
  index: integer("index").notNull(), regulationSeconds: integer("regulation_seconds").notNull(), addedTimeSeconds: integer("added_time_seconds").notNull().default(0),
  result: jsonb("result"), createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => [uniqueIndex("match_periods_match_index_uq").on(t.matchId, t.index)]);
export const matchEvents = pgTable("match_events", {
  id: uuid("id").primaryKey(), matchId: uuid("match_id").notNull().references(() => matches.id, { onDelete: "cascade" }),
  occurredAt: timestamp("occurred_at", { withTimezone: true }).notNull(), periodIndex: integer("period_index").notNull(), clockSeconds: integer("clock_seconds").notNull(),
  matchTimeLabel: text("match_time_label").notNull(), eventType: text("event_type").notNull(), payload: jsonb("payload"),
  teamId: uuid("team_id").references(() => teams.id, { onDelete: "set null" }),
  teamMemberId: uuid("team_member_id").references(() => teamMembers.id, { onDelete: "set null" }),
  teamSide: text("team_side"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index("match_events_match_time_idx").on(t.matchId, t.occurredAt)]);
export const matchMetrics = pgTable("match_metrics", {
  matchId: uuid("match_id").primaryKey().references(() => matches.id, { onDelete: "cascade" }),
  ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }), regulationMinutes: integer("regulation_minutes"),
  halfTimeMinutes: integer("half_time_minutes"), extraTimeMinutes: integer("extra_time_minutes"), penaltiesEnabled: boolean("penalties_enabled").notNull().default(false),
  totalGoals: integer("total_goals").notNull().default(0), totalCards: integer("total_cards").notNull().default(0), totalPenalties: integer("total_penalties").notNull().default(0),
  yellowCards: integer("yellow_cards").notNull().default(0), redCards: integer("red_cards").notNull().default(0), homeCards: integer("home_cards").notNull().default(0), awayCards: integer("away_cards").notNull().default(0),
  homeSubstitutions: integer("home_substitutions").notNull().default(0), awaySubstitutions: integer("away_substitutions").notNull().default(0),
  penaltiesScored: integer("penalties_scored").notNull().default(0), penaltiesMissed: integer("penalties_missed").notNull().default(0), avgAddedTimeSeconds: integer("avg_added_time_seconds").notNull().default(0),
  generatedAt: timestamp("generated_at", { withTimezone: true }).notNull().defaultNow(),
});
export const matchAssessments = pgTable("match_assessments", {
  id: uuid("id").primaryKey(), matchId: uuid("match_id").notNull().references(() => matches.id, { onDelete: "cascade" }),
  ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }), mood: assessmentMood("mood"), rating: integer("rating"), overall: text("overall"),
  wentWell: text("went_well"), toImprove: text("to_improve"), ...timestamps,
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
}, (t) => [
  uniqueIndex("match_assessments_match_owner_uq").on(t.matchId, t.ownerId),
  check("match_assessments_rating_check", sql`${t.rating} is null or (${t.rating} >= 1 and ${t.rating} <= 5)`),
]);

export const pages = pgTable("pages", {
  id: uuid("id").primaryKey().defaultRandom(),
  ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  pageType: pageType("page_type").notNull(),
  title: text("title"),
  contentJSON: jsonb("content_jsonb").notNull().default(sql`'{"type":"doc","content":[]}'::jsonb`),
  contentHTML: text("content_html"),
  contentText: text("content_text"),
  icon: text("icon"),
  tags: text("tags").array().default(sql`'{}'::text[]`),
  status: pageStatus("status").notNull().default("draft"),
  isFavorite: boolean("is_favorite").default(false),
  matchId: uuid("match_id").references(() => matches.id, { onDelete: "set null" }),
  submittedAt: timestamp("submitted_at", { withTimezone: true }),
  ...timestamps,
}, (t) => [
  index("pages_owner_id_idx").on(t.ownerId),
  index("pages_page_type_idx").on(t.pageType),
  index("pages_status_idx").on(t.status),
  index("pages_updated_at_idx").on(t.updatedAt),
  index("pages_match_id_idx").on(t.matchId).where(sql`${t.matchId} is not null`),
]);

export const workoutPresets = pgTable("workout_presets", {
  id: uuid("id").primaryKey().defaultRandom(),
  title: text("title").notNull(),
  description: text("description"),
  kind: text("kind").notNull(),
  estimatedDuration: integer("estimated_duration"),
  exercises: jsonb("exercises").notNull().default(sql`'[]'::jsonb`),
  intensityLevel: integer("intensity_level"),
  tags: text("tags").array().default(sql`'{}'::text[]`),
  isPublic: boolean("is_public").notNull().default(true),
  createdBy: uuid("created_by").references(() => appUsers.id, { onDelete: "set null" }),
  ...timestamps,
}, (t) => [
  index("workout_presets_created_by_idx").on(t.createdBy).where(sql`${t.createdBy} is not null`),
  index("workout_presets_kind_idx").on(t.kind),
  index("workout_presets_public_idx").on(t.isPublic).where(sql`${t.isPublic} = true`),
  check("workout_presets_intensity_level_check", sql`${t.intensityLevel} is null or (${t.intensityLevel} >= 1 and ${t.intensityLevel} <= 10)`),
]);

export const workoutSessions = pgTable("workout_sessions", {
  id: uuid("id").primaryKey(),
  ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  state: workoutState("state").notNull(),
  kind: workoutKind("kind").notNull(),
  title: text("title").notNull(),
  startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
  endedAt: timestamp("ended_at", { withTimezone: true }),
  perceivedExertion: integer("perceived_exertion"),
  presetId: uuid("preset_id"),
  notes: text("notes"),
  metadata: jsonb("metadata").default(sql`'{}'::jsonb`),
  summary: jsonb("summary"),
  sessionContext: sessionContext("session_context"),
  ...timestamps,
}, (t) => [index("workout_sessions_owner_started_idx").on(t.ownerId, t.startedAt)]);

export const referenceDisciplinaryCodes = pgTable("reference_disciplinary_codes", {
  id: uuid("id").primaryKey(),
  jurisdiction: text("jurisdiction").notNull(),
  seasonYear: integer("season_year").notNull(),
  recipientType: text("recipient_type").notNull(),
  cardType: text("card_type").notNull(),
  code: text("code").notNull(),
  title: text("title").notNull(),
  regulationRef: text("regulation_ref"),
  minimumSuspensionMatches: integer("minimum_suspension_matches"),
  sortOrder: integer("sort_order").notNull().default(0),
  notes: text("notes"),
  sourceUrl: text("source_url").notNull(),
  ...timestamps,
}, (t) => [
  uniqueIndex("reference_disciplinary_codes_key_uq").on(t.jurisdiction, t.seasonYear, t.recipientType, t.code),
  index("reference_disciplinary_codes_lookup_idx").on(t.jurisdiction, t.seasonYear, t.recipientType, t.cardType, t.sortOrder),
  check("reference_disciplinary_codes_season_year_check", sql`${t.seasonYear} >= 2000`),
  check("reference_disciplinary_codes_recipient_type_check", sql`${t.recipientType} in ('player', 'team_official', 'participant')`),
  check("reference_disciplinary_codes_card_type_check", sql`${t.cardType} in ('yellow', 'red', 'n/a')`),
]);

export const referenceDisciplinaryRules = pgTable("reference_disciplinary_rules", {
  id: uuid("id").primaryKey(),
  jurisdiction: text("jurisdiction").notNull(),
  seasonYear: integer("season_year").notNull(),
  ruleType: text("rule_type").notNull(),
  recipientType: text("recipient_type").notNull(),
  appliesToCodes: text("applies_to_codes").array().notNull().default(sql`'{}'::text[]`),
  triggerCount: integer("trigger_count"),
  repeatInterval: integer("repeat_interval"),
  suspensionMatches: integer("suspension_matches"),
  ruleText: text("rule_text").notNull(),
  regulationRef: text("regulation_ref"),
  notes: text("notes"),
  sourceUrl: text("source_url").notNull(),
  ...timestamps,
}, (t) => [
  uniqueIndex("reference_disciplinary_rules_key_uq").on(t.jurisdiction, t.seasonYear, t.ruleType, t.recipientType),
  index("reference_disciplinary_rules_lookup_idx").on(t.jurisdiction, t.seasonYear, t.recipientType, t.ruleType),
  check("reference_disciplinary_rules_season_year_check", sql`${t.seasonYear} >= 2000`),
  check("reference_disciplinary_rules_recipient_type_check", sql`${t.recipientType} in ('player', 'team_official', 'participant')`),
]);

export const idempotencyKeys = pgTable("idempotency_keys", {
  ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }), key: text("key").notNull(),
  requestHash: text("request_hash").notNull(), responseBody: jsonb("response_body"), statusCode: integer("status_code").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull().default(sql`now() + interval '24 hours'`),
}, (t) => [primaryKey({ columns: [t.ownerId, t.key] })]);

export const aiThreads = pgTable("ai_threads", {
  id: uuid("id").primaryKey(), ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }),
  title: text("title"), defaultModel: text("default_model"), lastActivityAt: timestamp("last_activity_at", { withTimezone: true }).notNull().defaultNow(),
  deletedAt: timestamp("deleted_at", { withTimezone: true }), ...timestamps,
});
export const aiMessages = pgTable("ai_messages", {
  id: uuid("id").primaryKey(), threadId: uuid("thread_id").notNull().references(() => aiThreads.id, { onDelete: "cascade" }), role: text("role").notNull(),
  content: jsonb("content").notNull(), model: text("model"), usageInputTokens: integer("usage_input_tokens"), usageOutputTokens: integer("usage_output_tokens"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
export const aiAttachments = pgTable("ai_attachments", {
  id: uuid("id").primaryKey(), messageId: uuid("message_id").notNull().references(() => aiMessages.id, { onDelete: "cascade" }),
  kind: text("kind").notNull(), storageKey: text("storage_key"), metadata: jsonb("metadata"), createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
export const aiUsageDaily = pgTable("ai_usage_daily", {
  ownerId: uuid("owner_id").notNull().references(() => appUsers.id, { onDelete: "cascade" }), onDate: date("on_date").notNull(), model: text("model").notNull(),
  inputTokens: integer("input_tokens").notNull().default(0), outputTokens: integer("output_tokens").notNull().default(0), responsesCount: integer("responses_count").notNull().default(0),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => [primaryKey({ columns: [t.ownerId, t.onDate, t.model] })]);

// Rollback ledger control-plane tables. Event rows are populated and protected by
// database triggers in migration 0010; delivery state is deliberately separate so
// the captured mutation envelope remains physically immutable.
export const mutationLedgerEpochs = pgTable("mutation_ledger_epochs", {
  id: uuid("id").primaryKey().defaultRandom(),
  status: text("status").notNull().default("preparing"),
  captureEnforced: boolean("capture_enforced").notNull().default(false),
  baselineSnapshotId: text("baseline_snapshot_id").notNull(),
  baselineSchemaHash: text("baseline_schema_hash").notNull(),
  baselineDataHash: text("baseline_data_hash").notNull(),
  openedAt: timestamp("opened_at", { withTimezone: true }),
  frozenAt: timestamp("frozen_at", { withTimezone: true }),
  frozenEventSequence: bigint("frozen_event_sequence", { mode: "number" }),
  ...timestamps,
}, (table) => [
  check("mutation_ledger_epochs_status_check", sql`${table.status} in ('preparing', 'open', 'frozen', 'archived')`),
  check("mutation_ledger_epochs_schema_hash_check", sql`${table.baselineSchemaHash} ~ '^[0-9a-f]{64}$'`),
  check("mutation_ledger_epochs_data_hash_check", sql`${table.baselineDataHash} ~ '^[0-9a-f]{64}$'`),
]);

export const mutationEntityRevisions = pgTable("mutation_entity_revisions", {
  tableName: text("table_name").notNull(),
  entityKey: text("entity_key").notNull(),
  revision: bigint("revision", { mode: "number" }).notNull().default(0),
}, (table) => [primaryKey({ columns: [table.tableName, table.entityKey] })]);

export const mutationOutboxEvents = pgTable("mutation_outbox_events", {
  eventId: uuid("event_id").primaryKey().defaultRandom(),
  eventSequence: bigserial("event_sequence", { mode: "number" }).notNull(),
  epochId: uuid("epoch_id").notNull().references(() => mutationLedgerEpochs.id, { onDelete: "restrict" }),
  mutationGroupId: uuid("mutation_group_id").notNull(),
  groupOrdinal: integer("group_ordinal").notNull(),
  tableName: text("table_name").notNull(),
  entityKey: text("entity_key").notNull(),
  entityRevision: bigint("entity_revision", { mode: "number" }).notNull(),
  operation: text("operation").notNull(),
  beforeJSON: jsonb("before_json"),
  afterJSON: jsonb("after_json"),
  sourceKind: text("source_kind").notNull(),
  sourceEventId: text("source_event_id"),
  requestId: text("request_id").notNull(),
  idempotencyKey: text("idempotency_key"),
  appUserId: uuid("app_user_id"),
  method: text("method"),
  path: text("path"),
  actorId: text("actor_id"),
  workerVersionId: text("worker_version_id").notNull(),
  schemaVersion: integer("schema_version").notNull().default(1),
  capturedAt: timestamp("captured_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  uniqueIndex("mutation_outbox_events_sequence_uq").on(table.eventSequence),
  uniqueIndex("mutation_outbox_events_group_ordinal_uq").on(table.mutationGroupId, table.groupOrdinal),
  uniqueIndex("mutation_outbox_events_entity_revision_uq").on(table.tableName, table.entityKey, table.entityRevision),
  index("mutation_outbox_events_epoch_sequence_idx").on(table.epochId, table.eventSequence),
  check("mutation_outbox_events_operation_check", sql`${table.operation} in ('insert', 'update', 'delete')`),
  check("mutation_outbox_events_ordinal_check", sql`${table.groupOrdinal} > 0`),
  check("mutation_outbox_events_revision_check", sql`${table.entityRevision} > 0`),
  check("mutation_outbox_events_schema_version_check", sql`${table.schemaVersion} = 1`),
]);

export const mutationOutboxDeliveries = pgTable("mutation_outbox_deliveries", {
  eventId: uuid("event_id").primaryKey().references(() => mutationOutboxEvents.eventId, { onDelete: "restrict" }),
  state: text("state").notNull().default("pending"),
  attemptCount: integer("attempt_count").notNull().default(0),
  leaseGeneration: bigint("lease_generation", { mode: "number" }).notNull().default(0),
  leasedUntil: timestamp("leased_until", { withTimezone: true }),
  nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }).notNull().defaultNow(),
  lastError: text("last_error"),
  encryptedEnvelope: text("encrypted_envelope"),
  encryptionKeyId: text("encryption_key_id"),
  encryptionNonce: text("encryption_nonce"),
  contentDigest: text("content_digest"),
  deliveredAt: timestamp("delivered_at", { withTimezone: true }),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  index("mutation_outbox_deliveries_dispatch_idx").on(table.state, table.nextAttemptAt),
  check("mutation_outbox_deliveries_state_check", sql`${table.state} in ('pending', 'leased', 'delivered', 'quarantined')`),
  check("mutation_outbox_deliveries_attempt_count_check", sql`${table.attemptCount} >= 0`),
  check("mutation_outbox_deliveries_lease_generation_check", sql`${table.leaseGeneration} >= 0`),
]);

// Provider-specific runtime pin. Each deployed branch receives exactly one
// reviewed marker after migrations; the Worker also verifies current_user's
// PlanetScale branch suffix so a cloned/cross-wired database fails closed.
export const runtimeDatabaseMarkers = pgTable("runtime_database_markers", {
  marker: text("marker").primaryKey(),
  branchId: text("branch_id").notNull(),
  environment: text("environment").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
