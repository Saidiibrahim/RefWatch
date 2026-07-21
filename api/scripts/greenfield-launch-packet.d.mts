export const supersededGreenfieldLaunchProfile: "greenfield_launch_v1";
export const historicalGreenfieldLaunchProfile: "greenfield_launch_v2";
export const greenfieldLaunchProfile: "greenfield_launch_v3";
export const greenfieldIdentityProfile: "greenfield_zero_legacy_v1";
export const supersededGreenfieldRollbackProfile: "greenfield_destructive_v1";
export const historicalGreenfieldRollbackProfile: "greenfield_destructive_v2";
export const greenfieldRollbackProfile: "greenfield_destructive_v3";
export const greenfieldAuthorizationProfile: "refwatch.greenfield-authorization.v1";
export const greenfieldAuthorizationArtifact: string;
export const greenfieldAuthorizationDigest: string;
export const greenfieldIdentityReceiptDigest: string;
export const greenfieldEmptyMappingHash: string;
export const productionClerk: Readonly<{
  applicationId: "app_3GWFGTs5EGNXyzQ4idk7p6JdsUP";
  applicationName: "refwatch";
  developmentInstanceId: "ins_3GWFGUvUfsAjzPeVYjDjckfls0a";
  instanceId: "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac";
  domain: "refwatch.ibby.ai";
  issuer: "https://clerk.refwatch.ibby.ai";
}>;
export const productionWorker: Readonly<{
  name: "refwatch-api";
  environment: "production";
  hostname: "api.refwatch.ibby.ai";
  routePattern: "api.refwatch.ibby.ai/*";
}>;
export const productionWorkerCustomDomain: Readonly<{
  kind: "custom_domain";
  hostname: "api.refwatch.ibby.ai";
  workerName: "refwatch-api";
  tlsStatus: "active";
  dnsManagement: "cloudflare_worker_custom_domain";
}>;
export const productionClerkLifecycleWebhook: Readonly<{
  endpointUid: "refwatch-production-clerk-lifecycle-v1";
  endpointDescription: "RefWatch production Clerk lifecycle";
  endpointURL: "https://api.refwatch.ibby.ai/webhooks/clerk";
  eventTypes: readonly ["user.created", "user.updated", "user.deleted"];
}>;
export const productionLastKnownGoodWorker: Readonly<{
  versionId: "e966d6df-b5ff-4288-832c-c8d91e00ce48";
  createdAtUTC: "2026-07-16T20:45:12.701Z";
  scriptEtag: string;
  hyperdriveId: "5345de83edfa40b790d5b26df32f56ab";
  runtimeRoleId: "vaqg84rqoedz";
}>;
export const productionDatabase: Readonly<{
  organization: "ibrahim-aka-ajax";
  database: "refwatch";
  branch: "main";
  branchId: "w3g1f8vcbg34";
  runtimeMarker: "refwatch:production:w3g1f8vcbg34";
  runtimeRoleId: "hvk7iheytj62";
  hyperdriveId: "920ca5b108034b2bb8700cf0201ac55f";
}>;
export const productionLedgerResources: Readonly<{
  d1Id: "6d1a7bbb-ea9d-47b2-ae77-44f992b9e3d2";
  queueName: "refwatch-mutation-ledger-production";
  deadLetterQueueName: "refwatch-mutation-ledger-dlq-production";
  encryptionKeyId: "production-20260715-v1";
}>;
export const cutoverAcceptance: Readonly<{
  overrideHeaderName: "Cloudflare-Workers-Version-Overrides";
  tokenHeaderName: "X-RefWatch-Cutover-Token";
  tokenSecretName: "CUTOVER_ACCEPTANCE_TOKEN";
}>;
export const productionWorkerSecretNames: readonly [
  "CLERK_PUBLISHABLE_KEY",
  "CLERK_SECRET_KEY",
  "CLERK_WEBHOOK_SIGNING_SECRET",
  "CUTOVER_ACCEPTANCE_TOKEN",
  "MUTATION_LEDGER_ENCRYPTION_KEY",
  "OPENAI_API_KEY",
];
export const reviewedSchema0016: Readonly<{
  migrationHead: "0016_careless_steel_serpent";
  migrationCount: 17;
  repositorySnapshotPath: "api/src/db/migrations/meta/0016_snapshot.json";
  repositorySnapshotSha256: string;
  providerQueryPath: "api/scripts/greenfield-schema-readback.sql";
  providerQuerySha256: string;
  migrationHeadId: 17;
  migrationHeadHash: string;
  migrationHistoryMd5: string;
  publicTableCount: 36;
  publicTableNamesMd5: string;
  publicTablePropertiesCount: 36;
  publicTablePropertiesMd5: string;
  publicColumnCount: 382;
  publicColumnsMd5: string;
  publicConstraintCount: 106;
  publicConstraintsMd5: string;
  publicIndexCount: 77;
  publicIndexesMd5: string;
  publicTriggerCount: 32;
  publicTriggersMd5: string;
  publicFunctionCount: 10;
  publicFunctionsMd5: string;
  publicEnumLabelCount: 27;
  publicEnumLabelsMd5: string;
  catalogContractMd5: string;
}>;
export const reviewedSchema: Readonly<{
  migrationHead: "0017_ambiguous_hedge_knight";
  migrationCount: 18;
  repositorySnapshotPath: "api/src/db/migrations/meta/0017_snapshot.json";
  repositorySnapshotSha256: string;
  providerQueryPath: "api/scripts/greenfield-schema-readback.sql";
  providerQuerySha256: string;
  migrationHeadId: 18;
  migrationHeadHash: string;
  migrationHistoryMd5: string;
  publicTableCount: 36;
  publicTableNamesMd5: string;
  publicTablePropertiesCount: 36;
  publicTablePropertiesMd5: string;
  publicColumnCount: 383;
  publicColumnsMd5: string;
  publicConstraintCount: 106;
  publicConstraintsMd5: string;
  publicIndexCount: 77;
  publicIndexesMd5: string;
  publicTriggerCount: 32;
  publicTriggersMd5: string;
  publicFunctionCount: 10;
  publicFunctionsMd5: string;
  publicEnumLabelCount: 27;
  publicEnumLabelsMd5: string;
  catalogContractMd5: string;
}>;
export const reviewedDeterministicSeed: Readonly<{
  migrationPath: "api/src/db/migrations/0002_crazy_yellowjacket.sql";
  migrationSha256: string;
  referenceCompetitionsCount: 5;
  referenceCompetitionsBusinessMd5: string;
  referenceTeamsCount: 54;
  referenceTeamsBusinessMd5: string;
  referenceDisciplinaryCodesCount: 0;
  referenceDisciplinaryRulesCount: 0;
  globalWorkoutPresetsCount: 0;
}>;
export const cleanTargetReadback: Readonly<{
  queryPath: "api/scripts/greenfield-clean-target-readback.sql";
  querySha256: string;
}>;
export const ledgerReadback: Readonly<{
  queryPath: "api/scripts/greenfield-ledger-readback.sql";
  querySha256: string;
}>;
export const greenfieldAcceptanceChecks: readonly string[];
export const greenfieldCleanTargetTables: readonly string[];
export const greenfieldStageMutableWorkerBindings: readonly [
  "NEW_USER_ONBOARDING_MODE",
  "WRITE_MODE",
];
export function canonicalSanitizedJSON(value: unknown): string;
export function computeSanitizedReceiptSha256(payload: unknown): string;
export function computeStableWorkerBindingSha256(versionReadback: unknown): string;
export function sanitizeWorkerVersionReadback(
  versionReadback: unknown,
  observedAtUTC: string,
): unknown;
export function expectedProductionWorkerBindings(
  writeMode: string,
  onboardingMode: string,
): unknown[];

export interface GreenfieldLaunchValidationResult {
  ok: boolean;
  errors: string[];
  summary: {
    launchProfile: string | null;
    authorizationDigest: string | null;
    clerkInstanceId: string | null;
    workerName: string | null;
    workerEnvironment: string | null;
    candidateWorkerVersionId: string | null;
    acceptedWorkerVersionId: string | null;
    databaseBranchId: string | null;
    legacyMappingCount: number | null;
    targetAppUserCount: number | null;
    activeLedgerEpochCount: number | null;
    rollbackPacketSha256: string | null;
    acceptanceChecks: number;
    physicalDeviceAcceptancePassed: boolean;
    writeMode: string | null;
    readyForProductionTraffic: boolean;
  };
}

export interface GreenfieldLaunchValidationOptions {
  now?: Date;
}

export function validateGreenfieldLaunchPacket(
  packet: unknown,
  options?: GreenfieldLaunchValidationOptions,
): GreenfieldLaunchValidationResult;
export function validateHistoricalGreenfieldLaunchPacketV2(
  packet: unknown,
  options?: GreenfieldLaunchValidationOptions,
): GreenfieldLaunchValidationResult;
