import { createHash, randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  canonicalSanitizedJSON,
  computeSanitizedReceiptSha256,
  productionWorkerSecretNames,
} from "./greenfield-launch-packet.mjs";
import {
  loadProductionClerkWebhookPreparationSources,
  productionClerkWebhookPreparationGate,
  productionClerkWebhookTarget,
  validateProductionClerkWebhookPreparationReceipt,
  withProductionClerkWebhookSecret,
} from "./prepare-production-clerk-webhook.mjs";
import {
  loadProductionGreenfieldWorkerLineageSources,
  productionGreenfieldWorkerLineageGate,
  validateProductionGreenfieldWorkerLineageReceipt,
  withProductionGreenfieldWorkerLineageLease,
} from "./prepare-production-greenfield-worker-lineage.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const MAX_REVIEW_LINE_BYTES = 64 * 1024;
const checkpointReceiptType =
  "refwatch_production_greenfield_cutover_review_checkpoint";
const providerGuardReceiptType =
  "refwatch_production_greenfield_cutover_provider_guard";
const sha256Pattern = /^[0-9a-f]{64}$/u;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const utcInstantPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u;
const lowercaseHexAlphabet = Buffer.from("0123456789abcdef", "ascii");
const controlledErrors = new WeakSet();
const lineagePinStart = "// refwatch-lineage-reviewed-source-pins:start";
const lineagePinEnd = "// refwatch-lineage-reviewed-source-pins:end";
const lineagePinSentinel = "/* refwatch-lineage-reviewed-source-pins:normalized-v1 */";
const reviewedNormalizedLineageHelperSha256 =
  "ba90f2217dd7fe6cbfed6573bc14ce35f1a08dd1cc8043d20eef5eb077047476";
const reviewedLineageHelperDeclarationSha256 =
  "760f6956b94d3a74960861e6214c7534c4a864410f20f853b34e9b10d955c47f";
const normalizedLineagePinBlockTemplate = [
  lineagePinStart,
  "// Recomputed only after the reviewed Worker source/config manifest changes.",
  "const reviewedSourceManifestSha256 =",
  "  \"<sha256>\";",
  "const reviewedSourceManifestFileCount = <count>;",
  "const reviewedSourceDigests = Object.freeze({",
  "  wranglerConfig:",
  "    \"<sha256>\",",
  "  packageLock:",
  "    \"<sha256>\",",
  "  greenfieldLaunchPacket:",
  "    \"<sha256>\",",
  "  greenfieldLaunchPacketDeclaration:",
  "    \"<sha256>\",",
  "  productionClerkWebhookPreparation:",
  "    \"<sha256>\",",
  "  productionClerkWebhookPreparationDeclaration:",
  "    \"<sha256>\",",
  "  productionRuntimeProvisioning:",
  "    \"<sha256>\",",
  "  productionRuntimeProvisioningDeclaration:",
  "    \"<sha256>\",",
  "  rollbackPacket:",
  "    \"<sha256>\",",
  "  rollbackPacketDeclaration:",
  "    \"<sha256>\",",
  "});",
  lineagePinEnd,
].join("\n");
const requiredReviewRoles = Object.freeze([
  "code_operational_risk",
  "docs_evidence_consistency",
]);
export const productionGreenfieldCutoverCrashClassification = Object.freeze({
  phase: "post_lineage_before_bounded_acceptance",
  resumability: "non_resumable",
  required_recovery: "reviewed_relineage_with_new_cutover_token",
  reason: "memory_only_cutover_token_is_not_provider_readable",
});

export const productionGreenfieldCutoverGate =
  "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER";

