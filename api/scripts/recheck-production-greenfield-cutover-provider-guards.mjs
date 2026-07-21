import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  canonicalSanitizedJSON,
  computeSanitizedReceiptSha256,
  productionWorker,
  productionWorkerSecretNames,
} from "./greenfield-launch-packet.mjs";
import {
  loadProductionClerkWebhookPreparationSources,
  productionClerkWebhookTarget,
  validateProductionClerkWebhookPreparationReceipt,
} from "./prepare-production-clerk-webhook.mjs";
import {
  loadProductionGreenfieldWorkerLineageSources,
  validateProductionGreenfieldWorkerLineageReceipt,
} from "./prepare-production-greenfield-worker-lineage.mjs";
import { productionRuntimeProvisioningTarget } from
  "./provision-production-runtime.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const apiDirectory = resolve(scriptDirectory, "..");
const MAX_OUTPUT_BYTES = 4 * 1024 * 1024;
const COMMAND_TIMEOUT_MS = 120_000;
const COMMAND_KILL_GRACE_MS = 2_000;
const wranglerCommand = "./node_modules/.bin/wrangler";
const cloudflareCommand = "cf";
const wranglerVersion = "4.110.0";
const cloudflareVersion = "0.1.0";
const clerkVersion = "2.2.0";
const zoneId = "955d108e63b6a9743e0e74206e2dbe09";
const receiptType = "refwatch_production_greenfield_cutover_provider_guard";
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const utcInstantPattern =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u;

export const productionGreenfieldProviderGuardGate =
  "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_PROVIDER_GUARD_RECHECK";
const productionGreenfieldCutoverGate =
  "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER";

function cfArgs(...args) {
  return Object.freeze(["--quiet", ...args]);
}

export const productionGreenfieldProviderGuardCommands = Object.freeze({
  wranglerVersion: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze(["--version"]),
  }),
  cloudflareVersion: Object.freeze({
    command: cloudflareCommand,
    args: Object.freeze(["--version"]),
  }),
  cloudflareContext: Object.freeze({
    command: cloudflareCommand,
    args: cfArgs("context", "show"),
  }),
  versionsList: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze([
      "versions", "list", "--name", productionWorker.name,
      "--env-file", "/dev/null", "--json",
    ]),
  }),
  deploymentStatus: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze([
      "deployments", "status", "--name", productionWorker.name,
      "--env-file", "/dev/null", "--json",
    ]),
  }),
  secretInventory: Object.freeze({
    command: cloudflareCommand,
    args: cfArgs(
      "workers", "secrets", "list", "--script-name", productionWorker.name,
    ),
  }),
  scriptSubdomain: Object.freeze({
    command: cloudflareCommand,
    args: cfArgs(
      "workers", "scripts", "subdomain", "get",
      "--script-name", productionWorker.name,
    ),
  }),
  zoneRoutes: Object.freeze({
    command: cloudflareCommand,
    args: cfArgs("--zone", zoneId, "workers", "routes", "list"),
  }),
  customDomains: Object.freeze({
    command: cloudflareCommand,
    args: cfArgs(
      "workers", "domains", "list", "--zone-id", zoneId,
      "--hostname", productionWorker.hostname,
    ),
  }),
  dnsRecords: Object.freeze({
    command: cloudflareCommand,
    args: cfArgs(
      "--zone", zoneId, "dns", "records", "list",
      "--name-exact", productionWorker.hostname,
      "--page", "1", "--per-page", "100",
    ),
  }),
  accessApplications: Object.freeze({
    command: cloudflareCommand,
    args: cfArgs(
      "zero-trust", "access", "applications", "list",
      "--domain", productionWorker.hostname, "--exact",
      "--page", "1", "--per-page", "100",
    ),
  }),
});

export class ProductionGreenfieldProviderGuardMissingAuditEvidenceError
  extends Error {
  constructor() {
    super("Production greenfield provider guard is blocked by missing audit evidence");
    this.name = "ProductionGreenfieldProviderGuardMissingAuditEvidenceError";
  }

  toJSON() {
    return {
      schema_version: 1,
      receipt_type: "refwatch_production_greenfield_provider_guard_blocker",
      status: "blocked_missing_audit_evidence",
      audit_source: "cloudflare_account_audit_logs_v2",
      route_mutation_count: null,
      access_mutation_count: null,
      provider_state_read_attempted: false,
    };
  }
}

