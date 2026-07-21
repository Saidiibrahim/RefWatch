import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { readFile, readdir } from "node:fs/promises";
import { dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import {
  canonicalSanitizedJSON,
  computeSanitizedReceiptSha256,
  computeStableWorkerBindingSha256,
  cutoverAcceptance,
  expectedProductionWorkerBindings,
  greenfieldAuthorizationDigest,
  greenfieldAuthorizationProfile,
  productionDatabase,
  productionLastKnownGoodWorker,
  productionLedgerResources,
  productionWorker,
  productionWorkerSecretNames,
  sanitizeWorkerVersionReadback,
} from "./greenfield-launch-packet.mjs";
import {
  productionClerkWebhookPreparationGate,
  validateProductionClerkWebhookPreparationReceipt,
} from "./prepare-production-clerk-webhook.mjs";
import { productionRuntimeProvisioningTarget } from "./provision-production-runtime.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const apiDirectory = resolve(scriptDirectory, "..");
const MAX_PROVIDER_OUTPUT_BYTES = 4 * 1024 * 1024;
const MAX_SECRET_BUNDLE_BYTES = 2 * 1024;
const PROVIDER_TIMEOUT_MS = 120_000;
const PROVIDER_KILL_GRACE_MS = 2_000;
const PROVIDER_OBSERVATION_ATTEMPTS = 6;
const PROVIDER_OBSERVATION_DELAY_MS = 250;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const sha256Pattern = /^[0-9a-f]{64}$/u;
const utcInstantPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u;
const receiptType = "refwatch_production_greenfield_worker_lineage";
const wranglerVersion = "4.110.0";
const cloudflareCliVersion = "0.1.0";
const wranglerCommand = "./node_modules/.bin/wrangler";
const cloudflareCommand = "cf";

// refwatch-lineage-reviewed-source-pins:start
// Recomputed only after the reviewed Worker source/config manifest changes.
const reviewedSourceManifestSha256 =
  "dedf2578b002865aa05486cf6fd329714140563235d97b5c8ddf1c3248b5aa36";
const reviewedSourceManifestFileCount = 80;
const reviewedSourceDigests = Object.freeze({
  wranglerConfig:
    "d294b351093967d6ef4e9fc129abb55fe7d2d4eda4ee6b85ab7d4d84dc85a176",
  packageLock:
    "18e03877ae0b65da4823ccfb61865e1ce8446a9ccc5af9b3eff67676d023c153",
  greenfieldLaunchPacket:
    "21b671ba5a5f585fe8ee4982a0ca1dfa570d15bbe23eb20c8f3e219e18772508",
  greenfieldLaunchPacketDeclaration:
    "c4db984c8ede394fe83ba461ecf94b22d797e892510f2af8a11a8d86be6275f3",
  productionClerkWebhookPreparation:
    "ca9a73ed8f74d22e1a1e574661dc09e0776be4467485397cc6762de8d1ed19a1",
  productionClerkWebhookPreparationDeclaration:
    "19333138cd96609342b0279b47ca28c4b833e01300f34bfdd3be3a685238a624",
  productionRuntimeProvisioning:
    "08b835e73a278d139d2f47dcf75bdd84ab7ba7e7e51eae7b578b6ba91635e7fd",
  productionRuntimeProvisioningDeclaration:
    "458907fe1d9a0832bdee430747aefdc9593e0700a90aca2f1fffe43e81ce25ca",
  rollbackPacket:
    "5bee3e8faea6f863e086a5569fe84dbaf868b7ae86183287be7c9f7efbc181c0",
  rollbackPacketDeclaration:
    "24e82551e0df21c06963a460dcab87fad45a42f04730fbe3f66588ec88b24170",
});
// refwatch-lineage-reviewed-source-pins:end

export const productionGreenfieldWorkerLineageGate =
  "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_WORKER_LINEAGE";
const productionGreenfieldCutoverGate =
  "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER";
let activeWorkerLineageLease;

export const productionGreenfieldWorkerLineageOrchestration = Object.freeze({
  executionMode: "reviewed_same_process_cutover_orchestrator",
  outerTechnicalGate: productionGreenfieldCutoverGate,
  clerkTechnicalGate: productionClerkWebhookPreparationGate,
  lineageTechnicalGate: productionGreenfieldWorkerLineageGate,
});

const existingSecretNames = Object.freeze(
  productionWorkerSecretNames.filter((name) =>
    name !== "CLERK_WEBHOOK_SIGNING_SECRET"
      && name !== cutoverAcceptance.tokenSecretName),
);

const sourceManifestStaticPaths = Object.freeze([
  "package-lock.json",
  "package.json",
  "scripts/execute-production-greenfield-cutover.d.mts",
  "scripts/execute-production-greenfield-cutover.mjs",
  "scripts/greenfield-launch-packet.d.mts",
  "scripts/greenfield-launch-packet.mjs",
  "scripts/prepare-production-clerk-webhook.d.mts",
  "scripts/prepare-production-clerk-webhook.mjs",
  "scripts/provision-production-runtime.d.mts",
  "scripts/provision-production-runtime.mjs",
  "scripts/rollback-packet.d.mts",
  "scripts/rollback-packet.mjs",
  "tsconfig.json",
  "wrangler.jsonc",
]);

const uploadStages = Object.freeze({
  candidate: Object.freeze({
    stage: "candidate_a",
    writeMode: "disabled",
    onboardingMode: "disabled",
    tag: "greenfield-disabled-a",
    message: "RefWatch greenfield disabled candidate A",
  }),
  accepted: Object.freeze({
    stage: "accepted_b",
    writeMode: "enabled",
    onboardingMode: "greenfield_bootstrap",
    tag: "greenfield-accepted-b",
    message: "RefWatch greenfield accepted candidate B",
  }),
  writeGuard: Object.freeze({
    stage: "write_guard_g",
    writeMode: "disabled",
    onboardingMode: "disabled",
    tag: "greenfield-write-guard-g",
    message: "RefWatch greenfield write guard G",
  }),
});

export const productionGreenfieldWorkerLineageCommands = Object.freeze({
  wranglerCommand,
  cloudflareCommand,
  wranglerVersion: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze(["--version"]),
  }),
  cloudflareVersion: Object.freeze({
    command: cloudflareCommand,
    args: Object.freeze(["--version"]),
  }),
  versionsList: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze([
      "versions",
      "list",
      "--name",
      productionWorker.name,
      "--env-file",
      "/dev/null",
      "--json",
    ]),
  }),
  deploymentStatus: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze([
      "deployments",
      "status",
      "--name",
      productionWorker.name,
      "--env-file",
      "/dev/null",
      "--json",
    ]),
  }),
  secretInventory: Object.freeze({
    command: cloudflareCommand,
    args: Object.freeze([
      "workers",
      "secrets",
      "list",
      "--script-name",
      productionWorker.name,
    ]),
  }),
  webhookSecretPut: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze([
      "versions",
      "secret",
      "put",
      "CLERK_WEBHOOK_SIGNING_SECRET",
      "--name",
      productionWorker.name,
      "--env-file",
      "/dev/null",
      "--tag",
      "greenfield-webhook-secret-source",
      "--message",
      "Install RefWatch production Clerk webhook signing secret",
    ]),
  }),
  cutoverSecretPut: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze([
      "versions",
      "secret",
      "put",
      cutoverAcceptance.tokenSecretName,
      "--name",
      productionWorker.name,
      "--env-file",
      "/dev/null",
      "--tag",
      "greenfield-cutover-secret-source",
      "--message",
      "Install RefWatch production cutover acceptance token",
    ]),
  }),
  candidateUpload: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze(renderUploadArguments(uploadStages.candidate)),
  }),
  acceptedUpload: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze(renderUploadArguments(uploadStages.accepted)),
  }),
  writeGuardUpload: Object.freeze({
    command: wranglerCommand,
    args: Object.freeze(renderUploadArguments(uploadStages.writeGuard)),
  }),
});

export function productionGreenfieldWorkerVersionViewCommand(versionId) {
  requireUUID(versionId);
  return Object.freeze({
    command: wranglerCommand,
    args: Object.freeze([
      "versions",
      "view",
      versionId,
      "--name",
      productionWorker.name,
      "--env-file",
      "/dev/null",
      "--json",
    ]),
  });
}

export async function loadProductionGreenfieldWorkerLineageSources() {
  return validateProductionGreenfieldWorkerLineageSources(
    await loadProductionGreenfieldWorkerLineageSourceInput(),
  );
}

export async function loadProductionGreenfieldWorkerLineageSourceInput() {
  const paths = [
    ...sourceManifestStaticPaths.map((path) => resolve(apiDirectory, path)),
    ...(await recursiveFiles(resolve(apiDirectory, "d1/migrations"))),
    ...(await recursiveFiles(resolve(apiDirectory, "src"))),
  ];
  const uniquePaths = [...new Set(paths)].sort();
  const entries = await Promise.all(uniquePaths.map(async (absolutePath) => ({
    path: relative(apiDirectory, absolutePath).split(sep).join("/"),
    content: await readFile(absolutePath),
  })));
  return { entries };
}