export function normalizeProductionGreenfieldWorkerLineageSource(value) {
  const source = Buffer.isBuffer(value)
    ? value.toString("utf8")
    : String(value);
  if (
    countOccurrences(source, lineagePinStart) !== 1
    || countOccurrences(source, lineagePinEnd) !== 1
    || countOccurrences(source, lineagePinSentinel) !== 0
  ) throw new Error("Production greenfield cutover lineage pin block is invalid");
  const start = source.indexOf(lineagePinStart);
  const end = source.indexOf(lineagePinEnd, start);
  if (start < 0 || end <= start) {
    throw new Error("Production greenfield cutover lineage pin block is invalid");
  }
  const blockEnd = end + lineagePinEnd.length;
  const block = source.slice(start, blockEnd);
  const digestValues = block.match(/"[0-9a-f]{64}"/gu) ?? [];
  if (digestValues.length !== 11) {
    throw new Error("Production greenfield cutover lineage pin block is invalid");
  }
  const normalizedBlock = block
    .replace(/"[0-9a-f]{64}"/gu, "\"<sha256>\"")
    .replace(
      /const reviewedSourceManifestFileCount = [1-9][0-9]*;/u,
      "const reviewedSourceManifestFileCount = <count>;",
    );
  if (normalizedBlock !== normalizedLineagePinBlockTemplate) {
    throw new Error("Production greenfield cutover lineage pin block is invalid");
  }
  const normalized = `${source.slice(0, start)}${lineagePinSentinel}${source.slice(blockEnd)}`;
  if (
    countOccurrences(normalized, lineagePinSentinel) !== 1
    || countOccurrences(normalized, lineagePinStart) !== 0
    || countOccurrences(normalized, lineagePinEnd) !== 0
  ) throw new Error("Production greenfield cutover lineage normalization failed");
  return Buffer.from(normalized, "utf8");
}

export function validateProductionGreenfieldCutoverLineageSources(value) {
  if (!value || typeof value !== "object") {
    throw new Error("Production greenfield cutover reviewed lineage source drifted");
  }
  const normalizedHelperSha256 = sha256(
    normalizeProductionGreenfieldWorkerLineageSource(value.helper),
  );
  const declarationSha256 = sha256(value.declaration);
  if (
    normalizedHelperSha256 !== reviewedNormalizedLineageHelperSha256
    || declarationSha256 !== reviewedLineageHelperDeclarationSha256
  ) throw new Error("Production greenfield cutover reviewed lineage source drifted");
  return Object.freeze({ normalizedHelperSha256, declarationSha256 });
}

export async function loadProductionGreenfieldCutoverSources() {
  const [
    orchestrator,
    declaration,
    clerkHelper,
    clerkHelperDeclaration,
    lineageHelper,
    lineageHelperDeclaration,
    clerk,
    lineage,
  ] = await Promise.all([
    readFile(fileURLToPath(import.meta.url)),
    readFile(resolve(scriptDirectory, "execute-production-greenfield-cutover.d.mts")),
    readFile(resolve(scriptDirectory, "prepare-production-clerk-webhook.mjs")),
    readFile(resolve(scriptDirectory, "prepare-production-clerk-webhook.d.mts")),
    readFile(resolve(
      scriptDirectory,
      "prepare-production-greenfield-worker-lineage.mjs",
    )),
    readFile(resolve(
      scriptDirectory,
      "prepare-production-greenfield-worker-lineage.d.mts",
    )),
    loadProductionClerkWebhookPreparationSources(),
    loadProductionGreenfieldWorkerLineageSources(),
  ]);
  const reviewedLineageSources = validateProductionGreenfieldCutoverLineageSources({
    helper: lineageHelper,
    declaration: lineageHelperDeclaration,
  });
  const payload = {
    orchestrator_sha256: sha256(orchestrator),
    declaration_sha256: sha256(declaration),
    clerk_helper_sha256: sha256(clerkHelper),
    clerk_helper_declaration_sha256: sha256(clerkHelperDeclaration),
    worker_lineage_helper_sha256: sha256(lineageHelper),
    worker_lineage_helper_normalized_sha256:
      reviewedLineageSources.normalizedHelperSha256,
    worker_lineage_helper_declaration_sha256:
      reviewedLineageSources.declarationSha256,
    clerk_lock_contract_sha256: requireSHA256(
      clerk.clerkLockContractSha256,
    ),
    clerk_launch_packet_sha256: requireSHA256(clerk.launchPacketSha256),
    worker_lineage_manifest_sha256: requireSHA256(lineage.manifestSha256),
    worker_lineage_manifest_file_count: requirePositiveInteger(lineage.fileCount),
  };
  return Object.freeze({
    ...payload,
    source_contract_sha256: computeSanitizedReceiptSha256(payload),
  });
}