export async function loadProductionGreenfieldProviderGuardSources() {
  const [packageJSON, packageLock, clerk, lineage] = await Promise.all([
    readFile(resolve(apiDirectory, "package.json"), "utf8"),
    readFile(resolve(apiDirectory, "package-lock.json"), "utf8"),
    loadProductionClerkWebhookPreparationSources(),
    loadProductionGreenfieldWorkerLineageSources(),
  ]);
  return validateProductionGreenfieldProviderGuardSources({
    packageJSON,
    packageLock,
    clerk,
    lineage,
  });
}

export function validateProductionGreenfieldProviderGuardSources(value) {
  let packageJSON;
  let packageLock;
  try {
    packageJSON = JSON.parse(value?.packageJSON);
    packageLock = JSON.parse(value?.packageLock);
  } catch {
    throw new Error("Production greenfield provider guard source contract is invalid");
  }
  if (
    packageJSON?.devDependencies?.clerk !== clerkVersion
    || packageJSON?.devDependencies?.wrangler !== "^4.110.0"
    || packageLock?.packages?.["node_modules/clerk"]?.version !== clerkVersion
    || packageLock?.packages?.["node_modules/wrangler"]?.version
      !== wranglerVersion
    || value?.clerk?.clerkCliVersion !== clerkVersion
    || typeof value?.lineage?.manifestSha256 !== "string"
    || !Number.isSafeInteger(value?.lineage?.fileCount)
    || value.lineage.fileCount <= 0
  ) throw new Error("Production greenfield provider guard reviewed sources drifted");
  return Object.freeze({
    clerkCliVersion: clerkVersion,
    wranglerVersion,
    cloudflareVersion,
    workerLineageManifestSha256: value.lineage.manifestSha256,
    workerLineageManifestFileCount: value.lineage.fileCount,
  });
}