export function validateProductionGreenfieldWorkerLineageSources(source) {
  if (!source || !Array.isArray(source.entries) || source.entries.length === 0) {
    throw new Error("Production Worker lineage source manifest is invalid");
  }
  const seen = new Set();
  const manifest = source.entries.map((entry) => {
    if (
      !entry
      || typeof entry.path !== "string"
      || entry.path.length === 0
      || entry.path.startsWith("/")
      || entry.path.includes("..")
      || seen.has(entry.path)
      || !(typeof entry.content === "string" || ArrayBuffer.isView(entry.content))
    ) {
      throw new Error("Production Worker lineage source manifest is invalid");
    }
    seen.add(entry.path);
    const content = Buffer.isBuffer(entry.content)
      ? entry.content
      : Buffer.from(entry.content);
    return {
      path: entry.path,
      byte_count: content.byteLength,
      sha256: sha256Hex(content),
    };
  }).sort((left, right) => left.path.localeCompare(right.path));
  const manifestSha256 = computeSanitizedReceiptSha256(manifest);
  if (manifestSha256 !== reviewedSourceManifestSha256) {
    throw new Error("Production Worker lineage reviewed source manifest drifted");
  }

  const contentFor = (path) => {
    const entry = source.entries.find((candidate) => candidate.path === path);
    if (!entry) throw new Error("Production Worker lineage source manifest is incomplete");
    return Buffer.from(entry.content).toString("utf8");
  };
  const wranglerConfig = parseSourceJSON(contentFor("wrangler.jsonc"));
  const packageJSON = parseSourceJSON(contentFor("package.json"));
  const packageLock = parseSourceJSON(contentFor("package-lock.json"));
  validateProductionWranglerConfiguration(wranglerConfig);
  if (
    packageJSON?.devDependencies?.wrangler !== "^4.110.0"
    || packageLock?.packages?.["node_modules/wrangler"]?.version !== wranglerVersion
    || packageJSON?.devDependencies?.clerk !== "2.2.0"
    || packageLock?.packages?.[""]?.devDependencies?.clerk !== "2.2.0"
    || packageLock?.packages?.["node_modules/clerk"]?.version !== "2.2.0"
    || packageJSON?.scripts?.["worker:lineage:production"] !== undefined
    || packageJSON?.scripts?.["worker:lineage:production:check"]
      !== "node scripts/prepare-production-greenfield-worker-lineage.mjs --check"
    || packageJSON?.scripts?.["clerk:webhook:production:check"]
      !== "node scripts/prepare-production-clerk-webhook.mjs --check"
    || packageJSON?.scripts?.["cutover:production"]
      !== "node scripts/execute-production-greenfield-cutover.mjs --execute"
    || packageJSON?.scripts?.["cutover:production:check"]
      !== "node scripts/execute-production-greenfield-cutover.mjs --check"
  ) {
    throw new Error("Production Worker lineage Wrangler source contract drifted");
  }

  const digestFor = (path) => manifest.find((entry) => entry.path === path)?.sha256;
  const selectedDigests = {
    wranglerConfigSha256: digestFor("wrangler.jsonc"),
    packageLockSha256: digestFor("package-lock.json"),
    greenfieldLaunchPacketSha256:
      digestFor("scripts/greenfield-launch-packet.mjs"),
    greenfieldLaunchPacketDeclarationSha256:
      digestFor("scripts/greenfield-launch-packet.d.mts"),
    productionClerkWebhookPreparationSha256:
      digestFor("scripts/prepare-production-clerk-webhook.mjs"),
    productionClerkWebhookPreparationDeclarationSha256:
      digestFor("scripts/prepare-production-clerk-webhook.d.mts"),
    productionRuntimeProvisioningSha256:
      digestFor("scripts/provision-production-runtime.mjs"),
    productionRuntimeProvisioningDeclarationSha256:
      digestFor("scripts/provision-production-runtime.d.mts"),
    rollbackPacketSha256: digestFor("scripts/rollback-packet.mjs"),
    rollbackPacketDeclarationSha256:
      digestFor("scripts/rollback-packet.d.mts"),
  };
  requireEqual(selectedDigests, {
    wranglerConfigSha256: reviewedSourceDigests.wranglerConfig,
    packageLockSha256: reviewedSourceDigests.packageLock,
    greenfieldLaunchPacketSha256: reviewedSourceDigests.greenfieldLaunchPacket,
    greenfieldLaunchPacketDeclarationSha256:
      reviewedSourceDigests.greenfieldLaunchPacketDeclaration,
    productionClerkWebhookPreparationSha256:
      reviewedSourceDigests.productionClerkWebhookPreparation,
    productionClerkWebhookPreparationDeclarationSha256:
      reviewedSourceDigests.productionClerkWebhookPreparationDeclaration,
    productionRuntimeProvisioningSha256:
      reviewedSourceDigests.productionRuntimeProvisioning,
    productionRuntimeProvisioningDeclarationSha256:
      reviewedSourceDigests.productionRuntimeProvisioningDeclaration,
    rollbackPacketSha256: reviewedSourceDigests.rollbackPacket,
    rollbackPacketDeclarationSha256:
      reviewedSourceDigests.rollbackPacketDeclaration,
  });
  return Object.freeze({
    manifestSha256,
    fileCount: manifest.length,
    ...selectedDigests,
    manifest: Object.freeze(manifest.map((entry) => Object.freeze(entry))),
  });
}

export async function executeProductionGreenfieldWorkerLineage(options = {}) {
  return executeProductionGreenfieldWorkerLineageWithLease(options, undefined);
}

export async function withProductionGreenfieldWorkerLineageLease(
  consumer,
  options = {},
) {
  if (typeof consumer !== "function") throw genericExecutionError();
  const environment = options.environment ?? process.env;
  if (
    environment[productionGreenfieldCutoverGate] !== "1"
    || environment[productionClerkWebhookPreparationGate] !== "1"
    || environment[productionGreenfieldWorkerLineageGate] !== "1"
    || activeWorkerLineageLease !== undefined
  ) throw genericExecutionError();
  const lease = { active: true };
  activeWorkerLineageLease = lease;
  let invoked = false;
  const execute = async (executionOptions = {}) => {
    if (invoked) throw genericExecutionError();
    invoked = true;
    return executeProductionGreenfieldWorkerLineageWithLease(
      { ...executionOptions, environment },
      lease,
    );
  };
  try {
    return await consumer(execute);
  } catch {
    throw genericExecutionError();
  } finally {
    lease.active = false;
    if (activeWorkerLineageLease === lease) activeWorkerLineageLease = undefined;
  }
}