/**
 * Generate 256 random bits and encode them directly into a 64-byte lowercase
 * hexadecimal Buffer. No secret JavaScript string is created.
 */
export function generateProductionGreenfieldCutoverToken(options = {}) {
  const randomBytesFunction = options.randomBytes ?? randomBytes;
  const entropy = randomBytesFunction(32);
  if (!Buffer.isBuffer(entropy) || entropy.length !== 32) {
    if (Buffer.isBuffer(entropy)) entropy.fill(0);
    throw new Error("Production greenfield cutover entropy source failed");
  }
  const token = Buffer.alloc(64);
  try {
    for (let index = 0; index < entropy.length; index += 1) {
      const byte = entropy[index];
      token[index * 2] = lowercaseHexAlphabet[byte >>> 4];
      token[(index * 2) + 1] = lowercaseHexAlphabet[byte & 0x0f];
    }
    return token;
  } catch {
    token.fill(0);
    throw new Error("Production greenfield cutover token generation failed");
  } finally {
    entropy.fill(0);
  }
}

export async function executeProductionGreenfieldCutover(options = {}) {
  const environment = options.environment ?? process.env;
  if (environment[productionGreenfieldCutoverGate] !== "1") {
    throw new Error("Production greenfield cutover gate is closed");
  }

  // These are deliberately mandatory. The standalone broker may not create
  // immutable versions unless the reviewed live guard and later route stage
  // are already wired in the same process.
  if (
    typeof options.recheckProviderGuards !== "function"
    || typeof options.continueCutover !== "function"
  ) {
    throw new Error("Production greenfield cutover continuation is not configured");
  }

  const loadSources = options.loadSources
    ?? loadProductionGreenfieldCutoverSources;
  let initialSources;
  let initialSourceDigest;
  try {
    initialSources = await loadSources();
    initialSourceDigest = sanitizedDigest(initialSources);
  } catch {
    throw genericExecutionError();
  }
  const acquireWebhookSecret = options.withClerkWebhookSecret
    ?? withProductionClerkWebhookSecret;
  const withLineageLease = options.withLineageLease
    ?? withProductionGreenfieldWorkerLineageLease;
  const emitCheckpoint = options.emitCheckpoint
    ?? ((value) => process.stdout.write(value));
  const input = options.input ?? process.stdin;
  const now = options.now ?? (() => new Date());
  const signalSource = options.signalSource ?? process;
  const childEnvironment = {
    ...environment,
    [productionClerkWebhookPreparationGate]: "1",
    [productionGreenfieldWorkerLineageGate]: "1",
  };

  try {
    return await acquireWebhookSecret(async ({
      secretMaterial: webhookSecret,
      receipt,
    }) => {
      if (!Buffer.isBuffer(webhookSecret)) throw genericExecutionError();
      const clerkReceipt = validateProductionClerkWebhookPreparationReceipt(receipt);
      const token = generateProductionGreenfieldCutoverToken({
        randomBytes: options.randomBytes,
      });
      const abortController = new AbortController();
      const onSignal = () => {
        webhookSecret.fill(0);
        token.fill(0);
        abortController.abort();
      };
      let sigintRegistered = false;
      let sigtermRegistered = false;

      try {
        signalSource.on("SIGINT", onSignal);
        sigintRegistered = true;
        signalSource.on("SIGTERM", onSignal);
        sigtermRegistered = true;
        const lineageReceipt = validateProductionGreenfieldWorkerLineageReceipt(
          await awaitAbortAware(withLineageLease(
            (executeLineage) => executeLineage({
              clerkWebhookPreparationReceipt: clerkReceipt,
              secretMaterial: {
                clerkWebhookSigningSecret: webhookSecret,
                cutoverAcceptanceToken: token,
              },
              signal: abortController.signal,
            }),
            { environment: childEnvironment },
          ), abortController.signal),
        );

        const checkpoint = createCheckpoint({
          clerkReceipt,
          lineageReceipt,
          sourceContractSha256: initialSourceDigest,
          observedAtUTC: normalizeUTCInstant(now()),
        });
        assertOmitsSecretMaterial(checkpoint, [webhookSecret, token]);
        await emitCheckpoint(`${canonicalSanitizedJSON(checkpoint)}\n`);

        const reviewQuorum = await readProductionGreenfieldCutoverReviewQuorum(
          input,
          checkpoint,
          { signal: abortController.signal },
        );

        const currentSources = await awaitAbortAware(
          loadSources(),
          abortController.signal,
        );
        if (sanitizedDigest(currentSources) !== initialSourceDigest) {
          throw controlledError(
            "Production greenfield cutover source drift detected",
          );
        }

        const providerGuard = validateProviderGuardReceipt(
          await awaitAbortAware(options.recheckProviderGuards({
            checkpoint,
            clerkWebhookPreparationReceipt: clerkReceipt,
            workerLineageReceipt: lineageReceipt,
            reviewQuorum,
            signal: abortController.signal,
          }), abortController.signal),
          checkpoint,
          reviewQuorum,
          clerkReceipt,
          lineageReceipt,
        );
        assertOmitsSecretMaterial(providerGuard, [webhookSecret, token]);

        const result = await awaitAbortAware(options.continueCutover({
          checkpoint,
          clerkWebhookPreparationReceipt: clerkReceipt,
          workerLineageReceipt: lineageReceipt,
          reviewQuorum,
          providerGuard,
          secretMaterial: {
            clerkWebhookSigningSecret: webhookSecret,
            cutoverAcceptanceToken: token,
          },
          signal: abortController.signal,
        }), abortController.signal);
        assertOmitsSecretMaterial(result, [webhookSecret, token]);
        return result;
      } catch (error) {
        throw safeExecutionError(error);
      } finally {
        token.fill(0);
        try {
          if (sigintRegistered) signalSource.off("SIGINT", onSignal);
        } finally {
          if (sigtermRegistered) signalSource.off("SIGTERM", onSignal);
        }
      }
    }, { environment: childEnvironment });
  } catch (error) {
    throw safeExecutionError(error);
  }
}

