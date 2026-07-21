import { EventEmitter } from "node:events";
import { readFile } from "node:fs/promises";
import { Readable } from "node:stream";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { productionWorkerSecretNames } from "../scripts/greenfield-launch-packet.mjs";
import { productionClerkWebhookTarget } from "../scripts/prepare-production-clerk-webhook.mjs";

const receiptValidators = vi.hoisted(() => ({
  clerk: vi.fn((value: unknown) => value),
  lineage: vi.fn((value: unknown) => value),
}));

vi.mock("../scripts/prepare-production-clerk-webhook.mjs", async (importOriginal) => ({
  ...await importOriginal<typeof import("../scripts/prepare-production-clerk-webhook.mjs")>(),
  validateProductionClerkWebhookPreparationReceipt: receiptValidators.clerk,
}));

vi.mock("../scripts/prepare-production-greenfield-worker-lineage.mjs", async (importOriginal) => ({
  ...await importOriginal<typeof import("../scripts/prepare-production-greenfield-worker-lineage.mjs")>(),
  validateProductionGreenfieldWorkerLineageReceipt: receiptValidators.lineage,
}));

import {
  executeProductionGreenfieldCutover,
  generateProductionGreenfieldCutoverToken,
  normalizeProductionGreenfieldWorkerLineageSource,
  productionGreenfieldCutoverGate,
  runProductionGreenfieldCutoverCLI,
  validateProductionGreenfieldCutoverLineageSources,
} from "../scripts/execute-production-greenfield-cutover.mjs";
import { computeSanitizedReceiptSha256 } from "../scripts/greenfield-launch-packet.mjs";

const clerkReceiptSha256 = "1".repeat(64);
const lineageReceiptSha256 = "2".repeat(64);
const checkpointTime = "2026-07-21T08:00:00.000Z";
const reviewTimeA = "2026-07-21T08:01:00.000Z";
const reviewTimeB = "2026-07-21T08:02:00.000Z";
const guardTime = "2026-07-21T08:03:00.000Z";
const clerkGuardTime = "2026-07-21T08:02:30.000Z";
const workerGuardTime = "2026-07-21T08:02:40.000Z";
const lastKnownGoodVersionId = "e966d6df-b5ff-4288-832c-c8d91e00ce48";
const lastKnownGoodDeploymentId = "89cff719-0e19-4648-ab09-63a37d806c95";
const webhookSecretText = `${["wh", "sec_"].join("")}test-only-cutover-secret-123456789`;