async function executeProductionGreenfieldWorkerLineageWithLease(
  options,
  lease,
) {
  requireActiveWorkerLineageLease(lease);
  const signal = options.signal;
  if (
    signal !== undefined
    && (
      typeof signal !== "object"
      || typeof signal.aborted !== "boolean"
      || typeof signal.addEventListener !== "function"
    )
  ) throw genericExecutionError();
  const requireExecutionActive = () => {
    requireActiveWorkerLineageLease(lease);
    if (signal?.aborted) throw genericExecutionError();
  };
  requireExecutionActive();
  const environment = options.environment ?? process.env;
  if (environment[productionGreenfieldWorkerLineageGate] !== "1") {
    throw new Error("Production greenfield Worker lineage gate is closed");
  }
  const sources = await (options.loadSources
    ?? loadProductionGreenfieldWorkerLineageSources)();
  requireExecutionActive();
  const clerkWebhookPreparationReceipt =
    validateProductionClerkWebhookPreparationReceipt(
      options.clerkWebhookPreparationReceipt,
    );
  if (!options.secretMaterial) throw genericExecutionError();
  const secretMaterial = cloneSecretMaterial(options.secretMaterial);
  const commandRunner = options.runCommand
    ?? runProductionGreenfieldWorkerLineageCommand;
  const providerEnvironment = buildProviderEnvironment(environment);
  const nowUTC = monotonicUTCClock(options.now ?? (() => new Date()));
  const delay = options.delay
    ?? ((milliseconds) => new Promise((resolvePromise) =>
      setTimeout(resolvePromise, milliseconds)));
  const waitForProviderObservation = () =>
    delay(PROVIDER_OBSERVATION_DELAY_MS);

  const run = async (command, stdin) => {
    requireExecutionActive();
    const result = await commandRunner({
      command: command.command,
      args: command.args,
      cwd: apiDirectory,
      environment: providerEnvironment,
      stdin,
      signal,
    });
    requireExecutionActive();
    return result;
  };
  const runJSON = async (command) => parseProviderJSON(await run(command));
  const readGuard = async () => {
    const history = validateVersionHistory(
      await runJSON(productionGreenfieldWorkerLineageCommands.versionsList),
    );
    const deployment = sanitizeDeploymentReadback(
      await runJSON(productionGreenfieldWorkerLineageCommands.deploymentStatus),
      nowUTC(),
    );
    return { history, deployment };
  };
  const readVersion = async (versionId) => {
    const raw = await runJSON(productionGreenfieldWorkerVersionViewCommand(versionId));
    const receipt = sanitizeWorkerVersionReadback(raw, nowUTC());
    if (receipt.worker_version_id !== versionId) throw genericExecutionError();
    return receipt;
  };
  const readSecrets = async () => validateSecretInventory(
    await runJSON(productionGreenfieldWorkerLineageCommands.secretInventory),
  );
  const readVersionEventually = async (versionId) => {
    for (let attempt = 1; attempt <= PROVIDER_OBSERVATION_ATTEMPTS; attempt += 1) {
      let raw;
      try {
        raw = await runJSON(productionGreenfieldWorkerVersionViewCommand(versionId));
      } catch {
        if (attempt === PROVIDER_OBSERVATION_ATTEMPTS) throw genericExecutionError();
        await waitForProviderObservation();
        continue;
      }
      if (raw?.id !== versionId) throw genericExecutionError();
      const receipt = sanitizeWorkerVersionReadback(raw, nowUTC());
      if (receipt.worker_version_id !== versionId) throw genericExecutionError();
      return receipt;
    }
    throw genericExecutionError();
  };
  const observeExpectedSecretInventory = async (previous, expected) => {
    for (let attempt = 1; attempt <= PROVIDER_OBSERVATION_ATTEMPTS; attempt += 1) {
      let raw;
      try {
        raw = await runJSON(
          productionGreenfieldWorkerLineageCommands.secretInventory,
        );
      } catch {
        if (attempt === PROVIDER_OBSERVATION_ATTEMPTS) throw genericExecutionError();
        await waitForProviderObservation();
        continue;
      }
      const observed = validateSecretInventory(raw);
      if (sameSanitizedValue([...observed].sort(), [...expected].sort())) {
        return observed;
      }
      if (!sameSanitizedValue([...observed].sort(), [...previous].sort())) {
        throw genericExecutionError();
      }
      if (attempt === PROVIDER_OBSERVATION_ATTEMPTS) throw genericExecutionError();
      await waitForProviderObservation();
    }
    throw genericExecutionError();
  };

  try {
    validateSecretMaterial(secretMaterial);
    const observedWranglerVersion = normalizedToolVersion(
      await run(productionGreenfieldWorkerLineageCommands.wranglerVersion),
    );
    const observedCloudflareVersion = normalizedToolVersion(
      await run(productionGreenfieldWorkerLineageCommands.cloudflareVersion),
    );
    if (
      observedWranglerVersion !== wranglerVersion
      || observedCloudflareVersion !== cloudflareCliVersion
    ) {
      throw genericExecutionError();
    }

    const initialGuard = await readGuard();
    validateLastKnownGoodDeployment(initialGuard.deployment);
    requireLatestVersion(initialGuard.history, productionLastKnownGoodWorker.versionId);
    const initialDeploymentId = initialGuard.deployment.deployment_id;
    const lastKnownGoodInitial = await readVersion(
      productionLastKnownGoodWorker.versionId,
    );
    validateLastKnownGoodVersion(lastKnownGoodInitial, existingSecretNames);
    requireExactSecretNames(await readSecrets(), existingSecretNames);

    const boundaries = [];
    let previousGuard = initialGuard;
    const mutate = async (stage, command, stdin, expectedTrigger) => {
      const before = await readGuard();
      validateLastKnownGoodDeployment(before.deployment);
      requireSameGuard(previousGuard, before, initialDeploymentId);
      const mutationResult = await run(command, stdin);
      wipeCommandResult(mutationResult);
      let after;
      let created;
      for (let attempt = 1; attempt <= PROVIDER_OBSERVATION_ATTEMPTS; attempt += 1) {
        try {
          after = await readGuard();
        } catch {
          if (attempt === PROVIDER_OBSERVATION_ATTEMPTS) {
            throw genericExecutionError();
          }
          await waitForProviderObservation();
          continue;
        }
        validateLastKnownGoodDeployment(after.deployment);
        requireSameDeployment(before.deployment, after.deployment, initialDeploymentId);
        created = classifyOneVersionDelta(
          before.history,
          after.history,
          expectedTrigger,
          commandArgument(command.args, "--tag"),
          commandArgument(command.args, "--message"),
        );
        if (created) break;
        if (attempt === PROVIDER_OBSERVATION_ATTEMPTS) {
          throw genericExecutionError();
        }
        await waitForProviderObservation();
      }
      if (!after || !created) throw genericExecutionError();
      boundaries.push(Object.freeze({
        stage,
        created_worker_version_id: created.id,
        created_worker_version_tag: created.tag,
        created_worker_version_message: created.message,
        before_version_history: before.history,
        before_version_history_sha256:
          computeSanitizedReceiptSha256(before.history),
        after_version_history: after.history,
        after_version_history_sha256:
          computeSanitizedReceiptSha256(after.history),
        before: before.deployment,
        after: after.deployment,
      }));
      previousGuard = after;
      return created;
    };

    const webhookVersion = await mutate(
      "webhook_secret_install",
      productionGreenfieldWorkerLineageCommands.webhookSecretPut,
      secretMaterial.clerkWebhookSigningSecret,
      "secret",
    );
    await observeExpectedSecretInventory(
      existingSecretNames,
      [...existingSecretNames, "CLERK_WEBHOOK_SIGNING_SECRET"],
    );
    const webhookSourceReadback = await readVersionEventually(webhookVersion.id);
    validateInheritedSourceVersion(
      webhookSourceReadback,
      lastKnownGoodInitial,
      [...existingSecretNames, "CLERK_WEBHOOK_SIGNING_SECRET"],
    );

    const sourceVersion = await mutate(
      "cutover_secret_install_source_s",
      productionGreenfieldWorkerLineageCommands.cutoverSecretPut,
      secretMaterial.cutoverAcceptanceToken,
      "secret",
    );
    await observeExpectedSecretInventory(
      [...existingSecretNames, "CLERK_WEBHOOK_SIGNING_SECRET"],
      productionWorkerSecretNames,
    );
    const sourceReadback = await readVersionEventually(sourceVersion.id);
    validateInheritedSourceVersion(
      sourceReadback,
      lastKnownGoodInitial,
      productionWorkerSecretNames,
    );

    const candidateVersion = await mutate(
      uploadStages.candidate.stage,
      productionGreenfieldWorkerLineageCommands.candidateUpload,
      undefined,
      "version_upload",
    );
    const candidateReadback = await readVersionEventually(candidateVersion.id);
    validateCurrentCandidateReadback(
      candidateReadback,
      uploadStages.candidate.writeMode,
      uploadStages.candidate.onboardingMode,
    );

    const acceptedVersion = await mutate(
      uploadStages.accepted.stage,
      productionGreenfieldWorkerLineageCommands.acceptedUpload,
      undefined,
      "version_upload",
    );
    const acceptedReadback = await readVersionEventually(acceptedVersion.id);
    validateCurrentCandidateReadback(
      acceptedReadback,
      uploadStages.accepted.writeMode,
      uploadStages.accepted.onboardingMode,
    );
    const writeGuardVersion = await mutate(
      uploadStages.writeGuard.stage,
      productionGreenfieldWorkerLineageCommands.writeGuardUpload,
      undefined,
      "version_upload",
    );
    const writeGuardReadback = await readVersionEventually(writeGuardVersion.id);
    validateCurrentCandidateReadback(
      writeGuardReadback,
      uploadStages.writeGuard.writeMode,
      uploadStages.writeGuard.onboardingMode,
    );

    const postWriteGuard = await readGuard();
    validateLastKnownGoodDeployment(postWriteGuard.deployment);
    requireSameGuard(previousGuard, postWriteGuard, initialDeploymentId);
    requireExactSecretNames(await readSecrets(), productionWorkerSecretNames);
    const lastKnownGoodFinal = await readVersion(
      productionLastKnownGoodWorker.versionId,
    );
    validateLastKnownGoodVersion(lastKnownGoodFinal, existingSecretNames);
    requireEqualVersionResources(lastKnownGoodInitial, lastKnownGoodFinal);
    const finalGuard = await readGuard();
    validateLastKnownGoodDeployment(finalGuard.deployment);
    requireSameGuard(postWriteGuard, finalGuard, initialDeploymentId);
    const lineageObservedAtUTC = nowUTC();

    requireChronology([
      lastKnownGoodInitial,
      webhookSourceReadback,
      sourceReadback,
      candidateReadback,
      acceptedReadback,
      writeGuardReadback,
    ]);
    const stableBindingSha256 = computeStableWorkerBindingSha256(
      candidateReadback,
    );
    if (
      candidateReadback.resources.script.etag
        !== productionLastKnownGoodWorker.scriptEtag
      || acceptedReadback.resources.script.etag
        !== productionLastKnownGoodWorker.scriptEtag
      || candidateReadback.resources.script.etag
        !== writeGuardReadback.resources.script.etag
      || stableBindingSha256
        !== computeStableWorkerBindingSha256(acceptedReadback)
      || stableBindingSha256
        !== computeStableWorkerBindingSha256(writeGuardReadback)
    ) {
      throw genericExecutionError();
    }

    const secretLineage = createSecretLineage({
      sourceReadback,
      candidateReadback,
      acceptedReadback,
      writeGuardReadback,
      lineageObservedAtUTC,
      boundaries,
    });
    const workerProviderObservedAtUTC = nowUTC();
    const packetWorker = createPacketWorkerFragment({
      sourceReadback,
      candidateReadback,
      acceptedReadback,
      writeGuardReadback,
      stableBindingSha256,
      secretLineage,
      observedAtUTC: workerProviderObservedAtUTC,
    });
    const payload = {
      schema_version: 1,
      receipt_type: receiptType,
      status: "completed",
      authorization: {
        profile: greenfieldAuthorizationProfile,
        digest: greenfieldAuthorizationDigest,
        execution_mode:
          productionGreenfieldWorkerLineageOrchestration.executionMode,
        outer_technical_gate:
          productionGreenfieldWorkerLineageOrchestration.outerTechnicalGate,
        clerk_technical_gate:
          productionGreenfieldWorkerLineageOrchestration.clerkTechnicalGate,
        lineage_technical_gate:
          productionGreenfieldWorkerLineageOrchestration.lineageTechnicalGate,
      },
      production_target: {
        account_id: productionRuntimeProvisioningTarget.cloudflareAccountId,
        worker_name: productionWorker.name,
        environment: productionWorker.environment,
        database_branch_id: productionDatabase.branchId,
        database_runtime_role_id: productionDatabase.runtimeRoleId,
        hyperdrive_id: productionDatabase.hyperdriveId,
      },
      source_contract: {
        manifest_sha256: sources.manifestSha256,
        file_count: sources.fileCount,
        wrangler_config_sha256: sources.wranglerConfigSha256,
        package_lock_sha256: sources.packageLockSha256,
        greenfield_launch_packet_sha256:
          sources.greenfieldLaunchPacketSha256,
        greenfield_launch_packet_declaration_sha256:
          sources.greenfieldLaunchPacketDeclarationSha256,
        production_clerk_webhook_preparation_sha256:
          sources.productionClerkWebhookPreparationSha256,
        production_clerk_webhook_preparation_declaration_sha256:
          sources.productionClerkWebhookPreparationDeclarationSha256,
        production_runtime_provisioning_sha256:
          sources.productionRuntimeProvisioningSha256,
        production_runtime_provisioning_declaration_sha256:
          sources.productionRuntimeProvisioningDeclarationSha256,
        rollback_packet_sha256: sources.rollbackPacketSha256,
        rollback_packet_declaration_sha256:
          sources.rollbackPacketDeclarationSha256,
      },
      provider_command_contract: {
        wrangler_command: wranglerCommand,
        wrangler_version: observedWranglerVersion,
        cloudflare_command: cloudflareCommand,
        cloudflare_cli_version: observedCloudflareVersion,
        worker_name: productionWorker.name,
        upload_environment: productionWorker.environment,
        env_file: "/dev/null",
        strict_upload: true,
        experimental_provision: false,
        experimental_auto_create: false,
        secret_transport: "stdin",
        secret_value_argument_count: 0,
        upload_secret_override_count: 0,
        traffic_mutation_count: 0,
        route_mutation_count: 0,
      },
      deployment_guard: {
        deployment_id: initialDeploymentId,
        worker_version_id: productionLastKnownGoodWorker.versionId,
        traffic_percentage: 100,
        boundary_count: boundaries.length,
        boundaries,
        final_version_history: finalGuard.history,
        final_version_history_sha256:
          computeSanitizedReceiptSha256(finalGuard.history),
        final_readback: finalGuard.deployment,
      },
      secret_installation: {
        installation_method:
          "wrangler_versions_secret_put_stdin_then_sequential_uploads",
        installed_secret_names: [
          "CLERK_WEBHOOK_SIGNING_SECRET",
          cutoverAcceptance.tokenSecretName,
        ],
        starting_secret_names: [...existingSecretNames],
        final_secret_names: [...productionWorkerSecretNames],
        interim_worker_version_id: webhookSourceReadback.worker_version_id,
        interim_worker_version_created_at_utc:
          webhookSourceReadback.created_at_utc,
        source_worker_version_id: sourceReadback.worker_version_id,
        source_worker_version_created_at_utc: sourceReadback.created_at_utc,
        clerk_webhook_preparation_receipt: clerkWebhookPreparationReceipt,
        clerk_webhook_preparation_receipt_sha256:
          clerkWebhookPreparationReceipt.receipt_sha256,
        secret_values_recorded: false,
      },
      version_readbacks: {
        webhook_secret_interim: webhookSourceReadback,
        source_s: sourceReadback,
        candidate_a: candidateReadback,
        accepted_b: acceptedReadback,
        write_guard_g: writeGuardReadback,
        last_known_good_l: lastKnownGoodFinal,
      },
      packet_worker: packetWorker,
    };
    const receipt = Object.freeze({
      ...payload,
      receipt_sha256: computeSanitizedReceiptSha256(payload),
    });
    const validated = validateProductionGreenfieldWorkerLineageReceipt(receipt);
    assertReceiptOmitsSecretValues(validated, secretMaterial);
    return validated;
  } catch {
    throw genericExecutionError();
  } finally {
    secretMaterial.clerkWebhookSigningSecret.fill(0);
    secretMaterial.cutoverAcceptanceToken.fill(0);
  }
}