export async function readProductionGreenfieldCutoverReviewQuorum(
  input,
  checkpoint,
  options = {},
) {
  try {
    const value = JSON.parse(await readFirstNonemptyLine(input, options.signal));
    requireExactKeys(value, ["action", "checkpoint_sha256", "reviews"]);
    if (value.action !== "continue") throw new Error("invalid action");
    if (value.checkpoint_sha256 !== checkpoint.receipt_sha256) {
      throw new Error("invalid checkpoint digest");
    }
    if (!Array.isArray(value.reviews) || value.reviews.length !== 2) {
      throw new Error("invalid review count");
    }
    const roles = new Set();
    const reviews = value.reviews.map((review) => {
      requireExactKeys(review, [
        "artifact_sha256",
        "reviewed_at_utc",
        "role",
        "verdict",
      ]);
      if (!requiredReviewRoles.includes(review.role)) {
        throw new Error("invalid review role");
      }
      if (roles.has(review.role)) throw new Error("duplicate review role");
      roles.add(review.role);
      if (review.verdict !== "NO FINDINGS") throw new Error("open review");
      if (review.artifact_sha256 !== checkpoint.receipt_sha256) {
        throw new Error("invalid artifact digest");
      }
      const reviewedAtUTC = normalizeUTCInstant(review.reviewed_at_utc);
      if (Date.parse(reviewedAtUTC) <= Date.parse(checkpoint.observed_at_utc)) {
        throw new Error("invalid review chronology");
      }
      return Object.freeze({
        role: review.role,
        verdict: review.verdict,
        artifact_sha256: review.artifact_sha256,
        reviewed_at_utc: reviewedAtUTC,
      });
    });
    if (roles.size !== requiredReviewRoles.length) {
      throw new Error("missing review role");
    }
    return Object.freeze({
      action: "continue",
      checkpoint_sha256: value.checkpoint_sha256,
      reviews: Object.freeze(reviews),
    });
  } catch (error) {
    if (controlledErrors.has(error)) throw error;
    throw controlledError(
      "Production greenfield cutover review quorum is invalid",
    );
  }
}

