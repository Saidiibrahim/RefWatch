import { EventEmitter } from "node:events";
import { Readable } from "node:stream";
import { describe, expect, it, vi } from "vitest";
import {
  executeProductionGreenfieldWorkerLineage,
  loadProductionGreenfieldWorkerLineageSourceInput,
  loadProductionGreenfieldWorkerLineageSources,
  productionGreenfieldWorkerLineageCommands,
  productionGreenfieldWorkerLineageGate,
  productionGreenfieldWorkerLineageOrchestration,
  productionGreenfieldWorkerVersionViewCommand,
  readProductionGreenfieldWorkerLineageSecretMaterial,
  runProductionGreenfieldWorkerLineageCommand,
  runProductionGreenfieldWorkerLineageCLI,
  validateProductionGreenfieldWorkerLineageReceipt,
  validateProductionGreenfieldWorkerLineageSources,
  withProductionGreenfieldWorkerLineageLease,
  type ProductionGreenfieldWorkerLineageCommandSpecification,
} from "../scripts/prepare-production-greenfield-worker-lineage.mjs";
import {
  canonicalSanitizedJSON,
  computeSanitizedReceiptSha256,
  computeStableWorkerBindingSha256,
  cutoverAcceptance,
  expectedProductionWorkerBindings,
  productionDatabase,
  productionLastKnownGoodWorker,
  productionWorker,
  productionWorkerSecretNames,
} from "../scripts/greenfield-launch-packet.mjs";
import { productionRuntimeProvisioningTarget } from "../scripts/provision-production-runtime.mjs";
import {
  productionClerkWebhookPreparationGate,
  productionClerkWebhookCommands,
  productionClerkWebhookPortalContract,
  productionClerkWebhookTarget,
} from "../scripts/prepare-production-clerk-webhook.mjs";

const webhookSecret = `${["wh", "sec_"].join("")}not-a-real-provider-secret_123456789`;
const cutoverToken = "not-a-real-cutover-token-12345678901234567890";