export function validateProductionGreenfieldWorkerLineageReceipt(value) {
  requireExactKeys(value, [
    "schema_version",
    "receipt_type",
    "status",
    "authorization",
    "production_target",
    "source_contract",
    "provider_command_contract",
    "deployment_guard",
    "secret_installation",
    "version_readbacks",
    "packet_worker",
    "receipt_sha256",
  ]);
  requireEqual(value.schema_version, 1);
  requireEqual(value.receipt_type, receiptType);
  requireEqual(value.status, "completed");
  requireExactKeys(value.authorization, [
    "profile",
    "digest",
    "execution_mode",
    "outer_technical_gate",
    "clerk_technical_gate",
    "lineage_technical_gate",
  ]);
  requireEqual(value.authorization.profile, greenfieldAuthorizationProfile);
  requireEqual(value.authorization.digest, greenfieldAuthorizationDigest);
  requireEqual(
    value.authorization.execution_mode,
    productionGreenfieldWorkerLineageOrchestration.executionMode,
  );
  requireEqual(
    value.authorization.outer_technical_gate,
    productionGreenfieldWorkerLineageOrchestration.outerTechnicalGate,
  );
  requireEqual(
    value.authorization.clerk_technical_gate,
    productionGreenfieldWorkerLineageOrchestration.clerkTechnicalGate,
  );
  requireEqual(
    value.authorization.lineage_technical_gate,
    productionGreenfieldWorkerLineageOrchestration.lineageTechnicalGate,
  );
  requireSha256(value.receipt_sha256);
  const payload = Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== "receipt_sha256"),
  );
  requireEqual(value.receipt_sha256, computeSanitizedReceiptSha256(payload));
  requireExactKeys(value.production_target, [
    "account_id",
    "worker_name",
    "environment",
    "database_branch_id",
    "database_runtime_role_id",
    "hyperdrive_id",
  ]);
  requireEqual(
    value.production_target.account_id,
    productionRuntimeProvisioningTarget.cloudflareAccountId,
  );
  requireEqual(value.production_target.worker_name, productionWorker.name);
  requireEqual(value.production_target.environment, productionWorker.environment);
  requireEqual(value.production_target.database_branch_id, productionDatabase.branchId);
  requireEqual(
    value.production_target.database_runtime_role_id,
    productionDatabase.runtimeRoleId,
  );
  requireEqual(value.production_target.hyperdrive_id, productionDatabase.hyperdriveId);
  requireExactKeys(value.source_contract, [
    "manifest_sha256",
    "file_count",
    "wrangler_config_sha256",
    "package_lock_sha256",
    "greenfield_launch_packet_sha256",
    "greenfield_launch_packet_declaration_sha256",
    "production_clerk_webhook_preparation_sha256",
    "production_clerk_webhook_preparation_declaration_sha256",
    "production_runtime_provisioning_sha256",
    "production_runtime_provisioning_declaration_sha256",
    "rollback_packet_sha256",
    "rollback_packet_declaration_sha256",
  ]);
  for (const field of [
    "manifest_sha256",
    "wrangler_config_sha256",
    "package_lock_sha256",
    "greenfield_launch_packet_sha256",
    "greenfield_launch_packet_declaration_sha256",
    "production_clerk_webhook_preparation_sha256",
    "production_clerk_webhook_preparation_declaration_sha256",
    "production_runtime_provisioning_sha256",
    "production_runtime_provisioning_declaration_sha256",
    "rollback_packet_sha256",
    "rollback_packet_declaration_sha256",
  ]) requireSha256(value.source_contract[field]);
  requireEqual(value.source_contract.manifest_sha256, reviewedSourceManifestSha256);
  requireEqual(value.source_contract.file_count, reviewedSourceManifestFileCount);
  requireEqual(value.source_contract.wrangler_config_sha256, reviewedSourceDigests.wranglerConfig);
  requireEqual(value.source_contract.package_lock_sha256, reviewedSourceDigests.packageLock);
  requireEqual(
    value.source_contract.greenfield_launch_packet_sha256,
    reviewedSourceDigests.greenfieldLaunchPacket,
  );
  requireEqual(
    value.source_contract.greenfield_launch_packet_declaration_sha256,
    reviewedSourceDigests.greenfieldLaunchPacketDeclaration,
  );
  requireEqual(
    value.source_contract.production_clerk_webhook_preparation_sha256,
    reviewedSourceDigests.productionClerkWebhookPreparation,
  );
  requireEqual(
    value.source_contract.production_clerk_webhook_preparation_declaration_sha256,
    reviewedSourceDigests.productionClerkWebhookPreparationDeclaration,
  );
  requireEqual(
    value.source_contract.production_runtime_provisioning_sha256,
    reviewedSourceDigests.productionRuntimeProvisioning,
  );
  requireEqual(
    value.source_contract.production_runtime_provisioning_declaration_sha256,
    reviewedSourceDigests.productionRuntimeProvisioningDeclaration,
  );
  requireEqual(
    value.source_contract.rollback_packet_sha256,
    reviewedSourceDigests.rollbackPacket,
  );
  requireEqual(
    value.source_contract.rollback_packet_declaration_sha256,
    reviewedSourceDigests.rollbackPacketDeclaration,
  );
  requireExactKeys(value.provider_command_contract, [
    "wrangler_command",
    "wrangler_version",
    "cloudflare_command",
    "cloudflare_cli_version",
    "worker_name",
    "upload_environment",
    "env_file",
    "strict_upload",
    "experimental_provision",
    "experimental_auto_create",
    "secret_transport",
    "secret_value_argument_count",
    "upload_secret_override_count",
    "traffic_mutation_count",
    "route_mutation_count",
  ]);
  requireEqual(value.provider_command_contract.wrangler_command, wranglerCommand);
  requireEqual(value.provider_command_contract.wrangler_version, wranglerVersion);
  requireEqual(value.provider_command_contract.cloudflare_command, cloudflareCommand);
  requireEqual(
    value.provider_command_contract.cloudflare_cli_version,
    cloudflareCliVersion,
  );
  requireEqual(value.provider_command_contract.worker_name, productionWorker.name);
  requireEqual(
    value.provider_command_contract.upload_environment,
    productionWorker.environment,
  );
  requireEqual(value.provider_command_contract.env_file, "/dev/null");
  requireEqual(value.provider_command_contract.strict_upload, true);
  requireEqual(value.provider_command_contract.experimental_provision, false);
  requireEqual(value.provider_command_contract.experimental_auto_create, false);
  requireEqual(value.provider_command_contract.secret_transport, "stdin");
  for (const field of [
    "secret_value_argument_count",
    "upload_secret_override_count",
    "traffic_mutation_count",
    "route_mutation_count",
  ]) requireEqual(value.provider_command_contract[field], 0);

  validateSecretInstallationReceipt(value.secret_installation);
  validateVersionReadbackReceiptSet(
    value.version_readbacks,
    value.secret_installation,
  );
  validateDeploymentGuardReceipt(
    value.deployment_guard,
    value.secret_installation,
    value.version_readbacks,
  );
  validatePacketWorkerFragment(
    value.packet_worker,
    value.version_readbacks,
    value.deployment_guard,
  );
  return Object.freeze(value);
}

export function runProductionGreenfieldWorkerLineageCommand(
  specification,
  options = {},
) {
  const spawnImpl = options.spawnImpl ?? spawn;
  const timeoutMs = options.timeoutMs ?? PROVIDER_TIMEOUT_MS;
  const maxOutputBytes = options.maxOutputBytes ?? MAX_PROVIDER_OUTPUT_BYTES;
  const killGraceMs = options.killGraceMs ?? PROVIDER_KILL_GRACE_MS;
  return new Promise((resolvePromise, rejectPromise) => {
    let child;
    try {
      child = spawnImpl(specification.command, specification.args, {
        cwd: specification.cwd,
        env: specification.environment,
        signal: specification.signal,
        stdio: ["pipe", "pipe", "pipe"],
      });
    } catch {
      rejectPromise(genericExecutionError());
      return;
    }
    let settled = false;
    let failed = false;
    let outputBytes = 0;
    const stdoutChunks = [];
    let forceKillTimer;
    let stdinBytes;
    const timeout = setTimeout(() => fail(), timeoutMs);
    const finish = (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (forceKillTimer) clearTimeout(forceKillTimer);
      if (stdinBytes) stdinBytes.fill(0);
      if (error) {
        for (const chunk of stdoutChunks) chunk.fill(0);
        rejectPromise(genericExecutionError());
      }
      else {
        const stdout = Buffer.concat(stdoutChunks);
        for (const chunk of stdoutChunks) chunk.fill(0);
        resolvePromise({ stdout });
      }
    };
    const fail = () => {
      if (failed) return;
      failed = true;
      child.kill?.("SIGTERM");
      forceKillTimer = setTimeout(() => {
        child.kill?.("SIGKILL");
        finish(genericExecutionError());
      }, killGraceMs);
    };
    const countOutput = (chunk) => {
      const bytes = Buffer.isBuffer(chunk) ? chunk.byteLength : Buffer.byteLength(String(chunk));
      outputBytes += bytes;
      if (outputBytes > maxOutputBytes) fail();
    };
    child.stdout?.on("data", (chunk) => {
      countOutput(chunk);
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      if (!failed) stdoutChunks.push(buffer);
      else buffer.fill(0);
    });
    child.stderr?.on("data", (chunk) => {
      countOutput(chunk);
      if (Buffer.isBuffer(chunk)) chunk.fill(0);
    });
    child.on("error", fail);
    child.stdin?.on("error", fail);
    child.on("close", (code) => {
      if (!failed && code === 0) finish();
      else finish(genericExecutionError());
    });
    try {
      if (!child.stdin?.writable) throw new Error("stdin unavailable");
      if (specification.stdin) {
        stdinBytes = Buffer.alloc(specification.stdin.byteLength + 1);
        stdinBytes.set(specification.stdin, 0);
        stdinBytes[stdinBytes.length - 1] = 0x0a;
        child.stdin.end(stdinBytes);
      } else {
        child.stdin.end();
      }
    } catch {
      fail();
    }
  });
}

