import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  canonicalSanitizedJSON,
  computeSanitizedReceiptSha256,
  productionClerk,
  productionClerkLifecycleWebhook,
} from "./greenfield-launch-packet.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const apiDirectory = resolve(scriptDirectory, "..");
const MAX_COMMAND_OUTPUT_BYTES = 64 * 1024;
const MAX_JSON_RESPONSE_BYTES = 512 * 1024;
const MAX_LOGIN_RESPONSE_BYTES = 32 * 1024;
const MAX_SECRET_RESPONSE_BYTES = 2 * 1024;
const MAX_PORTAL_ASSET_BYTES = 3 * 1024 * 1024;
const COMMAND_TIMEOUT_MS = 120_000;
const COMMAND_KILL_GRACE_MS = 2_000;
const FETCH_TIMEOUT_MS = 30_000;
const MAX_ENDPOINT_PAGES = 20;
const MAX_ENDPOINTS = 500;
const ENDPOINT_PAGE_LIMIT = 50;
const receiptType = "refwatch_production_clerk_webhook_preparation";
const clerkCliVersion = "2.2.0";
const clerkCommand = "./node_modules/.bin/clerk";
const portalOrigin = "https://app.svix.com";
const portalLoginURL = `${portalOrigin}/login`;
const portalAssetPath = "/assets/index-pi6pKO0v.js";
const portalAssetSha256 =
  "b4820c5b0d199afbc9d688f9ce87056c32dcb304cff93b7a0588e6cb40d22643";
const launchPacketSha256 =
  "21b671ba5a5f585fe8ee4982a0ca1dfa570d15bbe23eb20c8f3e219e18772508";
const clerkLockContractSha256 =
  "4a4bab3d651b0333b4a87ccae0c05a656898babe05210bc47c5f93a8664c6ae4";
const endpointIdPattern = /^ep_[A-Za-z0-9]+$/u;
const svixApplicationIdPattern = /^app_[A-Za-z0-9]+$/u;
const signingSecretPrefix = String.fromCharCode(
  0x77,
  0x68,
  0x73,
  0x65,
  0x63,
  0x5f,
);
const signingSecretPrefixBytes = Buffer.from([
  0x77,
  0x68,
  0x73,
  0x65,
  0x63,
  0x5f,
]);
const secretLikePrefixes = Object.freeze([
  signingSecretPrefix,
  ["sk", "live", ""].join("_"),
  ["sk", "test", ""].join("_"),
  ["app", "sk", "_"].join(""),
]);
const utcInstantPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u;

export const productionClerkWebhookPreparationGate =
  "REFWATCH_ALLOW_PRODUCTION_CLERK_WEBHOOK_PREPARATION";

export const productionClerkWebhookTarget = Object.freeze({
  clerkApplicationId: productionClerk.applicationId,
  clerkApplicationName: productionClerk.applicationName,
  developmentClerkInstanceId: productionClerk.developmentInstanceId,
  clerkInstanceId: productionClerk.instanceId,
  endpointUid: productionClerkLifecycleWebhook.endpointUid,
  endpointDescription: productionClerkLifecycleWebhook.endpointDescription,
  endpointURL: productionClerkLifecycleWebhook.endpointURL,
  eventTypes: productionClerkLifecycleWebhook.eventTypes,
  disabled: true,
});

function clerkAPIArguments(endpoint, method) {
  return Object.freeze([
    "--mode",
    "agent",
    "api",
    endpoint,
    "--app",
    productionClerk.applicationId,
    "--instance",
    productionClerk.instanceId,
    "-X",
    method,
    "--yes",
  ]);
}

export const productionClerkWebhookCommands = Object.freeze({
  version: Object.freeze({
    command: clerkCommand,
    args: Object.freeze(["--version"]),
  }),
  whoami: Object.freeze({
    command: clerkCommand,
    args: Object.freeze([
      "--mode",
      "agent",
      "whoami",
      "--json",
    ]),
  }),
  userCount: Object.freeze({
    command: clerkCommand,
    args: clerkAPIArguments("/users/count", "GET"),
  }),
  svixURL: Object.freeze({
    command: clerkCommand,
    args: clerkAPIArguments("/webhooks/svix_url", "POST"),
  }),
});

export const productionClerkWebhookPortalContract = Object.freeze({
  portalOrigin,
  loginURL: portalLoginURL,
  assetPath: portalAssetPath,
  assetSha256: portalAssetSha256,
  exchangePath: "/api/v1/auth/one-time-token",
  requiredCapabilities: Object.freeze([
    "ManageEndpoint",
    "ViewEndpointSecret",
  ]),
  supportedCapabilities: Object.freeze([
    "CreateAttempts",
    "ManageEndpoint",
    "ManageEndpointSecret",
    "ManageTransformations",
    "ViewBase",
    "ViewEndpointSecret",
  ]),
  supportedRegions: Object.freeze(["au", "ca", "eu", "in", "us"]),
});

const sourcePaths = Object.freeze({
  packageJSON: resolve(apiDirectory, "package.json"),
  packageLock: resolve(apiDirectory, "package-lock.json"),
  launchPacket: resolve(scriptDirectory, "greenfield-launch-packet.mjs"),
});

export async function loadProductionClerkWebhookPreparationSources() {
  const [packageJSON, packageLock, launchPacket] = await Promise.all([
    readFile(sourcePaths.packageJSON, "utf8"),
    readFile(sourcePaths.packageLock, "utf8"),
    readFile(sourcePaths.launchPacket),
  ]);
  return validateProductionClerkWebhookPreparationSources({
    packageJSON,
    packageLock,
    launchPacket,
  });
}

export function validateProductionClerkWebhookPreparationSources(source) {
  const packageJSON = parseSourceJSON(source?.packageJSON);
  const packageLock = parseSourceJSON(source?.packageLock);
  const packet = source?.launchPacket;
  if (!(typeof packet === "string" || ArrayBuffer.isView(packet))) {
    throw new Error("Production Clerk webhook source contract is invalid");
  }
  const clerkLockEntries = Object.entries(packageLock?.packages ?? {})
    .filter(([path]) =>
      path === "node_modules/clerk"
      || path.startsWith("node_modules/@clerk/cli-"))
    .map(([path, entry]) => ({
      path,
      version: entry?.version,
      resolved: entry?.resolved,
      integrity: entry?.integrity,
    }))
    .sort((left, right) => left.path.localeCompare(right.path));
  if (
    packageJSON?.dependencies?.["@clerk/backend"] !== "^3.11.4"
    || packageJSON?.devDependencies?.clerk !== clerkCliVersion
    || packageJSON?.scripts?.["clerk:webhook:production"] !== undefined
    || packageJSON?.scripts?.["clerk:webhook:production:check"]
      !== "node scripts/prepare-production-clerk-webhook.mjs --check"
    || packageLock?.packages?.["node_modules/@clerk/backend"]?.version !== "3.11.4"
    || computeSanitizedReceiptSha256(clerkLockEntries)
      !== clerkLockContractSha256
    || sha256Hex(packet) !== launchPacketSha256
    || productionClerk.instanceId !== "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac"
    || productionClerkLifecycleWebhook.endpointURL
      !== "https://api.refwatch.ibby.ai/webhooks/clerk"
    || productionClerkWebhookCommands.version.args.includes("--secret-key")
    || productionClerkWebhookCommands.whoami.args.includes("--secret-key")
    || productionClerkWebhookCommands.userCount.args.includes("--secret-key")
    || productionClerkWebhookCommands.svixURL.args.includes("--secret-key")
  ) {
    throw new Error("Production Clerk webhook reviewed sources drifted");
  }
  return Object.freeze({
    clerkBackendVersion: "3.11.4",
    clerkCliVersion,
    clerkLockContractSha256,
    launchPacketSha256,
    portalAssetPath,
    portalAssetSha256,
  });
}