describe("production greenfield Worker lineage helper", () => {
  it("pins the reviewed Worker source tree, config, toolchain, and last-known-good identity", async () => {
    const source = await loadProductionGreenfieldWorkerLineageSources();

    expect(source.manifestSha256).toBe(
      "dedf2578b002865aa05486cf6fd329714140563235d97b5c8ddf1c3248b5aa36",
    );
    expect(source.fileCount).toBe(80);
    expect(source.wranglerConfigSha256).toBe(
      "d294b351093967d6ef4e9fc129abb55fe7d2d4eda4ee6b85ab7d4d84dc85a176",
    );
    expect(Object.isFrozen(productionLastKnownGoodWorker)).toBe(true);
    expect(productionLastKnownGoodWorker).toEqual({
      versionId: "e966d6df-b5ff-4288-832c-c8d91e00ce48",
      createdAtUTC: "2026-07-16T20:45:12.701Z",
      scriptEtag:
        "c7fe13feeaec6962e56ee072a7479b1ea022b21ded00bf2d21a04d4d5477ccc4",
      hyperdriveId: "5345de83edfa40b790d5b26df32f56ab",
      runtimeRoleId: "vaqg84rqoedz",
    });
  });

  it("fails the source-only check for any reviewed source drift", async () => {
    const input = await loadProductionGreenfieldWorkerLineageSourceInput();
    const drifted = {
      entries: input.entries.map((entry) => entry.path === "wrangler.jsonc"
        ? { ...entry, content: Buffer.concat([Buffer.from(entry.content as any), Buffer.from("\n")]) }
        : entry),
    };

    expect(() => validateProductionGreenfieldWorkerLineageSources(drifted))
      .toThrow("reviewed source manifest drifted");
  });

  it("uses the exact direct-target secret commands and config-targeted strict uploads", () => {
    expect(productionGreenfieldWorkerLineageCommands.webhookSecretPut).toEqual({
      command: "./node_modules/.bin/wrangler",
      args: [
        "versions",
        "secret",
        "put",
        "CLERK_WEBHOOK_SIGNING_SECRET",
        "--name",
        "refwatch-api",
        "--env-file",
        "/dev/null",
        "--tag",
        "greenfield-webhook-secret-source",
        "--message",
        "Install RefWatch production Clerk webhook signing secret",
      ],
    });
    expect(productionGreenfieldWorkerLineageCommands.cutoverSecretPut.args)
      .toContain(cutoverAcceptance.tokenSecretName);
    expect(productionGreenfieldWorkerLineageCommands.cutoverSecretPut.args)
      .not.toContain("--env");

    expect(productionGreenfieldWorkerLineageCommands.candidateUpload.args).toEqual([
      "versions",
      "upload",
      "--env",
      "production",
      "--env-file",
      "/dev/null",
      "--strict",
      "--no-experimental-provision",
      "--no-experimental-auto-create",
      "--var",
      "WRITE_MODE:disabled",
      "--var",
      "NEW_USER_ONBOARDING_MODE:disabled",
      "--tag",
      "greenfield-disabled-a",
      "--message",
      "RefWatch greenfield disabled candidate A",
    ]);
    expect(productionGreenfieldWorkerLineageCommands.acceptedUpload.args)
      .toContain("WRITE_MODE:enabled");
    expect(productionGreenfieldWorkerLineageCommands.acceptedUpload.args)
      .toContain("NEW_USER_ONBOARDING_MODE:greenfield_bootstrap");
    expect(productionGreenfieldWorkerLineageCommands.writeGuardUpload.args)
      .toContain("greenfield-write-guard-g");
    for (const upload of [
      productionGreenfieldWorkerLineageCommands.candidateUpload,
      productionGreenfieldWorkerLineageCommands.acceptedUpload,
      productionGreenfieldWorkerLineageCommands.writeGuardUpload,
    ]) {
      expect(upload.args).not.toContain("--name");
      expect(upload.args).not.toContain("--keep-vars");
      expect(upload.args).not.toContain("--secrets-file");
      expect(upload.args).not.toContain("--preview-alias");
    }
    expect(productionGreenfieldWorkerVersionViewCommand(
      productionLastKnownGoodWorker.versionId,
    ).args).toEqual([
      "versions",
      "view",
      productionLastKnownGoodWorker.versionId,
      "--name",
      "refwatch-api",
      "--env-file",
      "/dev/null",
      "--json",
    ]);
  });

  it("rejects direct or escaped execution without an active callback lease", async () => {
    const provider = fakeProvider();
    const environment = lineageLeaseEnvironment();
    const executionOptions = {
      environment,
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: provider.run,
      now: () => new Date("2026-07-21T06:00:00.000Z"),
    };
    await expect(executeProductionGreenfieldWorkerLineage(executionOptions))
      .rejects.toThrow("Production greenfield Worker lineage execution failed");

    const unleasedConsumer = vi.fn();
    await expect(withProductionGreenfieldWorkerLineageLease(
      unleasedConsumer,
      {
        environment: {
          [productionClerkWebhookPreparationGate]: "1",
          [productionGreenfieldWorkerLineageGate]: "1",
        },
      },
    )).rejects.toThrow("Production greenfield Worker lineage execution failed");
    expect(unleasedConsumer).not.toHaveBeenCalled();

    let escapedExecute: ((options: any) => Promise<unknown>) | undefined;
    await withProductionGreenfieldWorkerLineageLease(async (execute) => {
      escapedExecute = execute;
    }, { environment });
    expect(escapedExecute).toBeDefined();
    await expect(escapedExecute!({
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: provider.run,
    })).rejects.toThrow("Production greenfield Worker lineage execution failed");
    expect(provider.calls).toHaveLength(0);
  });

  it("makes each callback lease one-shot after an ambiguous partial failure", async () => {
    const provider = fakeProvider({ concurrentAt: "candidate_a" });
    const environment = lineageLeaseEnvironment();
    await withProductionGreenfieldWorkerLineageLease(async (execute) => {
      const executionOptions = {
        secretMaterial: fakeSecretMaterial(),
        clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
        loadSources: async () => ({}) as never,
        runCommand: provider.run,
        now: () => new Date("2026-07-21T06:00:00.000Z"),
      };
      await expect(execute(executionOptions)).rejects.toThrow(
        "Production greenfield Worker lineage execution failed",
      );
      const callCountAfterPartialFailure = provider.calls.length;
      await expect(execute(executionOptions)).rejects.toThrow(
        "Production greenfield Worker lineage execution failed",
      );
      expect(provider.calls).toHaveLength(callCountAfterPartialFailure);
    }, { environment });
  });

  it("rejects an aborted leased execution before the first provider command", async () => {
    const provider = fakeProvider();
    const environment = lineageLeaseEnvironment();
    const controller = new AbortController();
    controller.abort();
    await withProductionGreenfieldWorkerLineageLease(async (execute) => {
      await expect(execute({
        secretMaterial: fakeSecretMaterial(),
        clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
        runCommand: provider.run,
        signal: controller.signal,
      })).rejects.toThrow(
        "Production greenfield Worker lineage execution failed",
      );
    }, { environment });
    expect(provider.calls).toHaveLength(0);
  });

  it("wipes helper-owned secret buffers when a signal crosses a mutation", async () => {
    const provider = fakeProvider();
    const environment = lineageLeaseEnvironment();
    const controller = new AbortController();
    await withProductionGreenfieldWorkerLineageLease(async (execute) => {
      await expect(execute({
        secretMaterial: fakeSecretMaterial(),
        clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
        loadSources: async () => ({}) as never,
        runCommand: async (specification) => {
          const result = await provider.run(specification);
          if (
            specification.args ===
              productionGreenfieldWorkerLineageCommands.webhookSecretPut.args
            || (
              specification.args[0] === "versions"
              && specification.args[1] === "secret"
              && specification.args[3] === "CLERK_WEBHOOK_SIGNING_SECRET"
            )
          ) controller.abort();
          return result;
        },
        signal: controller.signal,
      })).rejects.toThrow(
        "Production greenfield Worker lineage execution failed",
      );
    }, { environment });
    expect(provider.stdinReferences).toHaveLength(1);
    expect(provider.stdinReferences[0]?.every((byte) => byte === 0)).toBe(true);
  });

  it("creates exactly interim/S/A/B/G, preserves L=100, and emits one secret-free packet receipt", async () => {
    const provider = fakeProvider();
    const receipt: any = await executeWithLineageLease({
      environment: {
        [productionGreenfieldWorkerLineageGate]: "1",
        PATH: "/usr/bin",
        CLOUDFLARE_API_BASE_URL: "https://unreviewed.invalid",
        CLERK_SECRET_KEY: "must-not-cross-provider-boundary",
      },
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: provider.run,
      now: () => new Date("2026-07-21T06:00:00.000Z"),
    });

    expect(validateProductionGreenfieldWorkerLineageReceipt(receipt)).toBe(receipt);
    expect(receipt.receipt_sha256).toMatch(/^[0-9a-f]{64}$/u);
    expect(receipt.authorization).toEqual({
      profile: "refwatch.greenfield-authorization.v1",
      digest: "17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b",
      execution_mode: "reviewed_same_process_cutover_orchestrator",
      outer_technical_gate:
        productionGreenfieldWorkerLineageOrchestration.outerTechnicalGate,
      clerk_technical_gate: productionClerkWebhookPreparationGate,
      lineage_technical_gate: productionGreenfieldWorkerLineageGate,
    });
    expect(receipt.deployment_guard).toMatchObject({
      deployment_id: "89cff719-0e19-4648-ab09-63a37d806c95",
      worker_version_id: productionLastKnownGoodWorker.versionId,
      traffic_percentage: 100,
      boundary_count: 5,
    });
    expect(receipt.deployment_guard.boundaries.map((boundary: any) => boundary.stage))
      .toEqual([
        "webhook_secret_install",
        "cutover_secret_install_source_s",
        "candidate_a",
        "accepted_b",
        "write_guard_g",
      ]);
    expect(new Set(
      receipt.deployment_guard.boundaries.map(
        (boundary: any) => boundary.created_worker_version_id,
      ),
    ).size).toBe(5);
    expect(receipt.packet_worker.secret_lineage).toMatchObject({
      status: "passed",
      intervening_secret_mutation_count: 0,
      unexpected_intervening_version_count: 0,
      upload_secret_override_count: 0,
      secret_values_recorded: false,
    });
    expect(receipt.packet_worker.versions.candidate_script_etag).toBe(
      receipt.packet_worker.versions.accepted_script_etag,
    );
    expect(receipt.packet_worker.versions.candidate_stable_binding_sha256).toBe(
      receipt.packet_worker.versions.accepted_stable_binding_sha256,
    );
    expect(receipt.version_readbacks.last_known_good_l.worker_version_id).toBe(
      productionLastKnownGoodWorker.versionId,
    );
    expect(receipt.secret_installation.clerk_webhook_preparation_receipt)
      .toEqual(fakeClerkWebhookReceipt());
    expect(receipt.secret_installation.clerk_webhook_preparation_receipt_sha256)
      .toBe(fakeClerkWebhookReceipt().receipt_sha256);
    expect(receipt.version_readbacks.webhook_secret_interim.worker_version_id)
      .toBe(receipt.secret_installation.interim_worker_version_id);
    for (const boundary of receipt.deployment_guard.boundaries) {
      expect(boundary.before_version_history_sha256).toBe(
        computeSanitizedReceiptSha256(boundary.before_version_history),
      );
      expect(boundary.after_version_history_sha256).toBe(
        computeSanitizedReceiptSha256(boundary.after_version_history),
      );
    }

    const serialized = canonicalSanitizedJSON(receipt);
    expect(serialized).not.toContain(webhookSecret);
    expect(serialized).not.toContain(cutoverToken);
    expect(serialized).not.toContain("author_email");
    expect(serialized).not.toContain("author_id");

    const secretCalls = provider.calls.filter((call) => call.stdin !== undefined);
    expect(secretCalls).toHaveLength(2);
    expect(secretCalls.map((call) => call.stdin?.toString("utf8"))).toEqual([
      webhookSecret,
      cutoverToken,
    ]);
    for (const call of provider.calls) {
      expect(call.args.join(" ")).not.toContain(webhookSecret);
      expect(call.args.join(" ")).not.toContain(cutoverToken);
      expect(canonicalSanitizedJSON(call.environment)).not.toContain(webhookSecret);
      expect(canonicalSanitizedJSON(call.environment)).not.toContain(cutoverToken);
      expect(call.environment).toMatchObject({
        CLOUDFLARE_ACCOUNT_ID:
          productionRuntimeProvisioningTarget.cloudflareAccountId,
        WRANGLER_WRITE_LOGS: "0",
        WRANGLER_LOG_SANITIZE: "true",
        WRANGLER_SEND_METRICS: "false",
        NO_COLOR: "1",
      });
      expect(call.environment).not.toHaveProperty("CLOUDFLARE_API_BASE_URL");
      expect(call.environment).not.toHaveProperty("CLERK_SECRET_KEY");
    }
    expect(provider.stdinReferences).toHaveLength(2);
    expect(provider.stdinReferences.every((value) =>
      value.every((byte) => byte === 0))).toBe(true);
    const mutationArgs = provider.calls
      .filter((call) => call.args.includes("put") || call.args.includes("upload"))
      .map((call) => call.args);
    expect(mutationArgs).toEqual([
      [...productionGreenfieldWorkerLineageCommands.webhookSecretPut.args],
      [...productionGreenfieldWorkerLineageCommands.cutoverSecretPut.args],
      [...productionGreenfieldWorkerLineageCommands.candidateUpload.args],
      [...productionGreenfieldWorkerLineageCommands.acceptedUpload.args],
      [...productionGreenfieldWorkerLineageCommands.writeGuardUpload.args],
    ]);
  });

  it("fails closed when concurrent version creation crosses a mutation boundary", async () => {
    const provider = fakeProvider({ concurrentAt: "candidate_a" });

    await expect(executeWithLineageLease({
      environment: { [productionGreenfieldWorkerLineageGate]: "1" },
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: provider.run,
      now: () => new Date("2026-07-21T06:00:00.000Z"),
    })).rejects.toThrow("Production greenfield Worker lineage execution failed");
  });

  it("polls bounded readback propagation without retrying any mutation", async () => {
    const provider = fakeProvider({ delayedVisibility: true });
    const receipt = await executeWithLineageLease({
      environment: { [productionGreenfieldWorkerLineageGate]: "1" },
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: provider.run,
      now: () => new Date("2026-07-21T06:00:00.000Z"),
      delay: async () => undefined,
    });

    expect(receipt.status).toBe("completed");
    expect(provider.calls.filter(
      (call) => call.args.includes("put") || call.args.includes("upload"),
    )).toHaveLength(5);
  });

  it("rejects forged standalone receipts across bindings, lineage, deployment, and authorization", async () => {
    const provider = fakeProvider();
    const base: any = await executeWithLineageLease({
      environment: { [productionGreenfieldWorkerLineageGate]: "1" },
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: provider.run,
      now: () => new Date("2026-07-21T06:00:00.000Z"),
    });
    const cases: Array<[string, (receipt: any) => void]> = [
      ["candidate binding mode", (receipt) => {
        const candidate = receipt.version_readbacks.candidate_a;
        candidate.resources.bindings.find(
          (binding: any) => binding.name === "WRITE_MODE",
        ).text = "enabled";
        sealInline(candidate, "readback_sha256");
        receipt.packet_worker.versions.candidate_sanitized_readback = candidate;
        const stable = computeStableWorkerBindingSha256(candidate);
        receipt.packet_worker.versions.candidate_stable_binding_sha256 = stable;
        receipt.packet_worker.versions.accepted_stable_binding_sha256 = stable;
        sealInline(receipt.packet_worker, "provider_readback_sha256");
      }],
      ["write guard script", (receipt) => {
        receipt.version_readbacks.write_guard_g.resources.script.etag = "b".repeat(64);
        sealInline(receipt.version_readbacks.write_guard_g, "readback_sha256");
      }],
      ["last-known-good binding", (receipt) => {
        receipt.version_readbacks.last_known_good_l.resources.bindings.find(
          (binding: any) => binding.name === "HYPERDRIVE",
        ).id = productionDatabase.hyperdriveId;
        sealInline(receipt.version_readbacks.last_known_good_l, "readback_sha256");
      }],
      ["source secret inheritance", (receipt) => {
        receipt.version_readbacks.source_s.resources.bindings =
          receipt.version_readbacks.source_s.resources.bindings.filter(
            (binding: any) => binding.name !== cutoverAcceptance.tokenSecretName,
          );
        sealInline(receipt.version_readbacks.source_s, "readback_sha256");
      }],
      ["interim webhook-secret inheritance", (receipt) => {
        receipt.version_readbacks.webhook_secret_interim.resources.bindings =
          receipt.version_readbacks.webhook_secret_interim.resources.bindings.filter(
            (binding: any) => binding.name !== "CLERK_WEBHOOK_SIGNING_SECRET",
          );
        sealInline(
          receipt.version_readbacks.webhook_secret_interim,
          "readback_sha256",
        );
      }],
      ["Clerk production instance", (receipt) => {
        forgeEmbeddedClerkReceipt(receipt, (clerkReceipt) => {
          clerkReceipt.clerk.instance_id = "ins_wrong";
        });
      }],
      ["Clerk endpoint URL", (receipt) => {
        forgeEmbeddedClerkReceipt(receipt, (clerkReceipt) => {
          clerkReceipt.svix.endpoint_url = "https://wrong.example/webhook";
        });
      }],
      ["Clerk endpoint disabled state", (receipt) => {
        forgeEmbeddedClerkReceipt(receipt, (clerkReceipt) => {
          clerkReceipt.svix.disabled = false;
        });
      }],
      ["Clerk zero-user readback", (receipt) => {
        forgeEmbeddedClerkReceipt(receipt, (clerkReceipt) => {
          clerkReceipt.clerk.user_count = 1;
          clerkReceipt.clerk.post_reconciliation_user_count = 1;
        });
      }],
      ["Clerk preparation digest binding", (receipt) => {
        receipt.secret_installation.clerk_webhook_preparation_receipt_sha256 =
          "f".repeat(64);
      }],
      ["boundary identity", (receipt) => {
        receipt.deployment_guard.boundaries[1].created_worker_version_id =
          "30000000-0000-4000-8000-000000000099";
      }],
      ["boundary annotation", (receipt) => {
        receipt.deployment_guard.boundaries[2].created_worker_version_tag =
          "unreviewed-tag";
      }],
      ["boundary chronology", (receipt) => {
        const boundary = receipt.deployment_guard.boundaries[0];
        boundary.after.observed_at_utc = boundary.before.observed_at_utc;
        sealInline(boundary.after, "readback_sha256");
      }],
      ["boundary version trigger", (receipt) => {
        const boundary = receipt.deployment_guard.boundaries[2];
        boundary.after_version_history.at(-1).trigger = "dashboard";
        boundary.after_version_history_sha256 = computeSanitizedReceiptSha256(
          boundary.after_version_history,
        );
      }],
      ["boundary version number", (receipt) => {
        const boundary = receipt.deployment_guard.boundaries[2];
        boundary.after_version_history.at(-1).number += 1;
        boundary.after_version_history_sha256 = computeSanitizedReceiptSha256(
          boundary.after_version_history,
        );
      }],
      ["boundary retained history tail", (receipt) => {
        const boundary = receipt.deployment_guard.boundaries[2];
        boundary.after_version_history[0].id =
          "90000000-0000-4000-8000-000000000001";
        boundary.after_version_history_sha256 = computeSanitizedReceiptSha256(
          boundary.after_version_history,
        );
      }],
      ["post-G final history", (receipt) => {
        const history = receipt.deployment_guard.final_version_history;
        const latest = history.at(-1);
        history.push({
          ...latest,
          id: "90000000-0000-4000-8000-000000000002",
          number: latest.number + 1,
          created_at_utc: new Date(
            Date.parse(latest.created_at_utc) + 1_000,
          ).toISOString(),
          trigger: "version_upload",
          tag: "unreviewed-post-g",
          message: "Unreviewed post-G version",
        });
        while (history.length > 10) history.shift();
        receipt.deployment_guard.final_version_history_sha256 =
          computeSanitizedReceiptSha256(history);
      }],
      ["deployment snapshot creation", (receipt) => {
        const deployment = receipt.deployment_guard.boundaries[2].after;
        deployment.created_at_utc = new Date(
          Date.parse(deployment.created_at_utc) + 1_000,
        ).toISOString();
        sealInline(deployment, "readback_sha256");
      }],
      ["deployment source", (receipt) => {
        receipt.deployment_guard.final_readback.source = "dashboard";
        sealInline(receipt.deployment_guard.final_readback, "readback_sha256");
      }],
      ["secret-lineage deterministic receipt id", (receipt) => {
        receipt.packet_worker.secret_lineage.receipt_id =
          "refwatch-worker-secret-lineage-forged";
        resealPacketLineage(receipt);
      }],
      ["version-history deterministic receipt id", (receipt) => {
        receipt.packet_worker.secret_lineage.provider_version_history_receipt_id =
          "refwatch-worker-version-history-forged";
        resealPacketLineage(receipt, true);
      }],
      ["lineage observation chronology", (receipt) => {
        receipt.packet_worker.secret_lineage.observed_at_utc =
          receipt.deployment_guard.final_readback.observed_at_utc;
        resealPacketLineage(receipt, true);
      }],
      ["late G readback", (receipt) => {
        receipt.version_readbacks.write_guard_g.observed_at_utc =
          receipt.packet_worker.provider_readback_at_utc;
        sealInline(receipt.version_readbacks.write_guard_g, "readback_sha256");
      }],
      ["late L readback", (receipt) => {
        receipt.version_readbacks.last_known_good_l.observed_at_utc =
          receipt.packet_worker.provider_readback_at_utc;
        sealInline(receipt.version_readbacks.last_known_good_l, "readback_sha256");
      }],
      ["authorization", (receipt) => {
        receipt.authorization.digest = "f".repeat(64);
      }],
    ];

    for (const [label, mutate] of cases) {
      const receipt = JSON.parse(JSON.stringify(base));
      mutate(receipt);
      sealInline(receipt, "receipt_sha256");
      expect(
        () => validateProductionGreenfieldWorkerLineageReceipt(receipt),
        label,
      ).toThrow("Production greenfield Worker lineage execution failed");
    }
  });

  it("fails closed if traffic leaves L=100 or the starting secret set conflicts", async () => {
    const deploymentProvider = fakeProvider({ deploymentDriftAt: "webhook_secret_install" });
    await expect(executeWithLineageLease({
      environment: { [productionGreenfieldWorkerLineageGate]: "1" },
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: deploymentProvider.run,
      now: () => new Date("2026-07-21T06:00:00.000Z"),
    })).rejects.toThrow("Production greenfield Worker lineage execution failed");

    const conflictProvider = fakeProvider({ startingSecretConflict: true });
    await expect(executeWithLineageLease({
      environment: { [productionGreenfieldWorkerLineageGate]: "1" },
      secretMaterial: fakeSecretMaterial(),
      clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
      runCommand: conflictProvider.run,
      now: () => new Date("2026-07-21T06:00:00.000Z"),
    })).rejects.toThrow("Production greenfield Worker lineage execution failed");
    expect(conflictProvider.calls.some((call) => call.args.includes("put"))).toBe(false);
  });

  it("rejects malformed provider output without echoing it", async () => {
    const marker = "MALFORMED_PROVIDER_SECRET_MARKER";
    const provider = fakeProvider({ malformedHistory: marker });
    let error: Error | undefined;
    try {
      await executeWithLineageLease({
        environment: { [productionGreenfieldWorkerLineageGate]: "1" },
        secretMaterial: fakeSecretMaterial(),
        clerkWebhookPreparationReceipt: fakeClerkWebhookReceipt(),
        runCommand: provider.run,
      });
    } catch (caught) {
      error = caught as Error;
    }
    expect(error?.message).toBe(
      "Production greenfield Worker lineage execution failed",
    );
    expect(error?.message).not.toContain(marker);
  });

  it("keeps execution impossible by default and makes --check source-only", async () => {
    const checkSources = vi.fn(async () => undefined);
    const stdout = vi.fn();
    const stderr = vi.fn();

    expect(await runProductionGreenfieldWorkerLineageCLI({
      args: [],
      environment: {},
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(2);
    expect(await runProductionGreenfieldWorkerLineageCLI({
      args: ["--execute"],
      environment: {},
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(2);
    expect(checkSources).not.toHaveBeenCalled();

    expect(await runProductionGreenfieldWorkerLineageCLI({
      args: ["--check"],
      environment: {},
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(0);
    expect(checkSources).toHaveBeenCalledOnce();
  });

  it("never invokes a standalone provider execution path", async () => {
    const stdout = vi.fn();
    const stderr = vi.fn();
    const exitCode = await runProductionGreenfieldWorkerLineageCLI({
      args: ["--execute"],
      environment: { [productionGreenfieldWorkerLineageGate]: "1" },
      writeStdout: stdout,
      writeStderr: stderr,
    });

    expect(exitCode).toBe(2);
    expect(stdout).not.toHaveBeenCalled();
    expect(stderr).toHaveBeenCalledOnce();
    expect(stderr).toHaveBeenCalledWith(
      "Standalone production Worker lineage execution is disabled; use the reviewed same-process cutover orchestrator.\n",
    );
  });

  it("bounds runner timeout and output while never disclosing captured provider text", async () => {
    const timeoutChild = fakeChild();
    let timeoutStdin: Buffer | undefined;
    timeoutChild.stdin.end = vi.fn((value: Buffer) => {
      timeoutStdin = value;
    });
    const timeout = runProductionGreenfieldWorkerLineageCommand(
      { ...commandSpecification(), stdin: Buffer.from(webhookSecret) },
      {
        spawnImpl: vi.fn(() => timeoutChild as never),
        timeoutMs: 5,
        killGraceMs: 5,
      },
    );
    await expect(timeout).rejects.toThrow(
      "Production greenfield Worker lineage execution failed",
    );
    expect(timeoutChild.kill).toHaveBeenNthCalledWith(1, "SIGTERM");
    expect(timeoutChild.kill).toHaveBeenNthCalledWith(2, "SIGKILL");
    expect(timeoutStdin?.every((byte) => byte === 0)).toBe(true);

    const overflowChild = fakeChild();
    let overflowStdin: Buffer | undefined;
    overflowChild.stdin.end = vi.fn((value: Buffer) => {
      overflowStdin = value;
    });
    const overflow = runProductionGreenfieldWorkerLineageCommand(
      { ...commandSpecification(), stdin: Buffer.from(webhookSecret) },
      {
        spawnImpl: vi.fn(() => overflowChild as never),
        timeoutMs: 2_000,
        maxOutputBytes: 16,
      },
    );
    const overflowStdout = Buffer.from(webhookSecret);
    const overflowStderr = Buffer.from(cutoverToken);
    overflowChild.stdout.emit("data", overflowStdout);
    overflowChild.stderr.emit("data", overflowStderr);
    overflowChild.emit("close", 1);
    let overflowError: Error | undefined;
    try {
      await overflow;
    } catch (caught) {
      overflowError = caught as Error;
    }
    expect(overflowError?.message).toBe(
      "Production greenfield Worker lineage execution failed",
    );
    expect(overflowError?.message).not.toContain(webhookSecret);
    expect(overflowError?.message).not.toContain(cutoverToken);
    expect(overflowStdout.every((byte) => byte === 0)).toBe(true);
    expect(overflowStderr.every((byte) => byte === 0)).toBe(true);
    expect(overflowStdin?.every((byte) => byte === 0)).toBe(true);

    const invalidChild = fakeChild();
    let invalidStdin: Buffer | undefined;
    invalidChild.stdin.end = vi.fn((value: Buffer) => {
      invalidStdin = value;
      throw new Error("SENSITIVE_STDIN_FAILURE");
    });
    await expect(runProductionGreenfieldWorkerLineageCommand(
      { ...commandSpecification(), stdin: Buffer.from(webhookSecret) },
      {
        spawnImpl: vi.fn(() => invalidChild as never),
        timeoutMs: 2_000,
        killGraceMs: 5,
      },
    )).rejects.toThrow("Production greenfield Worker lineage execution failed");
    expect(invalidStdin?.every((byte) => byte === 0)).toBe(true);

    const successChild = fakeChild();
    let successStdin: Buffer | undefined;
    successChild.stdin.end = vi.fn((value: Buffer) => {
      successStdin = value;
    });
    const success = runProductionGreenfieldWorkerLineageCommand(
      { ...commandSpecification(), stdin: Buffer.from(webhookSecret) },
      {
        spawnImpl: vi.fn(() => successChild as never),
        timeoutMs: 5,
        killGraceMs: 5,
      },
    );
    const successOutput = Buffer.from(webhookSecret);
    successChild.stdout.emit("data", successOutput);
    successChild.emit("close", 0);
    const successResult = await success;
    expect(Buffer.from(successResult.stdout).toString("utf8")).toBe(webhookSecret);
    expect(successOutput.every((byte) => byte === 0)).toBe(true);
    expect(successStdin?.every((byte) => byte === 0)).toBe(true);
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 15));
    expect(successChild.kill).not.toHaveBeenCalled();
    if (Buffer.isBuffer(successResult.stdout)) successResult.stdout.fill(0);
  });

  it.each(["nonzero", "error", "spawn"] as const)(
    "fails runner %s generically and zeroes captured output",
    async (failure) => {
      const marker = Buffer.from(webhookSecret);
      const child = fakeChild();
      let result: Promise<any>;
      if (failure === "spawn") {
        result = runProductionGreenfieldWorkerLineageCommand(
          commandSpecification(),
          {
            spawnImpl: vi.fn(() => {
              throw new Error(webhookSecret);
            }),
          },
        );
      } else {
        result = runProductionGreenfieldWorkerLineageCommand(
          commandSpecification(),
          {
            spawnImpl: vi.fn(() => child as never),
            timeoutMs: 2_000,
            killGraceMs: 5,
          },
        );
        child.stdout.emit("data", marker);
        if (failure === "nonzero") child.emit("close", 1);
        else child.emit("error", new Error(webhookSecret));
      }
      let error: unknown;
      try {
        await result;
      } catch (caught) {
        error = caught;
      }
      expect(String(error)).toBe(
        "Error: Production greenfield Worker lineage execution failed",
      );
      expect(String(error)).not.toContain(webhookSecret);
      if (failure !== "spawn") {
        expect(marker.every((byte) => byte === 0)).toBe(true);
      }
    },
  );

  it("accepts exactly two bounded stdin-only secret lines", async () => {
    const result = await readProductionGreenfieldWorkerLineageSecretMaterial(
      Readable.from([Buffer.from(`${webhookSecret}\n${cutoverToken}\n`)]),
    );
    expect(Buffer.from(result.clerkWebhookSigningSecret).toString("utf8")).toBe(webhookSecret);
    expect(Buffer.from(result.cutoverAcceptanceToken).toString("utf8")).toBe(cutoverToken);

    await expect(readProductionGreenfieldWorkerLineageSecretMaterial(
      Readable.from([Buffer.from(`${webhookSecret}\n${cutoverToken}\nextra\n`)]),
    )).rejects.toThrow("secret input is invalid");
  });
});

function fakeSecretMaterial() {
  return {
    clerkWebhookSigningSecret: Buffer.from(webhookSecret),
    cutoverAcceptanceToken: Buffer.from(cutoverToken),
  };
}

function lineageLeaseEnvironment(environment: NodeJS.ProcessEnv = {}) {
  return {
    ...environment,
    [productionGreenfieldWorkerLineageOrchestration.outerTechnicalGate]: "1",
    [productionClerkWebhookPreparationGate]: "1",
    [productionGreenfieldWorkerLineageGate]: "1",
  };
}

function executeWithLineageLease(options: Record<string, any>) {
  const { environment: requestedEnvironment = {}, ...executionOptions } = options;
  const environment = lineageLeaseEnvironment(requestedEnvironment);
  return withProductionGreenfieldWorkerLineageLease(
    (execute) => execute(executionOptions as never),
    { environment },
  );
}

function fakeClerkWebhookReceipt() {
  const payload = {
    schema_version: 1,
    receipt_type: "refwatch_production_clerk_webhook_preparation",
    status: "prepared",
    operation: "reused",
    observed_at_utc: "2026-07-21T04:59:59.000Z",
    source_contract: {
      clerk_backend_version: "3.11.4",
      clerk_cli_version: "2.2.0",
      clerk_lock_contract_sha256:
        "4a4bab3d651b0333b4a87ccae0c05a656898babe05210bc47c5f93a8664c6ae4",
      launch_packet_sha256:
        "21b671ba5a5f585fe8ee4982a0ca1dfa570d15bbe23eb20c8f3e219e18772508",
    },
    provider_command: {
      command: "./node_modules/.bin/clerk",
      credential_source: "clerk_cli_oauth_credential_store",
      secret_key_argument_count: 0,
      whoami_arguments: [...productionClerkWebhookCommands.whoami.args],
      user_count_arguments: [...productionClerkWebhookCommands.userCount.args],
      svix_url_arguments: [...productionClerkWebhookCommands.svixURL.args],
    },
    clerk: {
      application_id: productionClerkWebhookTarget.clerkApplicationId,
      application_name: productionClerkWebhookTarget.clerkApplicationName,
      instance_id: productionClerkWebhookTarget.clerkInstanceId,
      user_count: 0,
      initial_user_count: 0,
      pre_reconciliation_user_count: 0,
      post_reconciliation_user_count: 0,
      user_count_source: "clerk_backend_api_users_count",
    },
    portal_protocol: {
      portal_origin: productionClerkWebhookPortalContract.portalOrigin,
      login_url: productionClerkWebhookPortalContract.loginURL,
      asset_path: productionClerkWebhookPortalContract.assetPath,
      asset_sha256: productionClerkWebhookPortalContract.assetSha256,
      region: "us",
      capabilities: ["ManageEndpoint", "ViewEndpointSecret"],
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
      created_at_utc: "2026-07-21T04:58:00.000Z",
      updated_at_utc: "2026-07-21T04:58:00.000Z",
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
    secret_material: {
      representation: "buffer",
      secret_values_hashed: false,
      secret_values_recorded: false,
    },
  };
  return {
    ...payload,
    receipt_sha256: computeSanitizedReceiptSha256(payload),
  };
}

function commandSpecification() {
  return {
    command: "./node_modules/.bin/wrangler",
    args: ["versions", "list", "--name", productionWorker.name, "--json"],
    cwd: process.cwd(),
    environment: {},
  };
}

function fakeChild() {
  const child = new EventEmitter() as EventEmitter & Record<string, any>;
  child.stdout = new EventEmitter();
  child.stderr = new EventEmitter();
  child.stdin = new EventEmitter();
  child.stdin.writable = true;
  child.stdin.end = vi.fn();
  child.kill = vi.fn();
  return child;
}

function sealInline(value: Record<string, any>, digestField: string) {
  const payload = Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== digestField),
  );
  value[digestField] = computeSanitizedReceiptSha256(payload);
}

function forgeEmbeddedClerkReceipt(
  receipt: any,
  mutate: (clerkReceipt: any) => void,
) {
  const embedded =
    receipt.secret_installation.clerk_webhook_preparation_receipt;
  mutate(embedded);
  sealInline(embedded, "receipt_sha256");
  receipt.secret_installation.clerk_webhook_preparation_receipt_sha256 =
    embedded.receipt_sha256;
}

function resealPacketLineage(receipt: any, resealProviderHistory = false) {
  const lineage = receipt.packet_worker.secret_lineage;
  if (resealProviderHistory) {
    lineage.provider_version_history_receipt_sha256 =
      computeSanitizedReceiptSha256({
        receipt_id: lineage.provider_version_history_receipt_id,
        observed_at_utc: lineage.observed_at_utc,
        worker_name: productionWorker.name,
        environment: productionWorker.environment,
        version_history_boundaries:
          receipt.deployment_guard.boundaries.map((boundary: any) => ({
            stage: boundary.stage,
            created_worker_version_id: boundary.created_worker_version_id,
            before_version_history_sha256:
              boundary.before_version_history_sha256,
            after_version_history_sha256:
              boundary.after_version_history_sha256,
          })),
      });
  }
  sealInline(lineage, "receipt_sha256");
  sealInline(receipt.packet_worker, "provider_readback_sha256");
}

function fakeProvider(options: {
  concurrentAt?: string;
  deploymentDriftAt?: string;
  startingSecretConflict?: boolean;
  malformedHistory?: string;
  delayedVisibility?: boolean;
} = {}) {
  const calls: Array<{
    command: string;
    args: string[];
    environment: NodeJS.ProcessEnv;
    stdin?: Buffer;
  }> = [];
  const stdinReferences: Buffer[] = [];
  const history = Array.from({ length: 9 }, (_, index) => {
    const number = index + 5;
    return historyEntry(
      versionUUID(1, number),
      number,
      `2026-07-15T00:00:${String(number).padStart(2, "0")}.000Z`,
      "secret",
    );
  });
  history.push(historyEntry(
    productionLastKnownGoodWorker.versionId,
    14,
    "2026-07-16T20:45:12.701021Z",
    "version_upload",
  ));
  const rawVersions = new Map<string, any>();
  rawVersions.set(
    productionLastKnownGoodWorker.versionId,
    rawVersion(
      productionLastKnownGoodWorker.versionId,
      "2026-07-16T20:45:12.701021Z",
      lastKnownGoodBindings(initialSecretNames()),
      productionLastKnownGoodWorker.scriptEtag,
    ),
  );
  const secrets = new Set<string>(initialSecretNames());
  if (options.startingSecretConflict) secrets.add("CLERK_WEBHOOK_SIGNING_SECRET");
  const deployment: any = {
    id: "89cff719-0e19-4648-ab09-63a37d806c95",
    source: "wrangler",
    strategy: "percentage",
    author_email: "discarded@example.invalid",
    annotations: { "workers/triggered_by": "deployment" },
    versions: [{
      version_id: productionLastKnownGoodWorker.versionId,
      percentage: 100,
    }],
    created_on: "2026-07-16T20:45:13.836364Z",
  };
  let malformedPending = options.malformedHistory !== undefined;
  let laggedHistory: any[] | undefined;
  let laggedSecretInventory: string[] | undefined;
  const pendingVersionViews = new Set<string>();

  const addVersion = (
    trigger: "secret" | "version_upload",
    bindings: any[],
    scriptEtag: string,
    tag: string,
    message: string,
  ) => {
    if (options.delayedVisibility) {
      laggedHistory = JSON.parse(JSON.stringify(history));
    }
    const number = history.at(-1)!.number + 1;
    const id = versionUUID(2, number);
    const created = `2026-07-21T05:00:${String(number).padStart(2, "0")}.000001Z`;
    history.push(historyEntry(id, number, created, trigger, tag, message));
    while (history.length > 10) history.shift();
    rawVersions.set(id, rawVersion(id, created, bindings, scriptEtag));
    if (options.delayedVisibility) pendingVersionViews.add(id);
    return id;
  };

  const run = async (specification: ProductionGreenfieldWorkerLineageCommandSpecification) => {
    if (Buffer.isBuffer(specification.stdin)) {
      stdinReferences.push(specification.stdin);
    }
    calls.push({
      command: specification.command,
      args: [...specification.args],
      environment: { ...specification.environment },
      ...(specification.stdin
        ? { stdin: Buffer.from(specification.stdin) }
        : {}),
    });
    const args = [...specification.args];
    if (args.length === 1 && args[0] === "--version") {
      return { stdout: specification.command === "cf"
        ? "🍊☁️  cf · v0.1.0\n"
        : "4.110.0\n" };
    }
    if (args[0] === "versions" && args[1] === "list") {
      if (malformedPending) {
        malformedPending = false;
        return { stdout: options.malformedHistory! };
      }
      if (laggedHistory) {
        const value = laggedHistory;
        laggedHistory = undefined;
        return { stdout: JSON.stringify(value) };
      }
      return { stdout: JSON.stringify(history) };
    }
    if (args[0] === "deployments" && args[1] === "status") {
      return { stdout: JSON.stringify(deployment) };
    }
    if (specification.command === "cf" && args.slice(0, 3).join(" ") === "workers secrets list") {
      if (laggedSecretInventory) {
        const value = laggedSecretInventory;
        laggedSecretInventory = undefined;
        return { stdout: JSON.stringify(value.sort().map((name) => ({
          name,
          type: "secret_text",
        }))) };
      }
      return { stdout: JSON.stringify([...secrets].sort().map((name) => ({
        name,
        type: "secret_text",
      }))) };
    }
    if (args[0] === "versions" && args[1] === "view") {
      const versionId = args[2];
      if (!versionId) throw new Error("fixture version id missing");
      if (pendingVersionViews.delete(versionId)) {
        throw new Error("fixture simulates a not-yet-visible exact version");
      }
      const value = rawVersions.get(versionId);
      if (!value) throw new Error("fixture version missing");
      return { stdout: JSON.stringify(value) };
    }
    if (args[0] === "versions" && args[1] === "secret" && args[2] === "put") {
      if (!specification.stdin) throw new Error("fixture requires secret stdin");
      const secretName = args[3];
      if (!secretName) throw new Error("fixture secret name missing");
      if (options.delayedVisibility) laggedSecretInventory = [...secrets];
      secrets.add(secretName);
      const previous = rawVersions.get(history.at(-1)!.id);
      const bindings = [
        ...previous.resources.bindings.filter((binding: any) => binding.name !== secretName),
        { name: secretName, type: "secret_text" },
      ];
      const id = addVersion(
        "secret",
        bindings,
        productionLastKnownGoodWorker.scriptEtag,
        optionValue(args, "--tag"),
        optionValue(args, "--message"),
      );
      const stage = secretName === "CLERK_WEBHOOK_SIGNING_SECRET"
        ? "webhook_secret_install"
        : "cutover_secret_install_source_s";
      if (options.deploymentDriftAt === stage) {
        deployment.versions = [{ version_id: id, percentage: 100 }];
      }
      return { stdout: "PROVIDER_OUTPUT_NOT_RECORDED" };
    }
    if (args[0] === "versions" && args[1] === "upload") {
      const writeMode = valueAfter(args, "--var", "WRITE_MODE:");
      const onboardingMode = valueAfter(args, "--var", "NEW_USER_ONBOARDING_MODE:");
      const stage = writeMode === "enabled"
        ? "accepted_b"
        : args.includes("greenfield-write-guard-g")
          ? "write_guard_g"
          : "candidate_a";
      addVersion(
        "version_upload",
        expectedProductionWorkerBindings(writeMode, onboardingMode),
        productionLastKnownGoodWorker.scriptEtag,
        optionValue(args, "--tag"),
        optionValue(args, "--message"),
      );
      if (options.concurrentAt === stage) {
        addVersion(
          "version_upload",
          expectedProductionWorkerBindings(writeMode, onboardingMode),
          productionLastKnownGoodWorker.scriptEtag,
          "concurrent-unreviewed-version",
          "Concurrent unreviewed version",
        );
      }
      return { stdout: "PROVIDER_OUTPUT_NOT_RECORDED" };
    }
    throw new Error(`unexpected fixture command: ${specification.command} ${args.join(" ")}`);
  };
  return { calls, run, stdinReferences };
}

function historyEntry(
  id: string,
  number: number,
  createdOn: string,
  trigger: string,
  tag?: string,
  message?: string,
) {
  return {
    id,
    number,
    metadata: {
      created_on: createdOn,
      source: "wrangler",
      author_id: "discarded-author-id",
      author_email: "discarded@example.invalid",
      has_preview: false,
    },
    annotations: {
      "workers/triggered_by": trigger,
      ...(tag ? { "workers/tag": tag } : {}),
      ...(message ? { "workers/message": message } : {}),
    },
  };
}

function rawVersion(
  id: string,
  createdOn: string,
  bindings: any[],
  scriptEtag: string,
) {
  return {
    id,
    metadata: {
      created_on: createdOn,
      author_email: "discarded@example.invalid",
    },
    resources: {
      script: {
        etag: scriptEtag,
        placement_mode: "smart",
        placement: { mode: "smart" },
        handlers: ["fetch", "scheduled", "queue"],
      },
      script_runtime: {
        compatibility_date: "2026-07-14",
        compatibility_flags: ["nodejs_compat"],
        usage_model: "standard",
      },
      bindings,
    },
  };
}

function initialSecretNames() {
  return productionWorkerSecretNames.filter((name) =>
    name !== "CLERK_WEBHOOK_SIGNING_SECRET"
      && name !== cutoverAcceptance.tokenSecretName);
}

function lastKnownGoodBindings(secretNames: readonly string[]) {
  return expectedProductionWorkerBindings("disabled", "disabled")
    .filter((binding: any) =>
      binding.name !== "IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST"
        && binding.name !== "IDENTITY_RECONCILIATION_RECEIPT"
        && (binding.type !== "secret_text" || secretNames.includes(binding.name)))
    .map((binding: any) => {
      if (binding.name === "EXPECTED_DATABASE_ROLE_ID") {
        return { ...binding, text: productionLastKnownGoodWorker.runtimeRoleId };
      }
      if (binding.name === "HYPERDRIVE") {
        return { ...binding, id: productionLastKnownGoodWorker.hyperdriveId };
      }
      return binding;
    });
}

function versionUUID(prefix: number, number: number) {
  return `${prefix}0000000-0000-4000-8000-${String(number).padStart(12, "0")}`;
}

function valueAfter(args: string[], flag: string, prefix: string) {
  for (let index = 0; index < args.length - 1; index += 1) {
    const value = args[index + 1];
    if (args[index] === flag && value?.startsWith(prefix)) {
      return value.slice(prefix.length);
    }
  }
  throw new Error(`fixture argument missing: ${prefix}`);
}

function optionValue(args: string[], flag: string) {
  const index = args.indexOf(flag);
  const value = args[index + 1];
  if (index < 0 || !value) throw new Error(`fixture option missing: ${flag}`);
  return value;
}