export async function readProductionGreenfieldWorkerLineageSecretMaterial(
  input,
) {
  const chunks = [];
  let bytes = 0;
  let payload;
  try {
    for await (const chunk of input) {
      const buffer = Buffer.from(chunk);
      bytes += buffer.byteLength;
      if (bytes > MAX_SECRET_BUNDLE_BYTES) {
        buffer.fill(0);
        throw new Error("Production Worker lineage secret input is invalid");
      }
      chunks.push(buffer);
    }
    payload = Buffer.concat(chunks);
    const firstBreak = payload.indexOf(0x0a);
    let finalBreak = payload.lastIndexOf(0x0a);
    if (finalBreak === payload.length - 1) finalBreak = payload.lastIndexOf(0x0a, finalBreak - 1);
    if (firstBreak <= 0 || finalBreak !== firstBreak) {
      throw new Error("Production Worker lineage secret input is invalid");
    }
    let webhook = payload.subarray(0, firstBreak);
    let token = payload.subarray(firstBreak + 1);
    if (token.at(-1) === 0x0a) token = token.subarray(0, -1);
    if (webhook.at(-1) === 0x0d) webhook = webhook.subarray(0, -1);
    if (token.at(-1) === 0x0d) token = token.subarray(0, -1);
    const result = {
      clerkWebhookSigningSecret: Buffer.from(webhook),
      cutoverAcceptanceToken: Buffer.from(token),
    };
    try {
      validateSecretMaterial(result);
      return result;
    } catch {
      result.clerkWebhookSigningSecret.fill(0);
      result.cutoverAcceptanceToken.fill(0);
      throw new Error("Production Worker lineage secret input is invalid");
    }
  } catch {
    throw new Error("Production Worker lineage secret input is invalid");
  } finally {
    payload?.fill(0);
    for (const chunk of chunks) chunk.fill(0);
  }
}

export async function runProductionGreenfieldWorkerLineageCLI(options = {}) {
  const args = options.args ?? process.argv.slice(2);
  const environment = options.environment ?? process.env;
  const writeStdout = options.writeStdout
    ?? ((value) => process.stdout.write(value));
  const writeStderr = options.writeStderr
    ?? ((value) => process.stderr.write(value));
  const checkSources = options.checkSources
    ?? loadProductionGreenfieldWorkerLineageSources;

  if (args.length === 1 && args[0] === "--check") {
    try {
      await checkSources();
      writeStdout("Production greenfield Worker lineage sources verified.\n");
      return 0;
    } catch {
      writeStderr("Production greenfield Worker lineage source check failed.\n");
      return 1;
    }
  }
  if (args.length !== 1 || args[0] !== "--execute") {
    writeStderr(
      "Usage: node scripts/prepare-production-greenfield-worker-lineage.mjs --check|--execute\n",
    );
    return 2;
  }
  writeStderr(
    "Standalone production Worker lineage execution is disabled; use the reviewed same-process cutover orchestrator.\n",
  );
  return 2;
}

function createSecretLineage({
  sourceReadback,
  candidateReadback,
  acceptedReadback,
  writeGuardReadback,
  lineageObservedAtUTC,
  boundaries,
}) {
  const providerVersionHistoryReceiptId =
    `refwatch-worker-version-history-${sourceReadback.worker_version_id}`;
  const providerHistoryPayload = providerVersionHistoryPayload(
    providerVersionHistoryReceiptId,
    lineageObservedAtUTC,
    boundaries,
  );
  const payload = {
    status: "passed",
    receipt_kind: "worker_secret_lineage:sequential_inheritance",
    receipt_id: `refwatch-worker-secret-lineage-${sourceReadback.worker_version_id}`,
    observed_at_utc: lineageObservedAtUTC,
    installation_method:
      "wrangler_versions_secret_put_stdin_then_sequential_uploads",
    source_worker_version_id: sourceReadback.worker_version_id,
    source_worker_version_created_at_utc: sourceReadback.created_at_utc,
    candidate_worker_version_id: candidateReadback.worker_version_id,
    candidate_worker_version_created_at_utc: candidateReadback.created_at_utc,
    candidate_inherited_from_worker_version_id:
      sourceReadback.worker_version_id,
    accepted_worker_version_id: acceptedReadback.worker_version_id,
    accepted_worker_version_created_at_utc: acceptedReadback.created_at_utc,
    accepted_inherited_from_worker_version_id:
      candidateReadback.worker_version_id,
    required_secret_names: [...productionWorkerSecretNames],
    unexpected_intervening_version_count: 0,
    intervening_secret_mutation_count: 0,
    upload_secret_override_count: 0,
    non_echoing_installation_status: "passed",
    secret_values_recorded: false,
    operator_confirmation_status: "passed",
    provider_version_history_receipt_id: providerVersionHistoryReceiptId,
    provider_version_history_receipt_sha256:
      computeSanitizedReceiptSha256(providerHistoryPayload),
  };
  return Object.freeze({
    ...payload,
    receipt_sha256: computeSanitizedReceiptSha256(payload),
  });
}

function providerVersionHistoryPayload(receiptId, observedAtUTC, boundaries) {
  return {
    receipt_id: receiptId,
    observed_at_utc: observedAtUTC,
    worker_name: productionWorker.name,
    environment: productionWorker.environment,
    version_history_boundaries: boundaries.map((boundary) => ({
      stage: boundary.stage,
      created_worker_version_id: boundary.created_worker_version_id,
      before_version_history_sha256:
        boundary.before_version_history_sha256,
      after_version_history_sha256:
        boundary.after_version_history_sha256,
    })),
  };
}

function createPacketWorkerFragment({
  sourceReadback,
  candidateReadback,
  acceptedReadback,
  writeGuardReadback,
  stableBindingSha256,
  secretLineage,
  observedAtUTC,
}) {
  const payload = {
    name: productionWorker.name,
    environment: productionWorker.environment,
    versions: {
      candidate_worker_version_id: candidateReadback.worker_version_id,
      accepted_worker_version_id: acceptedReadback.worker_version_id,
      write_guard_worker_version_id: writeGuardReadback.worker_version_id,
      last_known_good_worker_version_id:
        productionLastKnownGoodWorker.versionId,
      candidate_worker_created_at_utc: candidateReadback.created_at_utc,
      accepted_worker_created_at_utc: acceptedReadback.created_at_utc,
      candidate_script_etag: candidateReadback.resources.script.etag,
      accepted_script_etag: acceptedReadback.resources.script.etag,
      candidate_stable_binding_sha256: stableBindingSha256,
      accepted_stable_binding_sha256: stableBindingSha256,
      candidate_sanitized_readback: candidateReadback,
      accepted_sanitized_readback: acceptedReadback,
    },
    secret_lineage: secretLineage,
    provider_readback_at_utc: observedAtUTC,
  };
  return Object.freeze({
    ...payload,
    provider_readback_sha256: computeSanitizedReceiptSha256(payload),
  });
}

function validatePacketWorkerFragment(worker, readbacks, deploymentGuard) {
  requireExactKeys(worker, [
    "name",
    "environment",
    "versions",
    "secret_lineage",
    "provider_readback_at_utc",
    "provider_readback_sha256",
  ]);
  requireEqual(worker.name, productionWorker.name);
  requireEqual(worker.environment, productionWorker.environment);
  requireUTCInstant(worker.provider_readback_at_utc);
  requireSha256(worker.provider_readback_sha256);
  const payload = Object.fromEntries(
    Object.entries(worker).filter(([key]) => key !== "provider_readback_sha256"),
  );
  requireEqual(
    worker.provider_readback_sha256,
    computeSanitizedReceiptSha256(payload),
  );
  const versions = worker.versions;
  requireExactKeys(versions, [
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
  ]);
  requireEqual(versions.candidate_worker_version_id, readbacks.candidate_a.worker_version_id);
  requireEqual(versions.accepted_worker_version_id, readbacks.accepted_b.worker_version_id);
  requireEqual(versions.write_guard_worker_version_id, readbacks.write_guard_g.worker_version_id);
  requireEqual(versions.last_known_good_worker_version_id, productionLastKnownGoodWorker.versionId);
  requireEqual(versions.candidate_worker_created_at_utc, readbacks.candidate_a.created_at_utc);
  requireEqual(versions.accepted_worker_created_at_utc, readbacks.accepted_b.created_at_utc);
  requireEqual(versions.candidate_sanitized_readback, readbacks.candidate_a);
  requireEqual(versions.accepted_sanitized_readback, readbacks.accepted_b);
  requireSha256(versions.candidate_script_etag);
  requireEqual(versions.candidate_script_etag, versions.accepted_script_etag);
  requireSha256(versions.candidate_stable_binding_sha256);
  requireEqual(
    versions.candidate_stable_binding_sha256,
    versions.accepted_stable_binding_sha256,
  );
  requireEqual(
    versions.candidate_stable_binding_sha256,
    computeStableWorkerBindingSha256(readbacks.candidate_a),
  );
  validateSecretLineageReceipt(
    worker.secret_lineage,
    readbacks,
    deploymentGuard,
  );
  if (
    Object.values(readbacks).some((readback) =>
      Date.parse(readback.observed_at_utc)
        >= Date.parse(worker.provider_readback_at_utc))
    || Date.parse(worker.secret_lineage.observed_at_utc)
      >= Date.parse(worker.provider_readback_at_utc)
  ) throw genericExecutionError();
}

function validateSecretLineageReceipt(lineage, readbacks, deploymentGuard) {
  requireExactKeys(lineage, [
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
  ]);
  requireEqual(lineage.status, "passed");
  requireEqual(lineage.receipt_kind, "worker_secret_lineage:sequential_inheritance");
  requireEqual(
    lineage.receipt_id,
    `refwatch-worker-secret-lineage-${readbacks.source_s.worker_version_id}`,
  );
  requireUTCInstant(lineage.observed_at_utc);
  requireSha256(lineage.receipt_sha256);
  const payload = Object.fromEntries(
    Object.entries(lineage).filter(([key]) => key !== "receipt_sha256"),
  );
  requireEqual(lineage.receipt_sha256, computeSanitizedReceiptSha256(payload));
  requireEqual(
    lineage.installation_method,
    "wrangler_versions_secret_put_stdin_then_sequential_uploads",
  );
  requireEqual(lineage.source_worker_version_id, readbacks.source_s.worker_version_id);
  requireEqual(lineage.source_worker_version_created_at_utc, readbacks.source_s.created_at_utc);
  requireEqual(lineage.candidate_worker_version_id, readbacks.candidate_a.worker_version_id);
  requireEqual(lineage.candidate_worker_version_created_at_utc, readbacks.candidate_a.created_at_utc);
  requireEqual(lineage.candidate_inherited_from_worker_version_id, readbacks.source_s.worker_version_id);
  requireEqual(lineage.accepted_worker_version_id, readbacks.accepted_b.worker_version_id);
  requireEqual(lineage.accepted_worker_version_created_at_utc, readbacks.accepted_b.created_at_utc);
  requireEqual(lineage.accepted_inherited_from_worker_version_id, readbacks.candidate_a.worker_version_id);
  requireEqual(lineage.required_secret_names, [...productionWorkerSecretNames]);
  for (const field of [
    "unexpected_intervening_version_count",
    "intervening_secret_mutation_count",
    "upload_secret_override_count",
  ]) requireEqual(lineage[field], 0);
  requireEqual(lineage.non_echoing_installation_status, "passed");
  requireEqual(lineage.secret_values_recorded, false);
  requireEqual(lineage.operator_confirmation_status, "passed");
  requireEqual(
    lineage.provider_version_history_receipt_id,
    `refwatch-worker-version-history-${readbacks.source_s.worker_version_id}`,
  );
  requireSha256(lineage.provider_version_history_receipt_sha256);
  requireEqual(
    lineage.provider_version_history_receipt_sha256,
    computeSanitizedReceiptSha256(providerVersionHistoryPayload(
      lineage.provider_version_history_receipt_id,
      lineage.observed_at_utc,
      deploymentGuard.boundaries,
    )),
  );
  if (
    deploymentGuard.boundaries.some((boundary) =>
      Date.parse(boundary.after.observed_at_utc)
        >= Date.parse(lineage.observed_at_utc))
    || Date.parse(deploymentGuard.final_readback.observed_at_utc)
      >= Date.parse(lineage.observed_at_utc)
    || Date.parse(deploymentGuard.final_version_history.at(-1)?.created_at_utc)
      >= Date.parse(lineage.observed_at_utc)
    || Date.parse(readbacks.write_guard_g.observed_at_utc)
      >= Date.parse(lineage.observed_at_utc)
  ) throw genericExecutionError();
}