export async function runProductionGreenfieldCutoverCLI(options = {}) {
  const args = options.args ?? process.argv.slice(2);
  const environment = options.environment ?? process.env;
  const writeStdout = options.writeStdout
    ?? ((value) => process.stdout.write(value));
  const writeStderr = options.writeStderr
    ?? ((value) => process.stderr.write(value));
  const checkSources = options.checkSources
    ?? loadProductionGreenfieldCutoverSources;
  const execute = options.execute
    ?? (() => executeProductionGreenfieldCutover({
      environment,
      input: options.input ?? process.stdin,
      emitCheckpoint: writeStdout,
    }));

  if (args.length === 1 && args[0] === "--check") {
    try {
      await checkSources();
      writeStdout("Production greenfield cutover sources verified.\n");
      return 0;
    } catch {
      writeStderr("Production greenfield cutover source check failed.\n");
      return 1;
    }
  }
  if (args.length !== 1 || args[0] !== "--execute") {
    writeStderr(
      "Usage: node scripts/execute-production-greenfield-cutover.mjs --check|--execute\n",
    );
    return 2;
  }
  if (environment[productionGreenfieldCutoverGate] !== "1") {
    writeStderr("Production greenfield cutover technical gate is closed.\n");
    return 2;
  }
  try {
    await execute();
    return 0;
  } catch {
    writeStderr("Production greenfield cutover execution failed.\n");
    return 1;
  }
}

function createCheckpoint({
  clerkReceipt,
  lineageReceipt,
  sourceContractSha256,
  observedAtUTC,
}) {
  if (!clerkReceipt || typeof clerkReceipt !== "object") {
    throw genericExecutionError();
  }
  if (!lineageReceipt || typeof lineageReceipt !== "object") {
    throw genericExecutionError();
  }
  const clerkReceiptSha256 = requireSHA256(clerkReceipt.receipt_sha256);
  const lineageReceiptSha256 = requireSHA256(lineageReceipt.receipt_sha256);
  if (
    lineageReceipt.secret_installation
      ?.clerk_webhook_preparation_receipt_sha256 !== clerkReceiptSha256
  ) throw genericExecutionError();
  const payload = {
    receipt_type: checkpointReceiptType,
    status: "awaiting_post_lineage_reviews",
    observed_at_utc: observedAtUTC,
    source_contract_sha256: requireSHA256(sourceContractSha256),
    crash_classification: productionGreenfieldCutoverCrashClassification,
    clerk_webhook_preparation_receipt_sha256: clerkReceiptSha256,
    worker_lineage_receipt_sha256: lineageReceiptSha256,
    clerk_webhook_preparation: clerkReceipt,
    worker_lineage: lineageReceipt,
  };
  return Object.freeze({
    ...payload,
    receipt_sha256: computeSanitizedReceiptSha256(payload),
  });
}