export async function recheckProductionGreenfieldCutoverProviderGuards(
  input,
  options = {},
) {
  const environment = options.environment ?? process.env;
  if (
    environment[productionGreenfieldCutoverGate] !== "1"
    || environment[productionGreenfieldProviderGuardGate] !== "1"
  ) throw genericGuardError();
  if (typeof options.readAuditEvidence !== "function") {
    throw new ProductionGreenfieldProviderGuardMissingAuditEvidenceError();
  }
  if (
    !input?.clerkController
    || typeof input.clerkController.readExact !== "function"
  ) throw genericGuardError();

  try {
    await (options.loadSources ?? loadProductionGreenfieldProviderGuardSources)();
    const clerkReceipt = validateProductionClerkWebhookPreparationReceipt(
      input.clerkWebhookPreparationReceipt,
    );
    const lineageReceipt = validateProductionGreenfieldWorkerLineageReceipt(
      input.workerLineageReceipt,
    );
    validateBrokerBindings(input, clerkReceipt, lineageReceipt);

    const providerEnvironment = buildProviderEnvironment(environment);
    const commandRunner = options.runCommand
      ?? runProductionGreenfieldProviderGuardCommand;
    const run = async (specification) => commandRunner({
      command: specification.command,
      args: specification.args,
      cwd: apiDirectory,
      environment: providerEnvironment,
      signal: input.signal,
    });
    const observedWranglerVersion = consumeVersion(
      await run(productionGreenfieldProviderGuardCommands.wranglerVersion),
    );
    const observedCloudflareVersion = consumeVersion(
      await run(productionGreenfieldProviderGuardCommands.cloudflareVersion),
    );
    if (
      observedWranglerVersion !== wranglerVersion
      || observedCloudflareVersion !== cloudflareVersion
    ) throw genericGuardError();
    validateCloudflareContext(consumeJSON(
      await run(productionGreenfieldProviderGuardCommands.cloudflareContext),
    ));

    const clerkGuard = validateClerkGuardReadback(
      await input.clerkController.readExact(),
      clerkReceipt,
      latestReviewTime(input.reviewQuorum),
    );
    if (clerkGuard.clerk_cli_version !== clerkVersion) throw genericGuardError();

    const first = await readCloudflareState(run, lineageReceipt);
    const second = await readCloudflareState(run, lineageReceipt);
    if (canonicalSanitizedJSON(first) !== canonicalSanitizedJSON(second)) {
      throw genericGuardError();
    }
    const now = options.now ?? (() => new Date());
    const observedAtUTC = normalizeUTCInstant(now());
    const audit = validateAuditEvidence(await options.readAuditEvidence({
      accountId: productionRuntimeProvisioningTarget.cloudflareAccountId,
      zoneId,
      workerName: productionWorker.name,
      hostname: productionWorker.hostname,
      sinceUTC: lineageReceipt.observed_at_utc,
      beforeUTC: observedAtUTC,
      signal: input.signal,
    }), lineageReceipt.observed_at_utc, observedAtUTC);
    const payload = {
      schema_version: 1,
      receipt_type: receiptType,
      status: "passed",
      observed_at_utc: observedAtUTC,
      checkpoint_sha256: input.checkpoint.receipt_sha256,
      clerk_webhook_preparation_receipt_sha256: clerkReceipt.receipt_sha256,
      worker_lineage_receipt_sha256: lineageReceipt.receipt_sha256,
      clerk_guard: mapClerkGuard(clerkGuard),
      worker_guard: {
        observed_at_utc: observedAtUTC,
        deployment_id: first.deployment_id,
        sole_worker_version_id: first.sole_worker_version_id,
        deployment_version_count: 1,
        sole_traffic_percentage: 100,
        secret_names: [...productionWorkerSecretNames],
        secret_count: productionWorkerSecretNames.length,
        route_mutation_count: audit.route_mutation_count,
        access_mutation_count: audit.access_mutation_count,
      },
    };
    return Object.freeze({
      ...payload,
      receipt_sha256: computeSanitizedReceiptSha256(payload),
    });
  } catch (error) {
    if (error instanceof ProductionGreenfieldProviderGuardMissingAuditEvidenceError) {
      throw error;
    }
    throw genericGuardError();
  }
}

async function readCloudflareState(run, lineageReceipt) {
  const results = [];
  for (const command of [
    productionGreenfieldProviderGuardCommands.versionsList,
    productionGreenfieldProviderGuardCommands.deploymentStatus,
    productionGreenfieldProviderGuardCommands.secretInventory,
    productionGreenfieldProviderGuardCommands.scriptSubdomain,
    productionGreenfieldProviderGuardCommands.zoneRoutes,
    productionGreenfieldProviderGuardCommands.customDomains,
    productionGreenfieldProviderGuardCommands.dnsRecords,
    productionGreenfieldProviderGuardCommands.accessApplications,
  ]) results.push(consumeJSON(await run(command)));
  validateVersionHistory(results[0], lineageReceipt);
  const deployment = validateDeployment(results[1], lineageReceipt);
  validateSecrets(results[2]);
  requireExactKeys(results[3], ["enabled", "previews_enabled"]);
  if (results[3].enabled !== false || results[3].previews_enabled !== false) {
    throw genericGuardError();
  }
  for (const value of results.slice(4)) requireEmptyProviderCollection(value);
  return Object.freeze({
    deployment_id: deployment.deployment_id,
    sole_worker_version_id: deployment.sole_worker_version_id,
    secret_names: Object.freeze([...productionWorkerSecretNames]),
    workers_dev_enabled: false,
    previews_enabled: false,
    zone_route_count: 0,
    custom_domain_count: 0,
    dns_record_count: 0,
    access_application_count: 0,
  });
}