export async function loadProductionClerkWebhookPortalProtocol(options = {}) {
  const fetchProvider = options.fetchProvider ?? globalThis.fetch;
  if (typeof fetchProvider !== "function") {
    throw genericPreparationError();
  }
  const login = await fetchBytes(fetchProvider, portalLoginURL, {
    method: "GET",
    headers: { accept: "text/html" },
    redirect: "error",
  }, MAX_LOGIN_RESPONSE_BYTES, ["text/html"], options.fetchTimeoutMs);
  const loginHTML = login.toString("utf8");
  login.fill(0);
  const assetPaths = [...loginHTML.matchAll(
    /<script\b[^>]*\bsrc=["']([^"']*\/assets\/index-[A-Za-z0-9_-]+\.js)["'][^>]*>/gu,
  )].map((match) => new URL(match[1], portalLoginURL).pathname);
  if (assetPaths.length !== 1 || assetPaths[0] !== portalAssetPath) {
    throw genericPreparationError();
  }
  const assetURL = `${portalOrigin}${portalAssetPath}`;
  const asset = await fetchBytes(fetchProvider, assetURL, {
    method: "GET",
    headers: { accept: "text/javascript, application/javascript" },
    redirect: "error",
  }, MAX_PORTAL_ASSET_BYTES, ["text/javascript", "application/javascript"],
  options.fetchTimeoutMs);
  try {
    const assetDigest = sha256Hex(asset);
    const source = asset.toString("utf8");
    if (
      assetDigest !== portalAssetSha256
      || !source.includes("/api/v1/auth/one-time-token")
      || !source.includes("oneTimeToken")
      || !source.includes("ManageEndpoint")
      || !source.includes("ViewEndpointSecret")
    ) {
      throw genericPreparationError();
    }
    return Object.freeze({
      portalOrigin,
      loginURL: portalLoginURL,
      assetPath: portalAssetPath,
      assetSha256: assetDigest,
    });
  } finally {
    asset.fill(0);
  }
}

export function parseProductionClerkWebhookSvixURL(value) {
  if (typeof value !== "string" || value.length < 32 || value.length > 16_384) {
    throw genericPreparationError();
  }
  let url;
  try {
    url = new URL(value);
  } catch {
    throw genericPreparationError();
  }
  if (
    url.protocol !== "https:"
    || url.origin !== portalOrigin
    || url.pathname !== "/login"
    || url.username !== ""
    || url.password !== ""
    || url.search !== ""
    || !url.hash.startsWith("#")
  ) throw genericPreparationError();

  const params = new URLSearchParams(url.hash.slice(1));
  if ([...params.keys()].length !== 1 || !params.has("key")) {
    throw genericPreparationError();
  }
  const encoded = params.get("key");
  if (
    typeof encoded !== "string"
    || encoded.length < 16
    || encoded.length > 12_288
    || encoded.length % 4 !== 0
    || !/^[A-Za-z0-9+/]+={0,2}$/u.test(encoded)
  ) throw genericPreparationError();
  let decoded;
  try {
    decoded = Buffer.from(encoded, "base64");
    if (decoded.toString("base64") !== encoded) throw new Error("invalid base64");
    const payload = JSON.parse(decoded.toString("utf8"));
    requireExactKeys(payload, payload?.serverUrl === undefined
      ? ["appId", "oneTimeToken", "region"]
      : ["appId", "oneTimeToken", "region", "serverUrl"]);
    if (
      payload.serverUrl !== undefined
      || !svixApplicationIdPattern.test(payload.appId ?? "")
      || !productionClerkWebhookPortalContract.supportedRegions.includes(
        payload.region,
      )
      || typeof payload.oneTimeToken !== "string"
      || payload.oneTimeToken.length < 16
      || payload.oneTimeToken.length > 4096
      || !/^[!-~]+$/u.test(payload.oneTimeToken)
    ) throw genericPreparationError();
    return Object.freeze({
      appId: payload.appId,
      region: payload.region,
      oneTimeToken: payload.oneTimeToken,
    });
  } catch {
    throw genericPreparationError();
  } finally {
    decoded?.fill(0);
  }
}

export async function withProductionClerkWebhookSecret(consumer, options = {}) {
  if (typeof consumer !== "function") throw genericPreparationError();
  const result = await acquireProductionClerkWebhookSecret(options);
  const controllerLease = createOpaqueEndpointController(
    result.controllerOperations,
  );
  try {
    return await consumer({
      secretMaterial: result.secretMaterial,
      receipt: result.receipt,
      controller: controllerLease.controller,
    });
  } catch {
    throw genericPreparationError();
  } finally {
    controllerLease.revoke();
    result.secretMaterial.fill(0);
  }
}

function createOpaqueEndpointController(operations) {
  let active = true;
  let operationInProgress = false;
  const invoke = async (operation) => {
    if (!active || operationInProgress) throw genericPreparationError();
    operationInProgress = true;
    try {
      return await operation();
    } catch {
      throw genericPreparationError();
    } finally {
      operationInProgress = false;
    }
  };
  return Object.freeze({
    controller: Object.freeze({
      readExact: () => invoke(() => operations.readExact()),
      setDisabled: (expected, next) => invoke(
        () => operations.setDisabled(expected, next),
      ),
    }),
    revoke: () => {
      active = false;
    },
  });
}