function validateVersionReadbackReceiptSet(readbacks, installation) {
  requireExactKeys(readbacks, [
    "webhook_secret_interim",
    "source_s",
    "candidate_a",
    "accepted_b",
    "write_guard_g",
    "last_known_good_l",
  ]);
  const ids = Object.values(readbacks).map((readback) => {
    validateSanitizedVersionReceipt(readback);
    return readback.worker_version_id;
  });
  if (new Set(ids).size !== ids.length) throw genericExecutionError();
  requireEqual(
    readbacks.last_known_good_l.worker_version_id,
    productionLastKnownGoodWorker.versionId,
  );
  validateLastKnownGoodVersion(readbacks.last_known_good_l, existingSecretNames);
  validateInheritedSourceVersion(
    readbacks.webhook_secret_interim,
    readbacks.last_known_good_l,
    [...existingSecretNames, "CLERK_WEBHOOK_SIGNING_SECRET"],
  );
  validateInheritedSourceVersion(
    readbacks.source_s,
    readbacks.last_known_good_l,
    productionWorkerSecretNames,
  );
  validateCurrentCandidateReadback(
    readbacks.candidate_a,
    "disabled",
    "disabled",
  );
  validateCurrentCandidateReadback(
    readbacks.accepted_b,
    "enabled",
    "greenfield_bootstrap",
  );
  validateCurrentCandidateReadback(
    readbacks.write_guard_g,
    "disabled",
    "disabled",
  );
  const stableBindingSha256 = computeStableWorkerBindingSha256(
    readbacks.candidate_a,
  );
  if (
    computeStableWorkerBindingSha256(readbacks.accepted_b)
      !== stableBindingSha256
    || computeStableWorkerBindingSha256(readbacks.write_guard_g)
      !== stableBindingSha256
  ) throw genericExecutionError();
  requireChronology([
    readbacks.last_known_good_l,
    readbacks.webhook_secret_interim,
    readbacks.source_s,
    readbacks.candidate_a,
    readbacks.accepted_b,
    readbacks.write_guard_g,
  ]);
  requireEqual(
    installation.interim_worker_version_id,
    readbacks.webhook_secret_interim.worker_version_id,
  );
  requireEqual(
    installation.interim_worker_version_created_at_utc,
    readbacks.webhook_secret_interim.created_at_utc,
  );
  requireEqual(
    installation.source_worker_version_id,
    readbacks.source_s.worker_version_id,
  );
  requireEqual(
    installation.source_worker_version_created_at_utc,
    readbacks.source_s.created_at_utc,
  );
}

function validateSanitizedVersionReceipt(receipt) {
  requireExactKeys(receipt, [
    "worker_version_id",
    "created_at_utc",
    "observed_at_utc",
    "resources",
    "readback_sha256",
  ]);
  requireUUID(receipt.worker_version_id);
  requireUTCInstant(receipt.created_at_utc);
  requireUTCInstant(receipt.observed_at_utc);
  if (Date.parse(receipt.created_at_utc) >= Date.parse(receipt.observed_at_utc)) {
    throw genericExecutionError();
  }
  requireSha256(receipt.readback_sha256);
  const payload = Object.fromEntries(
    Object.entries(receipt).filter(([key]) => key !== "readback_sha256"),
  );
  requireEqual(receipt.readback_sha256, computeSanitizedReceiptSha256(payload));
  validateWorkerRuntimeResources(receipt.resources);
}

function validateWorkerRuntimeResources(resources) {
  requireExactKeys(resources, ["script", "script_runtime", "bindings"]);
  requireExactKeys(resources.script, ["etag", "placement_mode", "placement"]);
  requireSha256(resources.script.etag);
  requireEqual(resources.script.placement_mode, "smart");
  requireEqual(resources.script.placement, { mode: "smart" });
  requireExactKeys(resources.script_runtime, [
    "compatibility_date",
    "compatibility_flags",
    "usage_model",
  ]);
  requireEqual(resources.script_runtime, {
    compatibility_date: "2026-07-14",
    compatibility_flags: ["nodejs_compat"],
    usage_model: "standard",
  });
  if (!Array.isArray(resources.bindings) || resources.bindings.length === 0) {
    throw genericExecutionError();
  }
}

function validateDeploymentGuardReceipt(guard, installation, readbacks) {
  requireExactKeys(guard, [
    "deployment_id",
    "worker_version_id",
    "traffic_percentage",
    "boundary_count",
    "boundaries",
    "final_version_history",
    "final_version_history_sha256",
    "final_readback",
  ]);
  requireUUID(guard.deployment_id);
  requireEqual(guard.worker_version_id, productionLastKnownGoodWorker.versionId);
  requireEqual(guard.traffic_percentage, 100);
  requireEqual(guard.boundary_count, 5);
  if (!Array.isArray(guard.boundaries) || guard.boundaries.length !== 5) {
    throw genericExecutionError();
  }
  requireEqual(guard.boundaries.map((boundary) => boundary.stage), [
    "webhook_secret_install",
    "cutover_secret_install_source_s",
    "candidate_a",
    "accepted_b",
    "write_guard_g",
  ]);
  const boundaryCommands = [
    productionGreenfieldWorkerLineageCommands.webhookSecretPut,
    productionGreenfieldWorkerLineageCommands.cutoverSecretPut,
    productionGreenfieldWorkerLineageCommands.candidateUpload,
    productionGreenfieldWorkerLineageCommands.acceptedUpload,
    productionGreenfieldWorkerLineageCommands.writeGuardUpload,
  ];
  requireEqual(
    guard.boundaries.map((boundary) => boundary.created_worker_version_tag),
    boundaryCommands.map((command) => commandArgument(command.args, "--tag")),
  );
  requireEqual(
    guard.boundaries.map((boundary) => boundary.created_worker_version_message),
    boundaryCommands.map((command) => commandArgument(command.args, "--message")),
  );
  requireEqual(
    guard.boundaries.map((boundary) => boundary.created_worker_version_id),
    [
      installation.interim_worker_version_id,
      installation.source_worker_version_id,
      readbacks.candidate_a.worker_version_id,
      readbacks.accepted_b.worker_version_id,
      readbacks.write_guard_g.worker_version_id,
    ],
  );
  const createdIds = [];
  const stableDeployment = guard.boundaries[0]?.before;
  const expectedTriggers = [
    "secret",
    "secret",
    "version_upload",
    "version_upload",
    "version_upload",
  ];
  const expectedReadbacks = [
    readbacks.webhook_secret_interim,
    readbacks.source_s,
    readbacks.candidate_a,
    readbacks.accepted_b,
    readbacks.write_guard_g,
  ];
  let previousAfterUTC;
  let previousAfterHistory;
  for (const [index, boundary] of guard.boundaries.entries()) {
    requireExactKeys(boundary, [
      "stage",
      "created_worker_version_id",
      "created_worker_version_tag",
      "created_worker_version_message",
      "before_version_history",
      "before_version_history_sha256",
      "after_version_history",
      "after_version_history_sha256",
      "before",
      "after",
    ]);
    requireUUID(boundary.created_worker_version_id);
    requireNonEmptyString(boundary.created_worker_version_tag);
    requireNonEmptyString(boundary.created_worker_version_message);
    createdIds.push(boundary.created_worker_version_id);
    const beforeHistory = validateSanitizedVersionHistory(
      boundary.before_version_history,
    );
    const afterHistory = validateSanitizedVersionHistory(
      boundary.after_version_history,
    );
    requireSha256(boundary.before_version_history_sha256);
    requireSha256(boundary.after_version_history_sha256);
    requireEqual(
      boundary.before_version_history_sha256,
      computeSanitizedReceiptSha256(beforeHistory),
    );
    requireEqual(
      boundary.after_version_history_sha256,
      computeSanitizedReceiptSha256(afterHistory),
    );
    if (index === 0) {
      requireEqual(
        beforeHistory.at(-1)?.id,
        productionLastKnownGoodWorker.versionId,
      );
    } else {
      requireEqual(beforeHistory, previousAfterHistory);
    }
    const createdHistoryEntry = classifyOneVersionDelta(
      beforeHistory,
      afterHistory,
      expectedTriggers[index],
      boundary.created_worker_version_tag,
      boundary.created_worker_version_message,
    );
    if (!createdHistoryEntry) throw genericExecutionError();
    requireEqual(
      createdHistoryEntry.id,
      boundary.created_worker_version_id,
    );
    requireEqual(
      createdHistoryEntry.created_at_utc,
      expectedReadbacks[index].created_at_utc,
    );
    previousAfterHistory = afterHistory;
    validateSanitizedDeployment(boundary.before);
    validateSanitizedDeployment(boundary.after);
    requireSameDeploymentSnapshot(stableDeployment, boundary.before);
    requireSameDeploymentSnapshot(stableDeployment, boundary.after);
    requireEqual(boundary.before.deployment_id, guard.deployment_id);
    requireEqual(boundary.after.deployment_id, guard.deployment_id);
    if (
      Date.parse(boundary.before.observed_at_utc)
        >= Date.parse(boundary.after.observed_at_utc)
      || (
        previousAfterUTC !== undefined
        && Date.parse(previousAfterUTC)
          >= Date.parse(boundary.before.observed_at_utc)
      )
    ) throw genericExecutionError();
    previousAfterUTC = boundary.after.observed_at_utc;
  }
  if (
    new Set(createdIds).size !== createdIds.length
    || createdIds.includes(readbacks.last_known_good_l.worker_version_id)
  ) throw genericExecutionError();
  requireEqual(
    previousAfterHistory?.at(-1)?.id,
    readbacks.write_guard_g.worker_version_id,
  );
  const finalHistory = validateSanitizedVersionHistory(
    guard.final_version_history,
  );
  requireSha256(guard.final_version_history_sha256);
  requireEqual(
    guard.final_version_history_sha256,
    computeSanitizedReceiptSha256(finalHistory),
  );
  requireEqual(finalHistory, previousAfterHistory);
  validateSanitizedDeployment(guard.final_readback);
  requireSameDeploymentSnapshot(stableDeployment, guard.final_readback);
  requireEqual(guard.final_readback.deployment_id, guard.deployment_id);
  if (
    previousAfterUTC === undefined
    || Date.parse(previousAfterUTC)
      >= Date.parse(guard.final_readback.observed_at_utc)
  ) throw genericExecutionError();
}