function validateVersionHistory(value, lineageReceipt) {
  if (!Array.isArray(value) || value.length === 0 || value.length > 10) {
    throw genericGuardError();
  }
  const actual = value.map((entry) => ({
    id: requireUUID(entry?.id),
    number: requirePositiveInteger(entry?.number),
    created_at_utc: normalizeUTCInstant(entry?.metadata?.created_on),
    trigger: requireString(entry?.annotations?.["workers/triggered_by"]),
    tag: optionalString(entry?.annotations?.["workers/tag"]),
    message: optionalString(entry?.annotations?.["workers/message"]),
  }));
  if (
    canonicalSanitizedJSON(actual)
      !== canonicalSanitizedJSON(
        lineageReceipt.deployment_guard.final_version_history,
      )
  ) throw genericGuardError();
  const readbacks = lineageReceipt.version_readbacks;
  for (const key of [
    "source_s", "candidate_a", "accepted_b", "write_guard_g",
    "last_known_good_l",
  ]) {
    if (!actual.some((entry) => entry.id === readbacks[key].worker_version_id)) {
      throw genericGuardError();
    }
  }
}

function validateDeployment(value, lineageReceipt) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw genericGuardError();
  }
  const expected = lineageReceipt.deployment_guard.final_readback;
  if (
    value.id !== expected.deployment_id
    || value.source !== expected.source
    || value.strategy !== expected.strategy
    || normalizeUTCInstant(value.created_on) !== expected.created_at_utc
    || !Array.isArray(value.versions)
    || value.versions.length !== 1
    || value.versions[0]?.version_id
      !== lineageReceipt.version_readbacks.last_known_good_l.worker_version_id
    || value.versions[0]?.percentage !== 100
  ) throw genericGuardError();
  return Object.freeze({
    deployment_id: value.id,
    sole_worker_version_id: value.versions[0].version_id,
  });
}

function validateSecrets(value) {
  if (!Array.isArray(value)) throw genericGuardError();
  const names = value.map((entry) => {
    requireExactKeys(entry, ["name", "type"]);
    if (entry.type !== "secret_text") throw genericGuardError();
    return requireString(entry.name);
  }).sort();
  if (
    new Set(names).size !== names.length
    || canonicalSanitizedJSON(names)
      !== canonicalSanitizedJSON([...productionWorkerSecretNames].sort())
  ) throw genericGuardError();
}

function requireEmptyProviderCollection(value) {
  if (Array.isArray(value)) {
    if (value.length !== 0) throw genericGuardError();
    return;
  }
  requireExactKeys(value, ["result", "result_info"]);
  if (!Array.isArray(value.result) || value.result.length !== 0) {
    throw genericGuardError();
  }
  if (
    !value.result_info
    || typeof value.result_info !== "object"
    || Array.isArray(value.result_info)
    || !["count", "total_count"].some((key) => value.result_info[key] === 0)
  ) throw genericGuardError();
}

function validateCloudflareContext(value) {
  if (
    !value
    || typeof value !== "object"
    || Array.isArray(value)
    || value.accountId?.value
      !== productionRuntimeProvisioningTarget.cloudflareAccountId
  ) throw genericGuardError();
}

function validateClerkGuardReadback(value, receipt, latestReview) {
  requireExactKeys(value, [
    "observed_at_utc", "clerk_cli_version", "clerk_application_id",
    "clerk_application_name", "clerk_instance_id", "user_count",
    "svix_application_id", "endpoint_inventory_count", "endpoint_id",
    "endpoint_uid", "endpoint_url", "endpoint_description", "event_types",
    "disabled", "header_count", "sensitive_header_name_count",
    "transformation_enabled", "transformation_present",
    "endpoint_created_at_utc", "endpoint_updated_at_utc",
  ]);
  const final = receipt.final_provider_readback;
  if (
    Date.parse(normalizeUTCInstant(value.observed_at_utc)) <= latestReview
    || value.clerk_application_id !== productionClerkWebhookTarget.clerkApplicationId
    || value.clerk_application_id !== receipt.clerk.application_id
    || value.clerk_application_name !== productionClerkWebhookTarget.clerkApplicationName
    || value.clerk_instance_id !== productionClerkWebhookTarget.clerkInstanceId
    || value.clerk_instance_id !== receipt.clerk.instance_id
    || value.user_count !== 0
    || value.svix_application_id !== final.svix_application_id
    || value.endpoint_inventory_count !== 1
    || value.endpoint_id !== final.endpoint_id
    || value.endpoint_uid !== productionClerkWebhookTarget.endpointUid
    || value.endpoint_uid !== final.endpoint_uid
    || value.endpoint_url !== productionClerkWebhookTarget.endpointURL
    || value.endpoint_url !== final.endpoint_url
    || value.endpoint_description !== productionClerkWebhookTarget.endpointDescription
    || value.endpoint_description !== final.endpoint_description
    || canonicalSanitizedJSON(value.event_types)
      !== canonicalSanitizedJSON(productionClerkWebhookTarget.eventTypes)
    || value.disabled !== true
    || value.header_count !== 0
    || value.sensitive_header_name_count !== 0
    || value.transformation_enabled !== false
    || value.transformation_present !== false
  ) throw genericGuardError();
  normalizeUTCInstant(value.endpoint_created_at_utc);
  normalizeUTCInstant(value.endpoint_updated_at_utc);
  return value;
}