async function acquireProductionClerkWebhookSecret(options = {}) {
  const environment = options.environment ?? process.env;
  if (environment[productionClerkWebhookPreparationGate] !== "1") {
    throw new Error("Production Clerk webhook preparation gate is closed");
  }
  const sources = await (options.loadSources
    ?? loadProductionClerkWebhookPreparationSources)();
  const commandRunner = options.runCommand
    ?? runProductionClerkWebhookPreparationCommand;
  const fetchProvider = options.fetchProvider ?? globalThis.fetch;
  if (typeof fetchProvider !== "function") throw genericPreparationError();
  const fetchTimeoutMs = options.fetchTimeoutMs ?? FETCH_TIMEOUT_MS;
  const now = options.now ?? (() => new Date());
  if (
    !Number.isSafeInteger(fetchTimeoutMs)
    || fetchTimeoutMs <= 0
    || fetchTimeoutMs > FETCH_TIMEOUT_MS
  ) throw genericPreparationError();
  const providerEnvironment = buildClerkProviderEnvironment(environment);
  const run = async (specification) => commandRunner({
    command: specification.command,
    args: specification.args,
    cwd: apiDirectory,
    environment: providerEnvironment,
  });

  const version = consumeCommandText(
    await run(productionClerkWebhookCommands.version),
  );
  if (version !== clerkCliVersion) throw genericPreparationError();
  const whoami = validateWhoami(consumeCommandJSON(
    await run(productionClerkWebhookCommands.whoami),
  ));
  const readUserCount = async () => validateUserCount(consumeCommandJSON(
    await run(productionClerkWebhookCommands.userCount),
  ));
  const initialUserCount = await readUserCount();

  // The public hosted portal protocol is pinned before the authenticated
  // svix_url call, which may create Svix application state.
  const portalProtocol = await (options.loadPortalProtocol
    ?? (() => loadProductionClerkWebhookPortalProtocol({ fetchProvider })))();
  validatePortalProtocolReceipt(portalProtocol);

  const svixURLResponse = consumeCommandJSON(
    await run(productionClerkWebhookCommands.svixURL),
  );
  requireExactKeys(svixURLResponse, ["svix_url"]);
  const login = parseProductionClerkWebhookSvixURL(svixURLResponse.svix_url);
  const exchange = await exchangeOneTimeToken(
    fetchProvider,
    login,
    fetchTimeoutMs,
  );
  const preReconciliationUserCount = await readUserCount();
  const reconciliation = await reconcileEndpoint(
    fetchProvider,
    login,
    exchange.token,
    fetchTimeoutMs,
  );
  const endpointBehavior = await readEndpointBehavior(
    fetchProvider,
    login,
    exchange.token,
    reconciliation.endpoint.id,
    fetchTimeoutMs,
  );
  const postReconciliationUserCount = await readUserCount();
  const secretMaterial = await readEndpointSecret(
    fetchProvider,
    login,
    exchange.token,
    reconciliation.endpoint.id,
    fetchTimeoutMs,
  );
  try {
    const finalEndpoints = await listEndpoints(
      fetchProvider,
      login,
      exchange.token,
      fetchTimeoutMs,
    );
    const finalEndpoint = selectEndpoint(finalEndpoints);
    if (
      !finalEndpoint
      || finalEndpoint.id !== reconciliation.endpoint.id
      || canonicalSanitizedJSON(finalEndpoint)
        !== canonicalSanitizedJSON(reconciliation.endpoint)
    ) throw genericPreparationError();
    const finalEndpointBehavior = await readEndpointBehavior(
      fetchProvider,
      login,
      exchange.token,
      finalEndpoint.id,
      fetchTimeoutMs,
    );
    requireEqual(finalEndpointBehavior, endpointBehavior);
    const observedAtUTC = normalizeUTCInstant(now());
    const receipt = createReceipt({
      sources,
      whoami,
      initialUserCount,
      preReconciliationUserCount,
      postReconciliationUserCount,
      portalProtocol,
      login,
      capabilities: exchange.capabilities,
      reconciliation,
      endpointBehavior,
      finalProviderReadback: {
        endpointInventoryCount: finalEndpoints.length,
        endpoint: finalEndpoint,
        endpointBehavior: finalEndpointBehavior,
      },
      observedAtUTC,
    });
    const controllerOperations = Object.freeze({
      readExact: () => readExactControllerState({
        fetchProvider,
        fetchTimeoutMs,
        login,
        now,
        readUserCount,
        run,
        token: exchange.token,
      }),
      setDisabled: (expected, next) => setExactEndpointDisabled({
        expected,
        fetchProvider,
        fetchTimeoutMs,
        login,
        next,
        now,
        readUserCount,
        run,
        token: exchange.token,
      }),
    });
    return { controllerOperations, secretMaterial, receipt };
  } catch (error) {
    secretMaterial.fill(0);
    throw error;
  }
}

