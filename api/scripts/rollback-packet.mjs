import { createHash } from "node:crypto";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const sha256Pattern = /^[0-9a-f]{64}$/;
const requiredThresholds = [
  "auth_failure_rate_percent",
  "owner_scope_violations",
  "worker_5xx_rate_percent",
  "sync_backlog_oldest_seconds",
  "database_connection_utilization_percent",
];
const requiredLedgerFields = [
  "schema_version", "event_id", "event_sequence", "epoch_id", "mutation_group_id",
  "group_ordinal", "entity_type", "entity_id", "entity_revision", "operation",
  "before", "after", "source_kind", "source_event_id", "request_id",
  "idempotency_key", "app_user_id", "method", "path", "actor_id",
  "worker_version_id", "captured_at_utc", "content_digest", "encryption_key_id",
];
const activeRollbackProfiles = new Set([
  "stateful_migration_v1",
  "greenfield_destructive_v1",
  "greenfield_destructive_v3",
]);
const historicalGreenfieldRollbackProfile = "greenfield_destructive_v2";
const activeGreenfieldRollbackProfile = "greenfield_destructive_v3";
const requiredGreenfieldRecoverySteps = [
  "stop_production_traffic_and_writes",
  "route_to_write_guard_worker",
  "roll_back_worker_and_client",
  "reset_planetscale_application_state",
  "reseed_deterministic_reference_data",
  "recreate_test_identities",
  "rerun_greenfield_launch_acceptance",
];
const requiredGreenfieldRecoveryKeys = [
  "mode",
  "steps",
  "operator_instructions",
  "ledger_escrow_required",
  "ledger_recovery_required",
  "ledger_activation_required",
  "supabase_reverse_import_required",
];
const v2TopLevelKeys = [
  "schema_version",
  "rollback_profile",
  "status",
  "owner",
  "approved_at_utc",
  "window",
  "trigger_thresholds",
  "versions",
  "greenfield_recovery",
  "client_recovery_release",
];
const v3TopLevelKeys = [
  ...v2TopLevelKeys,
  "edge_binding",
  "conflicting_zone_route_count",
  "manual_dns_origin_present",
];
const v2VersionKeys = [
  "worker_name",
  "environment",
  "candidate_worker_version_id",
  "accepted_worker_version_id",
  "last_known_good_worker_version_id",
  "write_guard_worker_version_id",
  "provider_readback_at_utc",
  "write_guard_probe",
  "last_known_good_probe",
];
const v2ProbeKeys = [
  "status",
  "receipt_id",
  "receipt_sha256",
  "observed_at_utc",
  "worker_version_id",
  "worker_name",
  "environment",
  "versions_provider_readback_at_utc",
  "deployment_id",
  "deployment_provider_receipt_id",
  "deployment_provider_readback_sha256",
  "deployment_observed_before_at_utc",
  "deployment_observed_after_at_utc",
  "route_id",
  "hostname",
  "route_pattern",
  "traffic_percentage",
  "competing_version_count",
  "health_status",
  "health_worker_version_id",
  "readiness_status",
  "readiness_worker_version_id",
  "write_mode",
  "new_user_onboarding_mode",
  "write_denial_status",
  "write_denial_http_status",
  "identity_mutation_count",
  "application_mutation_count",
  "clerk_instance_id",
  "database_branch_id",
];
const v3ProbeKeys = v2ProbeKeys.filter(
  (key) => !["route_id", "hostname", "route_pattern"].includes(key),
).concat([
  "edge_binding",
  "conflicting_zone_route_count",
  "manual_dns_origin_present",
]);
const v2ClientKeys = [
  "marketing_version",
  "build",
  "distribution_status",
  "operator_instructions",
];
const productionClerkInstanceId = "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac";
const productionDatabaseBranchId = "w3g1f8vcbg34";
const productionHostname = "api.refwatch.ibby.ai";
const productionRoutePattern = "api.refwatch.ibby.ai/*";
const productionWorkerName = "refwatch-api";
const cloudflareProviderIdPattern =
  /^(?:[0-9a-f]{32}|[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i;
const customDomainEdgeBindingKeys = [
  "kind",
  "hostname",
  "provider_id",
  "worker_name",
  "tls_status",
  "dns_management",
];

const utcInstantPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;

function validUTCInstant(value) {
  if (typeof value !== "string" || !utcInstantPattern.test(value)) return false;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return false;
  const canonical = value.includes(".")
    ? value
    : value.replace(/Z$/, ".000Z");
  return parsed.toISOString() === canonical;
}

function requireCondition(condition, message, errors) {
  if (!condition) errors.push(message);
}

function hasOwn(value, name) {
  return value !== null
    && typeof value === "object"
    && Object.prototype.hasOwnProperty.call(value, name);
}

function hasExactKeys(value, expectedKeys) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort();
  const expected = [...expectedKeys].sort();
  return actual.length === expected.length
    && actual.every((key, index) => key === expected[index]);
}

function validateCustomDomainEdgeBinding(value, label, errors) {
  requireCondition(
    hasExactKeys(value, customDomainEdgeBindingKeys),
    `${label} keys must exactly match the Cloudflare Custom Domain binding contract`,
    errors,
  );
  requireCondition(
    value?.kind === "custom_domain",
    `${label}.kind must be custom_domain`,
    errors,
  );
  requireCondition(
    value?.hostname === productionHostname,
    `${label}.hostname must be ${productionHostname}`,
    errors,
  );
  requireCondition(
    cloudflareProviderIdPattern.test(value?.provider_id ?? ""),
    `${label}.provider_id must be a Cloudflare provider identifier`,
    errors,
  );
  requireCondition(
    value?.worker_name === productionWorkerName,
    `${label}.worker_name must be ${productionWorkerName}`,
    errors,
  );
  requireCondition(
    value?.tls_status === "active",
    `${label}.tls_status must be active`,
    errors,
  );
  requireCondition(
    value?.dns_management === "cloudflare_worker_custom_domain",
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

function canonicalSanitizedJSON(value) {
  if (value === null || typeof value === "boolean" || typeof value === "string") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("rollback receipt contains a non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalSanitizedJSON).join(",")}]`;
  }
  if (value && typeof value === "object") {
    const keys = Object.keys(value).sort();
    return `{${keys.map((key) => {
      if (value[key] === undefined) throw new Error("rollback receipt contains undefined");
      return `${JSON.stringify(key)}:${canonicalSanitizedJSON(value[key])}`;
    }).join(",")}}`;
  }
  throw new Error("rollback receipt contains an unsupported value");
}

function computeReceiptSha256(value, digestField) {
  const payload = Object.fromEntries(
    Object.entries(value ?? {}).filter(([key]) => key !== digestField),
  );
  return createHash("sha256").update(canonicalSanitizedJSON(payload)).digest("hex");
}

function validateGreenfieldFallbackProbe(
  probe,
  label,
  expectedVersionId,
  providerReadbackAtUTC,
  contractVersion,
  errors,
) {
  const isV3 = contractVersion === 3;
  requireCondition(
    hasExactKeys(probe, isV3 ? v3ProbeKeys : v2ProbeKeys),
    `${label} keys must exactly match the greenfield v${contractVersion} fallback probe contract`,
    errors,
  );
  requireCondition(probe?.status === "passed", `${label}.status must be passed`, errors);
  requireCondition(
    typeof probe?.receipt_id === "string" && probe.receipt_id.trim().length > 0,
    `${label}.receipt_id is required`,
    errors,
  );
  requireCondition(
    sha256Pattern.test(probe?.receipt_sha256 ?? ""),
    `${label}.receipt_sha256 must be SHA-256`,
    errors,
  );
  try {
    requireCondition(
      probe?.receipt_sha256 === computeReceiptSha256(probe, "receipt_sha256"),
      `${label}.receipt_sha256 must match the canonical sanitized probe`,
      errors,
    );
  } catch {
    errors.push(`${label} must contain a canonical sanitized probe`);
  }
  requireCondition(validUTCInstant(probe?.observed_at_utc), `${label}.observed_at_utc must be a strict UTC instant`, errors);
  requireCondition(
    probe?.worker_version_id === expectedVersionId,
    `${label}.worker_version_id must match the fallback Worker version`,
    errors,
  );
  requireCondition(probe?.worker_name === "refwatch-api", `${label}.worker_name must be refwatch-api`, errors);
  requireCondition(probe?.environment === "production", `${label}.environment must be production`, errors);
  requireCondition(
    probe?.versions_provider_readback_at_utc === providerReadbackAtUTC,
    `${label}.versions_provider_readback_at_utc must match versions.provider_readback_at_utc`,
    errors,
  );
  requireCondition(
    typeof probe?.deployment_id === "string" && probe.deployment_id.trim().length > 0,
    `${label}.deployment_id is required`,
    errors,
  );
  requireCondition(
    typeof probe?.deployment_provider_receipt_id === "string"
      && probe.deployment_provider_receipt_id.trim().length > 0,
    `${label}.deployment_provider_receipt_id is required`,
    errors,
  );
  requireCondition(
    sha256Pattern.test(probe?.deployment_provider_readback_sha256 ?? ""),
    `${label}.deployment_provider_readback_sha256 must be SHA-256`,
    errors,
  );
  try {
    const providerPayload = {
      receipt_id: probe?.deployment_provider_receipt_id,
      deployment_id: probe?.deployment_id,
      worker_version_id: probe?.worker_version_id,
      ...(isV3
        ? {
            edge_binding: probe?.edge_binding,
            conflicting_zone_route_count:
              probe?.conflicting_zone_route_count,
            manual_dns_origin_present: probe?.manual_dns_origin_present,
          }
        : {
            route_id: probe?.route_id,
            hostname: probe?.hostname,
            route_pattern: probe?.route_pattern,
          }),
      traffic_percentage: probe?.traffic_percentage,
      competing_version_count: probe?.competing_version_count,
      observed_before_at_utc: probe?.deployment_observed_before_at_utc,
      observed_after_at_utc: probe?.deployment_observed_after_at_utc,
    };
    const expectedProviderDigest = createHash("sha256")
      .update(canonicalSanitizedJSON(providerPayload))
      .digest("hex");
    requireCondition(
      probe?.deployment_provider_readback_sha256 === expectedProviderDigest,
      `${label}.deployment_provider_readback_sha256 must match the canonical provider deployment readback`,
      errors,
    );
  } catch {
    errors.push(`${label} provider deployment readback must be canonical and sanitized`);
  }
  requireCondition(
    validUTCInstant(probe?.deployment_observed_before_at_utc),
    `${label}.deployment_observed_before_at_utc must be a strict UTC instant`,
    errors,
  );
  requireCondition(
    validUTCInstant(probe?.deployment_observed_after_at_utc),
    `${label}.deployment_observed_after_at_utc must be a strict UTC instant`,
    errors,
  );
  if (isV3) {
    validateCustomDomainEdgeBinding(probe?.edge_binding, `${label}.edge_binding`, errors);
    requireCondition(
      probe?.conflicting_zone_route_count === 0,
      `${label}.conflicting_zone_route_count must be zero`,
      errors,
    );
    requireCondition(
      probe?.manual_dns_origin_present === false,
      `${label}.manual_dns_origin_present must be false`,
      errors,
    );
  } else {
    requireCondition(
      typeof probe?.route_id === "string" && probe.route_id.trim().length > 0,
      `${label}.route_id is required`,
      errors,
    );
    requireCondition(
      probe?.hostname === productionHostname && probe?.route_pattern === productionRoutePattern,
      `${label} must use the exact production route`,
      errors,
    );
  }
  requireCondition(
    probe?.traffic_percentage === 100 && probe?.competing_version_count === 0,
    `${label} must prove the exact fallback version at 100 percent with no competitor`,
    errors,
  );
  requireCondition(probe?.health_status === "passed", `${label}.health_status must be passed`, errors);
  requireCondition(probe?.readiness_status === "passed", `${label}.readiness_status must be passed`, errors);
  requireCondition(
    probe?.health_worker_version_id === expectedVersionId,
    `${label}.health_worker_version_id must report the fallback Worker version`,
    errors,
  );
  requireCondition(
    probe?.readiness_worker_version_id === expectedVersionId,
    `${label}.readiness_worker_version_id must report the fallback Worker version`,
    errors,
  );
  requireCondition(probe?.write_mode === "disabled", `${label}.write_mode must be disabled`, errors);
  requireCondition(
    probe?.new_user_onboarding_mode === "disabled",
    `${label}.new_user_onboarding_mode must be disabled`,
    errors,
  );
  requireCondition(
    probe?.write_denial_status === "retryable_denial"
      && probe?.write_denial_http_status === 503,
    `${label} must prove retryable write denial with HTTP 503`,
    errors,
  );
  requireCondition(
    probe?.identity_mutation_count === 0 && probe?.application_mutation_count === 0,
    `${label} must prove zero identity and application mutations`,
    errors,
  );
  requireCondition(
    probe?.clerk_instance_id === productionClerkInstanceId,
    `${label}.clerk_instance_id must match production`,
    errors,
  );
  requireCondition(
    probe?.database_branch_id === productionDatabaseBranchId,
    `${label}.database_branch_id must match production`,
    errors,
  );
  if (validUTCInstant(providerReadbackAtUTC) && validUTCInstant(probe?.observed_at_utc)) {
    requireCondition(
      Date.parse(probe.observed_at_utc) > Date.parse(providerReadbackAtUTC),
      `${label} must follow the exact Worker-version readback`,
      errors,
    );
  }
  if (
    validUTCInstant(probe?.deployment_observed_before_at_utc)
    && validUTCInstant(probe?.observed_at_utc)
    && validUTCInstant(probe?.deployment_observed_after_at_utc)
  ) {
    requireCondition(
      Date.parse(probe.deployment_observed_before_at_utc)
        < Date.parse(probe.observed_at_utc)
        && Date.parse(probe.observed_at_utc)
          < Date.parse(probe.deployment_observed_after_at_utc),
      `${label} operational probe must be bracketed by provider deployment readbacks`,
      errors,
    );
  }
}

function validateRollbackPacketContract(packet, options, contractVersion) {
  const errors = [];
  const now = options.now instanceof Date ? options.now : new Date();
  const hasExplicitRollbackProfile = hasOwn(packet, "rollback_profile");
  const rollbackProfile = hasExplicitRollbackProfile
    ? packet?.rollback_profile
    : "stateful_migration_v1";
  const window = packet?.window ?? {};
  const thresholds = packet?.trigger_thresholds ?? {};
  const versions = packet?.versions ?? {};
  const client = packet?.client_recovery_release ?? {};
  const isHistoricalV2 =
    contractVersion === 2
    && rollbackProfile === historicalGreenfieldRollbackProfile;
  const isActiveV3 =
    contractVersion === 3
    && rollbackProfile === activeGreenfieldRollbackProfile;
  const isBoundedGreenfield = isHistoricalV2 || isActiveV3;

  requireCondition(packet?.schema_version === 1, "schema_version must be 1", errors);
  if (contractVersion === 2) {
    requireCondition(
      isHistoricalV2,
      `historical rollback_profile must be ${historicalGreenfieldRollbackProfile}`,
      errors,
    );
  } else {
    requireCondition(
      activeRollbackProfiles.has(rollbackProfile),
      "rollback_profile must be stateful_migration_v1, greenfield_destructive_v1, or greenfield_destructive_v3",
      errors,
    );
  }
  if (isHistoricalV2 || isActiveV3) {
    const profileLabel = isActiveV3
      ? activeGreenfieldRollbackProfile
      : historicalGreenfieldRollbackProfile;
    const versionLabel = isActiveV3 ? "v3" : "v2";
    requireCondition(
      hasExactKeys(packet, isActiveV3 ? v3TopLevelKeys : v2TopLevelKeys),
      `${profileLabel} top-level keys must exactly match the ${versionLabel} rollback contract`,
      errors,
    );
    requireCondition(
      hasExactKeys(window, ["start_at_utc", "end_at_utc"]),
      `${profileLabel} window keys must exactly match the ${versionLabel} rollback contract`,
      errors,
    );
    requireCondition(
      hasExactKeys(thresholds, requiredThresholds),
      `${profileLabel} trigger_thresholds keys must exactly match the ${versionLabel} rollback contract`,
      errors,
    );
    requireCondition(
      hasExactKeys(versions, v2VersionKeys),
      `${profileLabel} versions keys must exactly match the ${versionLabel} rollback contract`,
      errors,
    );
    requireCondition(
      hasExactKeys(client, v2ClientKeys),
      `${profileLabel} client_recovery_release keys must exactly match the ${versionLabel} rollback contract`,
      errors,
    );
    if (isActiveV3) {
      validateCustomDomainEdgeBinding(
        packet?.edge_binding,
        "edge_binding",
        errors,
      );
      requireCondition(
        packet?.conflicting_zone_route_count === 0,
        "conflicting_zone_route_count must be zero",
        errors,
      );
      requireCondition(
        packet?.manual_dns_origin_present === false,
        "manual_dns_origin_present must be false",
        errors,
      );
    }
  }
  requireCondition(packet?.status === "approved", "status must be approved", errors);
  requireCondition(typeof packet?.owner === "string" && packet.owner.trim().length > 0, "owner is required", errors);
  requireCondition(validUTCInstant(packet?.approved_at_utc), "approved_at_utc must be a strict UTC instant", errors);
  requireCondition(validUTCInstant(window.start_at_utc), "window.start_at_utc must be a strict UTC instant", errors);
  requireCondition(validUTCInstant(window.end_at_utc), "window.end_at_utc must be a strict UTC instant", errors);
  if (validUTCInstant(window.start_at_utc) && validUTCInstant(window.end_at_utc)) {
    requireCondition(Date.parse(window.end_at_utc) > Date.parse(window.start_at_utc), "rollback window end must be after start", errors);
    requireCondition(Date.parse(window.end_at_utc) > now.getTime(), "rollback window must not already be expired", errors);
  }
  if (validUTCInstant(packet?.approved_at_utc) && validUTCInstant(window.start_at_utc)) {
    requireCondition(Date.parse(packet.approved_at_utc) <= Date.parse(window.start_at_utc), "approval must not occur after the rollback window starts", errors);
  }

  for (const name of requiredThresholds) {
    requireCondition(typeof thresholds[name] === "number" && Number.isFinite(thresholds[name]) && thresholds[name] >= 0, `trigger_thresholds.${name} must be a non-negative number`, errors);
  }
  for (const name of ["auth_failure_rate_percent", "worker_5xx_rate_percent", "database_connection_utilization_percent"]) {
    requireCondition(typeof thresholds[name] === "number" && thresholds[name] <= 100, `trigger_thresholds.${name} must not exceed 100`, errors);
  }
  requireCondition(thresholds.owner_scope_violations === 0, "owner_scope_violations threshold must be zero", errors);
  const requiredWorkerVersionIds = isBoundedGreenfield
    ? [
        "candidate_worker_version_id",
        "accepted_worker_version_id",
        "last_known_good_worker_version_id",
        "write_guard_worker_version_id",
      ]
    : [
        "candidate_worker_version_id",
        "last_known_good_worker_version_id",
        "write_guard_worker_version_id",
      ];
  for (const name of requiredWorkerVersionIds) {
    requireCondition(uuidPattern.test(versions[name] ?? ""), `versions.${name} must be a Worker version UUID`, errors);
  }
  const versionIds = new Set(requiredWorkerVersionIds.map((name) => versions[name]));
  requireCondition(
    versionIds.size === requiredWorkerVersionIds.length,
    isBoundedGreenfield
      ? "candidate, accepted, last-known-good, and write-guard versions must be distinct"
      : "candidate, last-known-good, and write-guard versions must be distinct",
    errors,
  );
  requireCondition(versions.worker_name === "refwatch-api", "versions.worker_name must be refwatch-api", errors);
  requireCondition(versions.environment === "production", "versions.environment must be production", errors);

  if (rollbackProfile === "stateful_migration_v1") {
    const ledger = packet?.write_ledger ?? {};
    requireCondition(!hasOwn(packet, "greenfield_recovery"), "stateful_migration_v1 must not include greenfield_recovery", errors);
    requireCondition(typeof ledger.location === "string" && ledger.location.startsWith("restricted://refwatch/"), "write_ledger.location must use the restricted RefWatch namespace", errors);
    requireCondition(ledger.schema_version === 1, "write_ledger.schema_version must be 1", errors);
    const fields = new Set(Array.isArray(ledger.fields) ? ledger.fields : []);
    for (const field of requiredLedgerFields) requireCondition(fields.has(field), `write_ledger.fields must include ${field}`, errors);
    requireCondition(validUTCInstant(ledger.provider_readback_at_utc), "write_ledger.provider_readback_at_utc must be a strict UTC instant", errors);
    requireCondition(typeof ledger.probe_receipt_id === "string" && ledger.probe_receipt_id.trim().length > 0, "write_ledger.probe_receipt_id is required", errors);
  }

  if (
    rollbackProfile === "greenfield_destructive_v1"
    || isBoundedGreenfield
  ) {
    const recovery = packet?.greenfield_recovery ?? {};
    const steps = Array.isArray(recovery.steps) ? recovery.steps : [];
    requireCondition(!hasOwn(packet, "write_ledger"), `${rollbackProfile} must not include write_ledger`, errors);
    requireCondition(
      hasExactKeys(recovery, requiredGreenfieldRecoveryKeys),
      "greenfield_recovery keys must exactly match the greenfield destructive recovery contract",
      errors,
    );
    requireCondition(recovery.mode === "destructive_reset_reseed_recreate", "greenfield_recovery.mode must be destructive_reset_reseed_recreate", errors);
    requireCondition(
      JSON.stringify(steps) === JSON.stringify(requiredGreenfieldRecoverySteps),
      "greenfield_recovery.steps must exactly match the approved destructive recovery sequence",
      errors,
    );
    requireCondition(
      typeof recovery.operator_instructions === "string" && recovery.operator_instructions.trim().length > 0,
      "greenfield_recovery.operator_instructions are required",
      errors,
    );
    requireCondition(recovery.ledger_escrow_required === false, "greenfield_recovery.ledger_escrow_required must be false", errors);
    requireCondition(recovery.ledger_recovery_required === false, "greenfield_recovery.ledger_recovery_required must be false", errors);
    requireCondition(recovery.ledger_activation_required === false, "greenfield_recovery.ledger_activation_required must be false", errors);
    requireCondition(
      recovery.supabase_reverse_import_required === false,
      "greenfield_recovery.supabase_reverse_import_required must be false",
      errors,
    );
  }

  requireCondition(validUTCInstant(versions.provider_readback_at_utc), "versions.provider_readback_at_utc must be a strict UTC instant", errors);
  if (isBoundedGreenfield) {
    validateGreenfieldFallbackProbe(
      versions.write_guard_probe,
      "versions.write_guard_probe",
      versions.write_guard_worker_version_id,
      versions.provider_readback_at_utc,
      contractVersion,
      errors,
    );
    validateGreenfieldFallbackProbe(
      versions.last_known_good_probe,
      "versions.last_known_good_probe",
      versions.last_known_good_worker_version_id,
      versions.provider_readback_at_utc,
      contractVersion,
      errors,
    );
    requireCondition(
      versions.write_guard_probe?.receipt_id !== versions.last_known_good_probe?.receipt_id,
      `greenfield v${contractVersion} fallback probe receipt IDs must be distinct`,
      errors,
    );
    requireCondition(
      versions.write_guard_probe?.deployment_id !== versions.last_known_good_probe?.deployment_id,
      `greenfield v${contractVersion} fallback probe deployment IDs must be distinct`,
      errors,
    );
    requireCondition(
      versions.write_guard_probe?.deployment_provider_receipt_id
        !== versions.last_known_good_probe?.deployment_provider_receipt_id,
      `greenfield v${contractVersion} fallback provider receipt IDs must be distinct`,
      errors,
    );
    if (isActiveV3) {
      requireCondition(
        sameCanonicalValue(
          versions.write_guard_probe?.edge_binding,
          packet?.edge_binding,
        )
          && sameCanonicalValue(
            versions.last_known_good_probe?.edge_binding,
            packet?.edge_binding,
          ),
        "greenfield v3 rollback and fallback probes must use the same Custom Domain binding",
        errors,
      );
    } else {
      requireCondition(
        versions.write_guard_probe?.route_id === versions.last_known_good_probe?.route_id,
        "greenfield v2 fallback probes must use the same production route ID",
        errors,
      );
    }

    const probeTimeline = [
      ["versions.write_guard_probe", versions.write_guard_probe],
      ["versions.last_known_good_probe", versions.last_known_good_probe],
    ];
    for (const [label, probe] of probeTimeline) {
      if (
        validUTCInstant(window.start_at_utc)
        && validUTCInstant(probe?.deployment_observed_before_at_utc)
        && validUTCInstant(probe?.deployment_observed_after_at_utc)
        && validUTCInstant(window.end_at_utc)
      ) {
        requireCondition(
          Date.parse(window.start_at_utc)
            < Date.parse(probe.deployment_observed_before_at_utc)
            && Date.parse(probe.deployment_observed_after_at_utc)
              < Date.parse(window.end_at_utc),
          `${label} provider-bracketed proof must occur inside the rollback window`,
          errors,
        );
        requireCondition(
          Date.parse(probe.deployment_observed_after_at_utc) <= now.getTime(),
          `${label} provider-bracketed proof must complete by validation time`,
          errors,
        );
      }
    }
    if (
      validUTCInstant(versions.write_guard_probe?.deployment_observed_after_at_utc)
      && validUTCInstant(
        versions.last_known_good_probe?.deployment_observed_before_at_utc,
      )
    ) {
      requireCondition(
        Date.parse(versions.write_guard_probe.deployment_observed_after_at_utc)
          < Date.parse(
            versions.last_known_good_probe.deployment_observed_before_at_utc,
          ),
        "write-guard provider readback must complete before the last-known-good provider readback begins",
        errors,
      );
    }
    if (validUTCInstant(versions.provider_readback_at_utc)) {
      requireCondition(
        Date.parse(versions.provider_readback_at_utc) <= now.getTime(),
        "versions.provider_readback_at_utc must not be in the future",
        errors,
      );
    }
  } else {
    requireCondition(
      typeof versions.write_guard_probe_receipt_id === "string"
        && versions.write_guard_probe_receipt_id.trim().length > 0,
      "versions.write_guard_probe_receipt_id is required",
      errors,
    );
  }

  requireCondition(typeof client.marketing_version === "string" && client.marketing_version.length > 0, "client recovery marketing_version is required", errors);
  requireCondition(typeof client.build === "string" && client.build.length > 0, "client recovery build is required", errors);
  requireCondition(["app_store_ready", "testflight_ready", "managed_distribution_ready"].includes(client.distribution_status), "client recovery release must already be distributable", errors);
  requireCondition(typeof client.operator_instructions === "string" && client.operator_instructions.trim().length > 0, "client recovery operator_instructions are required", errors);

  return {
    ok: errors.length === 0,
    errors,
    summary: {
      rollbackProfile: rollbackProfile ?? null,
      owner: packet?.owner ?? null,
      windowEndUTC: window.end_at_utc ?? null,
      workerName: versions.worker_name ?? null,
      recoveryMode: rollbackProfile === "greenfield_destructive_v1"
        || isBoundedGreenfield
        ? packet?.greenfield_recovery?.mode ?? null
        : rollbackProfile === "stateful_migration_v1"
          ? "stateful_ledger_recovery"
          : null,
      clientRecovery: client.marketing_version && client.build ? `${client.marketing_version} (${client.build})` : null,
    },
  };
}

export function validateRollbackPacket(packet, options = {}) {
  return validateRollbackPacketContract(packet, options, 3);
}

export function validateHistoricalGreenfieldRollbackPacketV2(
  packet,
  options = {},
) {
  return validateRollbackPacketContract(packet, options, 2);
}