function validateSecretInstallationReceipt(receipt) {
  requireExactKeys(receipt, [
    "installation_method",
    "installed_secret_names",
    "starting_secret_names",
    "final_secret_names",
    "interim_worker_version_id",
    "interim_worker_version_created_at_utc",
    "source_worker_version_id",
    "source_worker_version_created_at_utc",
    "clerk_webhook_preparation_receipt",
    "clerk_webhook_preparation_receipt_sha256",
    "secret_values_recorded",
  ]);
  requireEqual(
    receipt.installation_method,
    "wrangler_versions_secret_put_stdin_then_sequential_uploads",
  );
  requireEqual(receipt.installed_secret_names, [
    "CLERK_WEBHOOK_SIGNING_SECRET",
    cutoverAcceptance.tokenSecretName,
  ]);
  requireEqual(receipt.starting_secret_names, [...existingSecretNames]);
  requireEqual(receipt.final_secret_names, [...productionWorkerSecretNames]);
  requireUUID(receipt.interim_worker_version_id);
  requireUUID(receipt.source_worker_version_id);
  if (receipt.interim_worker_version_id === receipt.source_worker_version_id) {
    throw genericExecutionError();
  }
  requireUTCInstant(receipt.interim_worker_version_created_at_utc);
  requireUTCInstant(receipt.source_worker_version_created_at_utc);
  let clerkReceipt;
  try {
    clerkReceipt = validateProductionClerkWebhookPreparationReceipt(
      receipt.clerk_webhook_preparation_receipt,
    );
  } catch {
    throw genericExecutionError();
  }
  requireSha256(receipt.clerk_webhook_preparation_receipt_sha256);
  requireEqual(
    receipt.clerk_webhook_preparation_receipt_sha256,
    clerkReceipt.receipt_sha256,
  );
  if (
    Date.parse(clerkReceipt.observed_at_utc)
      >= Date.parse(receipt.interim_worker_version_created_at_utc)
    ||
    Date.parse(receipt.interim_worker_version_created_at_utc)
      >= Date.parse(receipt.source_worker_version_created_at_utc)
  ) throw genericExecutionError();
  requireEqual(receipt.secret_values_recorded, false);
}

function validateSanitizedDeployment(deployment) {
  requireExactKeys(deployment, [
    "deployment_id",
    "source",
    "strategy",
    "created_at_utc",
    "observed_at_utc",
    "versions",
    "readback_sha256",
  ]);
  requireUUID(deployment.deployment_id);
  requireEqual(deployment.source, "wrangler");
  requireEqual(deployment.strategy, "percentage");
  requireUTCInstant(deployment.created_at_utc);
  requireUTCInstant(deployment.observed_at_utc);
  if (!Array.isArray(deployment.versions) || deployment.versions.length !== 1) {
    throw genericExecutionError();
  }
  requireExactKeys(deployment.versions[0], ["worker_version_id", "percentage"]);
  requireEqual(
    deployment.versions[0].worker_version_id,
    productionLastKnownGoodWorker.versionId,
  );
  requireEqual(deployment.versions[0].percentage, 100);
  requireSha256(deployment.readback_sha256);
  const payload = Object.fromEntries(
    Object.entries(deployment).filter(([key]) => key !== "readback_sha256"),
  );
  requireEqual(deployment.readback_sha256, computeSanitizedReceiptSha256(payload));
}

function sanitizeDeploymentReadback(value, observedAtUTC) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw genericExecutionError();
  }
  requireUUID(value.id);
  const createdAtUTC = normalizeUTCInstant(value.created_on);
  requireUTCInstant(observedAtUTC);
  if (!Array.isArray(value.versions) || value.versions.length !== 1) {
    throw genericExecutionError();
  }
  const version = value.versions[0];
  requireUUID(version?.version_id);
  if (typeof version?.percentage !== "number" || !Number.isFinite(version.percentage)) {
    throw genericExecutionError();
  }
  const payload = {
    deployment_id: value.id,
    source: requireNonEmptyString(value.source),
    strategy: requireNonEmptyString(value.strategy),
    created_at_utc: createdAtUTC,
    observed_at_utc: observedAtUTC,
    versions: [{
      worker_version_id: version.version_id,
      percentage: version.percentage,
    }],
  };
  return Object.freeze({
    ...payload,
    readback_sha256: computeSanitizedReceiptSha256(payload),
  });
}

function validateVersionHistory(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > 10) {
    throw genericExecutionError();
  }
  const entries = value.map((entry) => {
    requireUUID(entry?.id);
    if (!Number.isSafeInteger(entry?.number) || entry.number <= 0) {
      throw genericExecutionError();
    }
    return Object.freeze({
      id: entry.id,
      number: entry.number,
      created_at_utc: normalizeUTCInstant(entry?.metadata?.created_on),
      trigger: requireNonEmptyString(entry?.annotations?.["workers/triggered_by"]),
      tag: optionalNonEmptyString(entry?.annotations?.["workers/tag"]),
      message: optionalNonEmptyString(entry?.annotations?.["workers/message"]),
    });
  });
  for (let index = 1; index < entries.length; index += 1) {
    if (
      entries[index].number !== entries[index - 1].number + 1
      || Date.parse(entries[index].created_at_utc)
        <= Date.parse(entries[index - 1].created_at_utc)
    ) throw genericExecutionError();
  }
  return Object.freeze(entries);
}

function validateSanitizedVersionHistory(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > 10) {
    throw genericExecutionError();
  }
  const entries = value.map((entry) => {
    requireExactKeys(entry, [
      "id",
      "number",
      "created_at_utc",
      "trigger",
      "tag",
      "message",
    ]);
    requireUUID(entry.id);
    if (!Number.isSafeInteger(entry.number) || entry.number <= 0) {
      throw genericExecutionError();
    }
    requireUTCInstant(entry.created_at_utc);
    requireNonEmptyString(entry.trigger);
    if (entry.tag !== null) requireNonEmptyString(entry.tag);
    if (entry.message !== null) requireNonEmptyString(entry.message);
    return entry;
  });
  if (new Set(entries.map((entry) => entry.id)).size !== entries.length) {
    throw genericExecutionError();
  }
  for (let index = 1; index < entries.length; index += 1) {
    if (
      entries[index].number !== entries[index - 1].number + 1
      || Date.parse(entries[index].created_at_utc)
        <= Date.parse(entries[index - 1].created_at_utc)
    ) throw genericExecutionError();
  }
  return entries;
}

function classifyOneVersionDelta(
  before,
  after,
  expectedTrigger,
  expectedTag,
  expectedMessage,
) {
  if (sameSanitizedValue(before, after)) return undefined;
  const expectedLength = Math.min(before.length + 1, 10);
  if (
    after.length !== expectedLength
    || after.at(-1).number !== before.at(-1).number + 1
    || before.some((entry) => entry.id === after.at(-1).id)
    || after.at(-1).trigger !== expectedTrigger
  ) throw genericExecutionError();
  const retainedBefore = before.slice(-(after.length - 1));
  const retainedAfter = after.slice(0, -1);
  if (canonicalSanitizedJSON(retainedBefore) !== canonicalSanitizedJSON(retainedAfter)) {
    throw genericExecutionError();
  }
  if (
    (after.at(-1).tag !== null && after.at(-1).tag !== expectedTag)
    || (after.at(-1).message !== null
      && after.at(-1).message !== expectedMessage)
  ) throw genericExecutionError();
  if (after.at(-1).tag === null || after.at(-1).message === null) {
    return undefined;
  }
  return after.at(-1);
}

function validateSecretInventory(value) {
  if (!Array.isArray(value)) throw genericExecutionError();
  const names = value.map((entry) => {
    requireExactKeys(entry, ["name", "type"]);
    requireEqual(entry.type, "secret_text");
    if (!productionWorkerSecretNames.includes(entry.name)) throw genericExecutionError();
    return entry.name;
  }).sort();
  if (new Set(names).size !== names.length) throw genericExecutionError();
  return names;
}

function requireExactSecretNames(actual, expected) {
  requireEqual([...actual].sort(), [...expected].sort());
}

function validateLastKnownGoodDeployment(deployment) {
  validateSanitizedDeployment(deployment);
  requireEqual(
    deployment.versions,
    [{
      worker_version_id: productionLastKnownGoodWorker.versionId,
      percentage: 100,
    }],
  );
}

function validateLastKnownGoodVersion(receipt, secretNames) {
  validateSanitizedVersionReceipt(receipt);
  requireEqual(receipt.worker_version_id, productionLastKnownGoodWorker.versionId);
  requireEqual(receipt.created_at_utc, productionLastKnownGoodWorker.createdAtUTC);
  requireEqual(receipt.resources.script.etag, productionLastKnownGoodWorker.scriptEtag);
  requireEqual(
    receipt.resources.bindings,
    expectedLastKnownGoodBindings(secretNames),
  );
}

function validateInheritedSourceVersion(receipt, lastKnownGood, secretNames) {
  validateSanitizedVersionReceipt(receipt);
  requireEqual(receipt.resources.script, lastKnownGood.resources.script);
  requireEqual(receipt.resources.script_runtime, lastKnownGood.resources.script_runtime);
  requireEqual(receipt.resources.bindings, expectedLastKnownGoodBindings(secretNames));
}

function validateCurrentCandidateReadback(receipt, writeMode, onboardingMode) {
  validateSanitizedVersionReceipt(receipt);
  requireEqual(receipt.resources.script.etag, productionLastKnownGoodWorker.scriptEtag);
  requireEqual(
    receipt.resources.bindings,
    expectedProductionWorkerBindings(writeMode, onboardingMode),
  );
}

