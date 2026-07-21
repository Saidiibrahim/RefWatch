import { createHash } from "node:crypto";
import {
  productionRuntimeProvisioningTarget,
} from "./provision-production-runtime.mjs";
import {
  validateHistoricalGreenfieldRollbackPacketV2,
  validateRollbackPacket,
} from "./rollback-packet.mjs";

const sha256Pattern = /^[0-9a-f]{64}$/;
const md5Pattern = /^[0-9a-f]{32}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const cloudflareProviderIdPattern =
  /^(?:[0-9a-f]{32}|[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i;
const utcInstantPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;

export const supersededGreenfieldLaunchProfile = "greenfield_launch_v1";
export const historicalGreenfieldLaunchProfile = "greenfield_launch_v2";
export const greenfieldLaunchProfile = "greenfield_launch_v3";
export const greenfieldIdentityProfile = "greenfield_zero_legacy_v1";
export const supersededGreenfieldRollbackProfile = "greenfield_destructive_v1";
export const historicalGreenfieldRollbackProfile = "greenfield_destructive_v2";
export const greenfieldRollbackProfile = "greenfield_destructive_v3";
export const greenfieldAuthorizationProfile = "refwatch.greenfield-authorization.v1";
export const greenfieldAuthorizationArtifact =
  "docs/exec-plans/active/backend-platform-migration/evidence/2026-07-20-greenfield-cutover-authorization.md";
export const greenfieldAuthorizationDigest =
  "17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b";
export const greenfieldIdentityReceiptDigest =
  "27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18";
export const greenfieldEmptyMappingHash =
  "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945";
export const productionClerk = Object.freeze({
  applicationId: "app_3GWFGTs5EGNXyzQ4idk7p6JdsUP",
  applicationName: "refwatch",
  developmentInstanceId: "ins_3GWFGUvUfsAjzPeVYjDjckfls0a",
  instanceId: "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac",
  domain: "refwatch.ibby.ai",
  issuer: "https://clerk.refwatch.ibby.ai",
});
export const productionWorker = Object.freeze({
  name: "refwatch-api",
  environment: "production",
  hostname: "api.refwatch.ibby.ai",
  routePattern: "api.refwatch.ibby.ai/*",
});
export const productionWorkerCustomDomain = Object.freeze({
  kind: "custom_domain",
  hostname: productionWorker.hostname,
  workerName: productionWorker.name,
  tlsStatus: "active",
  dnsManagement: "cloudflare_worker_custom_domain",
});
export const productionClerkLifecycleWebhook = Object.freeze({
  endpointUid: "refwatch-production-clerk-lifecycle-v1",
  endpointDescription: "RefWatch production Clerk lifecycle",
  endpointURL: `https://${productionWorker.hostname}/webhooks/clerk`,
  eventTypes: Object.freeze([
    "user.created",
    "user.updated",
    "user.deleted",
  ]),
});
export const productionLastKnownGoodWorker = Object.freeze({
  versionId: "e966d6df-b5ff-4288-832c-c8d91e00ce48",
  createdAtUTC: "2026-07-16T20:45:12.701Z",
  scriptEtag:
    "c7fe13feeaec6962e56ee072a7479b1ea022b21ded00bf2d21a04d4d5477ccc4",
  hyperdriveId: "5345de83edfa40b790d5b26df32f56ab",
  runtimeRoleId: "vaqg84rqoedz",
});
export const productionDatabase = Object.freeze({
  organization: "ibrahim-aka-ajax",
  database: "refwatch",
  branch: "main",
  branchId: "w3g1f8vcbg34",
  runtimeMarker: "refwatch:production:w3g1f8vcbg34",
  runtimeRoleId: "hvk7iheytj62",
  hyperdriveId: "920ca5b108034b2bb8700cf0201ac55f",
});
export const productionLedgerResources = Object.freeze({
  d1Id: "6d1a7bbb-ea9d-47b2-ae77-44f992b9e3d2",
  queueName: "refwatch-mutation-ledger-production",
  deadLetterQueueName: "refwatch-mutation-ledger-dlq-production",
  encryptionKeyId: "production-20260715-v1",
});
export const cutoverAcceptance = Object.freeze({
  overrideHeaderName: "Cloudflare-Workers-Version-Overrides",
  tokenHeaderName: "X-RefWatch-Cutover-Token",
  tokenSecretName: "CUTOVER_ACCEPTANCE_TOKEN",
});
export const productionWorkerSecretNames = Object.freeze([
  "CLERK_PUBLISHABLE_KEY",
  "CLERK_SECRET_KEY",
  "CLERK_WEBHOOK_SIGNING_SECRET",
  "CUTOVER_ACCEPTANCE_TOKEN",
  "MUTATION_LEDGER_ENCRYPTION_KEY",
  "OPENAI_API_KEY",
]);
export const reviewedSchema0016 = Object.freeze({
  migrationHead: "0016_careless_steel_serpent",
  migrationCount: 17,
  repositorySnapshotPath: "api/src/db/migrations/meta/0016_snapshot.json",
  repositorySnapshotSha256:
    "5a84baea9a5aec9738c0bb207b0e5b417af5c7b5606706a434b7d1a5323ef500",
  providerQueryPath: "api/scripts/greenfield-schema-readback.sql",
  providerQuerySha256:
    "391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd",
  migrationHeadId: 17,
  migrationHeadHash:
    "0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac",
  migrationHistoryMd5: "73ad9d2a055b09e83324a50f74ed94dd",
  publicTableCount: 36,
  publicTableNamesMd5: "02e5f3fb7142644e853fe509447bfa6d",
  publicTablePropertiesCount: 36,
  publicTablePropertiesMd5: "6bb3240a18426bb8a30066d6c94e732b",
  publicColumnCount: 382,
  publicColumnsMd5: "5b81e30a8d05cea8c78649cf2be7e9cf",
  publicConstraintCount: 106,
  publicConstraintsMd5: "7e1563a29be11d524afea2c781611ba5",
  publicIndexCount: 77,
  publicIndexesMd5: "a30882f0a9b197ba37521f0d33a07e1b",
  publicTriggerCount: 32,
  publicTriggersMd5: "ac33e05012c6461424ea1e4f33b99b46",
  publicFunctionCount: 10,
  publicFunctionsMd5: "0c77e33ed70225750ae38a135a520bd2",
  publicEnumLabelCount: 27,
  publicEnumLabelsMd5: "b2eda0943c2c27d19e9bfd5c673fea70",
  catalogContractMd5: "7bc279f12d67a0d7783cf44faa304061",
});
export const reviewedSchema = Object.freeze({
  ...reviewedSchema0016,
  migrationHead: "0017_ambiguous_hedge_knight",
  migrationCount: 18,
  repositorySnapshotPath: "api/src/db/migrations/meta/0017_snapshot.json",
  repositorySnapshotSha256:
    "0830ddcdde5afd629479f595fe3cc5c3e500491e5042428e50abed3209b9efb2",
  migrationHeadId: 18,
  migrationHeadHash:
    "14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9",
  migrationHistoryMd5: "f2f3ddf416d58b2d9a60749e41af11f7",
  publicColumnCount: 383,
  publicColumnsMd5: "5fa4e25bcf19d7caf1f9adcfb4879344",
  catalogContractMd5: "99dca5e8c11b8ec23debfb7c698a74d7",
});
export const reviewedDeterministicSeed = Object.freeze({
  migrationPath: "api/src/db/migrations/0002_crazy_yellowjacket.sql",
  migrationSha256:
    "134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b",
  referenceCompetitionsCount: 5,
  referenceCompetitionsBusinessMd5: "d56166798ab11268a1758c5cc8162c01",
  referenceTeamsCount: 54,
  referenceTeamsBusinessMd5: "a562b3b7e9fb153e6e1c614a8df3d6cf",
  referenceDisciplinaryCodesCount: 0,
  referenceDisciplinaryRulesCount: 0,
  globalWorkoutPresetsCount: 0,
});
export const cleanTargetReadback = Object.freeze({
  queryPath: "api/scripts/greenfield-clean-target-readback.sql",
  querySha256:
    "eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352",
});
export const ledgerReadback = Object.freeze({
  queryPath: "api/scripts/greenfield-ledger-readback.sql",
  querySha256:
    "0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b",
});

export const greenfieldAcceptanceChecks = Object.freeze([
  "health",
  "missing_bearer_rejection",
  "invalid_bearer_rejection",
  "api_me",
  "zero_legacy_onboarding",
  "tenant_isolation",
  "owner_spoof_rejection",
  "crud",
  "idempotency",
  "tombstones",
  "assistant_streaming",
  "match_sheet",
  "webhook_lifecycle",
  "write_round_trip",
]);

export const greenfieldStageMutableWorkerBindings = Object.freeze([
  "NEW_USER_ONBOARDING_MODE",
  "WRITE_MODE",
]);

export const greenfieldCleanTargetTables = Object.freeze([
  "app_users",
  "identity_reconciliation_receipts",
  "identity_reconciliation_activations",
  "identity_reconciliation_legacy_mappings",
  "clerk_user_deletion_tombstones",
  "clerk_webhook_delivery_receipts",
  "user_devices",
  "teams",
  "team_members",
  "team_officials",
  "team_tags",
  "competitions",
  "venues",
  "scheduled_matches",
  "matches",
  "match_periods",
  "match_events",
  "match_metrics",
  "match_assessments",
  "pages",
  "user_owned_workout_presets",
  "workout_sessions",
  "idempotency_keys",
  "ai_threads",
  "ai_messages",
  "ai_attachments",
  "ai_usage_daily",
]);

const destructiveRecoverySteps = Object.freeze([
  "stop_production_traffic_and_writes",
  "route_to_write_guard_worker",
  "roll_back_worker_and_client",
  "reset_planetscale_application_state",
  "reseed_deterministic_reference_data",
  "recreate_test_identities",
  "rerun_greenfield_launch_acceptance",
]);

const statefulClaimKeys = Object.freeze([
  "snapshot",
  "tables",
  "table_dispositions",
  "clerk_mappings",
  "source_auth_users",
  "source_auth_identities",
  "auth_only_users",
  "legacy_migration",
  "supabase_export",
  "write_ledger",
]);

function objectKeys(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? Object.keys(value).sort()
    : [];
}

function requireCondition(condition, message, errors) {
  if (!condition) errors.push(message);
}

function requireStrictlyBefore(earlier, later, message, errors) {
  if (validUTCInstant(earlier) && validUTCInstant(later)) {
    requireCondition(Date.parse(earlier) < Date.parse(later), message, errors);
  }
}

function requireExactKeys(value, expected, label, errors) {
  const actual = objectKeys(value);
  const wanted = [...expected].sort();
  requireCondition(
    actual.length === wanted.length && actual.every((key, index) => key === wanted[index]),
    `${label} keys must exactly match the greenfield launch contract`,
    errors,
  );
}

function validUTCInstant(value) {
  if (typeof value !== "string" || !utcInstantPattern.test(value)) return false;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return false;
  const canonical = value.includes(".")
    ? value
    : value.replace(/Z$/, ".000Z");
  return parsed.toISOString() === canonical;
}

function requireUTCInstant(value, label, errors) {
  requireCondition(validUTCInstant(value), `${label} must be a strict UTC instant`, errors);
}

function requireSha256(value, label, errors) {
  requireCondition(sha256Pattern.test(value ?? ""), `${label} must be SHA-256`, errors);
}

function requireNonEmpty(value, label, errors) {
  requireCondition(typeof value === "string" && value.trim().length > 0, `${label} is required`, errors);
}

export function canonicalSanitizedJSON(value) {
  if (value === null || typeof value === "boolean" || typeof value === "string") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("sanitized receipt contains a non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalSanitizedJSON).join(",")}]`;
  }
  if (value && typeof value === "object") {
    const keys = Object.keys(value).sort();
    return `{${keys.map((key) => {
      if (value[key] === undefined) throw new Error("sanitized receipt contains undefined");
      return `${JSON.stringify(key)}:${canonicalSanitizedJSON(value[key])}`;
    }).join(",")}}`;
  }
  throw new Error("sanitized receipt contains an unsupported value");
}

export function computeSanitizedReceiptSha256(payload) {
  return createHash("sha256").update(canonicalSanitizedJSON(payload)).digest("hex");
}

function validateCustomDomainEdgeBinding(value, label, errors) {
  requireExactKeys(
    value,
    [
      "kind",
      "hostname",
      "provider_id",
      "worker_name",
      "tls_status",
      "dns_management",
    ],
    label,
    errors,
  );
  requireCondition(
    value?.kind === productionWorkerCustomDomain.kind,
    `${label}.kind must be custom_domain`,
    errors,
  );
  requireCondition(
    value?.hostname === productionWorkerCustomDomain.hostname,
    `${label}.hostname must be ${productionWorker.hostname}`,
    errors,
  );
  requireCondition(
    cloudflareProviderIdPattern.test(value?.provider_id ?? ""),
    `${label}.provider_id must be a Cloudflare provider identifier`,
    errors,
  );
  requireCondition(
    value?.worker_name === productionWorkerCustomDomain.workerName,
    `${label}.worker_name must be ${productionWorker.name}`,
    errors,
  );
  requireCondition(
    value?.tls_status === productionWorkerCustomDomain.tlsStatus,
    `${label}.tls_status must be active`,
    errors,
  );
  requireCondition(
    value?.dns_management === productionWorkerCustomDomain.dnsManagement,
    `${label}.dns_management must be cloudflare_worker_custom_domain`,
    errors,
  );
}

function sameCanonicalValue(left, right) {
  try {
    return canonicalSanitizedJSON(left) === canonicalSanitizedJSON(right);
  } catch {
    return false;
  }
}

function requireCustomDomainReceiptState(value, label, errors) {
  validateCustomDomainEdgeBinding(value?.edge_binding, `${label}.edge_binding`, errors);
  requireCondition(
    value?.conflicting_zone_route_count === 0,
    `${label}.conflicting_zone_route_count must be zero`,
    errors,
  );
  requireCondition(
    value?.manual_dns_origin_present === false,
    `${label}.manual_dns_origin_present must be false`,
    errors,
  );
}

function requireWorkerReadbackString(value, label) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${label} is required`);
  }
  return value;
}

function requireWorkerReadbackExactKeys(value, expected, label) {
  const actual = objectKeys(value);
  const wanted = [...expected].sort();
  if (
    actual.length !== wanted.length
    || !actual.every((key, index) => key === wanted[index])
  ) {
    throw new Error(`${label} keys must exactly match the sanitized Worker readback contract`);
  }
}

function sanitizedWorkerBinding(binding) {
  if (!binding || typeof binding !== "object" || Array.isArray(binding)) {
    throw new Error("Worker binding must be an object");
  }
  const name = requireWorkerReadbackString(binding.name, "Worker binding name");
  const type = requireWorkerReadbackString(binding.type, "Worker binding type");
  if (type === "plain_text") {
    requireWorkerReadbackExactKeys(
      binding,
      ["name", "type", "text"],
      "Worker plain-text binding",
    );
    const text = requireWorkerReadbackString(
      binding.text,
      "Worker plain-text binding value",
    );
    return { name, type, text };
  }
  if (type === "secret_text" || type === "version_metadata") {
    requireWorkerReadbackExactKeys(
      binding,
      ["name", "type"],
      "Worker non-disclosing binding",
    );
    return { name, type };
  }
  if (type === "hyperdrive") {
    requireWorkerReadbackExactKeys(
      binding,
      ["name", "type", "id"],
      "Worker Hyperdrive binding",
    );
    return {
      name,
      type,
      id: requireWorkerReadbackString(binding.id, "Worker Hyperdrive binding id"),
    };
  }
  if (type === "d1") {
    requireWorkerReadbackExactKeys(
      binding,
      ["name", "type", "id", "database_id"],
      "Worker D1 binding",
    );
    return {
      name,
      type,
      id: requireWorkerReadbackString(binding.id, "Worker D1 binding id"),
      database_id: requireWorkerReadbackString(
        binding.database_id,
        "Worker D1 binding database_id",
      ),
    };
  }
  if (type === "queue") {
    requireWorkerReadbackExactKeys(
      binding,
      ["name", "type", "queue_name"],
      "Worker Queue binding",
    );
    return {
      name,
      type,
      queue_name: requireWorkerReadbackString(
        binding.queue_name,
        "Worker Queue binding queue_name",
      ),
    };
  }
  throw new Error("Unsupported Worker binding type");
}

function normalizedStableBinding(binding) {
  const sanitized = sanitizedWorkerBinding(binding);
  if (
    sanitized.type === "plain_text"
    && greenfieldStageMutableWorkerBindings.includes(sanitized.name)
  ) {
    return {
      ...sanitized,
      text: "__GREENFIELD_STAGE_MUTABLE__",
    };
  }
  return sanitized;
}

function sanitizedWorkerResources(versionReadback) {
  const script = versionReadback?.resources?.script;
  const scriptRuntime = versionReadback?.resources?.script_runtime;
  const bindings = versionReadback?.resources?.bindings;
  if (!script || typeof script !== "object" || Array.isArray(script)) {
    throw new Error("Worker version readback script resource is required");
  }
  if (!scriptRuntime || typeof scriptRuntime !== "object" || Array.isArray(scriptRuntime)) {
    throw new Error("Worker version readback script runtime is required");
  }
  if (!Array.isArray(bindings)) {
    throw new Error("Worker version readback bindings are required");
  }
  const placement = script.placement ?? null;
  if (placement !== null) {
    requireWorkerReadbackExactKeys(
      placement,
      ["mode"],
      "Worker script placement",
    );
  }
  requireWorkerReadbackExactKeys(
    scriptRuntime,
    ["compatibility_date", "compatibility_flags", "usage_model"],
    "Worker script runtime",
  );
  if (!Array.isArray(scriptRuntime.compatibility_flags)) {
    throw new Error("Worker script runtime compatibility_flags must be an array");
  }
  return {
    script: {
      etag: requireWorkerReadbackString(script.etag, "Worker script ETag"),
      placement_mode: script.placement_mode ?? null,
      placement,
    },
    script_runtime: {
      compatibility_date: requireWorkerReadbackString(
        scriptRuntime.compatibility_date,
        "Worker compatibility date",
      ),
      compatibility_flags: scriptRuntime.compatibility_flags.map((flag) =>
        requireWorkerReadbackString(flag, "Worker compatibility flag")),
      usage_model: requireWorkerReadbackString(
        scriptRuntime.usage_model,
        "Worker usage model",
      ),
    },
    bindings: bindings
      .map(sanitizedWorkerBinding)
      .sort((left, right) => canonicalSanitizedJSON(left).localeCompare(
        canonicalSanitizedJSON(right),
      )),
  };
}

/**
 * Reduce a raw `wrangler versions view --json` object to the exact packet-safe
 * provider receipt. Author metadata and all secret values stay outside the
 * returned object; secret bindings carry names and types only.
 */
export function sanitizeWorkerVersionReadback(versionReadback, observedAtUTC) {
  if (!validUTCInstant(observedAtUTC)) {
    throw new Error("Worker version observedAtUTC must be a strict UTC instant");
  }
  const createdAt = new Date(versionReadback?.metadata?.created_on ?? "");
  if (Number.isNaN(createdAt.getTime())) {
    throw new Error("Worker version created timestamp is required");
  }
  const receipt = {
    worker_version_id: requireWorkerReadbackString(
      versionReadback?.id,
      "Worker version id",
    ),
    created_at_utc: createdAt.toISOString(),
    observed_at_utc: observedAtUTC,
    resources: sanitizedWorkerResources(versionReadback),
    readback_sha256: "",
  };
  receipt.readback_sha256 = computeSanitizedReceiptSha256(
    receiptPayload(receipt, "readback_sha256"),
  );
  return receipt;
}

/**
 * Hash the stable, non-secret portion of a Wrangler `versions view --json`
 * readback. The only values deliberately normalized away are the two staged
 * launch-mode bindings; their exact values remain mandatory in the separate
 * traffic receipts.
 */
export function computeStableWorkerBindingSha256(versionReadback) {
  const resources = sanitizedWorkerResources(versionReadback);
  const normalizedBindings = resources.bindings
    .map(normalizedStableBinding)
    .sort((left, right) => canonicalSanitizedJSON(left).localeCompare(
      canonicalSanitizedJSON(right),
    ));
  return computeSanitizedReceiptSha256({
    script_etag: resources.script.etag,
    placement_mode: resources.script.placement_mode,
    placement: resources.script.placement,
    script_runtime: resources.script_runtime,
    bindings: normalizedBindings,
  });
}

export function expectedProductionWorkerBindings(writeMode, onboardingMode) {
  const bindings = [
    { name: "ALLOW_UNMAPPED_CLERK_USERS", type: "plain_text", text: "false" },
    { name: "CF_VERSION_METADATA", type: "version_metadata" },
    { name: "CLERK_INSTANCE_ID", type: "plain_text", text: productionClerk.instanceId },
    { name: "CLERK_ISSUER", type: "plain_text", text: productionClerk.issuer },
    ...productionWorkerSecretNames.map((name) => ({ name, type: "secret_text" })),
    {
      name: "EXPECTED_DATABASE_BRANCH_ID",
      type: "plain_text",
      text: productionDatabase.branchId,
    },
    {
      name: "EXPECTED_DATABASE_MARKER",
      type: "plain_text",
      text: productionDatabase.runtimeMarker,
    },
    {
      name: "EXPECTED_DATABASE_ROLE_ID",
      type: "plain_text",
      text: productionDatabase.runtimeRoleId,
    },
    {
      name: "HYPERDRIVE",
      type: "hyperdrive",
      id: productionDatabase.hyperdriveId,
    },
    {
      name: "IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST",
      type: "plain_text",
      text: greenfieldAuthorizationDigest,
    },
    {
      name: "IDENTITY_RECONCILIATION_RECEIPT",
      type: "plain_text",
      text: greenfieldIdentityReceiptDigest,
    },
    {
      name: "MUTATION_LEDGER",
      type: "d1",
      id: productionLedgerResources.d1Id,
      database_id: productionLedgerResources.d1Id,
    },
    {
      name: "MUTATION_LEDGER_DLQ_NAME",
      type: "plain_text",
      text: productionLedgerResources.deadLetterQueueName,
    },
    {
      name: "MUTATION_LEDGER_ENCRYPTION_KEY_ID",
      type: "plain_text",
      text: productionLedgerResources.encryptionKeyId,
    },
    {
      name: "MUTATION_LEDGER_QUEUE",
      type: "queue",
      queue_name: productionLedgerResources.queueName,
    },
    {
      name: "NEW_USER_ONBOARDING_MODE",
      type: "plain_text",
      text: onboardingMode,
    },
    { name: "REFWATCH_ENV", type: "plain_text", text: productionWorker.environment },
    { name: "WRITE_MODE", type: "plain_text", text: writeMode },
  ];
  return bindings.sort((left, right) => canonicalSanitizedJSON(left).localeCompare(
    canonicalSanitizedJSON(right),
  ));
}

function validateWorkerVersionReadback(
  receipt,
  label,
  expectedVersionId,
  expectedCreatedAtUTC,
  expectedScriptEtag,
  expectedStableBindingSha256,
  expectedWriteMode,
  expectedOnboardingMode,
  errors,
) {
  requireExactKeys(
    receipt,
    [
      "worker_version_id",
      "created_at_utc",
      "observed_at_utc",
      "resources",
      "readback_sha256",
    ],
    label,
    errors,
  );
  requireCondition(
    receipt?.worker_version_id === expectedVersionId,
    `${label}.worker_version_id must match its Worker version`,
    errors,
  );
  requireUTCInstant(receipt?.created_at_utc, `${label}.created_at_utc`, errors);
  requireCondition(
    receipt?.created_at_utc === expectedCreatedAtUTC,
    `${label}.created_at_utc must match worker.versions`,
    errors,
  );
  requireUTCInstant(receipt?.observed_at_utc, `${label}.observed_at_utc`, errors);
  requireStrictlyBefore(
    receipt?.created_at_utc,
    receipt?.observed_at_utc,
    `${label}.observed_at_utc must follow Worker version creation`,
    errors,
  );
  requireInlineReceiptDigest(receipt, "readback_sha256", label, errors);
  requireExactKeys(
    receipt?.resources,
    ["script", "script_runtime", "bindings"],
    `${label}.resources`,
    errors,
  );
  requireExactKeys(
    receipt?.resources?.script,
    ["etag", "placement_mode", "placement"],
    `${label}.resources.script`,
    errors,
  );
  requireExactKeys(
    receipt?.resources?.script?.placement,
    ["mode"],
    `${label}.resources.script.placement`,
    errors,
  );
  requireExactKeys(
    receipt?.resources?.script_runtime,
    ["compatibility_date", "compatibility_flags", "usage_model"],
    `${label}.resources.script_runtime`,
    errors,
  );
  requireCondition(
    receipt?.resources?.script?.etag === expectedScriptEtag,
    `${label} script ETag must match worker.versions`,
    errors,
  );
  requireCondition(
    receipt?.resources?.script?.placement_mode === "smart"
      && receipt?.resources?.script?.placement?.mode === "smart",
    `${label} must use the reviewed smart placement`,
    errors,
  );
  requireCondition(
    receipt?.resources?.script_runtime?.compatibility_date === "2026-07-14",
    `${label} compatibility date must match the reviewed production runtime`,
    errors,
  );
  requireCondition(
    JSON.stringify(receipt?.resources?.script_runtime?.compatibility_flags)
      === JSON.stringify(["nodejs_compat"]),
    `${label} compatibility flags must match the reviewed production runtime`,
    errors,
  );
  requireCondition(
    receipt?.resources?.script_runtime?.usage_model === "standard",
    `${label} usage model must match the reviewed production runtime`,
    errors,
  );
  let sanitizedBindings;
  try {
    sanitizedBindings = (receipt?.resources?.bindings ?? [])
      .map(sanitizedWorkerBinding)
      .sort((left, right) => canonicalSanitizedJSON(left).localeCompare(
        canonicalSanitizedJSON(right),
      ));
  } catch {
    errors.push(`${label} bindings are not a safe sanitized provider readback`);
  }
  requireCondition(
    canonicalSanitizedJSON(sanitizedBindings ?? null)
      === canonicalSanitizedJSON(
        expectedProductionWorkerBindings(expectedWriteMode, expectedOnboardingMode),
      ),
    `${label} bindings must exactly match the reviewed production binding contract`,
    errors,
  );
  try {
    requireCondition(
      computeStableWorkerBindingSha256(receipt) === expectedStableBindingSha256,
      `${label} stable-binding SHA-256 must be recomputed from its provider readback`,
      errors,
    );
  } catch {
    errors.push(`${label} stable-binding contract is invalid`);
  }
}

function validateWorkerSecretLineage(lineage, versions, errors) {
  const label = "worker.secret_lineage";
  requireExactKeys(
    lineage,
    [
      "status",
      "receipt_kind",
      "receipt_id",
      "receipt_sha256",
      "observed_at_utc",
      "installation_method",
      "source_worker_version_id",
      "source_worker_version_created_at_utc",
      "candidate_worker_version_id",
      "candidate_worker_version_created_at_utc",
      "candidate_inherited_from_worker_version_id",
      "accepted_worker_version_id",
      "accepted_worker_version_created_at_utc",
      "accepted_inherited_from_worker_version_id",
      "required_secret_names",
      "unexpected_intervening_version_count",
      "intervening_secret_mutation_count",
      "upload_secret_override_count",
      "non_echoing_installation_status",
      "secret_values_recorded",
      "operator_confirmation_status",
      "provider_version_history_receipt_id",
      "provider_version_history_receipt_sha256",
    ],
    label,
    errors,
  );
  requireCondition(lineage?.status === "passed", `${label}.status must be passed`, errors);
  requireCondition(
    lineage?.receipt_kind === "worker_secret_lineage:sequential_inheritance",
    `${label}.receipt_kind must be worker_secret_lineage:sequential_inheritance`,
    errors,
  );
  requireNonEmpty(lineage?.receipt_id, `${label}.receipt_id`, errors);
  requireInlineReceiptDigest(lineage, "receipt_sha256", label, errors);
  requireUTCInstant(lineage?.observed_at_utc, `${label}.observed_at_utc`, errors);
  requireCondition(
    lineage?.installation_method
      === "wrangler_versions_secret_put_stdin_then_sequential_uploads",
    `${label}.installation_method must use non-echoing Wrangler secret installation followed by sequential uploads`,
    errors,
  );
  requireCondition(
    uuidPattern.test(lineage?.source_worker_version_id ?? ""),
    `${label}.source_worker_version_id must be a Worker version UUID`,
    errors,
  );
  requireUTCInstant(
    lineage?.source_worker_version_created_at_utc,
    `${label}.source_worker_version_created_at_utc`,
    errors,
  );
  requireCondition(
    lineage?.candidate_worker_version_id
      === versions.candidate_worker_version_id
      && lineage?.candidate_worker_version_created_at_utc
        === versions.candidate_worker_created_at_utc
      && lineage?.candidate_inherited_from_worker_version_id
        === lineage?.source_worker_version_id,
    `${label} must bind Worker A to the reviewed secret-source version`,
    errors,
  );
  requireCondition(
    lineage?.accepted_worker_version_id
      === versions.accepted_worker_version_id
      && lineage?.accepted_worker_version_created_at_utc
        === versions.accepted_worker_created_at_utc
      && lineage?.accepted_inherited_from_worker_version_id
        === versions.candidate_worker_version_id,
    `${label} must bind Worker B to sequential inheritance from Worker A`,
    errors,
  );
  requireCondition(
    new Set([
      lineage?.source_worker_version_id,
      versions.candidate_worker_version_id,
      versions.accepted_worker_version_id,
      versions.write_guard_worker_version_id,
      versions.last_known_good_worker_version_id,
    ]).size === 5,
    `${label} source, A, B, write-guard, and last-known-good versions must be distinct`,
    errors,
  );
  requireCondition(
    JSON.stringify(lineage?.required_secret_names)
      === JSON.stringify(productionWorkerSecretNames),
    `${label}.required_secret_names must exactly match the reviewed non-disclosing secret-name set`,
    errors,
  );
  requireCondition(
    lineage?.unexpected_intervening_version_count === 0,
    `${label}.unexpected_intervening_version_count must be zero`,
    errors,
  );
  requireCondition(
    lineage?.intervening_secret_mutation_count === 0,
    `${label}.intervening_secret_mutation_count must be zero`,
    errors,
  );
  requireCondition(
    lineage?.upload_secret_override_count === 0,
    `${label}.upload_secret_override_count must be zero`,
    errors,
  );
  requireCondition(
    lineage?.non_echoing_installation_status === "passed",
    `${label}.non_echoing_installation_status must be passed`,
    errors,
  );
  requireCondition(
    lineage?.secret_values_recorded === false,
    `${label}.secret_values_recorded must be false`,
    errors,
  );
  requireCondition(
    lineage?.operator_confirmation_status === "passed",
    `${label}.operator_confirmation_status must be passed`,
    errors,
  );
  requireNonEmpty(
    lineage?.provider_version_history_receipt_id,
    `${label}.provider_version_history_receipt_id`,
    errors,
  );
  requireReceiptPayloadDigest(
    lineage?.provider_version_history_receipt_sha256,
    {
      receipt_id: lineage?.provider_version_history_receipt_id,
      observed_at_utc: lineage?.observed_at_utc,
      worker_name: productionWorker.name,
      environment: productionWorker.environment,
      source_worker_version_id: lineage?.source_worker_version_id,
      source_worker_version_created_at_utc:
        lineage?.source_worker_version_created_at_utc,
      candidate_worker_version_id: lineage?.candidate_worker_version_id,
      candidate_worker_version_created_at_utc:
        lineage?.candidate_worker_version_created_at_utc,
      candidate_inherited_from_worker_version_id:
        lineage?.candidate_inherited_from_worker_version_id,
      accepted_worker_version_id: lineage?.accepted_worker_version_id,
      accepted_worker_version_created_at_utc:
        lineage?.accepted_worker_version_created_at_utc,
      accepted_inherited_from_worker_version_id:
        lineage?.accepted_inherited_from_worker_version_id,
      required_secret_names: lineage?.required_secret_names,
      unexpected_intervening_version_count:
        lineage?.unexpected_intervening_version_count,
      intervening_secret_mutation_count:
        lineage?.intervening_secret_mutation_count,
      upload_secret_override_count: lineage?.upload_secret_override_count,
    },
    `${label}.provider_version_history_receipt_sha256`,
    errors,
  );
  requireStrictlyBefore(
    lineage?.source_worker_version_created_at_utc,
    versions.candidate_worker_created_at_utc,
    `${label} secret-source version must precede Worker A`,
    errors,
  );
  requireStrictlyBefore(
    versions.candidate_worker_created_at_utc,
    versions.accepted_worker_created_at_utc,
    `${label} Worker A must precede Worker B`,
    errors,
  );
  requireStrictlyBefore(
    versions.accepted_worker_created_at_utc,
    lineage?.observed_at_utc,
    `${label} provider history readback must follow Worker B`,
    errors,
  );
}

function receiptPayload(value, digestField) {
  return Object.fromEntries(
    objectKeys(value)
      .filter((key) => key !== digestField)
      .map((key) => [key, value[key]]),
  );
}

function requireInlineReceiptDigest(value, digestField, label, errors) {
  requireSha256(value?.[digestField], `${label}.${digestField}`, errors);
  try {
    requireCondition(
      value?.[digestField] === computeSanitizedReceiptSha256(receiptPayload(value, digestField)),
      `${label}.${digestField} must match the canonical sanitized receipt payload`,
      errors,
    );
  } catch {
    errors.push(`${label} must contain a canonical sanitized receipt payload`);
  }
}

function requireReceiptPayloadDigest(digest, payload, label, errors) {
  requireSha256(digest, label, errors);
  try {
    requireCondition(
      digest === computeSanitizedReceiptSha256(payload),
      `${label} must match the canonical sanitized receipt payload`,
      errors,
    );
  } catch {
    errors.push(`${label} payload must be canonical and sanitized`);
  }
}

function requirePassedReceipt(value, label, expectedReceiptKind, errors) {
  requireExactKeys(
    value,
    [
      "status",
      "receipt_kind",
      "receipt_id",
      "receipt_sha256",
      "observed_at_utc",
      "worker_version_id",
      "clerk_instance_id",
      "database_branch_id",
    ],
    label,
    errors,
  );
  requireCondition(value?.status === "passed", `${label}.status must be passed`, errors);
  requireCondition(
    value?.receipt_kind === expectedReceiptKind,
    `${label}.receipt_kind must be ${expectedReceiptKind}`,
    errors,
  );
  requireNonEmpty(value?.receipt_id, `${label}.receipt_id`, errors);
  requireInlineReceiptDigest(value, "receipt_sha256", label, errors);
  requireUTCInstant(value?.observed_at_utc, `${label}.observed_at_utc`, errors);
}

function requireBoundedWebhookReceipt(value, errors) {
  const label = "acceptance.checks.webhook_lifecycle";
  requireExactKeys(
    value,
    [
      "status",
      "receipt_kind",
      "receipt_id",
      "receipt_sha256",
      "observed_at_utc",
      "worker_version_id",
      "clerk_instance_id",
      "database_branch_id",
      "delivery_source",
      "endpoint_path",
      "version_override_header_name",
      "version_override_header_present",
      "cutover_token_header_name",
      "cutover_token_header_present",
      "valid_signature_status",
      "invalid_signature_rejection_status",
    ],
    label,
    errors,
  );
  requireCondition(value?.status === "passed", `${label}.status must be passed`, errors);
  requireCondition(
    value?.receipt_kind === "acceptance:webhook_lifecycle",
    `${label}.receipt_kind must be acceptance:webhook_lifecycle`,
    errors,
  );
  requireNonEmpty(value?.receipt_id, `${label}.receipt_id`, errors);
  requireInlineReceiptDigest(value, "receipt_sha256", label, errors);
  requireUTCInstant(value?.observed_at_utc, `${label}.observed_at_utc`, errors);
  requireCondition(
    value?.delivery_source === "manual_signed_harness",
    `${label}.delivery_source must be manual_signed_harness`,
    errors,
  );
  requireCondition(
    value?.endpoint_path === "/webhooks/clerk",
    `${label}.endpoint_path must be /webhooks/clerk`,
    errors,
  );
  requireCondition(
    value?.version_override_header_name === cutoverAcceptance.overrideHeaderName
      && value?.version_override_header_present === true,
    `${label} must prove the exact Worker version-override header was present`,
    errors,
  );
  requireCondition(
    value?.cutover_token_header_name === cutoverAcceptance.tokenHeaderName
      && value?.cutover_token_header_present === true,
    `${label} must prove the exact Worker cutover-token header was present`,
    errors,
  );
  requireCondition(
    value?.valid_signature_status === "passed"
      && value?.invalid_signature_rejection_status === "passed",
    `${label} must prove valid-signature acceptance and invalid-signature rejection`,
    errors,
  );
}

function requireProductionReceiptBinding(value, label, expectedWorkerVersionId, errors) {
  requireCondition(
    value?.worker_version_id === expectedWorkerVersionId,
    `${label}.worker_version_id must match the expected Worker version`,
    errors,
  );
  requireCondition(
    value?.clerk_instance_id === productionClerk.instanceId,
    `${label}.clerk_instance_id must match the production Clerk instance`,
    errors,
  );
  requireCondition(
    value?.database_branch_id === productionDatabase.branchId,
    `${label}.database_branch_id must match the production database branch`,
    errors,
  );
}

function validateInactiveLedgerReceipt(value, label, errors) {
  requireExactKeys(
    value,
    [
      "status",
      "query_path",
      "query_sha256",
      "database_name",
      "database_branch_id",
      "runtime_marker",
      "total_epoch_count",
      "preparing_epoch_count",
      "open_epoch_count",
      "frozen_epoch_count",
      "archived_epoch_count",
      "capture_enforced_epoch_count",
      "entity_revision_count",
      "outbox_event_count",
      "outbox_delivery_count",
      "queue_consumer_count",
      "cron_consumer_count",
      "d1_consumer_count",
      "provider_readback_at_utc",
      "provider_readback_sha256",
    ],
    label,
    errors,
  );
  requireCondition(
    value?.status === "inactive_with_optional_history",
    `${label}.status must be inactive_with_optional_history`,
    errors,
  );
  requireCondition(
    value?.query_path === ledgerReadback.queryPath,
    `${label}.query_path must identify the trusted ledger readback`,
    errors,
  );
  requireCondition(
    value?.query_sha256 === ledgerReadback.querySha256,
    `${label}.query_sha256 must match the trusted ledger readback`,
    errors,
  );
  requireCondition(
    value?.database_name === productionRuntimeProvisioningTarget.databaseName,
    `${label}.database_name must be ${productionRuntimeProvisioningTarget.databaseName}`,
    errors,
  );
  requireCondition(
    value?.database_branch_id === productionDatabase.branchId,
    `${label}.database_branch_id must match production`,
    errors,
  );
  requireCondition(
    value?.runtime_marker === productionDatabase.runtimeMarker,
    `${label}.runtime_marker must match production`,
    errors,
  );
  for (const name of [
    "total_epoch_count",
    "preparing_epoch_count",
    "open_epoch_count",
    "frozen_epoch_count",
    "archived_epoch_count",
    "capture_enforced_epoch_count",
    "entity_revision_count",
    "outbox_event_count",
    "outbox_delivery_count",
  ]) {
    requireCondition(
      Number.isInteger(value?.[name]) && value[name] >= 0,
      `${label}.${name} must be a non-negative integer`,
      errors,
    );
  }
  requireCondition(value?.open_epoch_count === 0, `${label}.open_epoch_count must be zero`, errors);
  requireCondition(
    value?.preparing_epoch_count === 0,
    `${label}.preparing_epoch_count must be zero`,
    errors,
  );
  requireCondition(
    value?.capture_enforced_epoch_count === 0,
    `${label}.capture_enforced_epoch_count must be zero`,
    errors,
  );
  requireCondition(
    value?.total_epoch_count
      === value?.preparing_epoch_count
        + value?.open_epoch_count
        + value?.frozen_epoch_count
        + value?.archived_epoch_count,
    `${label} epoch classification must sum to total_epoch_count`,
    errors,
  );
  for (const name of ["queue_consumer_count", "cron_consumer_count", "d1_consumer_count"]) {
    requireCondition(value?.[name] === 0, `${label}.${name} must be zero`, errors);
  }
  requireUTCInstant(value?.provider_readback_at_utc, `${label}.provider_readback_at_utc`, errors);
  requireInlineReceiptDigest(value, "provider_readback_sha256", label, errors);
}

/**
 * Validate the final greenfield production launch packet.
 *
 * This validator is intentionally separate from the retained stateful Supabase
 * cutover bundle. It validates provider readbacks and bounded acceptance, never
 * imported legacy rows or a mutation-ledger recovery claim.
 */
function validateGreenfieldLaunchPacketContract(
  packet,
  options,
  contractVersion,
) {
  const errors = [];
  const validOptions =
    options !== null
    && typeof options === "object"
    && !Array.isArray(options)
    && (
      Object.getPrototypeOf(options) === Object.prototype
      || Object.getPrototypeOf(options) === null
    );
  requireCondition(
    validOptions,
    "validation options must be an object",
    errors,
  );
  requireCondition(
    validOptions
      && objectKeys(options).every((key) => key === "now"),
    "validation options may only contain now",
    errors,
  );
  const hasNow = validOptions && Object.hasOwn(options, "now");
  const now =
    hasNow && options.now !== undefined
      ? options.now
      : new Date();
  const validNow =
    now instanceof Date
    && Number.isFinite(now.getTime());
  requireCondition(
    validNow,
    "validation options.now must be a valid Date",
    errors,
  );
  const nowMillis = validNow ? now.getTime() : null;
  const authorization = packet?.authorization ?? {};
  const clerk = packet?.clerk ?? {};
  const worker = packet?.worker ?? {};
  const versions = worker?.versions ?? {};
  const secretLineage = worker?.secret_lineage ?? {};
  const database = packet?.database ?? {};
  const databaseTarget = database?.target ?? {};
  const schema = database?.schema ?? {};
  const schemaReadback = schema?.provider_readback ?? {};
  const seed = database?.deterministic_seed ?? {};
  const cleanTarget = database?.clean_target_before_bootstrap ?? {};
  const identity = packet?.identity_bootstrap ?? {};
  const ledger = packet?.ledger ?? {};
  const finalLedger = packet?.final_ledger ?? {};
  const acceptance = packet?.acceptance ?? {};
  const window = acceptance?.bounded_window ?? {};
  const checks = acceptance?.checks ?? {};
  const rollback = packet?.rollback ?? {};
  const devices = packet?.physical_device_acceptance ?? {};
  const iphone = devices?.iphone_15_pro_max ?? {};
  const watch = devices?.apple_watch_series_9_45mm ?? {};
  const releaseConfig = devices?.release_configuration ?? {};
  const traffic = packet?.traffic_and_writes ?? {};
  const initialTraffic = traffic?.initial_candidate ?? {};
  const boundedTraffic = traffic?.bounded_acceptance_route ?? {};
  const promotedWebhook = traffic?.promoted_webhook_acceptance ?? {};
  const acceptedTraffic = traffic?.accepted_cutover ?? {};
  const isV3 = contractVersion === 3;
  const expectedLaunchProfile = isV3
    ? greenfieldLaunchProfile
    : historicalGreenfieldLaunchProfile;
  const expectedRollbackProfile = isV3
    ? greenfieldRollbackProfile
    : historicalGreenfieldRollbackProfile;

  requireCondition(
    packet?.launch_profile === expectedLaunchProfile,
    `launch_profile must be ${expectedLaunchProfile}`,
    errors,
  );
  requireCondition(
    packet?.schema_version === contractVersion,
    `schema_version must be ${contractVersion}`,
    errors,
  );
  requireCondition(packet?.status === "accepted", "status must be accepted", errors);

  const mixedClaims = statefulClaimKeys.filter((key) => Object.hasOwn(packet ?? {}, key));
  requireCondition(
    mixedClaims.length === 0,
    `greenfield launch packet must not contain stateful migration claims${mixedClaims.length > 0 ? `: ${mixedClaims.join(", ")}` : ""}`,
    errors,
  );
  requireExactKeys(
    packet,
    [
      "schema_version",
      "launch_profile",
      "status",
      "authorization",
      "clerk",
      "worker",
      "database",
      "identity_bootstrap",
      "ledger",
      "final_ledger",
      "acceptance",
      "rollback",
      "physical_device_acceptance",
      "traffic_and_writes",
    ],
    "packet",
    errors,
  );

  requireExactKeys(
    authorization,
    ["profile", "decision_artifact", "decision_sha256"],
    "authorization",
    errors,
  );
  requireCondition(
    authorization.profile === greenfieldAuthorizationProfile,
    `authorization.profile must be ${greenfieldAuthorizationProfile}`,
    errors,
  );
  requireCondition(
    authorization.decision_artifact === greenfieldAuthorizationArtifact,
    "authorization.decision_artifact must name the 2026-07-20 greenfield authorization",
    errors,
  );
  requireCondition(
    authorization.decision_sha256 === greenfieldAuthorizationDigest,
    "authorization.decision_sha256 must match the approved 2026-07-20 decision digest",
    errors,
  );

  requireExactKeys(
    clerk,
    [
      "instance_id",
      "domain",
      "issuer",
      "clean_user_count",
      "provider_readback_at_utc",
      "provider_readback_sha256",
    ],
    "clerk",
    errors,
  );
  requireCondition(
    clerk.instance_id === productionClerk.instanceId,
    "clerk.instance_id must identify the exact production Clerk instance",
    errors,
  );
  requireCondition(
    clerk.domain === productionClerk.domain,
    "clerk.domain must identify the exact production Clerk domain",
    errors,
  );
  requireCondition(
    clerk.issuer === productionClerk.issuer,
    "clerk.issuer must identify the exact production Clerk issuer",
    errors,
  );
  requireCondition(clerk.clean_user_count === 0, "clerk.clean_user_count must be zero before bootstrap", errors);
  requireUTCInstant(clerk.provider_readback_at_utc, "clerk.provider_readback_at_utc", errors);
  requireInlineReceiptDigest(clerk, "provider_readback_sha256", "clerk", errors);

  requireExactKeys(
    worker,
    [
      "name",
      "environment",
      "versions",
      "secret_lineage",
      "provider_readback_at_utc",
      "provider_readback_sha256",
    ],
    "worker",
    errors,
  );
  requireCondition(worker.name === productionWorker.name, "worker.name must be refwatch-api", errors);
  requireCondition(worker.environment === productionWorker.environment, "worker.environment must be production", errors);
  requireUTCInstant(worker.provider_readback_at_utc, "worker.provider_readback_at_utc", errors);
  requireInlineReceiptDigest(worker, "provider_readback_sha256", "worker", errors);
  requireExactKeys(
    versions,
    [
      "candidate_worker_version_id",
      "accepted_worker_version_id",
      "write_guard_worker_version_id",
      "last_known_good_worker_version_id",
      "candidate_worker_created_at_utc",
      "accepted_worker_created_at_utc",
      "candidate_script_etag",
      "accepted_script_etag",
      "candidate_stable_binding_sha256",
      "accepted_stable_binding_sha256",
      "candidate_sanitized_readback",
      "accepted_sanitized_readback",
    ],
    "worker.versions",
    errors,
  );
  for (const name of [
    "candidate_worker_version_id",
    "accepted_worker_version_id",
    "write_guard_worker_version_id",
    "last_known_good_worker_version_id",
  ]) {
    requireCondition(
      uuidPattern.test(versions[name] ?? ""),
      `worker.versions.${name} must be a Worker version UUID`,
      errors,
    );
  }
  requireCondition(
    new Set([
      versions.candidate_worker_version_id,
      versions.accepted_worker_version_id,
      versions.write_guard_worker_version_id,
      versions.last_known_good_worker_version_id,
    ]).size === 4,
    "disabled candidate, accepted candidate, write-guard, and last-known-good Worker versions must be distinct",
    errors,
  );
  requireUTCInstant(
    versions.candidate_worker_created_at_utc,
    "worker.versions.candidate_worker_created_at_utc",
    errors,
  );
  requireUTCInstant(
    versions.accepted_worker_created_at_utc,
    "worker.versions.accepted_worker_created_at_utc",
    errors,
  );
  requireSha256(
    versions.candidate_script_etag,
    "worker.versions.candidate_script_etag",
    errors,
  );
  requireSha256(
    versions.accepted_script_etag,
    "worker.versions.accepted_script_etag",
    errors,
  );
  requireSha256(
    versions.candidate_stable_binding_sha256,
    "worker.versions.candidate_stable_binding_sha256",
    errors,
  );
  requireSha256(
    versions.accepted_stable_binding_sha256,
    "worker.versions.accepted_stable_binding_sha256",
    errors,
  );
  requireCondition(
    versions.candidate_script_etag === versions.accepted_script_etag,
    "disabled and accepted candidate Worker versions must have the same script ETag",
    errors,
  );
  requireCondition(
    versions.candidate_stable_binding_sha256
      === versions.accepted_stable_binding_sha256,
    "disabled and accepted candidate Worker versions must have the same stable-binding contract",
    errors,
  );
  validateWorkerVersionReadback(
    versions.candidate_sanitized_readback,
    "worker.versions.candidate_sanitized_readback",
    versions.candidate_worker_version_id,
    versions.candidate_worker_created_at_utc,
    versions.candidate_script_etag,
    versions.candidate_stable_binding_sha256,
    "disabled",
    "disabled",
    errors,
  );
  validateWorkerVersionReadback(
    versions.accepted_sanitized_readback,
    "worker.versions.accepted_sanitized_readback",
    versions.accepted_worker_version_id,
    versions.accepted_worker_created_at_utc,
    versions.accepted_script_etag,
    versions.accepted_stable_binding_sha256,
    "enabled",
    "greenfield_bootstrap",
    errors,
  );
  requireStrictlyBefore(
    versions.candidate_sanitized_readback?.observed_at_utc,
    worker.provider_readback_at_utc,
    "candidate sanitized Worker readback must precede the aggregate Worker receipt",
    errors,
  );
  requireStrictlyBefore(
    versions.accepted_sanitized_readback?.observed_at_utc,
    worker.provider_readback_at_utc,
    "accepted sanitized Worker readback must precede the aggregate Worker receipt",
    errors,
  );
  validateWorkerSecretLineage(secretLineage, versions, errors);
  requireStrictlyBefore(
    secretLineage.observed_at_utc,
    worker.provider_readback_at_utc,
    "Worker secret-lineage readback must precede the aggregate Worker receipt",
    errors,
  );

  requireExactKeys(
    database,
    ["target", "schema", "deterministic_seed", "clean_target_before_bootstrap"],
    "database",
    errors,
  );
  requireExactKeys(
    databaseTarget,
    [
      "organization",
      "database",
      "branch",
      "branch_id",
      "runtime_marker",
      "runtime_role_id",
      "hyperdrive_id",
    ],
    "database.target",
    errors,
  );
  requireCondition(
    databaseTarget.organization === productionDatabase.organization,
    "database.target.organization must be ibrahim-aka-ajax",
    errors,
  );
  requireCondition(
    databaseTarget.database === productionDatabase.database,
    "database.target.database must be refwatch",
    errors,
  );
  requireCondition(
    databaseTarget.branch === productionDatabase.branch,
    "database.target.branch must be main",
    errors,
  );
  requireCondition(
    databaseTarget.branch_id === productionDatabase.branchId,
    "database.target.branch_id must be w3g1f8vcbg34",
    errors,
  );
  requireCondition(
    databaseTarget.runtime_marker === productionDatabase.runtimeMarker,
    "database.target.runtime_marker must identify the exact production branch",
    errors,
  );
  requireCondition(
    databaseTarget.runtime_role_id === productionDatabase.runtimeRoleId,
    "database.target.runtime_role_id must identify the reviewed durable production role",
    errors,
  );
  requireCondition(
    databaseTarget.hyperdrive_id === productionDatabase.hyperdriveId,
    "database.target.hyperdrive_id must identify the reviewed durable production Hyperdrive",
    errors,
  );
  requireExactKeys(
    schema,
    [
      "status",
      "migration_head",
      "migration_count",
      "repository_snapshot_path",
      "repository_snapshot_sha256",
      "provider_query_path",
      "provider_query_sha256",
      "provider_readback",
      "provider_receipt_sha256",
    ],
    "database.schema",
    errors,
  );
  requireCondition(schema.status === "reviewed", "database.schema.status must be reviewed", errors);
  requireCondition(
    schema.migration_head === reviewedSchema.migrationHead,
    `database.schema.migration_head must be ${reviewedSchema.migrationHead}`,
    errors,
  );
  requireCondition(
    schema.migration_count === reviewedSchema.migrationCount,
    `database.schema.migration_count must be ${reviewedSchema.migrationCount}`,
    errors,
  );
  requireCondition(
    schema.repository_snapshot_path === reviewedSchema.repositorySnapshotPath,
    `database.schema.repository_snapshot_path must identify the reviewed ${reviewedSchema.migrationHead} snapshot`,
    errors,
  );
  requireCondition(
    schema.repository_snapshot_sha256 === reviewedSchema.repositorySnapshotSha256,
    `database.schema.repository_snapshot_sha256 must match the reviewed ${reviewedSchema.migrationHead} snapshot`,
    errors,
  );
  requireCondition(
    schema.provider_query_path === reviewedSchema.providerQueryPath,
    "database.schema.provider_query_path must identify the trusted schema readback",
    errors,
  );
  requireCondition(
    schema.provider_query_sha256 === reviewedSchema.providerQuerySha256,
    "database.schema.provider_query_sha256 must match the trusted schema readback",
    errors,
  );
  requireExactKeys(
    schemaReadback,
    [
      "observed_at_utc",
      "database_name",
      "database_branch_id",
      "runtime_marker",
      "migration_count",
      "migration_head_id",
      "migration_head_hash",
      "migration_history_md5",
      "public_table_count",
      "public_table_names_md5",
      "public_table_properties_count",
      "public_table_properties_md5",
      "public_column_count",
      "public_columns_md5",
      "public_constraint_count",
      "public_constraints_md5",
      "public_index_count",
      "public_indexes_md5",
      "public_trigger_count",
      "public_triggers_md5",
      "public_function_count",
      "public_functions_md5",
      "public_enum_label_count",
      "public_enum_labels_md5",
      "catalog_contract_md5",
    ],
    "database.schema.provider_readback",
    errors,
  );
  requireUTCInstant(
    schemaReadback.observed_at_utc,
    "database.schema.provider_readback.observed_at_utc",
    errors,
  );
  requireCondition(
    schemaReadback.database_name
      === productionRuntimeProvisioningTarget.databaseName,
    `database.schema provider readback must identify database ${productionRuntimeProvisioningTarget.databaseName}`,
    errors,
  );
  requireCondition(
    schemaReadback.database_branch_id === productionDatabase.branchId,
    "database.schema provider readback must identify branch w3g1f8vcbg34",
    errors,
  );
  requireCondition(
    schemaReadback.runtime_marker === productionDatabase.runtimeMarker,
    "database.schema provider readback must identify the production runtime marker",
    errors,
  );
  requireCondition(
    schemaReadback.migration_count === reviewedSchema.migrationCount,
    `database.schema provider migration_count must be ${reviewedSchema.migrationCount}`,
    errors,
  );
  requireCondition(
    schemaReadback.migration_head_id === reviewedSchema.migrationHeadId,
    `database.schema provider migration_head_id must be ${reviewedSchema.migrationHeadId}`,
    errors,
  );
  requireCondition(
    schemaReadback.migration_head_hash === reviewedSchema.migrationHeadHash,
    `database.schema provider migration_head_hash must match migration ${reviewedSchema.migrationHead}`,
    errors,
  );
  requireCondition(
    schemaReadback.migration_history_md5 === reviewedSchema.migrationHistoryMd5,
    "database.schema provider migration_history_md5 must match the reviewed history",
    errors,
  );
  requireCondition(
    schemaReadback.public_table_count === reviewedSchema.publicTableCount,
    "database.schema provider public_table_count must be 36",
    errors,
  );
  requireCondition(
    schemaReadback.public_table_names_md5 === reviewedSchema.publicTableNamesMd5,
    "database.schema provider public_table_names_md5 must match the reviewed schema",
    errors,
  );
  for (const [field, expected, label] of [
    [
      "public_table_properties_count",
      reviewedSchema.publicTablePropertiesCount,
      "public table-properties count",
    ],
    [
      "public_table_properties_md5",
      reviewedSchema.publicTablePropertiesMd5,
      "public table-properties contract",
    ],
    ["public_column_count", reviewedSchema.publicColumnCount, "public column count"],
    ["public_columns_md5", reviewedSchema.publicColumnsMd5, "public column contract"],
    [
      "public_constraint_count",
      reviewedSchema.publicConstraintCount,
      "public constraint count",
    ],
    [
      "public_constraints_md5",
      reviewedSchema.publicConstraintsMd5,
      "public constraint contract",
    ],
    ["public_index_count", reviewedSchema.publicIndexCount, "public index count"],
    ["public_indexes_md5", reviewedSchema.publicIndexesMd5, "public index contract"],
    ["public_trigger_count", reviewedSchema.publicTriggerCount, "public trigger count"],
    [
      "public_triggers_md5",
      reviewedSchema.publicTriggersMd5,
      "public trigger contract",
    ],
    [
      "public_function_count",
      reviewedSchema.publicFunctionCount,
      "public function count",
    ],
    [
      "public_functions_md5",
      reviewedSchema.publicFunctionsMd5,
      "public function contract",
    ],
    [
      "public_enum_label_count",
      reviewedSchema.publicEnumLabelCount,
      "public enum-label count",
    ],
    [
      "public_enum_labels_md5",
      reviewedSchema.publicEnumLabelsMd5,
      "public enum-label contract",
    ],
    [
      "catalog_contract_md5",
      reviewedSchema.catalogContractMd5,
      "complete catalog contract",
    ],
  ]) {
    requireCondition(
      schemaReadback[field] === expected,
      `database.schema provider ${label} must match the reviewed catalog`,
      errors,
    );
  }
  requireInlineReceiptDigest(
    schema,
    "provider_receipt_sha256",
    "database.schema",
    errors,
  );

  requireExactKeys(
    seed,
    [
      "status",
      "repository_migration_path",
      "repository_migration_sha256",
      "reference_competitions_count",
      "reference_competitions_business_md5",
      "reference_teams_count",
      "reference_teams_business_md5",
      "reference_disciplinary_codes_count",
      "reference_disciplinary_rules_count",
      "global_workout_presets_count",
      "provider_query_path",
      "provider_query_sha256",
      "database_branch_id",
      "runtime_marker",
      "provider_readback_at_utc",
      "provider_readback_sha256",
    ],
    "database.deterministic_seed",
    errors,
  );
  requireCondition(seed.status === "reviewed", "database.deterministic_seed.status must be reviewed", errors);
  requireCondition(
    seed.repository_migration_path === reviewedDeterministicSeed.migrationPath,
    "database.deterministic_seed.repository_migration_path must identify migration 0002",
    errors,
  );
  requireCondition(
    seed.repository_migration_sha256 === reviewedDeterministicSeed.migrationSha256,
    "database.deterministic_seed.repository_migration_sha256 must match migration 0002",
    errors,
  );
  requireCondition(
    seed.reference_competitions_count === reviewedDeterministicSeed.referenceCompetitionsCount,
    "database.deterministic_seed.reference_competitions_count must be 5",
    errors,
  );
  requireCondition(
    md5Pattern.test(seed.reference_competitions_business_md5 ?? "")
      && seed.reference_competitions_business_md5
        === reviewedDeterministicSeed.referenceCompetitionsBusinessMd5,
    "database.deterministic_seed.reference_competitions_business_md5 must match the reviewed value",
    errors,
  );
  requireCondition(
    seed.reference_teams_count === reviewedDeterministicSeed.referenceTeamsCount,
    "database.deterministic_seed.reference_teams_count must be 54",
    errors,
  );
  requireCondition(
    md5Pattern.test(seed.reference_teams_business_md5 ?? "")
      && seed.reference_teams_business_md5 === reviewedDeterministicSeed.referenceTeamsBusinessMd5,
    "database.deterministic_seed.reference_teams_business_md5 must match the reviewed value",
    errors,
  );
  requireCondition(
    seed.reference_disciplinary_codes_count
      === reviewedDeterministicSeed.referenceDisciplinaryCodesCount,
    "database.deterministic_seed.reference_disciplinary_codes_count must be zero",
    errors,
  );
  requireCondition(
    seed.reference_disciplinary_rules_count
      === reviewedDeterministicSeed.referenceDisciplinaryRulesCount,
    "database.deterministic_seed.reference_disciplinary_rules_count must be zero",
    errors,
  );
  requireCondition(
    seed.global_workout_presets_count === reviewedDeterministicSeed.globalWorkoutPresetsCount,
    "database.deterministic_seed.global_workout_presets_count must be zero",
    errors,
  );
  requireCondition(
    seed.provider_query_path === cleanTargetReadback.queryPath,
    "database.deterministic_seed.provider_query_path must identify the trusted baseline readback",
    errors,
  );
  requireCondition(
    seed.provider_query_sha256 === cleanTargetReadback.querySha256,
    "database.deterministic_seed.provider_query_sha256 must match the trusted baseline readback",
    errors,
  );
  requireCondition(
    seed.database_branch_id === productionDatabase.branchId,
    "database.deterministic_seed.database_branch_id must match production",
    errors,
  );
  requireCondition(
    seed.runtime_marker === productionDatabase.runtimeMarker,
    "database.deterministic_seed.runtime_marker must match production",
    errors,
  );
  requireUTCInstant(
    seed.provider_readback_at_utc,
    "database.deterministic_seed.provider_readback_at_utc",
    errors,
  );
  requireInlineReceiptDigest(
    seed,
    "provider_readback_sha256",
    "database.deterministic_seed",
    errors,
  );

  requireExactKeys(
    cleanTarget,
    [
      "query_path",
      "query_sha256",
      "database_branch_id",
      "runtime_marker",
      "provider_readback_at_utc",
      "provider_readback_sha256",
      "inventory",
    ],
    "database.clean_target_before_bootstrap",
    errors,
  );
  requireCondition(
    cleanTarget.query_path === cleanTargetReadback.queryPath,
    "database.clean_target_before_bootstrap.query_path must identify the trusted readback query",
    errors,
  );
  requireCondition(
    cleanTarget.query_sha256 === cleanTargetReadback.querySha256,
    "database.clean_target_before_bootstrap.query_sha256 must match the trusted readback query",
    errors,
  );
  requireCondition(
    cleanTarget.database_branch_id === productionDatabase.branchId,
    "database.clean_target_before_bootstrap.database_branch_id must match production",
    errors,
  );
  requireCondition(
    cleanTarget.runtime_marker === productionDatabase.runtimeMarker,
    "database.clean_target_before_bootstrap.runtime_marker must match production",
    errors,
  );
  requireExactKeys(
    cleanTarget.inventory,
    greenfieldCleanTargetTables,
    "database.clean_target_before_bootstrap.inventory",
    errors,
  );
  for (const name of greenfieldCleanTargetTables) {
    requireCondition(
      cleanTarget.inventory?.[name] === 0,
      `database.clean_target_before_bootstrap.inventory.${name} must be zero`,
      errors,
    );
  }
  requireUTCInstant(
    cleanTarget.provider_readback_at_utc,
    "database.clean_target_before_bootstrap.provider_readback_at_utc",
    errors,
  );
  requireSha256(
    cleanTarget.provider_readback_sha256,
    "database.clean_target_before_bootstrap.provider_readback_sha256",
    errors,
  );
  requireInlineReceiptDigest(
    cleanTarget,
    "provider_readback_sha256",
    "database.clean_target_before_bootstrap",
    errors,
  );

  requireExactKeys(
    identity,
    [
      "reconciliation_profile",
      "receipt_digest",
      "authorization_digest",
      "mapping_hash",
      "legacy_mapping_count",
      "activated",
      "activated_at_utc",
      "activation_receipt_id",
      "activation_receipt_sha256",
      "activation_observed_at_utc",
      "clerk_instance_id",
      "database_branch_id",
    ],
    "identity_bootstrap",
    errors,
  );
  requireCondition(
    identity.reconciliation_profile === greenfieldIdentityProfile,
    `identity_bootstrap.reconciliation_profile must be ${greenfieldIdentityProfile}`,
    errors,
  );
  requireCondition(
    identity.receipt_digest === greenfieldIdentityReceiptDigest,
    "identity_bootstrap.receipt_digest must match the approved zero-legacy receipt",
    errors,
  );
  requireCondition(
    identity.authorization_digest === greenfieldAuthorizationDigest,
    "identity_bootstrap.authorization_digest must match the approved greenfield decision",
    errors,
  );
  requireCondition(
    identity.mapping_hash === greenfieldEmptyMappingHash,
    "identity_bootstrap.mapping_hash must be the canonical empty mapping hash",
    errors,
  );
  requireCondition(identity.legacy_mapping_count === 0, "identity_bootstrap.legacy_mapping_count must be zero", errors);
  requireCondition(identity.activated === true, "identity_bootstrap.activated must be true", errors);
  requireUTCInstant(identity.activated_at_utc, "identity_bootstrap.activated_at_utc", errors);
  requireNonEmpty(identity.activation_receipt_id, "identity_bootstrap.activation_receipt_id", errors);
  requireInlineReceiptDigest(
    identity,
    "activation_receipt_sha256",
    "identity_bootstrap",
    errors,
  );
  requireUTCInstant(
    identity.activation_observed_at_utc,
    "identity_bootstrap.activation_observed_at_utc",
    errors,
  );
  requireCondition(
    identity.clerk_instance_id === productionClerk.instanceId,
    "identity_bootstrap.clerk_instance_id must match the production Clerk instance",
    errors,
  );
  requireCondition(
    identity.database_branch_id === productionDatabase.branchId,
    "identity_bootstrap.database_branch_id must match the production database branch",
    errors,
  );
  requireStrictlyBefore(
    identity.activated_at_utc,
    identity.activation_observed_at_utc,
    "identity activation observation must occur after activation",
    errors,
  );
  requireStrictlyBefore(
    cleanTarget.provider_readback_at_utc,
    identity.activated_at_utc,
    "greenfield bootstrap activation must follow the clean-target readback",
    errors,
  );
  requireStrictlyBefore(
    clerk.provider_readback_at_utc,
    identity.activated_at_utc,
    "greenfield bootstrap activation must follow the clean Clerk readback",
    errors,
  );
  requireStrictlyBefore(
    identity.activation_observed_at_utc,
    secretLineage.source_worker_version_created_at_utc,
    "Worker secret installation must follow identity activation observation",
    errors,
  );
  requireStrictlyBefore(
    identity.activation_observed_at_utc,
    versions.candidate_worker_created_at_utc,
    "disabled candidate Worker creation must follow identity activation observation",
    errors,
  );
  requireStrictlyBefore(
    secretLineage.source_worker_version_created_at_utc,
    versions.candidate_worker_created_at_utc,
    "disabled candidate Worker creation must follow the secret-source version",
    errors,
  );
  requireStrictlyBefore(
    versions.candidate_worker_created_at_utc,
    versions.accepted_worker_created_at_utc,
    "accepted candidate Worker creation must follow disabled candidate creation",
    errors,
  );
  requireStrictlyBefore(
    versions.accepted_worker_created_at_utc,
    worker.provider_readback_at_utc,
    "Worker version readback must follow accepted candidate creation",
    errors,
  );

  validateInactiveLedgerReceipt(ledger, "ledger", errors);
  validateInactiveLedgerReceipt(finalLedger, "final_ledger", errors);
  for (const name of [
    "total_epoch_count",
    "preparing_epoch_count",
    "open_epoch_count",
    "frozen_epoch_count",
    "archived_epoch_count",
    "capture_enforced_epoch_count",
    "entity_revision_count",
    "outbox_event_count",
    "outbox_delivery_count",
    "queue_consumer_count",
    "cron_consumer_count",
    "d1_consumer_count",
  ]) {
    requireCondition(
      finalLedger?.[name] === ledger?.[name],
      `final_ledger.${name} must remain equal to the pre-launch inactive-ledger baseline`,
      errors,
    );
  }

  requireExactKeys(acceptance, ["bounded_window", "checks"], "acceptance", errors);
  requireExactKeys(
    window,
    [
      "started_at_utc",
      "completed_at_utc",
      "max_requests",
      "observed_requests",
      "max_test_identities",
      "observed_test_identities",
      "write_mode",
      "new_user_onboarding_mode",
      "traffic_scope",
      "reconciliation_receipt_digest",
      "worker_version_id",
    ],
    "acceptance.bounded_window",
    errors,
  );
  requireUTCInstant(window.started_at_utc, "acceptance.bounded_window.started_at_utc", errors);
  requireUTCInstant(window.completed_at_utc, "acceptance.bounded_window.completed_at_utc", errors);
  requireStrictlyBefore(
    window.started_at_utc,
    window.completed_at_utc,
    "acceptance bounded window completion must follow its start",
    errors,
  );
  requireStrictlyBefore(
    identity.activated_at_utc,
    window.started_at_utc,
    "bounded acceptance must begin after greenfield bootstrap activation",
    errors,
  );
  requireStrictlyBefore(
    identity.activation_observed_at_utc,
    window.started_at_utc,
    "bounded acceptance must begin after identity activation is observed",
    errors,
  );
  requireStrictlyBefore(
    initialTraffic.verified_at_utc,
    window.started_at_utc,
    "bounded acceptance must begin after write-disabled candidate verification",
    errors,
  );
  requireCondition(
    Number.isInteger(window.max_requests) && window.max_requests > 0 && window.max_requests <= 1_000,
    "acceptance.bounded_window.max_requests must be an integer from 1 through 1000",
    errors,
  );
  requireCondition(
    Number.isInteger(window.observed_requests)
      && window.observed_requests > 0
      && window.observed_requests <= window.max_requests,
    "acceptance observed_requests must be positive and no greater than max_requests",
    errors,
  );
  requireCondition(
    Number.isInteger(window.max_test_identities)
      && window.max_test_identities > 0
      && window.max_test_identities <= 10,
    "acceptance.bounded_window.max_test_identities must be an integer from 1 through 10",
    errors,
  );
  requireCondition(
    Number.isInteger(window.observed_test_identities)
      && window.observed_test_identities > 0
      && window.observed_test_identities <= window.max_test_identities,
    "acceptance observed_test_identities must be positive and no greater than max_test_identities",
    errors,
  );
  requireCondition(
    window.write_mode === "enabled",
    "acceptance.bounded_window.write_mode must be enabled",
    errors,
  );
  requireCondition(
    window.new_user_onboarding_mode === "greenfield_bootstrap",
    "acceptance.bounded_window.new_user_onboarding_mode must be greenfield_bootstrap",
    errors,
  );
  requireCondition(
    window.traffic_scope === "bounded_test_only",
    "acceptance.bounded_window.traffic_scope must be bounded_test_only",
    errors,
  );
  requireCondition(
    window.reconciliation_receipt_digest === greenfieldIdentityReceiptDigest,
    "acceptance.bounded_window.reconciliation_receipt_digest must match the approved receipt",
    errors,
  );
  requireCondition(
    window.worker_version_id === versions.accepted_worker_version_id,
    "acceptance.bounded_window.worker_version_id must match the accepted Worker version",
    errors,
  );
  requireExactKeys(checks, greenfieldAcceptanceChecks, "acceptance.checks", errors);
  for (const name of greenfieldAcceptanceChecks) {
    if (name === "webhook_lifecycle") {
      requireBoundedWebhookReceipt(checks[name], errors);
    } else {
      requirePassedReceipt(
        checks[name],
        `acceptance.checks.${name}`,
        `acceptance:${name}`,
        errors,
      );
    }
    requireProductionReceiptBinding(
      checks[name],
      `acceptance.checks.${name}`,
      versions.accepted_worker_version_id,
      errors,
    );
    if (
      validUTCInstant(window.started_at_utc)
      && validUTCInstant(window.completed_at_utc)
      && validUTCInstant(checks[name]?.observed_at_utc)
    ) {
      requireCondition(
        Date.parse(checks[name].observed_at_utc) >= Date.parse(window.started_at_utc)
          && Date.parse(checks[name].observed_at_utc) <= Date.parse(window.completed_at_utc),
        `acceptance.checks.${name}.observed_at_utc must fall within the bounded window`,
        errors,
      );
    }
  }
  const automatedReceiptIds = greenfieldAcceptanceChecks.map((name) =>
    checks[name]?.receipt_id);
  requireCondition(
    automatedReceiptIds.every((receiptId) =>
      typeof receiptId === "string" && receiptId.length > 0)
      && new Set(automatedReceiptIds).size === greenfieldAcceptanceChecks.length,
    "acceptance check receipt IDs must be unique",
    errors,
  );

  requireExactKeys(
    rollback,
    [
      "validation_status",
      "validated_at_utc",
      "packet",
      "packet_sha256",
    ],
    "rollback",
    errors,
  );
  requireCondition(rollback.validation_status === "passed", "rollback.validation_status must be passed", errors);
  requireUTCInstant(rollback.validated_at_utc, "rollback.validated_at_utc", errors);
  requireReceiptPayloadDigest(
    rollback.packet_sha256,
    rollback.packet,
    "rollback.packet_sha256",
    errors,
  );
  const rollbackPacket = rollback.packet ?? {};
  const rollbackVersions = rollbackPacket.versions ?? {};
  const rollbackWindow = rollbackPacket.window ?? {};
  const standaloneRollbackValidation = (isV3
    ? validateRollbackPacket
    : validateHistoricalGreenfieldRollbackPacketV2)(
    rollbackPacket,
    {
      now: validUTCInstant(rollback.validated_at_utc)
        ? new Date(rollback.validated_at_utc)
        : new Date(0),
    },
  );
  requireCondition(
    standaloneRollbackValidation.ok,
    `rollback.packet must pass the standalone v${contractVersion} validator`,
    errors,
  );
  if (!standaloneRollbackValidation.ok) {
    for (const error of standaloneRollbackValidation.errors) {
      errors.push(`rollback.packet: ${error}`);
    }
  }
  requireCondition(
    rollbackPacket.rollback_profile === expectedRollbackProfile,
    `rollback.packet.rollback_profile must be ${expectedRollbackProfile}`,
    errors,
  );
  for (const name of [
    "candidate_worker_version_id",
    "accepted_worker_version_id",
    "write_guard_worker_version_id",
    "last_known_good_worker_version_id",
  ]) {
    requireCondition(
      rollbackVersions[name] === versions[name],
      `rollback.packet.versions.${name} must match the launch Worker version`,
      errors,
    );
  }
  requireCondition(
    rollbackVersions.provider_readback_at_utc === worker.provider_readback_at_utc,
    "rollback.packet.versions.provider_readback_at_utc must match the launch Worker readback",
    errors,
  );
  if (isV3) {
    requireCondition(
      sameCanonicalValue(
        rollbackPacket.edge_binding,
        initialTraffic.edge_binding,
      )
        && sameCanonicalValue(
          rollbackVersions.write_guard_probe?.edge_binding,
          initialTraffic.edge_binding,
        )
        && sameCanonicalValue(
          rollbackVersions.last_known_good_probe?.edge_binding,
          initialTraffic.edge_binding,
        ),
      "rollback packet and fallback probes must use the reviewed Custom Domain binding",
      errors,
    );
  } else {
    requireCondition(
      rollbackVersions.write_guard_probe?.route_id === initialTraffic.route_id
        && rollbackVersions.last_known_good_probe?.route_id
          === initialTraffic.route_id,
      "rollback fallback probes must use the reviewed initial production route ID",
      errors,
    );
  }
  requireStrictlyBefore(
    rollbackWindow.start_at_utc,
    rollback.validated_at_utc,
    "standalone rollback window must be open before launch validation",
    errors,
  );
  requireStrictlyBefore(
    rollbackWindow.start_at_utc,
    rollbackVersions.write_guard_probe?.observed_at_utc,
    "write-guard probe must occur inside the standalone rollback window",
    errors,
  );
  requireStrictlyBefore(
    rollbackWindow.start_at_utc,
    rollbackVersions.last_known_good_probe?.observed_at_utc,
    "last-known-good probe must occur inside the standalone rollback window",
    errors,
  );
  requireStrictlyBefore(
    rollbackVersions.write_guard_probe?.deployment_observed_after_at_utc,
    rollback.validated_at_utc,
    "greenfield rollback packet validation must follow the bracketed write-guard probe",
    errors,
  );
  requireStrictlyBefore(
    rollbackVersions.last_known_good_probe?.deployment_observed_after_at_utc,
    rollback.validated_at_utc,
    "greenfield rollback packet validation must follow the bracketed last-known-good probe",
    errors,
  );

  requireExactKeys(
    devices,
    ["iphone_15_pro_max", "apple_watch_series_9_45mm", "release_configuration"],
    "physical_device_acceptance",
    errors,
  );
  requirePassedReceipt(
    iphone,
    "physical_device_acceptance.iphone_15_pro_max",
    "physical_device:iphone_15_pro_max",
    errors,
  );
  requirePassedReceipt(
    watch,
    "physical_device_acceptance.apple_watch_series_9_45mm",
    "physical_device:apple_watch_series_9_45mm",
    errors,
  );
  requirePassedReceipt(
    releaseConfig,
    "physical_device_acceptance.release_configuration",
    "physical_device:release_configuration",
    errors,
  );
  for (const [name, receipt] of [
    ["iphone_15_pro_max", iphone],
    ["apple_watch_series_9_45mm", watch],
    ["release_configuration", releaseConfig],
  ]) {
    requireProductionReceiptBinding(
      receipt,
      `physical_device_acceptance.${name}`,
      versions.accepted_worker_version_id,
      errors,
    );
    requireStrictlyBefore(
      window.completed_at_utc,
      receipt?.observed_at_utc,
      `physical_device_acceptance.${name}.observed_at_utc must follow automated acceptance`,
      errors,
    );
  }
  const allAcceptanceReceiptIds = [
    ...automatedReceiptIds,
    iphone?.receipt_id,
    watch?.receipt_id,
    releaseConfig?.receipt_id,
  ];
  requireCondition(
    allAcceptanceReceiptIds.every((receiptId) =>
      typeof receiptId === "string" && receiptId.length > 0)
      && new Set(allAcceptanceReceiptIds).size === allAcceptanceReceiptIds.length,
    "automated, physical-device, and release receipt IDs must be unique",
    errors,
  );

  requireExactKeys(
    traffic,
    [
      "initial_candidate",
      "bounded_acceptance_route",
      "promoted_webhook_acceptance",
      "accepted_cutover",
    ],
    "traffic_and_writes",
    errors,
  );
  requireExactKeys(
    initialTraffic,
    [
      "worker_version_id",
      "deployment_id",
      ...(isV3
        ? [
            "edge_binding",
            "conflicting_zone_route_count",
            "manual_dns_origin_present",
          ]
        : ["route_id", "hostname", "route_pattern"]),
      "route_status",
      "version_weights",
      "write_mode",
      "new_user_onboarding_mode",
      "verified_at_utc",
      "provider_receipt_id",
      "provider_receipt_sha256",
      "clerk_instance_id",
      "database_branch_id",
      "workers_dev_enabled",
      "preview_urls_enabled",
      "health_status",
      "health_worker_version_id",
      "readiness_status",
      "readiness_worker_version_id",
      "missing_bearer_rejection_status",
      "missing_bearer_http_status",
      "invalid_bearer_rejection_status",
      "invalid_bearer_http_status",
      "write_denial_status",
      "write_denial_http_status",
      "webhook_denial_status",
      "webhook_denial_http_status",
      "identity_mutation_count",
      "application_mutation_count",
    ],
    "traffic_and_writes.initial_candidate",
    errors,
  );
  requireCondition(
    initialTraffic.worker_version_id === versions.candidate_worker_version_id,
    "initial candidate traffic must identify the candidate Worker version",
    errors,
  );
  requireCondition(
    initialTraffic.route_status === "write_disabled_route",
    "initial candidate route_status must be write_disabled_route",
    errors,
  );
  requireNonEmpty(initialTraffic.deployment_id, "traffic_and_writes.initial_candidate.deployment_id", errors);
  if (isV3) {
    requireCustomDomainReceiptState(
      initialTraffic,
      "traffic_and_writes.initial_candidate",
      errors,
    );
  } else {
    requireNonEmpty(initialTraffic.route_id, "traffic_and_writes.initial_candidate.route_id", errors);
    requireCondition(
      initialTraffic.hostname === productionWorker.hostname,
      "initial candidate hostname must be api.refwatch.ibby.ai",
      errors,
    );
    requireCondition(
      initialTraffic.route_pattern === productionWorker.routePattern,
      "initial candidate route pattern must be api.refwatch.ibby.ai/*",
      errors,
    );
  }
  requireCondition(
    JSON.stringify(initialTraffic.version_weights) === JSON.stringify([
      {
        worker_version_id: versions.candidate_worker_version_id,
        traffic_percentage: 100,
      },
      {
        worker_version_id: versions.accepted_worker_version_id,
        traffic_percentage: 0,
      },
    ]),
    "initial deployment must route A at 100 percent and hold B at zero percent",
    errors,
  );
  requireCondition(initialTraffic.write_mode === "disabled", "initial candidate WRITE_MODE must be disabled", errors);
  requireCondition(
    initialTraffic.new_user_onboarding_mode === "disabled",
    "initial candidate NEW_USER_ONBOARDING_MODE must be disabled",
    errors,
  );
  requireUTCInstant(initialTraffic.verified_at_utc, "traffic_and_writes.initial_candidate.verified_at_utc", errors);
  requireNonEmpty(initialTraffic.provider_receipt_id, "traffic_and_writes.initial_candidate.provider_receipt_id", errors);
  requireInlineReceiptDigest(
    initialTraffic,
    "provider_receipt_sha256",
    "traffic_and_writes.initial_candidate",
    errors,
  );
  requireCondition(
    initialTraffic.clerk_instance_id === productionClerk.instanceId,
    "initial candidate receipt must bind the production Clerk instance",
    errors,
  );
  requireCondition(
    initialTraffic.database_branch_id === productionDatabase.branchId,
    "initial candidate receipt must bind the production database branch",
    errors,
  );
  requireCondition(
    initialTraffic.workers_dev_enabled === false,
    "initial candidate Workers.dev must be disabled",
    errors,
  );
  requireCondition(
    initialTraffic.preview_urls_enabled === false,
    "initial candidate preview URLs must be disabled",
    errors,
  );
  for (const [field, expected] of [
    ["health_status", "passed"],
    ["readiness_status", "passed"],
    ["missing_bearer_rejection_status", "passed"],
    ["invalid_bearer_rejection_status", "passed"],
    ["write_denial_status", "retryable_denial"],
    ["webhook_denial_status", "retryable_denial"],
  ]) {
    requireCondition(
      initialTraffic[field] === expected,
      `initial candidate ${field} must be ${expected}`,
      errors,
    );
  }
  requireCondition(
    initialTraffic.health_worker_version_id === versions.candidate_worker_version_id,
    "initial health probe must report candidate Worker A",
    errors,
  );
  requireCondition(
    initialTraffic.readiness_worker_version_id === versions.candidate_worker_version_id,
    "initial readiness probe must report candidate Worker A",
    errors,
  );
  for (const field of ["missing_bearer_http_status", "invalid_bearer_http_status"]) {
    requireCondition(initialTraffic[field] === 401, `initial candidate ${field} must be 401`, errors);
  }
  for (const field of ["write_denial_http_status", "webhook_denial_http_status"]) {
    requireCondition(initialTraffic[field] === 503, `initial candidate ${field} must be 503`, errors);
  }
  requireCondition(
    initialTraffic.identity_mutation_count === 0,
    "initial candidate identity_mutation_count must be zero",
    errors,
  );
  requireCondition(
    initialTraffic.application_mutation_count === 0,
    "initial candidate application_mutation_count must be zero",
    errors,
  );

  requireExactKeys(
    boundedTraffic,
    [
      "worker_version_id",
      "deployment_id",
      ...(isV3
        ? [
            "edge_binding",
            "conflicting_zone_route_count",
            "manual_dns_origin_present",
          ]
        : ["route_id", "hostname", "route_pattern"]),
      "exposure_method",
      "override_header_name",
      "override_header_value",
      "access_control",
      "access_application_id",
      "access_policy_id",
      "access_service_token_id",
      "access_path_pattern",
      "access_policy_action",
      "access_allowed_service_token_count",
      "access_bypass_policy_count",
      "access_provider_readback_at_utc",
      "access_provider_receipt_id",
      "access_provider_receipt_sha256",
      "access_token_header_name",
      "access_token_secret_name",
      "version_weights",
      "write_mode",
      "new_user_onboarding_mode",
      "reconciliation_receipt_digest",
      "workers_dev_enabled",
      "preview_urls_enabled",
      "missing_token_rejection_status",
      "missing_token_http_status",
      "invalid_token_rejection_status",
      "invalid_token_http_status",
      "enabled_at_utc",
      "closed_disposition",
      "closed_at_utc",
      "promoted_deployment_id",
      "provider_receipt_id",
      "provider_receipt_sha256",
      "clerk_instance_id",
      "database_branch_id",
    ],
    "traffic_and_writes.bounded_acceptance_route",
    errors,
  );
  requireCondition(
    boundedTraffic.worker_version_id === versions.accepted_worker_version_id,
    "bounded acceptance route must target Worker B",
    errors,
  );
  requireCondition(
    boundedTraffic.deployment_id === initialTraffic.deployment_id,
    "bounded acceptance route must use the reviewed A=100/B=0 deployment",
    errors,
  );
  if (isV3) {
    requireCustomDomainReceiptState(
      boundedTraffic,
      "traffic_and_writes.bounded_acceptance_route",
      errors,
    );
    requireCondition(
      sameCanonicalValue(
        boundedTraffic.edge_binding,
        initialTraffic.edge_binding,
      ),
      "bounded acceptance must use the reviewed Custom Domain binding",
      errors,
    );
  } else {
    requireCondition(
      boundedTraffic.route_id === initialTraffic.route_id,
      "bounded acceptance route must use the reviewed production route ID",
      errors,
    );
    requireCondition(
      boundedTraffic.hostname === productionWorker.hostname
        && boundedTraffic.route_pattern === productionWorker.routePattern,
      "bounded acceptance route must use api.refwatch.ibby.ai/*",
      errors,
    );
  }
  requireCondition(
    boundedTraffic.exposure_method === "version_override",
    "bounded acceptance exposure_method must be version_override",
    errors,
  );
  requireCondition(
    boundedTraffic.override_header_name === cutoverAcceptance.overrideHeaderName,
    `bounded acceptance override header must be ${cutoverAcceptance.overrideHeaderName}`,
    errors,
  );
  requireCondition(
    boundedTraffic.override_header_value
      === `${productionWorker.name}="${versions.accepted_worker_version_id}"`,
    "bounded acceptance override header must target exact Worker B",
    errors,
  );
  requireCondition(
    boundedTraffic.access_control
      === "cloudflare_access_service_token_and_worker_cutover_token",
    "bounded acceptance access_control must combine Cloudflare Access and the Worker cutover token",
    errors,
  );
  for (const field of [
    "access_application_id",
    "access_policy_id",
    "access_service_token_id",
  ]) {
    requireNonEmpty(
      boundedTraffic[field],
      `traffic_and_writes.bounded_acceptance_route.${field}`,
      errors,
    );
    requireCondition(
      cloudflareProviderIdPattern.test(boundedTraffic[field] ?? ""),
      `traffic_and_writes.bounded_acceptance_route.${field} must be a sanitized Cloudflare provider ID`,
      errors,
    );
  }
  requireCondition(
    boundedTraffic.access_path_pattern === `${productionWorker.hostname}/api/*`,
    "bounded acceptance Cloudflare Access path must be api.refwatch.ibby.ai/api/*",
    errors,
  );
  requireCondition(
    boundedTraffic.access_policy_action === "service_auth",
    "bounded acceptance Cloudflare Access policy action must be service_auth",
    errors,
  );
  requireCondition(
    boundedTraffic.access_allowed_service_token_count === 1,
    "bounded acceptance Cloudflare Access must allow exactly one service token",
    errors,
  );
  requireCondition(
    boundedTraffic.access_bypass_policy_count === 0,
    "bounded acceptance Cloudflare Access must have zero bypass policies",
    errors,
  );
  requireUTCInstant(
    boundedTraffic.access_provider_readback_at_utc,
    "traffic_and_writes.bounded_acceptance_route.access_provider_readback_at_utc",
    errors,
  );
  requireNonEmpty(
    boundedTraffic.access_provider_receipt_id,
    "traffic_and_writes.bounded_acceptance_route.access_provider_receipt_id",
    errors,
  );
  requireReceiptPayloadDigest(
    boundedTraffic.access_provider_receipt_sha256,
    {
      receipt_id: boundedTraffic.access_provider_receipt_id,
      observed_at_utc: boundedTraffic.access_provider_readback_at_utc,
      application_id: boundedTraffic.access_application_id,
      policy_id: boundedTraffic.access_policy_id,
      service_token_id: boundedTraffic.access_service_token_id,
      path_pattern: boundedTraffic.access_path_pattern,
      policy_action: boundedTraffic.access_policy_action,
      allowed_service_token_count:
        boundedTraffic.access_allowed_service_token_count,
      bypass_policy_count: boundedTraffic.access_bypass_policy_count,
    },
    "traffic_and_writes.bounded_acceptance_route.access_provider_receipt_sha256",
    errors,
  );
  requireCondition(
    boundedTraffic.access_token_header_name === cutoverAcceptance.tokenHeaderName,
    `bounded acceptance token header must be ${cutoverAcceptance.tokenHeaderName}`,
    errors,
  );
  requireCondition(
    boundedTraffic.access_token_secret_name === cutoverAcceptance.tokenSecretName,
    `bounded acceptance token secret must be ${cutoverAcceptance.tokenSecretName}`,
    errors,
  );
  requireCondition(
    JSON.stringify(boundedTraffic.version_weights)
      === JSON.stringify(initialTraffic.version_weights),
    "bounded acceptance must keep A at 100 percent and B at zero percent",
    errors,
  );
  requireCondition(
    boundedTraffic.write_mode === "enabled"
      && boundedTraffic.new_user_onboarding_mode === "greenfield_bootstrap",
    "bounded acceptance must target enabled greenfield Worker B",
    errors,
  );
  requireCondition(
    boundedTraffic.reconciliation_receipt_digest === greenfieldIdentityReceiptDigest,
    "bounded acceptance route must bind the approved greenfield receipt",
    errors,
  );
  requireCondition(
    boundedTraffic.workers_dev_enabled === false
      && boundedTraffic.preview_urls_enabled === false,
    "bounded acceptance must keep Workers.dev and preview URLs disabled",
    errors,
  );
  requireCondition(
    boundedTraffic.missing_token_rejection_status === "passed"
      && boundedTraffic.missing_token_http_status === 403,
    "bounded acceptance must prove missing cutover-token rejection with 403",
    errors,
  );
  requireCondition(
    boundedTraffic.invalid_token_rejection_status === "passed"
      && boundedTraffic.invalid_token_http_status === 403,
    "bounded acceptance must prove invalid cutover-token rejection with 403",
    errors,
  );
  requireUTCInstant(
    boundedTraffic.enabled_at_utc,
    "traffic_and_writes.bounded_acceptance_route.enabled_at_utc",
    errors,
  );
  requireStrictlyBefore(
    boundedTraffic.access_provider_readback_at_utc,
    boundedTraffic.enabled_at_utc,
    "Cloudflare Access readback must precede bounded routing",
    errors,
  );
  requireCondition(
    boundedTraffic.closed_disposition === "promoted_to_physical_acceptance",
    "bounded acceptance route must be promoted to physical acceptance",
    errors,
  );
  requireUTCInstant(
    boundedTraffic.closed_at_utc,
    "traffic_and_writes.bounded_acceptance_route.closed_at_utc",
    errors,
  );
  requireNonEmpty(
    boundedTraffic.promoted_deployment_id,
    "traffic_and_writes.bounded_acceptance_route.promoted_deployment_id",
    errors,
  );
  requireNonEmpty(
    boundedTraffic.provider_receipt_id,
    "traffic_and_writes.bounded_acceptance_route.provider_receipt_id",
    errors,
  );
  requireInlineReceiptDigest(
    boundedTraffic,
    "provider_receipt_sha256",
    "traffic_and_writes.bounded_acceptance_route",
    errors,
  );
  requireCondition(
    boundedTraffic.clerk_instance_id === productionClerk.instanceId
      && boundedTraffic.database_branch_id === productionDatabase.branchId,
    "bounded acceptance route must bind exact Clerk and database provenance",
    errors,
  );

  requireExactKeys(
    promotedWebhook,
    [
      "status",
      "receipt_kind",
      "receipt_id",
      "receipt_sha256",
      "observed_at_utc",
      "worker_version_id",
      "deployment_id",
      ...(isV3
        ? [
            "edge_binding",
            "conflicting_zone_route_count",
            "manual_dns_origin_present",
          ]
        : []),
      "endpoint_path",
      "version_override_header_present",
      "cutover_token_header_present",
      "api_access_policy_status",
      "provider_source",
      "subscribed_event_types",
      "provider_delivery_status",
      "valid_signature_status",
      "create_status",
      "update_status",
      "delete_status",
      "retry_idempotency_status",
      "delete_wins_status",
      "final_test_identity_count",
      "final_application_row_count",
      "clerk_instance_id",
      "database_branch_id",
    ],
    "traffic_and_writes.promoted_webhook_acceptance",
    errors,
  );
  requireCondition(
    promotedWebhook.status === "passed",
    "promoted webhook acceptance status must be passed",
    errors,
  );
  requireCondition(
    promotedWebhook.receipt_kind === "promoted_webhook:clerk_lifecycle",
    "promoted webhook receipt_kind must be promoted_webhook:clerk_lifecycle",
    errors,
  );
  requireNonEmpty(
    promotedWebhook.receipt_id,
    "traffic_and_writes.promoted_webhook_acceptance.receipt_id",
    errors,
  );
  requireInlineReceiptDigest(
    promotedWebhook,
    "receipt_sha256",
    "traffic_and_writes.promoted_webhook_acceptance",
    errors,
  );
  requireUTCInstant(
    promotedWebhook.observed_at_utc,
    "traffic_and_writes.promoted_webhook_acceptance.observed_at_utc",
    errors,
  );
  requireCondition(
    promotedWebhook.worker_version_id === versions.accepted_worker_version_id,
    "promoted webhook acceptance must exercise Worker B",
    errors,
  );
  requireCondition(
    promotedWebhook.deployment_id === boundedTraffic.promoted_deployment_id,
    "promoted webhook acceptance must use the B=100 deployment",
    errors,
  );
  if (isV3) {
    requireCustomDomainReceiptState(
      promotedWebhook,
      "traffic_and_writes.promoted_webhook_acceptance",
      errors,
    );
    requireCondition(
      sameCanonicalValue(
        promotedWebhook.edge_binding,
        initialTraffic.edge_binding,
      ),
      "promoted webhook acceptance must use the reviewed Custom Domain binding",
      errors,
    );
  }
  requireCondition(
    promotedWebhook.endpoint_path === "/webhooks/clerk",
    "promoted webhook endpoint must be /webhooks/clerk",
    errors,
  );
  requireCondition(
    promotedWebhook.version_override_header_present === false
      && promotedWebhook.cutover_token_header_present === false,
    "real Clerk provider delivery must not claim version-override or cutover-token headers",
    errors,
  );
  requireCondition(
    promotedWebhook.api_access_policy_status === "active_service_auth",
    "Cloudflare Access must remain active on /api/* during promoted webhook acceptance",
    errors,
  );
  requireCondition(
    promotedWebhook.provider_source === "clerk_production_instance",
    "promoted webhook provider source must be the production Clerk instance",
    errors,
  );
  requireCondition(
    JSON.stringify(promotedWebhook.subscribed_event_types)
      === JSON.stringify(productionClerkLifecycleWebhook.eventTypes),
    "promoted webhook event types must exactly match the three reviewed Clerk lifecycle events",
    errors,
  );
  for (const field of [
    "provider_delivery_status",
    "valid_signature_status",
    "create_status",
    "update_status",
    "delete_status",
    "retry_idempotency_status",
    "delete_wins_status",
  ]) {
    requireCondition(
      promotedWebhook[field] === "passed",
      `promoted webhook ${field} must be passed`,
      errors,
    );
  }
  requireCondition(
    promotedWebhook.final_test_identity_count === 0,
    "promoted webhook final_test_identity_count must be zero",
    errors,
  );
  requireCondition(
    promotedWebhook.final_application_row_count === 0,
    "promoted webhook final_application_row_count must be zero",
    errors,
  );
  requireCondition(
    promotedWebhook.clerk_instance_id === productionClerk.instanceId
      && promotedWebhook.database_branch_id === productionDatabase.branchId,
    "promoted webhook acceptance must bind exact Clerk and database provenance",
    errors,
  );
  requireCondition(
    !allAcceptanceReceiptIds.includes(promotedWebhook.receipt_id),
    "promoted webhook receipt ID must be unique across acceptance receipts",
    errors,
  );

  requireExactKeys(
    acceptedTraffic,
    [
      "routed_worker_version_id",
      "deployment_id",
      ...(isV3
        ? [
            "edge_binding",
            "conflicting_zone_route_count",
            "manual_dns_origin_present",
          ]
        : ["route_id", "hostname", "route_pattern"]),
      "route_status",
      "version_weights",
      "traffic_percentage",
      "competing_version_count",
      "workers_dev_enabled",
      "preview_urls_enabled",
      "write_mode",
      "new_user_onboarding_mode",
      "traffic_scope",
      "reconciliation_receipt_digest",
      "enabled_at_utc",
      "deployment_history_receipt_id",
      "deployment_history_receipt_sha256",
      "deployment_history_observed_at_utc",
      "bounded_access_status",
      "bounded_access_removed_at_utc",
      "bounded_access_removal_receipt_id",
      "bounded_access_removal_receipt_sha256",
      "production_accepted_at_utc",
      "observation_status",
      "observation_receipt_id",
      "observation_receipt_sha256",
      "observation_completed_at_utc",
      "clerk_instance_id",
      "database_branch_id",
    ],
    "traffic_and_writes.accepted_cutover",
    errors,
  );
  requireCondition(
    acceptedTraffic.routed_worker_version_id === versions.accepted_worker_version_id,
    "accepted traffic must route the accepted Worker version",
    errors,
  );
  requireCondition(
    acceptedTraffic.deployment_id === boundedTraffic.promoted_deployment_id,
    "accepted traffic deployment must match the bounded-route promotion",
    errors,
  );
  if (isV3) {
    requireCustomDomainReceiptState(
      acceptedTraffic,
      "traffic_and_writes.accepted_cutover",
      errors,
    );
    requireCondition(
      sameCanonicalValue(
        acceptedTraffic.edge_binding,
        initialTraffic.edge_binding,
      ),
      "accepted traffic must use the reviewed Custom Domain binding",
      errors,
    );
  } else {
    requireCondition(
      acceptedTraffic.route_id === initialTraffic.route_id,
      "accepted traffic must use the reviewed production route ID",
      errors,
    );
    requireCondition(
      acceptedTraffic.hostname === productionWorker.hostname
        && acceptedTraffic.route_pattern === productionWorker.routePattern,
      "accepted traffic must use api.refwatch.ibby.ai/*",
      errors,
    );
  }
  requireCondition(acceptedTraffic.route_status === "production_active", "accepted route_status must be production_active", errors);
  requireCondition(
    JSON.stringify(acceptedTraffic.version_weights) === JSON.stringify([
      {
        worker_version_id: versions.accepted_worker_version_id,
        traffic_percentage: 100,
      },
    ]),
    "accepted deployment must route only Worker B at 100 percent",
    errors,
  );
  requireCondition(
    acceptedTraffic.traffic_percentage === 100
      && acceptedTraffic.competing_version_count === 0,
    "accepted traffic must route Worker B at 100 percent with no competing version",
    errors,
  );
  requireCondition(
    acceptedTraffic.workers_dev_enabled === false
      && acceptedTraffic.preview_urls_enabled === false,
    "accepted traffic must keep Workers.dev and preview URLs disabled",
    errors,
  );
  requireCondition(acceptedTraffic.write_mode === "enabled", "accepted WRITE_MODE must be enabled", errors);
  requireCondition(
    acceptedTraffic.new_user_onboarding_mode === "greenfield_bootstrap",
    "accepted NEW_USER_ONBOARDING_MODE must be greenfield_bootstrap",
    errors,
  );
  requireCondition(
    acceptedTraffic.traffic_scope === "production",
    "accepted traffic_scope must be production",
    errors,
  );
  requireCondition(
    acceptedTraffic.reconciliation_receipt_digest === greenfieldIdentityReceiptDigest,
    "accepted traffic must bind the approved greenfield reconciliation receipt",
    errors,
  );
  requireUTCInstant(acceptedTraffic.enabled_at_utc, "traffic_and_writes.accepted_cutover.enabled_at_utc", errors);
  requireNonEmpty(
    acceptedTraffic.deployment_history_receipt_id,
    "traffic_and_writes.accepted_cutover.deployment_history_receipt_id",
    errors,
  );
  requireReceiptPayloadDigest(
    acceptedTraffic.deployment_history_receipt_sha256,
    {
      receipt_id: acceptedTraffic.deployment_history_receipt_id,
      observed_at_utc: acceptedTraffic.deployment_history_observed_at_utc,
      worker_name: worker.name,
      ...(isV3
        ? { edge_binding: acceptedTraffic.edge_binding }
        : { route_id: acceptedTraffic.route_id }),
      initial_deployment_id: initialTraffic.deployment_id,
      promoted_deployment_id: acceptedTraffic.deployment_id,
      candidate_worker_version_id: versions.candidate_worker_version_id,
      accepted_worker_version_id: versions.accepted_worker_version_id,
      initial_candidate_percentage: 100,
      initial_accepted_percentage: 0,
      final_accepted_percentage: 100,
      final_competing_version_count: 0,
    },
    "traffic_and_writes.accepted_cutover.deployment_history_receipt_sha256",
    errors,
  );
  requireUTCInstant(
    acceptedTraffic.deployment_history_observed_at_utc,
    "traffic_and_writes.accepted_cutover.deployment_history_observed_at_utc",
    errors,
  );
  requireCondition(
    acceptedTraffic.bounded_access_status === "removed",
    "accepted traffic must remove the bounded Cloudflare Access policy",
    errors,
  );
  requireUTCInstant(
    acceptedTraffic.bounded_access_removed_at_utc,
    "traffic_and_writes.accepted_cutover.bounded_access_removed_at_utc",
    errors,
  );
  requireNonEmpty(
    acceptedTraffic.bounded_access_removal_receipt_id,
    "traffic_and_writes.accepted_cutover.bounded_access_removal_receipt_id",
    errors,
  );
  requireReceiptPayloadDigest(
    acceptedTraffic.bounded_access_removal_receipt_sha256,
    {
      receipt_id: acceptedTraffic.bounded_access_removal_receipt_id,
      removed_at_utc: acceptedTraffic.bounded_access_removed_at_utc,
      application_id: boundedTraffic.access_application_id,
      policy_id: boundedTraffic.access_policy_id,
      path_pattern: boundedTraffic.access_path_pattern,
      status: acceptedTraffic.bounded_access_status,
    },
    "traffic_and_writes.accepted_cutover.bounded_access_removal_receipt_sha256",
    errors,
  );
  requireUTCInstant(
    acceptedTraffic.production_accepted_at_utc,
    "traffic_and_writes.accepted_cutover.production_accepted_at_utc",
    errors,
  );
  requireCondition(
    acceptedTraffic.observation_status === "passed",
    "accepted traffic observation_status must be passed",
    errors,
  );
  requireNonEmpty(
    acceptedTraffic.observation_receipt_id,
    "traffic_and_writes.accepted_cutover.observation_receipt_id",
    errors,
  );
  requireInlineReceiptDigest(
    acceptedTraffic,
    "observation_receipt_sha256",
    "traffic_and_writes.accepted_cutover",
    errors,
  );
  requireUTCInstant(
    acceptedTraffic.observation_completed_at_utc,
    "traffic_and_writes.accepted_cutover.observation_completed_at_utc",
    errors,
  );
  requireCondition(
    acceptedTraffic.clerk_instance_id === productionClerk.instanceId,
    "accepted traffic observation must bind the production Clerk instance",
    errors,
  );
  requireCondition(
    acceptedTraffic.database_branch_id === productionDatabase.branchId,
    "accepted traffic observation must bind the production database branch",
    errors,
  );

  requireStrictlyBefore(
    identity.activated_at_utc,
    acceptedTraffic.enabled_at_utc,
    "WRITE_MODE must be enabled after the greenfield bootstrap receipt is activated",
    errors,
  );
  requireStrictlyBefore(
    window.completed_at_utc,
    acceptedTraffic.enabled_at_utc,
    "Worker B must be promoted after bounded acceptance completes",
    errors,
  );
  requireStrictlyBefore(
    initialTraffic.verified_at_utc,
    acceptedTraffic.enabled_at_utc,
    "accepted cutover must follow the write-disabled candidate verification",
    errors,
  );
  requireCondition(
    boundedTraffic.closed_at_utc === acceptedTraffic.enabled_at_utc,
    "bounded override exposure must close when Worker B is promoted",
    errors,
  );
  for (const [name, receipt] of [
    ["iphone_15_pro_max", iphone],
    ["apple_watch_series_9_45mm", watch],
    ["release_configuration", releaseConfig],
  ]) {
    requireStrictlyBefore(
      acceptedTraffic.bounded_access_removed_at_utc,
      receipt?.observed_at_utc,
      `${name} acceptance must follow bounded Access removal`,
      errors,
    );
    requireStrictlyBefore(
      acceptedTraffic.enabled_at_utc,
      receipt?.observed_at_utc,
      `${name} acceptance must exercise promoted Worker B`,
      errors,
    );
    requireStrictlyBefore(
      receipt?.observed_at_utc,
      acceptedTraffic.production_accepted_at_utc,
      `production acceptance must follow ${name}`,
      errors,
    );
  }
  requireStrictlyBefore(
    acceptedTraffic.production_accepted_at_utc,
    acceptedTraffic.observation_completed_at_utc,
    "production traffic observation must complete after production acceptance",
    errors,
  );
  requireStrictlyBefore(
    acceptedTraffic.enabled_at_utc,
    promotedWebhook.observed_at_utc,
    "real Clerk provider delivery must follow Worker B promotion",
    errors,
  );
  requireStrictlyBefore(
    promotedWebhook.observed_at_utc,
    acceptedTraffic.bounded_access_removed_at_utc,
    "bounded Cloudflare Access removal must follow real Clerk provider delivery",
    errors,
  );
  requireStrictlyBefore(
    acceptedTraffic.bounded_access_removed_at_utc,
    acceptedTraffic.deployment_history_observed_at_utc,
    "deployment history readback must follow bounded Access removal",
    errors,
  );
  requireStrictlyBefore(
    acceptedTraffic.deployment_history_observed_at_utc,
    acceptedTraffic.production_accepted_at_utc,
    "production acceptance must follow deployment history readback",
    errors,
  );
  if (validUTCInstant(acceptedTraffic.observation_completed_at_utc) && validNow) {
    requireCondition(
      Date.parse(acceptedTraffic.observation_completed_at_utc) <= nowMillis,
      "production traffic observation must not complete in the future",
      errors,
    );
  }
  requireStrictlyBefore(
    rollback.validated_at_utc,
    boundedTraffic.enabled_at_utc,
    "greenfield rollback packet must be validated before bounded routing",
    errors,
  );
  requireStrictlyBefore(
    boundedTraffic.enabled_at_utc,
    window.started_at_utc,
    "bounded acceptance window must start after its protected route is enabled",
    errors,
  );
  requireStrictlyBefore(
    window.completed_at_utc,
    boundedTraffic.closed_at_utc,
    "bounded acceptance route must remain available through the automated window",
    errors,
  );
  requireStrictlyBefore(
    acceptedTraffic.observation_completed_at_utc,
    finalLedger.provider_readback_at_utc,
    "final inactive-ledger readback must follow the production observation",
    errors,
  );
  requireStrictlyBefore(
    finalLedger.provider_readback_at_utc,
    rollbackWindow.end_at_utc,
    "greenfield rollback window must end after the production traffic observation",
    errors,
  );
  if (validUTCInstant(rollbackWindow.end_at_utc) && validNow) {
    requireCondition(
      Date.parse(rollbackWindow.end_at_utc) > nowMillis,
      "greenfield rollback window must end after validation time",
      errors,
    );
  }
  for (const [label, observedAtUTC] of [
    ["schema", schemaReadback.observed_at_utc],
    ["deterministic seed", seed.provider_readback_at_utc],
    ["clean target", cleanTarget.provider_readback_at_utc],
    ["inactive ledger", ledger.provider_readback_at_utc],
    ["Clerk", clerk.provider_readback_at_utc],
  ]) {
    requireStrictlyBefore(
      observedAtUTC,
      initialTraffic.verified_at_utc,
      `${label} baseline must precede write-disabled candidate verification`,
      errors,
    );
  }
  requireStrictlyBefore(
    worker.provider_readback_at_utc,
    initialTraffic.verified_at_utc,
    "Worker version readback must precede write-disabled candidate verification",
    errors,
  );
  requireStrictlyBefore(
    rollbackVersions.write_guard_probe?.deployment_observed_after_at_utc,
    initialTraffic.verified_at_utc,
    "final candidate verification must follow the write-guard probe",
    errors,
  );
  requireStrictlyBefore(
    rollbackVersions.last_known_good_probe?.deployment_observed_after_at_utc,
    initialTraffic.verified_at_utc,
    "final candidate verification must follow the last-known-good probe",
    errors,
  );
  requireStrictlyBefore(
    initialTraffic.verified_at_utc,
    rollback.validated_at_utc,
    "rollback validation must follow the final A/B safety receipt",
    errors,
  );
  requireStrictlyBefore(
    rollbackWindow.start_at_utc,
    initialTraffic.verified_at_utc,
    "final A/B safety receipt must occur inside the standalone rollback window",
    errors,
  );
  if (validUTCInstant(finalLedger.provider_readback_at_utc) && validNow) {
    requireCondition(
      Date.parse(finalLedger.provider_readback_at_utc) <= nowMillis,
      "final inactive-ledger readback must not be in the future",
      errors,
    );
  }

  return {
    ok: errors.length === 0,
    errors,
    summary: {
      launchProfile: packet?.launch_profile ?? null,
      authorizationDigest: authorization?.decision_sha256 ?? null,
      clerkInstanceId: clerk?.instance_id ?? null,
      workerName: worker?.name ?? null,
      workerEnvironment: worker?.environment ?? null,
      candidateWorkerVersionId: versions?.candidate_worker_version_id ?? null,
      acceptedWorkerVersionId: versions?.accepted_worker_version_id ?? null,
      databaseBranchId: databaseTarget?.branch_id ?? null,
      legacyMappingCount:
        cleanTarget?.inventory?.identity_reconciliation_legacy_mappings ?? null,
      targetAppUserCount: cleanTarget?.inventory?.app_users ?? null,
      activeLedgerEpochCount: ledger?.open_epoch_count ?? null,
      rollbackPacketSha256: rollback?.packet_sha256 ?? null,
      acceptanceChecks: greenfieldAcceptanceChecks.length,
      physicalDeviceAcceptancePassed:
        iphone?.status === "passed"
        && watch?.status === "passed"
        && releaseConfig?.status === "passed",
      writeMode: acceptedTraffic?.write_mode ?? null,
      readyForProductionTraffic: errors.length === 0,
    },
  };
}

export function validateGreenfieldLaunchPacket(packet, options = {}) {
  return validateGreenfieldLaunchPacketContract(packet, options, 3);
}

export function validateHistoricalGreenfieldLaunchPacketV2(
  packet,
  options = {},
) {
  return validateGreenfieldLaunchPacketContract(packet, options, 2);
}