function validateProviderGuardReceipt(
  value,
  checkpoint,
  reviewQuorum,
  clerkReceipt,
  lineageReceipt,
) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw genericExecutionError();
  }
  requireExactKeys(value, [
    "schema_version",
    "receipt_type",
    "status",
    "observed_at_utc",
    "checkpoint_sha256",
    "clerk_webhook_preparation_receipt_sha256",
    "worker_lineage_receipt_sha256",
    "clerk_guard",
    "worker_guard",
    "receipt_sha256",
  ]);
  if (
    value.schema_version !== 1
    || value.receipt_type !== providerGuardReceiptType
    || value.status !== "passed"
    || value.checkpoint_sha256 !== checkpoint.receipt_sha256
    || value.clerk_webhook_preparation_receipt_sha256
      !== clerkReceipt.receipt_sha256
    || value.worker_lineage_receipt_sha256 !== lineageReceipt.receipt_sha256
    || checkpoint.clerk_webhook_preparation_receipt_sha256
      !== clerkReceipt.receipt_sha256
    || checkpoint.worker_lineage_receipt_sha256 !== lineageReceipt.receipt_sha256
  ) throw genericExecutionError();
  const observedAtUTC = normalizeUTCInstant(value.observed_at_utc);
  const latestReviewTime = Math.max(...reviewQuorum.reviews.map(
    (review) => Date.parse(review.reviewed_at_utc),
  ));
  if (Date.parse(observedAtUTC) <= latestReviewTime) throw genericExecutionError();

  requireExactKeys(value.clerk_guard, [
    "observed_at_utc",
    "clerk_application_id",
    "clerk_instance_id",
    "user_count",
    "svix_application_id",
    "endpoint_inventory_count",
    "endpoint_id",
    "endpoint_uid",
    "endpoint_url",
    "endpoint_description",
    "event_types",
    "disabled",
    "header_count",
    "sensitive_header_name_count",
    "transformation_enabled",
    "transformation_present",
  ]);
  requireExactKeys(clerkReceipt.final_provider_readback, [
    "svix_application_id",
    "endpoint_inventory_count",
    "endpoint_id",
    "endpoint_uid",
    "endpoint_url",
    "endpoint_description",
    "event_types",
    "disabled",
    "header_count",
    "sensitive_header_name_count",
    "transformation_enabled",
    "transformation_present",
  ]);
  const finalProviderReadback = clerkReceipt.final_provider_readback;
  const clerkObservedAtUTC = normalizeUTCInstant(
    value.clerk_guard.observed_at_utc,
  );
  if (
    Date.parse(clerkObservedAtUTC) <= latestReviewTime
    || Date.parse(clerkObservedAtUTC) > Date.parse(observedAtUTC)
    || value.clerk_guard.clerk_application_id
      !== productionClerkWebhookTarget.clerkApplicationId
    || value.clerk_guard.clerk_application_id
      !== clerkReceipt.clerk.application_id
    || value.clerk_guard.clerk_instance_id
      !== productionClerkWebhookTarget.clerkInstanceId
    || value.clerk_guard.clerk_instance_id !== clerkReceipt.clerk.instance_id
    || value.clerk_guard.user_count !== 0
    || clerkReceipt.clerk.user_count !== 0
    || value.clerk_guard.svix_application_id
      !== clerkReceipt.svix.application_id
    || value.clerk_guard.svix_application_id
      !== finalProviderReadback.svix_application_id
    || finalProviderReadback.svix_application_id
      !== clerkReceipt.svix.application_id
    || value.clerk_guard.endpoint_inventory_count !== 1
    || finalProviderReadback.endpoint_inventory_count !== 1
    || value.clerk_guard.endpoint_id !== clerkReceipt.svix.endpoint_id
    || value.clerk_guard.endpoint_id !== finalProviderReadback.endpoint_id
    || finalProviderReadback.endpoint_id !== clerkReceipt.svix.endpoint_id
    || value.clerk_guard.endpoint_uid
      !== productionClerkWebhookTarget.endpointUid
    || value.clerk_guard.endpoint_uid !== clerkReceipt.svix.endpoint_uid
    || value.clerk_guard.endpoint_uid !== finalProviderReadback.endpoint_uid
    || finalProviderReadback.endpoint_uid !== clerkReceipt.svix.endpoint_uid
    || value.clerk_guard.endpoint_url
      !== productionClerkWebhookTarget.endpointURL
    || value.clerk_guard.endpoint_url !== clerkReceipt.svix.endpoint_url
    || value.clerk_guard.endpoint_url !== finalProviderReadback.endpoint_url
    || finalProviderReadback.endpoint_url !== clerkReceipt.svix.endpoint_url
    || value.clerk_guard.endpoint_description
      !== productionClerkWebhookTarget.endpointDescription
    || value.clerk_guard.endpoint_description
      !== clerkReceipt.svix.endpoint_description
    || value.clerk_guard.endpoint_description
      !== finalProviderReadback.endpoint_description
    || finalProviderReadback.endpoint_description
      !== clerkReceipt.svix.endpoint_description
    || canonicalSanitizedJSON(value.clerk_guard.event_types)
      !== canonicalSanitizedJSON(productionClerkWebhookTarget.eventTypes)
    || canonicalSanitizedJSON(value.clerk_guard.event_types)
      !== canonicalSanitizedJSON(clerkReceipt.svix.event_types)
    || canonicalSanitizedJSON(value.clerk_guard.event_types)
      !== canonicalSanitizedJSON(finalProviderReadback.event_types)
    || canonicalSanitizedJSON(finalProviderReadback.event_types)
      !== canonicalSanitizedJSON(clerkReceipt.svix.event_types)
    || value.clerk_guard.disabled !== true
    || clerkReceipt.svix.disabled !== true
    || finalProviderReadback.disabled !== true
    || value.clerk_guard.header_count !== 0
    || clerkReceipt.svix.header_count !== 0
    || finalProviderReadback.header_count !== 0
    || value.clerk_guard.sensitive_header_name_count !== 0
    || clerkReceipt.svix.sensitive_header_name_count !== 0
    || finalProviderReadback.sensitive_header_name_count !== 0
    || value.clerk_guard.transformation_enabled !== false
    || clerkReceipt.svix.transformation_enabled !== false
    || finalProviderReadback.transformation_enabled !== false
    || value.clerk_guard.transformation_present !== false
    || clerkReceipt.svix.transformation_present !== false
    || finalProviderReadback.transformation_present !== false
  ) throw genericExecutionError();

  requireExactKeys(value.worker_guard, [
    "observed_at_utc",
    "deployment_id",
    "sole_worker_version_id",
    "deployment_version_count",
    "sole_traffic_percentage",
    "secret_names",
    "secret_count",
    "route_mutation_count",
    "access_mutation_count",
  ]);
  const workerObservedAtUTC = normalizeUTCInstant(
    value.worker_guard.observed_at_utc,
  );
  const expectedLastKnownGoodVersionId =
    lineageReceipt.version_readbacks.last_known_good_l.worker_version_id;
  const expectedDeploymentId = lineageReceipt.deployment_guard.deployment_id;
  if (
    Date.parse(workerObservedAtUTC) <= latestReviewTime
    || Date.parse(workerObservedAtUTC) > Date.parse(observedAtUTC)
    || !uuidPattern.test(value.worker_guard.deployment_id)
    || value.worker_guard.deployment_id !== expectedDeploymentId
    || !uuidPattern.test(value.worker_guard.sole_worker_version_id)
    || value.worker_guard.sole_worker_version_id
      !== expectedLastKnownGoodVersionId
    || value.worker_guard.sole_worker_version_id
      !== lineageReceipt.deployment_guard.worker_version_id
    || value.worker_guard.deployment_version_count !== 1
    || value.worker_guard.sole_traffic_percentage !== 100
    || canonicalSanitizedJSON(value.worker_guard.secret_names)
      !== canonicalSanitizedJSON(productionWorkerSecretNames)
    || canonicalSanitizedJSON(value.worker_guard.secret_names)
      !== canonicalSanitizedJSON(
        lineageReceipt.secret_installation.final_secret_names,
      )
    || value.worker_guard.secret_count !== productionWorkerSecretNames.length
    || value.worker_guard.route_mutation_count !== 0
    || value.worker_guard.access_mutation_count !== 0
  ) throw genericExecutionError();

  requireSHA256(value.receipt_sha256);
  const payload = Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== "receipt_sha256"),
  );
  if (computeSanitizedReceiptSha256(payload) !== value.receipt_sha256) {
    throw genericExecutionError();
  }
  return Object.freeze(value);
}