function mapClerkGuard(value) {
  const {
    clerk_cli_version: _clerkCliVersion,
    clerk_application_name: _clerkApplicationName,
    endpoint_created_at_utc: _createdAt,
    endpoint_updated_at_utc: _updatedAt,
    ...guard
  } = value;
  return guard;
}

function validateAuditEvidence(value, sinceUTC, beforeUTC) {
  requireExactKeys(value, [
    "source", "account_id", "complete", "since_utc", "before_utc",
    "route_mutation_count", "access_mutation_count",
  ]);
  if (
    value.source !== "cloudflare_account_audit_logs_v2"
    || value.account_id !== productionRuntimeProvisioningTarget.cloudflareAccountId
    || value.complete !== true
    || value.since_utc !== sinceUTC
    || value.before_utc !== beforeUTC
    || value.route_mutation_count !== 0
    || value.access_mutation_count !== 0
  ) throw genericGuardError();
  return value;
}

function validateBrokerBindings(input, clerkReceipt, lineageReceipt) {
  if (
    !input.checkpoint
    || input.checkpoint.receipt_sha256 !== input.reviewQuorum?.checkpoint_sha256
    || input.checkpoint.clerk_webhook_preparation_receipt_sha256
      !== clerkReceipt.receipt_sha256
    || input.checkpoint.worker_lineage_receipt_sha256
      !== lineageReceipt.receipt_sha256
    || !Array.isArray(input.reviewQuorum?.reviews)
    || input.reviewQuorum.reviews.length !== 2
  ) throw genericGuardError();
  latestReviewTime(input.reviewQuorum);
}

function latestReviewTime(reviewQuorum) {
  const times = reviewQuorum.reviews.map((review) => {
    if (review.verdict !== "NO FINDINGS") throw genericGuardError();
    return Date.parse(normalizeUTCInstant(review.reviewed_at_utc));
  });
  return Math.max(...times);
}

