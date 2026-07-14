const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const requiredThresholds = [
  "auth_failure_rate_percent",
  "owner_scope_violations",
  "worker_5xx_rate_percent",
  "sync_backlog_oldest_seconds",
  "database_connection_utilization_percent",
];
const requiredLedgerFields = [
  "request_id", "idempotency_key", "app_user_id", "method", "path",
  "entity_type", "entity_id", "operation", "committed_at_utc", "worker_version_id",
];

const utcInstantPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;

function validUTCInstant(value) {
  return typeof value === "string" && utcInstantPattern.test(value) && !Number.isNaN(Date.parse(value));
}

function requireCondition(condition, message, errors) {
  if (!condition) errors.push(message);
}

export function validateRollbackPacket(packet, options = {}) {
  const errors = [];
  const now = options.now instanceof Date ? options.now : new Date();
  const window = packet?.window ?? {};
  const thresholds = packet?.trigger_thresholds ?? {};
  const versions = packet?.versions ?? {};
  const ledger = packet?.write_ledger ?? {};
  const client = packet?.client_recovery_release ?? {};

  requireCondition(packet?.schema_version === 1, "schema_version must be 1", errors);
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
  for (const name of ["candidate_worker_version_id", "last_known_good_worker_version_id", "write_guard_worker_version_id"]) {
    requireCondition(uuidPattern.test(versions[name] ?? ""), `versions.${name} must be a Worker version UUID`, errors);
  }
  const versionIds = new Set([
    versions.candidate_worker_version_id,
    versions.last_known_good_worker_version_id,
    versions.write_guard_worker_version_id,
  ]);
  requireCondition(versionIds.size === 3, "candidate, last-known-good, and write-guard versions must be distinct", errors);
  requireCondition(versions.worker_name === "refwatch-api-production", "versions.worker_name must be refwatch-api-production", errors);
  requireCondition(versions.environment === "production", "versions.environment must be production", errors);

  requireCondition(typeof ledger.location === "string" && ledger.location.startsWith("restricted://refwatch/"), "write_ledger.location must use the restricted RefWatch namespace", errors);
  requireCondition(ledger.schema_version === 1, "write_ledger.schema_version must be 1", errors);
  const fields = new Set(Array.isArray(ledger.fields) ? ledger.fields : []);
  for (const field of requiredLedgerFields) requireCondition(fields.has(field), `write_ledger.fields must include ${field}`, errors);
  requireCondition(validUTCInstant(ledger.provider_readback_at_utc), "write_ledger.provider_readback_at_utc must be a strict UTC instant", errors);
  requireCondition(typeof ledger.probe_receipt_id === "string" && ledger.probe_receipt_id.trim().length > 0, "write_ledger.probe_receipt_id is required", errors);
  requireCondition(validUTCInstant(versions.provider_readback_at_utc), "versions.provider_readback_at_utc must be a strict UTC instant", errors);
  requireCondition(typeof versions.write_guard_probe_receipt_id === "string" && versions.write_guard_probe_receipt_id.trim().length > 0, "versions.write_guard_probe_receipt_id is required", errors);

  requireCondition(typeof client.marketing_version === "string" && client.marketing_version.length > 0, "client recovery marketing_version is required", errors);
  requireCondition(typeof client.build === "string" && client.build.length > 0, "client recovery build is required", errors);
  requireCondition(["app_store_ready", "testflight_ready", "managed_distribution_ready"].includes(client.distribution_status), "client recovery release must already be distributable", errors);
  requireCondition(typeof client.operator_instructions === "string" && client.operator_instructions.trim().length > 0, "client recovery operator_instructions are required", errors);

  return {
    ok: errors.length === 0,
    errors,
    summary: {
      owner: packet?.owner ?? null,
      windowEndUTC: window.end_at_utc ?? null,
      workerName: versions.worker_name ?? null,
      clientRecovery: client.marketing_version && client.build ? `${client.marketing_version} (${client.build})` : null,
    },
  };
}