export function runProductionClerkWebhookPreparationCommand(
  specification,
  options = {},
) {
  const spawnImpl = options.spawnImpl ?? spawn;
  const timeoutMs = options.timeoutMs ?? COMMAND_TIMEOUT_MS;
  const maxOutputBytes = options.maxOutputBytes ?? MAX_COMMAND_OUTPUT_BYTES;
  const killGraceMs = options.killGraceMs ?? COMMAND_KILL_GRACE_MS;
  return new Promise((resolvePromise, rejectPromise) => {
    let child;
    try {
      child = spawnImpl(specification.command, specification.args, {
        cwd: specification.cwd,
        env: specification.environment,
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch {
      rejectPromise(genericPreparationError());
      return;
    }
    let settled = false;
    let failed = false;
    let outputBytes = 0;
    const stdoutChunks = [];
    let forceKillTimer;
    const timeout = setTimeout(() => fail(), timeoutMs);
    const clear = () => {
      for (const chunk of stdoutChunks) chunk.fill(0);
    };
    const finish = (successful) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (forceKillTimer) clearTimeout(forceKillTimer);
      if (!successful) {
        clear();
        rejectPromise(genericPreparationError());
        return;
      }
      const stdout = Buffer.concat(stdoutChunks);
      clear();
      resolvePromise({ stdout });
    };
    function fail() {
      if (failed) return;
      failed = true;
      child.kill?.("SIGTERM");
      forceKillTimer = setTimeout(() => {
        child.kill?.("SIGKILL");
        finish(false);
      }, killGraceMs);
    }
    const countOutput = (chunk) => {
      const bytes = Buffer.isBuffer(chunk)
        ? chunk.byteLength
        : Buffer.byteLength(String(chunk));
      outputBytes += bytes;
      if (outputBytes > maxOutputBytes) fail();
      return !failed;
    };
    child.stdout?.on("data", (chunk) => {
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      if (countOutput(buffer)) stdoutChunks.push(buffer);
      else buffer.fill(0);
    });
    child.stderr?.on("data", (chunk) => {
      countOutput(chunk);
      if (Buffer.isBuffer(chunk)) chunk.fill(0);
    });
    child.on("error", fail);
    child.on("close", (code) => finish(!failed && code === 0));
  });
}

export function validateProductionClerkWebhookPreparationReceipt(value) {
  requireExactKeys(value, [
    "clerk",
    "final_provider_readback",
    "observed_at_utc",
    "operation",
    "portal_protocol",
    "provider_command",
    "receipt_sha256",
    "receipt_type",
    "schema_version",
    "secret_material",
    "source_contract",
    "status",
    "svix",
  ]);
  requireEqual(value.schema_version, 1);
  requireEqual(value.receipt_type, receiptType);
  requireEqual(value.status, "prepared");
  if (!["created", "reused"].includes(value.operation)) {
    throw genericPreparationError();
  }
  requireUTCInstant(value.observed_at_utc);
  requireExactKeys(value.source_contract, [
    "clerk_backend_version",
    "clerk_cli_version",
    "clerk_lock_contract_sha256",
    "launch_packet_sha256",
  ]);
  requireEqual(value.source_contract, {
    clerk_backend_version: "3.11.4",
    clerk_cli_version: clerkCliVersion,
    clerk_lock_contract_sha256: clerkLockContractSha256,
    launch_packet_sha256: launchPacketSha256,
  });
  requireExactKeys(value.provider_command, [
    "command",
    "credential_source",
    "secret_key_argument_count",
    "svix_url_arguments",
    "user_count_arguments",
    "whoami_arguments",
  ]);
  requireEqual(value.provider_command, {
    command: clerkCommand,
    credential_source: "clerk_cli_oauth_credential_store",
    secret_key_argument_count: 0,
    whoami_arguments: [...productionClerkWebhookCommands.whoami.args],
    user_count_arguments: [...productionClerkWebhookCommands.userCount.args],
    svix_url_arguments: [...productionClerkWebhookCommands.svixURL.args],
  });
  requireExactKeys(value.clerk, [
    "application_id",
    "application_name",
    "initial_user_count",
    "instance_id",
    "post_reconciliation_user_count",
    "pre_reconciliation_user_count",
    "user_count",
    "user_count_source",
  ]);
  requireEqual(value.clerk?.application_id, productionClerk.applicationId);
  requireEqual(value.clerk?.application_name, productionClerk.applicationName);
  requireEqual(value.clerk?.instance_id, productionClerk.instanceId);
  requireEqual(value.clerk?.user_count, 0);
  requireEqual(value.clerk?.initial_user_count, 0);
  requireEqual(value.clerk?.pre_reconciliation_user_count, 0);
  requireEqual(value.clerk?.post_reconciliation_user_count, 0);
  requireEqual(
    value.clerk?.user_count_source,
    "clerk_backend_api_users_count",
  );
  requireExactKeys(value.portal_protocol, [
    "asset_path",
    "asset_sha256",
    "capabilities",
    "login_url",
    "portal_origin",
    "region",
  ]);
  requireEqual(value.portal_protocol?.portal_origin, portalOrigin);
  requireEqual(value.portal_protocol?.login_url, portalLoginURL);
  requireEqual(value.svix?.endpoint_uid, productionClerkWebhookTarget.endpointUid);
  requireEqual(value.svix?.endpoint_url, productionClerkWebhookTarget.endpointURL);
  requireEqual(value.svix?.event_types, [...productionClerkWebhookTarget.eventTypes]);
  requireEqual(value.svix?.disabled, true);
  requireEqual(value.svix?.header_count, 0);
  requireEqual(value.svix?.sensitive_header_name_count, 0);
  requireEqual(value.svix?.transformation_enabled, false);
  requireEqual(value.svix?.transformation_present, false);
  requireEqual(value.portal_protocol?.asset_path, portalAssetPath);
  requireEqual(value.portal_protocol?.asset_sha256, portalAssetSha256);
  if (!productionClerkWebhookPortalContract.supportedRegions.includes(
    value.portal_protocol?.region,
  )) throw genericPreparationError();
  const capabilities = value.portal_protocol?.capabilities;
  if (
    !Array.isArray(capabilities)
    || capabilities.length === 0
    || new Set(capabilities).size !== capabilities.length
    || capabilities.some((capability) =>
      !productionClerkWebhookPortalContract.supportedCapabilities.includes(
        capability,
      ))
    || productionClerkWebhookPortalContract.requiredCapabilities.some(
      (capability) => !capabilities.includes(capability),
    )
    || canonicalSanitizedJSON(capabilities)
      !== canonicalSanitizedJSON([...capabilities].sort())
  ) throw genericPreparationError();
  requireExactKeys(value.svix, [
    "application_id",
    "created_at_utc",
    "disabled",
    "endpoint_description",
    "endpoint_id",
    "endpoint_uid",
    "endpoint_url",
    "event_types",
    "header_count",
    "sensitive_header_name_count",
    "transformation_enabled",
    "transformation_present",
    "updated_at_utc",
  ]);
  if (
    !svixApplicationIdPattern.test(value.svix?.application_id ?? "")
    || !endpointIdPattern.test(value.svix?.endpoint_id ?? "")
  ) throw genericPreparationError();
  requireEqual(
    value.svix?.endpoint_description,
    productionClerkWebhookTarget.endpointDescription,
  );
  requireUTCInstant(value.svix?.created_at_utc);
  requireUTCInstant(value.svix?.updated_at_utc);
  if (
    Date.parse(value.svix.created_at_utc) > Date.parse(value.svix.updated_at_utc)
    || Date.parse(value.svix.updated_at_utc) > Date.parse(value.observed_at_utc)
  ) throw genericPreparationError();
  requireExactKeys(value.final_provider_readback, [
    "disabled",
    "endpoint_description",
    "endpoint_id",
    "endpoint_inventory_count",
    "endpoint_uid",
    "endpoint_url",
    "event_types",
    "header_count",
    "sensitive_header_name_count",
    "svix_application_id",
    "transformation_enabled",
    "transformation_present",
  ]);
  requireEqual(value.final_provider_readback, {
    svix_application_id: value.svix.application_id,
    endpoint_inventory_count: 1,
    endpoint_id: value.svix.endpoint_id,
    endpoint_uid: productionClerkWebhookTarget.endpointUid,
    endpoint_url: productionClerkWebhookTarget.endpointURL,
    endpoint_description: productionClerkWebhookTarget.endpointDescription,
    event_types: [...productionClerkWebhookTarget.eventTypes],
    disabled: true,
    header_count: 0,
    sensitive_header_name_count: 0,
    transformation_enabled: false,
    transformation_present: false,
  });
  requireExactKeys(value.secret_material, [
    "representation",
    "secret_values_hashed",
    "secret_values_recorded",
  ]);
  requireEqual(value.secret_material, {
    representation: "buffer",
    secret_values_hashed: false,
    secret_values_recorded: false,
  });
  if (containsSecretLikeValue(value)) throw genericPreparationError();
  const payload = Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== "receipt_sha256"),
  );
  requireEqual(value.receipt_sha256, computeSanitizedReceiptSha256(payload));
  return Object.freeze(value);
}

export async function runProductionClerkWebhookPreparationCLI(options = {}) {
  const args = options.args ?? process.argv.slice(2);
  const writeStdout = options.writeStdout
    ?? ((value) => process.stdout.write(value));
  const writeStderr = options.writeStderr
    ?? ((value) => process.stderr.write(value));
  const checkSources = options.checkSources
    ?? loadProductionClerkWebhookPreparationSources;

  if (args.length === 1 && args[0] === "--check") {
    try {
      await checkSources();
      writeStdout("Production Clerk webhook preparation sources verified.\n");
      return 0;
    } catch {
      writeStderr("Production Clerk webhook preparation source check failed.\n");
      return 1;
    }
  }
  if (args.length !== 1 || args[0] !== "--execute") {
    writeStderr(
      "Usage: node scripts/prepare-production-clerk-webhook.mjs --check|--execute\n",
    );
    return 2;
  }
  writeStderr(
    "Standalone production Clerk webhook preparation is disabled; use the reviewed same-process cutover orchestrator.\n",
  );
  return 2;
}