function expectedLastKnownGoodBindings(secretNames) {
  return expectedProductionWorkerBindings("disabled", "disabled")
    .filter((binding) =>
      binding.name !== "IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST"
        && binding.name !== "IDENTITY_RECONCILIATION_RECEIPT"
        && (binding.type !== "secret_text" || secretNames.includes(binding.name)))
    .map((binding) => {
      if (binding.name === "EXPECTED_DATABASE_ROLE_ID") {
        return { ...binding, text: productionLastKnownGoodWorker.runtimeRoleId };
      }
      if (binding.name === "HYPERDRIVE") {
        return { ...binding, id: productionLastKnownGoodWorker.hyperdriveId };
      }
      return binding;
    })
    .sort((left, right) => canonicalSanitizedJSON(left).localeCompare(
      canonicalSanitizedJSON(right),
    ));
}

function validateProductionWranglerConfiguration(config) {
  const production = config?.env?.production;
  const expectedVars = Object.fromEntries(
    expectedProductionWorkerBindings("disabled", "disabled")
      .filter((binding) => binding.type === "plain_text")
      .map((binding) => [binding.name, binding.text]),
  );
  if (
    config?.name !== "refwatch-api-development"
    || config?.main !== "src/index.ts"
    || config?.compatibility_date !== "2026-07-14"
    || canonicalSanitizedJSON(config?.compatibility_flags)
      !== canonicalSanitizedJSON(["nodejs_compat"])
    || config?.placement?.mode !== "smart"
    || config?.version_metadata?.binding !== "CF_VERSION_METADATA"
    || production?.name !== productionWorker.name
    || production?.workers_dev !== false
    || production?.preview_urls !== false
    || production?.version_metadata?.binding !== "CF_VERSION_METADATA"
    || canonicalSanitizedJSON(production?.vars)
      !== canonicalSanitizedJSON(expectedVars)
    || canonicalSanitizedJSON(production?.hyperdrive)
      !== canonicalSanitizedJSON([{
        binding: "HYPERDRIVE",
        id: productionDatabase.hyperdriveId,
      }])
    || canonicalSanitizedJSON(production?.d1_databases)
      !== canonicalSanitizedJSON([{
        binding: "MUTATION_LEDGER",
        database_name: productionLedgerResources.queueName,
        database_id: productionLedgerResources.d1Id,
        migrations_dir: "d1/migrations",
      }])
    || canonicalSanitizedJSON(production?.queues)
      !== canonicalSanitizedJSON({
        producers: [{
          binding: "MUTATION_LEDGER_QUEUE",
          queue: productionLedgerResources.queueName,
        }],
      })
    || production?.triggers !== undefined
  ) throw new Error("Production Worker lineage Wrangler configuration drifted");
}

function renderUploadArguments(stage) {
  return [
    "versions",
    "upload",
    "--env",
    productionWorker.environment,
    "--env-file",
    "/dev/null",
    "--strict",
    "--no-experimental-provision",
    "--no-experimental-auto-create",
    "--var",
    `WRITE_MODE:${stage.writeMode}`,
    "--var",
    `NEW_USER_ONBOARDING_MODE:${stage.onboardingMode}`,
    "--tag",
    stage.tag,
    "--message",
    stage.message,
  ];
}

function commandArgument(args, name) {
  const index = args.indexOf(name);
  if (index < 0 || index === args.length - 1) throw genericExecutionError();
  return requireNonEmptyString(args[index + 1]);
}

function buildProviderEnvironment(environment) {
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
    "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_API_KEY",
    "CLOUDFLARE_EMAIL",
  ]) {
    if (environment[name] !== undefined) result[name] = environment[name];
  }
  return {
    ...result,
    CLOUDFLARE_ACCOUNT_ID:
      productionRuntimeProvisioningTarget.cloudflareAccountId,
    WRANGLER_WRITE_LOGS: "0",
    WRANGLER_LOG_SANITIZE: "true",
    WRANGLER_SEND_METRICS: "false",
    NO_COLOR: "1",
  };
}

function cloneSecretMaterial(value) {
  return {
    clerkWebhookSigningSecret: Buffer.from(value.clerkWebhookSigningSecret ?? []),
    cutoverAcceptanceToken: Buffer.from(value.cutoverAcceptanceToken ?? []),
  };
}

function validateSecretMaterial(value) {
  const webhook = Buffer.isBuffer(value?.clerkWebhookSigningSecret)
    ? value.clerkWebhookSigningSecret
    : Buffer.from(value?.clerkWebhookSigningSecret ?? []);
  const token = Buffer.isBuffer(value?.cutoverAcceptanceToken)
    ? value.cutoverAcceptanceToken
    : Buffer.from(value?.cutoverAcceptanceToken ?? []);
  if (
    webhook.length < 24
    || webhook.length > 512
    || !webhook.subarray(0, 6).equals(
      Buffer.from([0x77, 0x68, 0x73, 0x65, 0x63, 0x5f]),
    )
    || !isPrintableNonWhitespaceASCII(webhook)
    || token.length < 32
    || token.length > 512
    || !isPrintableNonWhitespaceASCII(token)
    || webhook.equals(token)
  ) throw new Error("Production Worker lineage secret material is invalid");
}

function isPrintableNonWhitespaceASCII(value) {
  return value.every((byte) => byte >= 0x21 && byte <= 0x7e);
}

function assertReceiptOmitsSecretValues(receipt, secretMaterial) {
  const serialized = Buffer.from(canonicalSanitizedJSON(receipt));
  try {
    if (
      serialized.includes(secretMaterial.clerkWebhookSigningSecret)
      || serialized.includes(secretMaterial.cutoverAcceptanceToken)
    ) throw genericExecutionError();
  } finally {
    serialized.fill(0);
  }
}

function parseProviderJSON(result) {
  try {
    const stdout = Buffer.isBuffer(result?.stdout)
      ? result.stdout
      : Buffer.from(result?.stdout ?? "");
    return JSON.parse(stdout.toString("utf8"));
  } catch {
    throw genericExecutionError();
  }
}

function wipeCommandResult(result) {
  if (Buffer.isBuffer(result?.stdout)) result.stdout.fill(0);
  else if (ArrayBuffer.isView(result?.stdout)) {
    new Uint8Array(
      result.stdout.buffer,
      result.stdout.byteOffset,
      result.stdout.byteLength,
    ).fill(0);
  }
}

function normalizedToolVersion(result) {
  const stdout = Buffer.isBuffer(result?.stdout)
    ? result.stdout.toString("utf8")
    : String(result?.stdout ?? "");
  const match = stdout.trim().match(/(?:^|[^0-9])(\d+\.\d+\.\d+)(?:[^0-9]|$)/u);
  if (!match) throw genericExecutionError();
  return match[1];
}

function requireLatestVersion(history, expectedVersionId) {
  requireEqual(history.at(-1)?.id, expectedVersionId);
}

function requireSameGuard(left, right, deploymentId) {
  requireEqual(left.history, right.history);
  requireSameDeployment(left.deployment, right.deployment, deploymentId);
}

function requireSameDeployment(left, right, deploymentId) {
  requireEqual(left.deployment_id, deploymentId);
  requireEqual(right.deployment_id, deploymentId);
  requireEqual(left.versions, right.versions);
  requireEqual(left.created_at_utc, right.created_at_utc);
  requireEqual(left.source, right.source);
  requireEqual(left.strategy, right.strategy);
}

function requireSameDeploymentSnapshot(left, right) {
  requireEqual(left.deployment_id, right.deployment_id);
  requireEqual(left.created_at_utc, right.created_at_utc);
  requireEqual(left.source, right.source);
  requireEqual(left.strategy, right.strategy);
  requireEqual(left.versions, right.versions);
}

function requireEqualVersionResources(left, right) {
  requireEqual(left.worker_version_id, right.worker_version_id);
  requireEqual(left.created_at_utc, right.created_at_utc);
  requireEqual(left.resources, right.resources);
}

function requireChronology(readbacks) {
  if (new Set(readbacks.map((receipt) => receipt.worker_version_id)).size
      !== readbacks.length) {
    throw genericExecutionError();
  }
  for (let index = 1; index < readbacks.length; index += 1) {
    if (
      Date.parse(readbacks[index - 1].created_at_utc)
        >= Date.parse(readbacks[index].created_at_utc)
    ) throw genericExecutionError();
  }
}

function monotonicUTCClock(now) {
  let previous = 0;
  return () => {
    const value = now();
    const milliseconds = value instanceof Date
      ? value.getTime()
      : new Date(value).getTime();
    if (!Number.isFinite(milliseconds)) throw genericExecutionError();
    previous = Math.max(milliseconds, previous + 1);
    return new Date(previous).toISOString();
  };
}

async function recursiveFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries
    .filter((entry) => entry.name !== ".DS_Store")
    .map(async (entry) => {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) return recursiveFiles(path);
      if (entry.isFile()) return [path];
      return [];
    }));
  return nested.flat();
}

function parseSourceJSON(value) {
  try {
    return JSON.parse(value);
  } catch {
    throw new Error("Production Worker lineage source JSON is invalid");
  }
}

function normalizeUTCInstant(value) {
  const date = new Date(value ?? "");
  if (Number.isNaN(date.getTime())) throw genericExecutionError();
  return date.toISOString();
}

function requireExactKeys(value, expected) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw genericExecutionError();
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (
    actual.length !== wanted.length
    || !actual.every((key, index) => key === wanted[index])
  ) throw genericExecutionError();
}

function requireEqual(actual, expected) {
  if (!sameSanitizedValue(actual, expected)) {
    throw genericExecutionError();
  }
}

function sameSanitizedValue(left, right) {
  return canonicalSanitizedJSON(left) === canonicalSanitizedJSON(right);
}

function requireUUID(value) {
  if (!uuidPattern.test(value ?? "")) throw genericExecutionError();
}

function requireSha256(value) {
  if (!sha256Pattern.test(value ?? "")) throw genericExecutionError();
}

function requireUTCInstant(value) {
  if (!utcInstantPattern.test(value ?? "") || new Date(value).toISOString() !== value) {
    throw genericExecutionError();
  }
}

function requirePositiveInteger(value) {
  if (!Number.isSafeInteger(value) || value <= 0) throw genericExecutionError();
}

function requireNonEmptyString(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw genericExecutionError();
  }
  return value;
}

function optionalNonEmptyString(value) {
  if (value === undefined || value === null) return null;
  return requireNonEmptyString(value);
}

function sha256Hex(value) {
  return createHash("sha256").update(value).digest("hex");
}

function genericExecutionError() {
  return new Error("Production greenfield Worker lineage execution failed");
}

function requireActiveWorkerLineageLease(lease) {
  if (
    !lease
    || lease.active !== true
    || activeWorkerLineageLease !== lease
  ) throw genericExecutionError();
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await runProductionGreenfieldWorkerLineageCLI();
}