describe("production greenfield cutover orchestrator", () => {
  beforeEach(() => {
    receiptValidators.clerk.mockClear();
    receiptValidators.lineage.mockClear();
  });
  it("is default-closed before any source or provider callback", async () => {
    const loadSources = vi.fn();
    const withClerkWebhookSecret = vi.fn();

    await expect(executeProductionGreenfieldCutover({
      environment: {},
      loadSources,
      withClerkWebhookSecret,
      recheckProviderGuards: vi.fn(),
      continueCutover: vi.fn(),
    })).rejects.toThrow("gate is closed");
    expect(loadSources).not.toHaveBeenCalled();
    expect(withClerkWebhookSecret).not.toHaveBeenCalled();

    await expect(executeProductionGreenfieldCutover({
      environment: { [productionGreenfieldCutoverGate]: "1" },
      loadSources,
      withClerkWebhookSecret,
    })).rejects.toThrow("continuation is not configured");
    expect(loadSources).not.toHaveBeenCalled();
    expect(withClerkWebhookSecret).not.toHaveBeenCalled();
  });

  it("keeps --check source-only and non-mutating", async () => {
    const checkSources = vi.fn(async () => ({ source: "checked" }));
    const execute = vi.fn();
    const stdout: string[] = [];
    const stderr: string[] = [];

    expect(await runProductionGreenfieldCutoverCLI({
      args: ["--check"],
      environment: {},
      checkSources,
      execute,
      writeStdout: (value) => stdout.push(value),
      writeStderr: (value) => stderr.push(value),
    })).toBe(0);
    expect(checkSources).toHaveBeenCalledOnce();
    expect(execute).not.toHaveBeenCalled();
    expect(stdout).toEqual(["Production greenfield cutover sources verified.\n"]);
    expect(stderr).toEqual([]);
  });

  it("normalizes only the exact lineage pin block and hard-pins executable logic", async () => {
    const helper = await readFile(new URL(
      "../scripts/prepare-production-greenfield-worker-lineage.mjs",
      import.meta.url,
    ));
    const declaration = await readFile(new URL(
      "../scripts/prepare-production-greenfield-worker-lineage.d.mts",
      import.meta.url,
    ));
    const normalized = normalizeProductionGreenfieldWorkerLineageSource(helper);
    const normalizedText = normalized.toString("utf8");
    expect(normalizedText.match(
      /\/\* refwatch-lineage-reviewed-source-pins:normalized-v1 \*\//gu,
    )).toHaveLength(1);
    expect(normalizedText).not.toContain(
      "// refwatch-lineage-reviewed-source-pins:start",
    );
    expect(normalizedText).not.toContain(
      "// refwatch-lineage-reviewed-source-pins:end",
    );
    expect(() => validateProductionGreenfieldCutoverLineageSources({
      helper,
      declaration,
    })).not.toThrow();

    const metadataOnlyDrift = helper.toString("utf8").replace(
      /(const reviewedSourceManifestSha256 =\n  ")[0-9a-f]{64}(";)/u,
      `$1${"0".repeat(64)}$2`,
    );
    expect(normalizeProductionGreenfieldWorkerLineageSource(metadataOnlyDrift)
      .equals(normalized)).toBe(true);
    expect(() => validateProductionGreenfieldCutoverLineageSources({
      helper: metadataOnlyDrift,
      declaration,
    })).not.toThrow();

    expect(() => validateProductionGreenfieldCutoverLineageSources({
      helper: Buffer.concat([helper, Buffer.from("\nvoid 0;\n")]),
      declaration,
    })).toThrow("reviewed lineage source drifted");
    expect(() => validateProductionGreenfieldCutoverLineageSources({
      helper,
      declaration: Buffer.concat([declaration, Buffer.from("\n")]),
    })).toThrow("reviewed lineage source drifted");

    const injectedInsidePins = helper.toString("utf8").replace(
      "// refwatch-lineage-reviewed-source-pins:end",
      "void 0;\n// refwatch-lineage-reviewed-source-pins:end",
    );
    expect(() => normalizeProductionGreenfieldWorkerLineageSource(
      injectedInsidePins,
    )).toThrow("pin block is invalid");
    expect(() => normalizeProductionGreenfieldWorkerLineageSource(
      `${helper.toString("utf8")}\n// refwatch-lineage-reviewed-source-pins:start`,
    )).toThrow("pin block is invalid");
  });

  it("requires exact --execute and the outer technical gate", async () => {
    const execute = vi.fn();
    const stderr: string[] = [];

    expect(await runProductionGreenfieldCutoverCLI({
      args: ["--execute"],
      environment: {},
      execute,
      writeStderr: (value) => stderr.push(value),
    })).toBe(2);
    expect(execute).not.toHaveBeenCalled();
    expect(stderr).toEqual([
      "Production greenfield cutover technical gate is closed.\n",
    ]);
  });

  it("encodes 256 bits directly as lowercase hex and wipes entropy", () => {
    const entropy = Buffer.from(Array.from({ length: 32 }, (_, index) => index));
    const token = generateProductionGreenfieldCutoverToken({
      randomBytes: () => entropy,
    });

    expect(token).toHaveLength(64);
    expect(token.toString("ascii")).toMatch(/^[0-9a-f]{64}$/u);
    expect(token.toString("ascii")).toBe(
      "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    );
    expect(entropy.equals(Buffer.alloc(32))).toBe(true);
  });

  it("retains callback-scoped credentials through review, then wipes them", async () => {
    const order: string[] = [];
    const emitted: string[] = [];
    let checkpoint: any;
    let tokenReference: Buffer | undefined;
    const webhookReference = Buffer.from(webhookSecretText);
    const source = { contract: "stable", digest: "a".repeat(64) };
    const input = reviewInput(() => checkpoint);

    const result = await executeProductionGreenfieldCutover({
      environment: { [productionGreenfieldCutoverGate]: "1" },
      loadSources: vi.fn(async () => {
        order.push(order.includes("sources_initial") ? "sources_recheck" : "sources_initial");
        return source;
      }),
      withClerkWebhookSecret: async (consumer, options) => {
        order.push("clerk");
        expect(options?.environment).toMatchObject({
          REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER: "1",
          REFWATCH_ALLOW_PRODUCTION_CLERK_WEBHOOK_PREPARATION: "1",
          REFWATCH_ALLOW_PRODUCTION_GREENFIELD_WORKER_LINEAGE: "1",
        });
        try {
          return await consumer({
            secretMaterial: webhookReference,
            receipt: fakeClerkReceipt(),
            controller: fakeClerkController(),
          });
        } finally {
          webhookReference.fill(0);
        }
      },
      withLineageLease: async (consumer, options) => {
        order.push("lineage_lease");
        expect(options?.environment).toMatchObject({
          REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER: "1",
          REFWATCH_ALLOW_PRODUCTION_CLERK_WEBHOOK_PREPARATION: "1",
          REFWATCH_ALLOW_PRODUCTION_GREENFIELD_WORKER_LINEAGE: "1",
        });
        return consumer(async (lineageOptions) => {
          order.push("lineage");
          expect(lineageOptions.clerkWebhookPreparationReceipt)
            .toEqual(fakeClerkReceipt());
          expect(lineageOptions.secretMaterial.clerkWebhookSigningSecret)
            .toBe(webhookReference);
          tokenReference = lineageOptions.secretMaterial.cutoverAcceptanceToken as Buffer;
          expect(tokenReference).toHaveLength(64);
          expect(tokenReference.toString("ascii")).toMatch(/^[0-9a-f]{64}$/u);
          return fakeLineageReceipt();
        });
      },
      emitCheckpoint: (value) => {
        order.push("checkpoint");
        emitted.push(value);
        checkpoint = JSON.parse(value);
      },
      input,
      recheckProviderGuards: async ({ checkpoint: received }) => {
        order.push("provider_guard");
        expect(received.receipt_sha256).toBe(checkpoint.receipt_sha256);
        return fakeProviderGuard(checkpoint.receipt_sha256);
      },
      continueCutover: async ({ secretMaterial, reviewQuorum, providerGuard }) => {
        order.push("continue");
        expect(secretMaterial.clerkWebhookSigningSecret).toBe(webhookReference);
        expect(secretMaterial.cutoverAcceptanceToken).toBe(tokenReference);
        expect(tokenReference?.toString("ascii")).toMatch(/^[0-9a-f]{64}$/u);
        expect(reviewQuorum.reviews).toHaveLength(2);
        expect(providerGuard.status).toBe("passed");
        return { status: "continued" };
      },
      randomBytes: () => Buffer.alloc(32, 0xab),
      now: () => new Date(checkpointTime),
    });

    expect(result).toEqual({ status: "continued" });
    expect(order).toEqual([
      "sources_initial",
      "clerk",
      "lineage_lease",
      "lineage",
      "checkpoint",
      "sources_recheck",
      "provider_guard",
      "continue",
    ]);
    expect(emitted).toHaveLength(1);
    expect(emitted[0]?.split("\n").filter(Boolean)).toHaveLength(1);
    expect(emitted[0]).not.toContain(webhookSecretText);
    expect(emitted[0]).not.toContain("ab".repeat(32));
    expect(checkpoint.crash_classification).toEqual({
      phase: "post_lineage_before_bounded_acceptance",
      resumability: "non_resumable",
      required_recovery: "reviewed_relineage_with_new_cutover_token",
      reason: "memory_only_cutover_token_is_not_provider_readable",
    });
    expect(tokenReference?.equals(Buffer.alloc(64))).toBe(true);
    expect(webhookReference.equals(Buffer.alloc(webhookReference.length))).toBe(true);
    expect(receiptValidators.clerk).toHaveBeenCalledWith(fakeClerkReceipt());
    expect(receiptValidators.lineage).toHaveBeenCalledWith(fakeLineageReceipt());
  });

  it.each([
    ["duplicate roles", (value: any) => {
      value.reviews[1].role = value.reviews[0].role;
    }],
    ["non-exact verdict", (value: any) => {
      value.reviews[0].verdict = "No findings";
    }],
    ["wrong digest", (value: any) => {
      value.reviews[1].artifact_sha256 = "f".repeat(64);
    }],
    ["stale timestamp", (value: any) => {
      value.reviews[0].reviewed_at_utc = checkpointTime;
    }],
  ])("rejects invalid review quorum: %s", async (_label, mutate) => {
    const tokenReferences: Buffer[] = [];
    const providerGuard = vi.fn();
    const continueCutover = vi.fn();
    let checkpoint: any;

    await expect(executeProductionGreenfieldCutover({
      ...baseOptions({
        emitCheckpoint: (value: string) => {
          checkpoint = JSON.parse(value);
        },
        input: reviewInput(() => checkpoint, mutate),
        captureToken: (value: Buffer) => tokenReferences.push(value),
        recheckProviderGuards: providerGuard,
        continueCutover,
      }),
    })).rejects.toThrow("review quorum is invalid");
    expect(providerGuard).not.toHaveBeenCalled();
    expect(continueCutover).not.toHaveBeenCalled();
    expect(tokenReferences[0]?.equals(Buffer.alloc(64))).toBe(true);
  });

  it.each([
    "orchestrator_sha256",
    "declaration_sha256",
    "clerk_helper_sha256",
    "clerk_helper_declaration_sha256",
    "worker_lineage_helper_normalized_sha256",
    "worker_lineage_helper_declaration_sha256",
  ])("aborts when reviewed source field %s drifts", async (driftedField) => {
    let sourceRead = 0;
    let checkpoint: any;
    let tokenReference: Buffer | undefined;
    const providerGuard = vi.fn();
    const continueCutover = vi.fn();

    await expect(executeProductionGreenfieldCutover({
      ...baseOptions({
        loadSources: async () => ({
          source_contract: "stable",
          [driftedField]: (++sourceRead === 1 ? "a" : "b").repeat(64),
        }),
        emitCheckpoint: (value: string) => {
          checkpoint = JSON.parse(value);
        },
        input: reviewInput(() => checkpoint),
        captureToken: (value: Buffer) => {
          tokenReference = value;
        },
        recheckProviderGuards: providerGuard,
        continueCutover,
      }),
    })).rejects.toThrow("source drift detected");
    expect(providerGuard).not.toHaveBeenCalled();
    expect(continueCutover).not.toHaveBeenCalled();
    expect(tokenReference?.equals(Buffer.alloc(64))).toBe(true);
  });

  it.each([
    ["active Clerk endpoint", (value: any) => {
      value.clerk_guard.disabled = false;
    }],
    ["nonzero Clerk users", (value: any) => {
      value.clerk_guard.user_count = 1;
    }],
    ["wrong Clerk application binding", (value: any) => {
      value.clerk_guard.clerk_application_id = "app_other123";
    }],
    ["wrong Clerk instance binding", (value: any) => {
      value.clerk_guard.clerk_instance_id = "ins_other123";
    }],
    ["duplicate Clerk endpoint inventory", (value: any) => {
      value.clerk_guard.endpoint_inventory_count = 2;
    }],
    ["wrong Svix application binding", (value: any) => {
      value.clerk_guard.svix_application_id = "app_svixOther123";
    }],
    ["wrong endpoint binding", (value: any) => {
      value.clerk_guard.endpoint_id = "ep_other123";
    }],
    ["wrong endpoint UID binding", (value: any) => {
      value.clerk_guard.endpoint_uid = "refwatch-other-endpoint";
    }],
    ["wrong endpoint description", (value: any) => {
      value.clerk_guard.endpoint_description = "Other webhook";
    }],
    ["unexpected endpoint header", (value: any) => {
      value.clerk_guard.header_count = 1;
    }],
    ["unexpected sensitive endpoint header", (value: any) => {
      value.clerk_guard.sensitive_header_name_count = 1;
    }],
    ["enabled endpoint transformation", (value: any) => {
      value.clerk_guard.transformation_enabled = true;
    }],
    ["present endpoint transformation", (value: any) => {
      value.clerk_guard.transformation_present = true;
    }],
    ["non-L sole traffic", (value: any) => {
      value.worker_guard.sole_worker_version_id =
        "12121212-1212-4121-8121-121212121212";
    }],
    ["incomplete secret inventory", (value: any) => {
      value.worker_guard.secret_names = value.worker_guard.secret_names.slice(1);
      value.worker_guard.secret_count -= 1;
    }],
    ["route mutation", (value: any) => {
      value.worker_guard.route_mutation_count = 1;
    }],
    ["Access mutation", (value: any) => {
      value.worker_guard.access_mutation_count = 1;
    }],
    ["wrong lineage binding", (value: any) => {
      value.worker_lineage_receipt_sha256 = "f".repeat(64);
    }],
  ])("rejects forged post-review provider guard: %s", async (_label, mutate) => {
    let checkpoint: any;
    let tokenReference: Buffer | undefined;
    const continueCutover = vi.fn();

    await expect(executeProductionGreenfieldCutover({
      ...baseOptions({
        emitCheckpoint: (value: string) => {
          checkpoint = JSON.parse(value);
        },
        input: reviewInput(() => checkpoint),
        captureToken: (value: Buffer) => {
          tokenReference = value;
        },
        recheckProviderGuards: async ({ checkpoint: received }: any) =>
          mutateAndResealGuard(
            fakeProviderGuard(received.receipt_sha256),
            mutate,
          ),
        continueCutover,
      }),
    })).rejects.toThrow("execution failed");
    expect(continueCutover).not.toHaveBeenCalled();
    expect(tokenReference?.equals(Buffer.alloc(64))).toBe(true);
  });

  it("binds the provider guard to the preparation receipt final readback", async () => {
    const clerkReceipt = fakeClerkReceipt();
    clerkReceipt.final_provider_readback.endpoint_id = "ep_other123";
    let checkpoint: any;
    const continueCutover = vi.fn();

    await expect(executeProductionGreenfieldCutover({
      ...baseOptions({
        clerkReceipt,
        emitCheckpoint: (value: string) => {
          checkpoint = JSON.parse(value);
        },
        input: reviewInput(() => checkpoint),
        continueCutover,
      }),
    })).rejects.toThrow("execution failed");
    expect(continueCutover).not.toHaveBeenCalled();
  });

  it("keeps raw injected callback errors generic", async () => {
    let checkpoint: any;

    await expect(executeProductionGreenfieldCutover({
      ...baseOptions({
        emitCheckpoint: (value: string) => {
          checkpoint = JSON.parse(value);
        },
        input: reviewInput(() => checkpoint),
        continueCutover: async () => {
          throw new Error("Production greenfield cutover source drift detected");
        },
      }),
    })).rejects.toThrow("Production greenfield cutover execution failed");
  });

  it("interrupts and closes a review iterator that never yields", async () => {
    const signalSource = new EventEmitter();
    const iterator = neverYieldingReviewInput();
    let tokenReference: Buffer | undefined;
    let checkpointEmittedResolve!: () => void;
    const checkpointEmitted = new Promise<void>((resolvePromise) => {
      checkpointEmittedResolve = resolvePromise;
    });

    const execution = executeProductionGreenfieldCutover({
      ...baseOptions({
        signalSource,
        input: iterator.input,
        emitCheckpoint: () => checkpointEmittedResolve(),
        captureToken: (value: Buffer) => {
          tokenReference = value;
        },
      }),
    });
    await checkpointEmitted;
    await iterator.started;
    signalSource.emit("SIGINT");

    await expect(Promise.race([
      execution,
      new Promise((_, rejectPromise) => setTimeout(
        () => rejectPromise(new Error("interrupt did not settle")),
        250,
      )),
    ])).rejects.toThrow("interrupted");
    expect(iterator.next).toHaveBeenCalledOnce();
    expect(iterator.close).toHaveBeenCalledOnce();
    expect(signalSource.listenerCount("SIGINT")).toBe(0);
    expect(signalSource.listenerCount("SIGTERM")).toBe(0);
    expect(tokenReference?.equals(Buffer.alloc(64))).toBe(true);
  });

  it("rejects a secret-bearing receipt without emitting it", async () => {
    const emitted = vi.fn();
    let tokenReference: Buffer | undefined;

    await expect(executeProductionGreenfieldCutover({
      ...baseOptions({
        emitCheckpoint: emitted,
        executeLineage: async (options: any) => {
          tokenReference = options.secretMaterial.cutoverAcceptanceToken as Buffer;
          return {
            ...fakeLineageReceipt(),
            leaked_value: tokenReference.toString("ascii"),
          };
        },
      }),
    })).rejects.toThrow("execution failed");
    expect(emitted).not.toHaveBeenCalled();
    expect(tokenReference?.equals(Buffer.alloc(64))).toBe(true);
  });

  it("wipes credentials immediately when interrupted", async () => {
    const signalSource = new EventEmitter();
    let checkpoint: any;
    let tokenReference: Buffer | undefined;
    const webhookReference = Buffer.from(webhookSecretText);

    await expect(executeProductionGreenfieldCutover({
      ...baseOptions({
        signalSource,
        webhookReference,
        emitCheckpoint: (value: string) => {
          checkpoint = JSON.parse(value);
        },
        input: reviewInput(() => checkpoint),
        captureToken: (value: Buffer) => {
          tokenReference = value;
        },
        continueCutover: async () => {
          signalSource.emit("SIGTERM");
          await Promise.resolve();
          return { status: "must-not-return" };
        },
      }),
    })).rejects.toThrow("interrupted");
    expect(tokenReference?.equals(Buffer.alloc(64))).toBe(true);
    expect(webhookReference.equals(Buffer.alloc(webhookReference.length))).toBe(true);
  });
});

function baseOptions(overrides: Record<string, unknown> = {}): any {
  const source = { contract: "stable", digest: "a".repeat(64) };
  const webhookReference = (overrides.webhookReference as Buffer | undefined)
    ?? Buffer.from(webhookSecretText);
  const clerkReceipt = (overrides.clerkReceipt as ReturnType<
    typeof fakeClerkReceipt
  > | undefined) ?? fakeClerkReceipt();
  const captureToken = overrides.captureToken as ((value: Buffer) => void) | undefined;
  const loadSources = (overrides.loadSources as (() => Promise<unknown>) | undefined)
    ?? (async () => source);
  const executeLineage = overrides.executeLineage as ((value: any) => Promise<any>)
    | undefined;
  const withLineageLease = overrides.withLineageLease as ((
    consumer: (execute: (value: any) => Promise<any>) => Promise<any>,
    options?: { environment?: NodeJS.ProcessEnv },
  ) => Promise<any>) | undefined;
  return {
    environment: { [productionGreenfieldCutoverGate]: "1" },
    loadSources,
    withClerkWebhookSecret: async (consumer: any) => {
      try {
        return await consumer({
          secretMaterial: webhookReference,
          receipt: clerkReceipt,
          controller: fakeClerkController(),
        });
      } finally {
        webhookReference.fill(0);
      }
    },
    withLineageLease: withLineageLease ?? (async (consumer: any) => consumer(
      executeLineage ?? (async (options: any) => {
        captureToken?.(options.secretMaterial.cutoverAcceptanceToken);
        return fakeLineageReceipt();
      }),
    )),
    emitCheckpoint: overrides.emitCheckpoint ?? vi.fn(),
    input: overrides.input ?? Readable.from([]),
    recheckProviderGuards: overrides.recheckProviderGuards
      ?? (async ({ checkpoint }: any) => fakeProviderGuard(checkpoint.receipt_sha256)),
    continueCutover: overrides.continueCutover ?? (async () => ({ status: "continued" })),
    randomBytes: () => Buffer.alloc(32, 0xab),
    now: () => new Date(checkpointTime),
    signalSource: overrides.signalSource,
  };
}

function fakeClerkReceipt() {
  return {
    receipt_type: "refwatch_production_clerk_webhook_preparation",
    status: "prepared",
    clerk: {
      application_id: productionClerkWebhookTarget.clerkApplicationId,
      instance_id: productionClerkWebhookTarget.clerkInstanceId,
      user_count: 0,
    },
    svix: {
      application_id: "app_svixRefWatch123",
      endpoint_id: "ep_refwatch123",
      endpoint_uid: productionClerkWebhookTarget.endpointUid,
      endpoint_url: productionClerkWebhookTarget.endpointURL,
      endpoint_description: productionClerkWebhookTarget.endpointDescription,
      event_types: [...productionClerkWebhookTarget.eventTypes],
      disabled: true,
      header_count: 0,
      sensitive_header_name_count: 0,
      transformation_enabled: false,
      transformation_present: false,
    },
    final_provider_readback: {
      svix_application_id: "app_svixRefWatch123",
      endpoint_inventory_count: 1,
      endpoint_id: "ep_refwatch123",
      endpoint_uid: productionClerkWebhookTarget.endpointUid,
      endpoint_url: productionClerkWebhookTarget.endpointURL,
      endpoint_description: productionClerkWebhookTarget.endpointDescription,
      event_types: [...productionClerkWebhookTarget.eventTypes],
      disabled: true,
      header_count: 0,
      sensitive_header_name_count: 0,
      transformation_enabled: false,
      transformation_present: false,
    },
    receipt_sha256: clerkReceiptSha256,
  };
}

function fakeClerkController() {
  return {
    readExact: async () => ({} as any),
    setDisabled: async () => ({} as any),
  };
}

function fakeLineageReceipt() {
  return {
    receipt_type: "refwatch_production_greenfield_worker_lineage",
    status: "passed",
    secret_installation: {
      clerk_webhook_preparation_receipt_sha256: clerkReceiptSha256,
      final_secret_names: [...productionWorkerSecretNames],
      secret_values_hashed: false,
      secret_values_recorded: false,
    },
    deployment_guard: {
      deployment_id: lastKnownGoodDeploymentId,
      worker_version_id: lastKnownGoodVersionId,
    },
    version_readbacks: {
      last_known_good_l: {
        worker_version_id: lastKnownGoodVersionId,
      },
    },
    receipt_sha256: lineageReceiptSha256,
  };
}

function fakeProviderGuard(checkpointSha256: string): any {
  const payload = {
    schema_version: 1,
    receipt_type: "refwatch_production_greenfield_cutover_provider_guard",
    status: "passed",
    observed_at_utc: guardTime,
    checkpoint_sha256: checkpointSha256,
    clerk_webhook_preparation_receipt_sha256: clerkReceiptSha256,
    worker_lineage_receipt_sha256: lineageReceiptSha256,
    clerk_guard: {
      observed_at_utc: clerkGuardTime,
      clerk_application_id: productionClerkWebhookTarget.clerkApplicationId,
      clerk_instance_id: productionClerkWebhookTarget.clerkInstanceId,
      user_count: 0,
      svix_application_id: "app_svixRefWatch123",
      endpoint_inventory_count: 1,
      endpoint_id: "ep_refwatch123",
      endpoint_uid: productionClerkWebhookTarget.endpointUid,
      endpoint_url: productionClerkWebhookTarget.endpointURL,
      endpoint_description: productionClerkWebhookTarget.endpointDescription,
      event_types: [...productionClerkWebhookTarget.eventTypes],
      disabled: true,
      header_count: 0,
      sensitive_header_name_count: 0,
      transformation_enabled: false,
      transformation_present: false,
    },
    worker_guard: {
      observed_at_utc: workerGuardTime,
      deployment_id: lastKnownGoodDeploymentId,
      sole_worker_version_id: lastKnownGoodVersionId,
      deployment_version_count: 1,
      sole_traffic_percentage: 100,
      secret_names: [...productionWorkerSecretNames],
      secret_count: productionWorkerSecretNames.length,
      route_mutation_count: 0,
      access_mutation_count: 0,
    },
  };
  return {
    ...payload,
    receipt_sha256: computeSanitizedReceiptSha256(payload),
  };
}

function mutateAndResealGuard(
  value: Record<string, any>,
  mutate: (value: Record<string, any>) => void,
) {
  mutate(value);
  const payload = Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== "receipt_sha256"),
  );
  return {
    ...payload,
    receipt_sha256: computeSanitizedReceiptSha256(payload),
  };
}