async function exchangeOneTimeToken(fetchProvider, login, fetchTimeoutMs) {
  const url = portalProxyURL(login.region, productionClerkWebhookPortalContract.exchangePath);
  const value = await fetchJSON(fetchProvider, url, {
    method: "POST",
    headers: {
      accept: "application/json",
      authorization: "Bearer unused",
      "content-type": "application/json",
    },
    body: JSON.stringify({ oneTimeToken: login.oneTimeToken }),
    redirect: "error",
  }, [200], fetchTimeoutMs);
  requireExactKeys(value, ["capabilities", "token"]);
  if (
    typeof value.token !== "string"
    || value.token.length < 16
    || value.token.length > 8192
    || !/^[!-~]+$/u.test(value.token)
    || !Array.isArray(value.capabilities)
    || new Set(value.capabilities).size !== value.capabilities.length
    || value.capabilities.some((capability) =>
      !productionClerkWebhookPortalContract.supportedCapabilities.includes(
        capability,
      ))
    || productionClerkWebhookPortalContract.requiredCapabilities.some(
      (capability) => !value.capabilities.includes(capability),
    )
  ) throw genericPreparationError();
  return Object.freeze({
    token: value.token,
    capabilities: Object.freeze([...value.capabilities].sort()),
  });
}

async function reconcileEndpoint(fetchProvider, login, token, fetchTimeoutMs) {
  let endpoints = await listEndpoints(fetchProvider, login, token, fetchTimeoutMs);
  let match = selectEndpoint(endpoints);
  let operation = "reused";
  if (!match) {
    operation = "created";
    const endpointURL = endpointsURL(login);
    try {
      const created = await fetchJSON(fetchProvider, endpointURL, {
        method: "POST",
        headers: providerJSONHeaders(token, {
          "idempotency-key":
            "refwatch-production-clerk-lifecycle-v1-create",
        }),
        body: JSON.stringify({
          description: productionClerkLifecycleWebhook.endpointDescription,
          disabled: true,
          filterTypes: [...productionClerkWebhookTarget.eventTypes],
          uid: productionClerkWebhookTarget.endpointUid,
          url: productionClerkWebhookTarget.endpointURL,
        }),
        redirect: "error",
      }, [200, 201], fetchTimeoutMs);
      validateEndpoint(created, true);
    } catch {
      // A response can be lost after Svix commits the deterministic create.
      // Never repeat POST: the bounded readback below is the only recovery.
    }
    endpoints = await listEndpoints(fetchProvider, login, token, fetchTimeoutMs);
    match = selectEndpoint(endpoints);
    if (!match) throw genericPreparationError();
  }
  return Object.freeze({ operation, endpoint: match });
}

async function listEndpoints(fetchProvider, login, token, fetchTimeoutMs) {
  const endpoints = [];
  const ids = new Set();
  const iterators = new Set();
  let iterator;
  for (let pageIndex = 0; pageIndex < MAX_ENDPOINT_PAGES; pageIndex += 1) {
    const url = new URL(endpointsURL(login));
    url.searchParams.set("limit", String(ENDPOINT_PAGE_LIMIT));
    url.searchParams.set("order", "ascending");
    if (iterator !== undefined) url.searchParams.set("iterator", iterator);
    const page = await fetchJSON(fetchProvider, url.href, {
      method: "GET",
      headers: providerJSONHeaders(token),
      redirect: "error",
    }, [200], fetchTimeoutMs);
    requireAllowedKeys(page, ["data", "done", "iterator", "prevIterator"]);
    if (
      !Array.isArray(page.data)
      || typeof page.done !== "boolean"
      || !(page.iterator === null || typeof page.iterator === "string")
    ) throw genericPreparationError();
    for (const raw of page.data) {
      const endpoint = validateEndpoint(raw, false);
      if (ids.has(endpoint.id)) throw genericPreparationError();
      ids.add(endpoint.id);
      endpoints.push(endpoint);
      if (endpoints.length > MAX_ENDPOINTS) throw genericPreparationError();
    }
    if (page.done) {
      if (page.iterator !== null) throw genericPreparationError();
      return Object.freeze(endpoints);
    }
    if (
      typeof page.iterator !== "string"
      || page.iterator.length === 0
      || page.iterator.length > 1024
      || iterators.has(page.iterator)
    ) throw genericPreparationError();
    iterators.add(page.iterator);
    iterator = page.iterator;
  }
  throw genericPreparationError();
}

function selectEndpoint(endpoints) {
  if (endpoints.length === 0) return undefined;
  if (endpoints.length !== 1 || !isExactEndpoint(endpoints[0])) {
    throw genericPreparationError();
  }
  return endpoints[0];
}

function selectControllerEndpoint(endpoints) {
  if (
    endpoints.length !== 1
    || !isExactEndpointCore(endpoints[0])
    || typeof endpoints[0].disabled !== "boolean"
  ) throw genericPreparationError();
  return endpoints[0];
}

function validateEndpoint(value, requireExact) {
  requireAllowedKeys(value, [
    "channels",
    "createdAt",
    "description",
    "disabled",
    "filterTypes",
    "id",
    "metadata",
    "rateLimit",
    "throttleRate",
    "uid",
    "updatedAt",
    "url",
    "version",
  ]);
  if (
    !endpointIdPattern.test(value.id ?? "")
    || typeof value.url !== "string"
    || value.url.length > 2048
    || typeof value.description !== "string"
    || value.description.length > 256
    || !(value.uid === null || typeof value.uid === "string")
    || !(value.disabled === undefined || typeof value.disabled === "boolean")
    || !(value.filterTypes === null || Array.isArray(value.filterTypes))
    || (Array.isArray(value.filterTypes)
      && value.filterTypes.some((event) => typeof event !== "string"))
    || !(value.channels === undefined || value.channels === null
      || Array.isArray(value.channels))
    || !(value.metadata === undefined || (
      value.metadata
      && typeof value.metadata === "object"
      && !Array.isArray(value.metadata)
    ))
    || !(value.rateLimit === undefined || value.rateLimit === null
      || Number.isFinite(value.rateLimit))
    || !(value.throttleRate === undefined || value.throttleRate === null
      || Number.isFinite(value.throttleRate))
  ) throw genericPreparationError();
  let endpointURL;
  try {
    endpointURL = new URL(value.url);
  } catch {
    throw genericPreparationError();
  }
  if (endpointURL.protocol !== "https:") throw genericPreparationError();
  const endpoint = Object.freeze({
    id: value.id,
    uid: value.uid ?? null,
    url: value.url,
    description: value.description,
    disabled: value.disabled,
    filterTypes: value.filterTypes === null
      ? null
      : Object.freeze([...value.filterTypes].sort()),
    channels: value.channels === undefined || value.channels === null
      ? null
      : Object.freeze([...value.channels].sort()),
    metadata: Object.freeze({ ...(value.metadata ?? {}) }),
    rateLimit: value.rateLimit ?? null,
    throttleRate: value.throttleRate ?? null,
    createdAtUTC: normalizeUTCInstant(value.createdAt),
    updatedAtUTC: normalizeUTCInstant(value.updatedAt),
  });
  if (requireExact && !isExactEndpoint(endpoint)) {
    throw genericPreparationError();
  }
  return endpoint;
}