export function runProductionGreenfieldProviderGuardCommand(
  specification,
  options = {},
) {
  const spawnImpl = options.spawnImpl ?? spawn;
  const timeoutMs = options.timeoutMs ?? COMMAND_TIMEOUT_MS;
  const maxOutputBytes = options.maxOutputBytes ?? MAX_OUTPUT_BYTES;
  const killGraceMs = options.killGraceMs ?? COMMAND_KILL_GRACE_MS;
  return new Promise((resolvePromise, rejectPromise) => {
    let child;
    try {
      child = spawnImpl(specification.command, specification.args, {
        cwd: specification.cwd,
        env: specification.environment,
        signal: specification.signal,
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch {
      rejectPromise(genericGuardError());
      return;
    }
    let settled = false;
    let failed = false;
    let bytes = 0;
    const chunks = [];
    let killTimer;
    const timeout = setTimeout(() => fail(), timeoutMs);
    const finish = (success) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (killTimer) clearTimeout(killTimer);
      if (!success) {
        for (const chunk of chunks) chunk.fill(0);
        rejectPromise(genericGuardError());
        return;
      }
      const stdout = Buffer.concat(chunks);
      for (const chunk of chunks) chunk.fill(0);
      resolvePromise({ stdout });
    };
    function fail() {
      if (failed) return;
      failed = true;
      child.kill?.("SIGTERM");
      killTimer = setTimeout(() => {
        child.kill?.("SIGKILL");
        finish(false);
      }, killGraceMs);
    }
    const capture = (chunk, keep) => {
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      bytes += buffer.byteLength;
      if (bytes > maxOutputBytes) fail();
      if (keep && !failed) chunks.push(buffer);
      else buffer.fill(0);
    };
    child.stdout?.on("data", (chunk) => capture(chunk, true));
    child.stderr?.on("data", (chunk) => capture(chunk, false));
    child.on("error", fail);
    child.on("close", (code) => finish(!failed && code === 0));
  });
}

export async function runProductionGreenfieldProviderGuardCLI(options = {}) {
  const args = options.args ?? process.argv.slice(2);
  const writeStdout = options.writeStdout ?? ((value) => process.stdout.write(value));
  const writeStderr = options.writeStderr ?? ((value) => process.stderr.write(value));
  if (args.length === 1 && args[0] === "--check") {
    try {
      await (options.checkSources ?? loadProductionGreenfieldProviderGuardSources)();
      writeStdout("Production greenfield provider guard sources verified.\n");
      return 0;
    } catch {
      writeStderr("Production greenfield provider guard source check failed.\n");
      return 1;
    }
  }
  writeStderr(
    "Standalone production greenfield provider guard execution is disabled; use the reviewed same-process cutover orchestrator.\n",
  );
  return 2;
}

function buildProviderEnvironment(environment) {
  const result = {};
  for (const name of [
    "PATH", "HOME", "USER", "LOGNAME", "SHELL", "TMPDIR", "LANG",
    "LC_ALL", "TERM", "COLORTERM", "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_API_KEY", "CLOUDFLARE_EMAIL",
  ]) if (environment[name] !== undefined) result[name] = environment[name];
  return {
    ...result,
    CLOUDFLARE_ACCOUNT_ID: productionRuntimeProvisioningTarget.cloudflareAccountId,
    WRANGLER_WRITE_LOGS: "0",
    WRANGLER_LOG_SANITIZE: "true",
    WRANGLER_SEND_METRICS: "false",
    NO_COLOR: "1",
  };
}

function consumeVersion(result) {
  const bytes = outputBuffer(result);
  try {
    const match = bytes.toString("utf8").trim()
      .match(/(?:^|[^0-9])(\d+\.\d+\.\d+)(?:[^0-9]|$)/u);
    if (!match) throw genericGuardError();
    return match[1];
  } finally {
    bytes.fill(0);
  }
}

function consumeJSON(result) {
  const bytes = outputBuffer(result);
  try {
    return JSON.parse(bytes.toString("utf8"));
  } catch {
    throw genericGuardError();
  } finally {
    bytes.fill(0);
  }
}

function outputBuffer(result) {
  if (Buffer.isBuffer(result?.stdout)) return result.stdout;
  if (typeof result?.stdout === "string" || ArrayBuffer.isView(result?.stdout)) {
    return Buffer.from(result.stdout);
  }
  throw genericGuardError();
}

function requireExactKeys(value, keys) {
  if (
    !value || typeof value !== "object" || Array.isArray(value)
    || canonicalSanitizedJSON(Object.keys(value).sort())
      !== canonicalSanitizedJSON([...keys].sort())
  ) throw genericGuardError();
}

function normalizeUTCInstant(value) {
  const date = value instanceof Date ? value : new Date(value);
  const normalized = date.toISOString();
  if (!utcInstantPattern.test(normalized) || normalized !== String(
    value instanceof Date ? value.toISOString() : value,
  )) throw genericGuardError();
  return normalized;
}

function requireUUID(value) {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw genericGuardError();
  }
  return value;
}

function requirePositiveInteger(value) {
  if (!Number.isSafeInteger(value) || value <= 0) throw genericGuardError();
  return value;
}

function requireString(value) {
  if (typeof value !== "string" || value.length === 0) throw genericGuardError();
  return value;
}

function optionalString(value) {
  return value === undefined ? null : requireString(value);
}

function genericGuardError() {
  return new Error(
    "Production greenfield provider guard failed without disclosing provider output",
  );
}

if (
  process.argv[1]
  && resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) process.exitCode = await runProductionGreenfieldProviderGuardCLI();