function neverYieldingReviewInput() {
  let startedResolve!: () => void;
  const started = new Promise<void>((resolvePromise) => {
    startedResolve = resolvePromise;
  });
  const next = vi.fn(() => {
    startedResolve();
    return new Promise<IteratorResult<string>>(() => {});
  });
  const close = vi.fn(async () => ({ done: true, value: undefined }));
  const input = {
    [Symbol.asyncIterator]: () => ({ next, return: close }),
  };
  return { input, next, close, started };
}

async function* reviewInput(
  readCheckpoint: () => any,
  mutate?: (value: any) => void,
) {
  await Promise.resolve();
  const checkpoint = readCheckpoint();
  const value = {
    action: "continue",
    checkpoint_sha256: checkpoint.receipt_sha256,
    reviews: [
      {
        role: "code_operational_risk",
        verdict: "NO FINDINGS",
        artifact_sha256: checkpoint.receipt_sha256,
        reviewed_at_utc: reviewTimeA,
      },
      {
        role: "docs_evidence_consistency",
        verdict: "NO FINDINGS",
        artifact_sha256: checkpoint.receipt_sha256,
        reviewed_at_utc: reviewTimeB,
      },
    ],
  };
  mutate?.(value);
  yield `${JSON.stringify(value)}\n`;
}