function isExactEndpointCore(endpoint) {
  return endpoint.uid === productionClerkWebhookTarget.endpointUid
    && endpoint.url === productionClerkWebhookTarget.endpointURL
    && endpoint.description === productionClerkLifecycleWebhook.endpointDescription
    && endpoint.channels === null
    && canonicalSanitizedJSON(endpoint.metadata) === "{}"
    && endpoint.rateLimit === null
    && endpoint.throttleRate === null
    && canonicalSanitizedJSON(endpoint.filterTypes)
      === canonicalSanitizedJSON(
        [...productionClerkWebhookTarget.eventTypes].sort(),
      );
}

function isExactEndpoint(endpoint, disabled = true) {
  return isExactEndpointCore(endpoint) && endpoint.disabled === disabled;
}

async function readExactControllerState({
  fetchProvider,
  fetchTimeoutMs,
  login,
  now,
  readUserCount,
  run,
  token,
}) {
  const version = consumeCommandText(
    await run(productionClerkWebhookCommands.version),
  );
  if (version !== clerkCliVersion) throw genericPreparationError();
  const whoami = validateWhoami(consumeCommandJSON(
    await run(productionClerkWebhookCommands.whoami),
  ));
  const userCount = await readUserCount();
  const endpoints = await listEndpoints(
    fetchProvider,
    login,
    token,
    fetchTimeoutMs,
  );
  const endpoint = selectControllerEndpoint(endpoints);
  const behavior = await readEndpointBehavior(
    fetchProvider,
    login,
    token,
    endpoint.id,
    fetchTimeoutMs,
  );
  return Object.freeze({
    observed_at_utc: normalizeUTCInstant(now()),
    clerk_cli_version: clerkCliVersion,
    clerk_application_id: whoami.applicationId,
    clerk_application_name: whoami.applicationName,
    clerk_instance_id: whoami.productionInstanceId,
    user_count: userCount,
    svix_application_id: login.appId,
    endpoint_inventory_count: endpoints.length,
    endpoint_id: endpoint.id,
    endpoint_uid: endpoint.uid,
    endpoint_url: endpoint.url,
    endpoint_description: endpoint.description,
    event_types: Object.freeze([...productionClerkWebhookTarget.eventTypes]),
    disabled: endpoint.disabled,
    header_count: behavior.headerCount,
    sensitive_header_name_count: behavior.sensitiveHeaderNameCount,
    transformation_enabled: behavior.transformationEnabled,
    transformation_present: behavior.transformationPresent,
    endpoint_created_at_utc: endpoint.createdAtUTC,
    endpoint_updated_at_utc: endpoint.updatedAtUTC,
  });
}

async function setExactEndpointDisabled(options) {
  if (
    typeof options.expected !== "boolean"
    || typeof options.next !== "boolean"
    || options.expected === options.next
  ) throw genericPreparationError();
  const before = await readExactControllerState(options);
  if (before.disabled !== options.expected) throw genericPreparationError();
  const patched = validateEndpoint(await fetchJSON(
    options.fetchProvider,
    `${endpointsURL(options.login)}/${encodeURIComponent(before.endpoint_id)}`,
    {
      method: "PATCH",
      headers: providerJSONHeaders(options.token),
      body: JSON.stringify({ disabled: options.next }),
      redirect: "error",
    },
    [200],
    options.fetchTimeoutMs,
  ), false);
  if (
    patched.id !== before.endpoint_id
    || !isExactEndpoint(patched, options.next)
  ) throw genericPreparationError();
  const after = await readExactControllerState(options);
  if (
    after.endpoint_id !== before.endpoint_id
    || after.svix_application_id !== before.svix_application_id
    || after.disabled !== options.next
  ) throw genericPreparationError();
  return Object.freeze({
    operation: "set_disabled",
    expected_disabled: options.expected,
    disabled: options.next,
    before,
    after,
  });
}

async function readEndpointSecret(
  fetchProvider,
  login,
  token,
  endpointId,
  fetchTimeoutMs,
) {
  const bytes = await fetchBytes(
    fetchProvider,
    `${endpointsURL(login)}/${encodeURIComponent(endpointId)}/secret`,
    {
      method: "GET",
      headers: providerJSONHeaders(token),
      redirect: "error",
    },
    MAX_SECRET_RESPONSE_BYTES,
    ["application/json"],
    fetchTimeoutMs,
  );
  return parseEndpointSecretResponseBytes(bytes);
}

function parseEndpointSecretResponseBytes(bytes) {
  if (!Buffer.isBuffer(bytes)) throw genericPreparationError();
  let secret;
  let offset = 0;
  const skipWhitespace = () => {
    while (
      offset < bytes.length
      && [0x09, 0x0a, 0x0d, 0x20].includes(bytes[offset])
    ) offset += 1;
  };
  const expectByte = (expected) => {
    if (bytes[offset] !== expected) throw genericPreparationError();
    offset += 1;
  };
  try {
    skipWhitespace();
    expectByte(0x7b);
    skipWhitespace();
    for (const byte of [0x22, 0x6b, 0x65, 0x79, 0x22]) {
      expectByte(byte);
    }
    skipWhitespace();
    expectByte(0x3a);
    skipWhitespace();
    expectByte(0x22);
    const secretStart = offset;
    while (offset < bytes.length && bytes[offset] !== 0x22) {
      const byte = bytes[offset];
      if (byte < 0x21 || byte > 0x7e || byte === 0x5c) {
        throw genericPreparationError();
      }
      offset += 1;
    }
    if (offset >= bytes.length) throw genericPreparationError();
    const secretLength = offset - secretStart;
    if (secretLength < 24 || secretLength > 512) {
      throw genericPreparationError();
    }
    secret = Buffer.alloc(secretLength);
    bytes.copy(secret, 0, secretStart, offset);
    expectByte(0x22);
    skipWhitespace();
    expectByte(0x7d);
    skipWhitespace();
    if (
      offset !== bytes.length
      || !secret.subarray(0, signingSecretPrefixBytes.length)
        .equals(signingSecretPrefixBytes)
      || !isPrintableNonWhitespaceASCII(secret)
    ) throw genericPreparationError();
    return secret;
  } catch {
    secret?.fill(0);
    throw genericPreparationError();
  } finally {
    bytes.fill(0);
  }
}