async function readFirstNonemptyLine(input, signal) {
  if (!input || typeof input[Symbol.asyncIterator] !== "function") {
    throw new Error("invalid review input");
  }
  const iterator = input[Symbol.asyncIterator]();
  if (!iterator || typeof iterator.next !== "function") {
    throw new Error("invalid review iterator");
  }
  let abortListener;
  let abortPromise;
  if (signal) {
    if (signal.aborted) {
      closeAsyncIterator(iterator);
      throw controlledError("Production greenfield cutover interrupted");
    }
    abortPromise = new Promise((_, rejectPromise) => {
      abortListener = () => rejectPromise(controlledError(
        "Production greenfield cutover interrupted",
      ));
      signal.addEventListener("abort", abortListener, { once: true });
    });
  }
  let pending = "";
  try {
    while (true) {
      const next = Promise.resolve().then(() => iterator.next());
      const step = abortPromise
        ? await Promise.race([next, abortPromise])
        : await next;
      if (!step || typeof step !== "object" || typeof step.done !== "boolean") {
        throw new Error("invalid review iterator result");
      }
      if (step.done) break;
      const chunk = step.value;
      if (chunk instanceof Uint8Array) {
        pending += Buffer.from(
          chunk.buffer,
          chunk.byteOffset,
          chunk.byteLength,
        ).toString("utf8");
      } else {
        pending += String(chunk);
      }
      if (Buffer.byteLength(pending, "utf8") > MAX_REVIEW_LINE_BYTES) {
        throw new Error("review input too large");
      }
      let newline;
      while ((newline = pending.indexOf("\n")) !== -1) {
        const line = pending.slice(0, newline).replace(/\r$/u, "");
        pending = pending.slice(newline + 1);
        if (line.trim().length > 0) return line;
      }
    }
    const finalLine = pending.trim();
    if (finalLine.length > 0) return finalLine;
    throw new Error("missing review input");
  } finally {
    if (signal && abortListener) {
      signal.removeEventListener("abort", abortListener);
    }
    closeAsyncIterator(iterator);
  }
}