async function readEndpointBehavior(
  fetchProvider,
  login,
  token,
  endpointId,
  fetchTimeoutMs,
) {
  const endpointURL = `${endpointsURL(login)}/${encodeURIComponent(endpointId)}`;
  const headers = await fetchJSON(
    fetchProvider,
    `${endpointURL}/headers`,
    {
      method: "GET",
      headers: providerJSONHeaders(token),
      redirect: "error",
    },
    [200],
    fetchTimeoutMs,
  );
  requireExactKeys(headers, ["headers", "sensitive"]);
  if (
    !headers.headers
    || typeof headers.headers !== "object"
    || Array.isArray(headers.headers)
    || Object.keys(headers.headers).length !== 0
    || !Array.isArray(headers.sensitive)
    || headers.sensitive.length !== 0
  ) throw genericPreparationError();

  const transformation = await fetchJSON(
    fetchProvider,
    `${endpointURL}/transformation`,
    {
      method: "GET",
      headers: providerJSONHeaders(token),
      redirect: "error",
    },
    [200],
    fetchTimeoutMs,
  );
  requireAllowedKeys(transformation, [
    "code",
    "enabled",
    "updatedAt",
    "variables",
  ]);
  if (
    transformation.enabled !== false
    || !(transformation.code === undefined || transformation.code === null)
    || !(transformation.updatedAt === undefined
      || transformation.updatedAt === null)
    || !(transformation.variables === undefined
      || transformation.variables === null
      || (
        typeof transformation.variables === "object"
        && !Array.isArray(transformation.variables)
        && Object.keys(transformation.variables).length === 0
      ))
  ) throw genericPreparationError();
  return Object.freeze({
    headerCount: 0,
    sensitiveHeaderNameCount: 0,
    transformationEnabled: false,
    transformationPresent: false,
  });
}

function createReceipt({
  sources,
  whoami,
  initialUserCount,
  preReconciliationUserCount,
  postReconciliationUserCount,
  portalProtocol,
  login,
  capabilities,
  reconciliation,
  endpointBehavior,
  finalProviderReadback,
  observedAtUTC,
}) {
  const payload = {
    schema_version: 1,
    receipt_type: receiptType,
    status: "prepared",
    operation: reconciliation.operation,
    observed_at_utc: observedAtUTC,
    source_contract: {
      clerk_backend_version: sources.clerkBackendVersion,
      clerk_cli_version: sources.clerkCliVersion,
      clerk_lock_contract_sha256: sources.clerkLockContractSha256,
      launch_packet_sha256: sources.launchPacketSha256,
    },
    provider_command: {
      command: clerkCommand,
      credential_source: "clerk_cli_oauth_credential_store",
      secret_key_argument_count: 0,
      whoami_arguments: [...productionClerkWebhookCommands.whoami.args],
      user_count_arguments: [...productionClerkWebhookCommands.userCount.args],
      svix_url_arguments: [...productionClerkWebhookCommands.svixURL.args],
    },
    clerk: {
      application_id: whoami.applicationId,
      application_name: whoami.applicationName,
      instance_id: whoami.productionInstanceId,
      user_count: postReconciliationUserCount,
      initial_user_count: initialUserCount,
      pre_reconciliation_user_count: preReconciliationUserCount,
      post_reconciliation_user_count: postReconciliationUserCount,
      user_count_source: "clerk_backend_api_users_count",
    },
    portal_protocol: {
      portal_origin: portalProtocol.portalOrigin,
      login_url: portalProtocol.loginURL,
      asset_path: portalProtocol.assetPath,
      asset_sha256: portalProtocol.assetSha256,
      region: login.region,
      capabilities: [...capabilities],
    },
    svix: {
      application_id: login.appId,
      endpoint_id: reconciliation.endpoint.id,
      endpoint_uid: reconciliation.endpoint.uid,
      endpoint_url: reconciliation.endpoint.url,
      endpoint_description: reconciliation.endpoint.description,
      event_types: [...productionClerkWebhookTarget.eventTypes],
      disabled: reconciliation.endpoint.disabled,
      header_count: endpointBehavior.headerCount,
      sensitive_header_name_count:
        endpointBehavior.sensitiveHeaderNameCount,
      transformation_enabled: endpointBehavior.transformationEnabled,
      transformation_present: endpointBehavior.transformationPresent,
      created_at_utc: reconciliation.endpoint.createdAtUTC,
      updated_at_utc: reconciliation.endpoint.updatedAtUTC,
    },
    final_provider_readback: {
      svix_application_id: login.appId,
      endpoint_inventory_count: finalProviderReadback.endpointInventoryCount,
      endpoint_id: finalProviderReadback.endpoint.id,
      endpoint_uid: finalProviderReadback.endpoint.uid,
      endpoint_url: finalProviderReadback.endpoint.url,
      endpoint_description: finalProviderReadback.endpoint.description,
      event_types: [...productionClerkWebhookTarget.eventTypes],
      disabled: finalProviderReadback.endpoint.disabled,
      header_count: finalProviderReadback.endpointBehavior.headerCount,
      sensitive_header_name_count:
        finalProviderReadback.endpointBehavior.sensitiveHeaderNameCount,
      transformation_enabled:
        finalProviderReadback.endpointBehavior.transformationEnabled,
      transformation_present:
        finalProviderReadback.endpointBehavior.transformationPresent,
    },
    secret_material: {
      representation: "buffer",
      secret_values_hashed: false,
      secret_values_recorded: false,
    },
  };
  return validateProductionClerkWebhookPreparationReceipt({
    ...payload,
    receipt_sha256: computeSanitizedReceiptSha256(payload),
  });
}

function validateWhoami(value) {
  requireExactKeys(value, ["email", "linked"]);
  if (typeof value.email !== "string" || value.email.length === 0) {
    throw genericPreparationError();
  }
  requireExactKeys(value.linked, [
    "appId",
    "appName",
    "development",
    "production",
    "resolvedVia",
  ]);
  requireExactKeys(value.linked.development, ["id", "type"]);
  requireExactKeys(value.linked.production, ["id", "type"]);
  requireEqual(value.linked.appId, productionClerk.applicationId);
  requireEqual(value.linked.appName, productionClerk.applicationName);
  requireEqual(value.linked.development, {
    id: productionClerk.developmentInstanceId,
    type: "string",
  });
  requireEqual(value.linked.production, {
    id: productionClerk.instanceId,
    type: "string",
  });
  requireEqual(value.linked.resolvedVia, "remote");
  return Object.freeze({
    applicationId: value.linked.appId,
    applicationName: value.linked.appName,
    productionInstanceId: value.linked.production.id,
  });
}

function validateUserCount(value) {
  requireExactKeys(value, ["object", "total_count"]);
  if (value.object !== "total_count" || value.total_count !== 0) {
    throw genericPreparationError();
  }
  return 0;
}

function validatePortalProtocolReceipt(value) {
  requireExactKeys(value, [
    "assetPath",
    "assetSha256",
    "loginURL",
    "portalOrigin",
  ]);
  requireEqual(value, {
    portalOrigin,
    loginURL: portalLoginURL,
    assetPath: portalAssetPath,
    assetSha256: portalAssetSha256,
  });
}

function providerJSONHeaders(token, additional = {}) {
  return {
    accept: "application/json",
    authorization: `Bearer ${token}`,
    "content-type": "application/json",
    ...additional,
  };
}

function portalProxyURL(region, path) {
  if (!productionClerkWebhookPortalContract.supportedRegions.includes(region)) {
    throw genericPreparationError();
  }
  return `${portalOrigin}/api/${region}${path}`;
}

function endpointsURL(login) {
  return portalProxyURL(
    login.region,
    `/api/v1/app/${encodeURIComponent(login.appId)}/endpoint`,
  );
}

async function fetchJSON(
  fetchProvider,
  url,
  init,
  acceptedStatuses = [200],
  timeoutMs = FETCH_TIMEOUT_MS,
) {
  const controller = new AbortController();
  try {
    return await withBoundedFetchTime(async () => {
      const response = await fetchProvider(url, {
        ...init,
        signal: controller.signal,
      });
      if (!response || !Number.isSafeInteger(response.status)) {
        throw genericPreparationError();
      }
      if (
        response.redirected === true
        || (typeof response.url === "string"
          && response.url.length > 0
          && response.url !== String(url))
      ) throw genericPreparationError();
      if (!acceptedStatuses.includes(response.status)) {
        throw genericPreparationError();
      }
      const contentType = response.headers?.get?.("content-type") ?? "";
      if (!contentType.toLowerCase().includes("application/json")) {
        throw genericPreparationError();
      }
      const bytes = await readBoundedResponse(
        response,
        MAX_JSON_RESPONSE_BYTES,
      );
      try {
        return JSON.parse(bytes.toString("utf8"));
      } finally {
        bytes.fill(0);
      }
    }, controller, timeoutMs);
  } catch {
    throw genericPreparationError();
  }
}

async function fetchBytes(
  fetchProvider,
  url,
  init,
  maxBytes,
  acceptedContentTypes,
  timeoutMs = FETCH_TIMEOUT_MS,
) {
  const controller = new AbortController();
  try {
    return await withBoundedFetchTime(async () => {
      const response = await fetchProvider(url, {
        ...init,
        signal: controller.signal,
      });
      if (!response || response.status !== 200) throw genericPreparationError();
      if (
        response.redirected === true
        || (typeof response.url === "string"
          && response.url.length > 0
          && response.url !== String(url))
      ) throw genericPreparationError();
      const contentType = (response.headers?.get?.("content-type") ?? "")
        .toLowerCase();
      if (!acceptedContentTypes.some((candidate) =>
        contentType.includes(candidate))) {
        throw genericPreparationError();
      }
      return readBoundedResponse(response, maxBytes);
    }, controller, timeoutMs);
  } catch {
    throw genericPreparationError();
  }
}

async function withBoundedFetchTime(operation, controller, timeoutMs) {
  let timeout;
  const timeoutFailure = new Promise((resolvePromise, rejectPromise) => {
    timeout = setTimeout(() => {
      controller.abort();
      rejectPromise(genericPreparationError());
    }, timeoutMs);
  });
  try {
    return await Promise.race([operation(), timeoutFailure]);
  } finally {
    clearTimeout(timeout);
  }
}

async function readBoundedResponse(response, maxBytes) {
  const contentLength = response.headers?.get?.("content-length");
  if (contentLength !== null && contentLength !== undefined) {
    const parsed = Number(contentLength);
    if (!Number.isSafeInteger(parsed) || parsed < 0 || parsed > maxBytes) {
      throw genericPreparationError();
    }
  }
  const reader = response.body?.getReader?.();
  if (!reader) throw genericPreparationError();
  const chunks = [];
  let byteCount = 0;
  try {
    while (true) {
      const result = await reader.read();
      if (result.done) break;
      const chunk = Buffer.from(result.value ?? []);
      byteCount += chunk.byteLength;
      if (byteCount > maxBytes) {
        chunk.fill(0);
        throw genericPreparationError();
      }
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  } catch {
    throw genericPreparationError();
  } finally {
    for (const chunk of chunks) chunk.fill(0);
    reader.releaseLock?.();
  }
}

function consumeCommandText(result) {
  const bytes = commandOutputBuffer(result);
  try {
    const value = bytes.toString("utf8").trim();
    if (value.length === 0 || value.length > MAX_COMMAND_OUTPUT_BYTES) {
      throw genericPreparationError();
    }
    return value;
  } finally {
    bytes.fill(0);
  }
}

function consumeCommandJSON(result) {
  const bytes = commandOutputBuffer(result);
  try {
    return JSON.parse(bytes.toString("utf8"));
  } catch {
    throw genericPreparationError();
  } finally {
    bytes.fill(0);
  }
}

function commandOutputBuffer(result) {
  if (Buffer.isBuffer(result?.stdout)) return result.stdout;
  if (typeof result?.stdout === "string" || ArrayBuffer.isView(result?.stdout)) {
    return Buffer.from(result.stdout);
  }
  throw genericPreparationError();
}

function buildClerkProviderEnvironment(environment) {
  const result = {};
  for (const name of [
    "PATH",
    "HOME",
    "USER",
    "LOGNAME",
    "SHELL",
    "TMPDIR",
    "LANG",
    "LC_ALL",
    "TERM",
    "COLORTERM",
  ]) {
    if (environment[name] !== undefined) result[name] = environment[name];
  }
  return {
    ...result,
    CI: "1",
    NO_COLOR: "1",
    NPM_CONFIG_UPDATE_NOTIFIER: "false",
  };
}

function parseSourceJSON(value) {
  if (typeof value !== "string") {
    throw new Error("Production Clerk webhook source contract is invalid");
  }
  try {
    return JSON.parse(value);
  } catch {
    throw new Error("Production Clerk webhook source contract is invalid");
  }
}

function normalizeUTCInstant(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.valueOf())) throw genericPreparationError();
  const normalized = date.toISOString();
  requireUTCInstant(normalized);
  return normalized;
}

function requireUTCInstant(value) {
  if (typeof value !== "string" || !utcInstantPattern.test(value)) {
    throw genericPreparationError();
  }
}

function requireExactKeys(value, keys) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw genericPreparationError();
  }
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (canonicalSanitizedJSON(actual) !== canonicalSanitizedJSON(expected)) {
    throw genericPreparationError();
  }
}

function requireAllowedKeys(value, keys) {
  if (
    !value
    || typeof value !== "object"
    || Array.isArray(value)
    || Object.keys(value).some((key) => !keys.includes(key))
  ) throw genericPreparationError();
}

function requireEqual(actual, expected) {
  if (canonicalSanitizedJSON(actual) !== canonicalSanitizedJSON(expected)) {
    throw genericPreparationError();
  }
}

function sha256Hex(value) {
  return createHash("sha256").update(value).digest("hex");
}

function containsSecretLikeValue(value) {
  const serialized = canonicalSanitizedJSON(value);
  return secretLikePrefixes.some((prefix) => serialized.includes(prefix));
}

function isPrintableNonWhitespaceASCII(value) {
  return value.every((byte) => byte >= 0x21 && byte <= 0x7e);
}

function genericPreparationError() {
  return new Error(
    "Production Clerk webhook preparation failed without disclosing provider output",
  );
}

if (
  process.argv[1]
  && resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  process.exitCode = await runProductionClerkWebhookPreparationCLI();
}