function closeAsyncIterator(iterator) {
  if (typeof iterator.return !== "function") return;
  try {
    Promise.resolve(iterator.return()).catch(() => {});
  } catch {
    // Cleanup is best-effort and must never replace the sanitized root error.
  }
}

function assertOmitsSecretMaterial(value, secrets) {
  if (containsSecretMaterial(value, secrets, new WeakSet())) {
    throw genericExecutionError();
  }
}

function containsSecretMaterial(value, secrets, seen) {
  if (typeof value === "string") {
    const bytes = Buffer.from(value, "utf8");
    try {
      return secrets.some((secret) => secret.length > 0 && bytes.includes(secret));
    } finally {
      bytes.fill(0);
    }
  }
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    const bytes = Buffer.from(value.buffer, value.byteOffset, value.byteLength);
    return secrets.some((secret) => secret.length > 0 && bytes.includes(secret));
  }
  if (!value || typeof value !== "object") return false;
  if (seen.has(value)) throw genericExecutionError();
  seen.add(value);
  try {
    return Object.values(value).some((entry) =>
      containsSecretMaterial(entry, secrets, seen));
  } finally {
    seen.delete(value);
  }
}

function sanitizedDigest(value) {
  try {
    return computeSanitizedReceiptSha256(value);
  } catch {
    throw genericExecutionError();
  }
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function countOccurrences(value, pattern) {
  let count = 0;
  let offset = 0;
  while (true) {
    const found = value.indexOf(pattern, offset);
    if (found === -1) return count;
    count += 1;
    offset = found + pattern.length;
  }
}

function requireSHA256(value) {
  if (typeof value !== "string" || !sha256Pattern.test(value)) {
    throw genericExecutionError();
  }
  return value;
}

function requirePositiveInteger(value) {
  if (!Number.isSafeInteger(value) || value <= 0) throw genericExecutionError();
  return value;
}

function normalizeUTCInstant(value) {
  const date = value instanceof Date ? value : new Date(value);
  const result = date.toISOString();
  if (!utcInstantPattern.test(result)) throw genericExecutionError();
  if (typeof value === "string" && value !== result) throw genericExecutionError();
  return result;
}

function requireExactKeys(value, expected) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid object");
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (canonicalSanitizedJSON(actual) !== canonicalSanitizedJSON(wanted)) {
    throw new Error("invalid keys");
  }
}

async function awaitAbortAware(promise, signal) {
  try {
    const value = await promise;
    if (signal.aborted) {
      throw controlledError("Production greenfield cutover interrupted");
    }
    return value;
  } catch (error) {
    if (signal.aborted) {
      throw controlledError("Production greenfield cutover interrupted");
    }
    throw safeExecutionError(error);
  }
}

function safeExecutionError(error) {
  if (error instanceof Error && controlledErrors.has(error)) return error;
  return genericExecutionError();
}

function controlledError(message) {
  const error = new Error(message);
  controlledErrors.add(error);
  return error;
}

function genericExecutionError() {
  return new Error("Production greenfield cutover execution failed");
}

if (
  process.argv[1]
  && resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  process.exitCode = await runProductionGreenfieldCutoverCLI();
}
