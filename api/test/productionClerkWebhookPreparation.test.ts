import { EventEmitter } from "node:events";
import { readFile } from "node:fs/promises";
import { PassThrough } from "node:stream";
import { describe, expect, it, vi } from "vitest";
import {
  loadProductionClerkWebhookPortalProtocol,
  parseProductionClerkWebhookSvixURL,
  productionClerkWebhookCommands,
  productionClerkWebhookPortalContract,
  productionClerkWebhookPreparationGate,
  productionClerkWebhookTarget,
  runProductionClerkWebhookPreparationCLI,
  runProductionClerkWebhookPreparationCommand,
  validateProductionClerkWebhookPreparationReceipt,
  validateProductionClerkWebhookPreparationSources,
  withProductionClerkWebhookSecret,
  type ProductionClerkWebhookPreparationCommandSpecification,
} from "../scripts/prepare-production-clerk-webhook.mjs";
import { computeSanitizedReceiptSha256 } from
  "../scripts/greenfield-launch-packet.mjs";

const signingSecretPrefix = ["wh", "sec", "_"].join("");
const clerkSecretKeyPrefix = ["sk", "live", ""].join("_");
const clerkAuthEnvironmentPrefix = ["app", "sk", "_"].join("");
const fakeSigningSecret =
  `${signingSecretPrefix}not-a-real-production-signing-secret-123456789`;
const fakePortalToken = "not-a-real-portal-token-1234567890";
const fakeOneTimeToken = "not-a-real-one-time-token-1234567890";
const portalProtocolReceipt = Object.freeze({
  portalOrigin: "https://app.svix.com" as const,
  loginURL: "https://app.svix.com/login" as const,
  assetPath: productionClerkWebhookPortalContract.assetPath,
  assetSha256: productionClerkWebhookPortalContract.assetSha256,
});
const reviewedSourceReceipt = Object.freeze({
  clerkBackendVersion: "3.11.4" as const,
  clerkCliVersion: "2.2.0" as const,
  clerkLockContractSha256:
    "4a4bab3d651b0333b4a87ccae0c05a656898babe05210bc47c5f93a8664c6ae4",
  launchPacketSha256:
    "21b671ba5a5f585fe8ee4982a0ca1dfa570d15bbe23eb20c8f3e219e18772508",
  portalAssetPath: productionClerkWebhookPortalContract.assetPath,
  portalAssetSha256: productionClerkWebhookPortalContract.assetSha256,
});

describe("production Clerk webhook preparation", () => {
  it("pins the local Clerk CLI, exact app/instance commands, and disabled endpoint", () => {
    expect(productionClerkWebhookCommands.version).toEqual({
      command: "./node_modules/.bin/clerk",
      args: ["--version"],
    });
    for (const command of [
      productionClerkWebhookCommands.userCount,
      productionClerkWebhookCommands.svixURL,
    ]) {
      expect(command.command).toBe("./node_modules/.bin/clerk");
      expect(command.args).toContain("--app");
      expect(command.args).toContain(productionClerkWebhookTarget.clerkApplicationId);
      expect(command.args).toContain("--instance");
      expect(command.args).toContain(productionClerkWebhookTarget.clerkInstanceId);
      expect(command.args).not.toContain("--secret-key");
    }
    expect(productionClerkWebhookTarget).toMatchObject({
      endpointUid: "refwatch-production-clerk-lifecycle-v1",
      endpointURL: "https://api.refwatch.ibby.ai/webhooks/clerk",
      eventTypes: ["user.created", "user.updated", "user.deleted"],
      disabled: true,
    });
  });

  it("keeps --check local and disables standalone --execute", async () => {
    const checkSources = vi.fn(async () => ({}));
    const stdout = vi.fn();
    const stderr = vi.fn();

    await expect(runProductionClerkWebhookPreparationCLI({
      args: ["--check"],
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).resolves.toBe(0);

    expect(checkSources).toHaveBeenCalledOnce();
    expect(stdout).toHaveBeenCalledWith(
      "Production Clerk webhook preparation sources verified.\n",
    );
    expect(stderr).not.toHaveBeenCalled();

    expect(await runProductionClerkWebhookPreparationCLI({
      args: ["--execute"],
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(2);
    expect(checkSources).toHaveBeenCalledOnce();
    expect(stderr).toHaveBeenLastCalledWith(
      "Standalone production Clerk webhook preparation is disabled; use the reviewed same-process cutover orchestrator.\n",
    );
  });

  it("fails local source and lockfile drift", async () => {
    const source = await sourceInput();
    expect(() => validateProductionClerkWebhookPreparationSources(source))
      .not.toThrow();

    const packageJSON = JSON.parse(source.packageJSON);
    packageJSON.devDependencies.clerk = "^2.2.0";
    expect(() => validateProductionClerkWebhookPreparationSources({
      ...source,
      packageJSON: JSON.stringify(packageJSON),
    })).toThrow("reviewed sources drifted");

    const packageLock = JSON.parse(source.packageLock);
    packageLock.packages["node_modules/clerk"].integrity = "sha512-drift";
    expect(() => validateProductionClerkWebhookPreparationSources({
      ...source,
      packageLock: JSON.stringify(packageLock),
    })).toThrow("reviewed sources drifted");

    expect(() => validateProductionClerkWebhookPreparationSources({
      ...source,
      launchPacket: Buffer.concat([
        Buffer.from(source.launchPacket),
        Buffer.from("\n"),
      ]),
    })).toThrow("reviewed sources drifted");
  });

  it("keeps the gate closed before any command or fetch", async () => {
    const runCommand = vi.fn();
    const fetchProvider = vi.fn();
    const consumer = vi.fn();
    await expect(withProductionClerkWebhookSecret(consumer, {
      environment: {},
      runCommand,
      fetchProvider,
    })).rejects.toThrow("gate is closed");
    expect(runCommand).not.toHaveBeenCalled();
    expect(fetchProvider).not.toHaveBeenCalled();
    expect(consumer).not.toHaveBeenCalled();
  });

  it("reuses one exact disabled endpoint, binds three zero reads, and wipes the Buffer", async () => {
    const harness = providerHarness({ endpoints: [exactEndpoint()] });
    let callbackBuffer: Buffer | undefined;
    let callbackSecret = "";
    const receipt = await withProductionClerkWebhookSecret(
      async ({ secretMaterial, receipt: value }) => {
        callbackBuffer = secretMaterial;
        callbackSecret = secretMaterial.toString("utf8");
        expect(Buffer.isBuffer(secretMaterial)).toBe(true);
        expect(JSON.stringify(value)).not.toContain(fakeSigningSecret);
        return value;
      },
      harness.options,
    );

    expect(callbackSecret).toBe(fakeSigningSecret);
    expect(callbackBuffer).toBeDefined();
    expect(callbackBuffer?.every((byte) => byte === 0)).toBe(true);
    expect(receipt).toMatchObject({
      operation: "reused",
      clerk: {
        application_id: productionClerkWebhookTarget.clerkApplicationId,
        instance_id: productionClerkWebhookTarget.clerkInstanceId,
        initial_user_count: 0,
        pre_reconciliation_user_count: 0,
        post_reconciliation_user_count: 0,
      },
      svix: {
        endpoint_id: "ep_refwatch123",
        endpoint_uid: productionClerkWebhookTarget.endpointUid,
        endpoint_url: productionClerkWebhookTarget.endpointURL,
        event_types: ["user.created", "user.updated", "user.deleted"],
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
        event_types: ["user.created", "user.updated", "user.deleted"],
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
    });
    expect(harness.userCountCalls()).toBe(3);
    expect(harness.createCalls()).toBe(0);
    expect(harness.secretCalls()).toBe(1);
    expect(JSON.stringify(receipt)).not.toMatch(new RegExp(
      `(?:${signingSecretPrefix}|not-a-real-portal-token|not-a-real-one-time-token)`,
      "u",
    ));
  });

  it("leases an opaque exact-read and compare-and-set controller only for the callback", async () => {
    const harness = providerHarness({ endpoints: [exactEndpoint()] });
    let escapedController: any;
    const result = await withProductionClerkWebhookSecret(
      async ({ controller }) => {
        escapedController = controller;
        expect(Object.isFrozen(controller)).toBe(true);
        expect(JSON.stringify(controller)).toBe("{}");
        const initial = await controller.readExact();
        expect(initial).toMatchObject({
          clerk_cli_version: "2.2.0",
          clerk_application_id: productionClerkWebhookTarget.clerkApplicationId,
          clerk_instance_id: productionClerkWebhookTarget.clerkInstanceId,
          user_count: 0,
          svix_application_id: "app_svixRefWatch123",
          endpoint_inventory_count: 1,
          endpoint_id: "ep_refwatch123",
          disabled: true,
          header_count: 0,
          sensitive_header_name_count: 0,
          transformation_enabled: false,
          transformation_present: false,
        });
        expect(JSON.stringify(initial)).not.toContain(fakePortalToken);

        const transition = await controller.setDisabled(true, false);
        expect(transition).toMatchObject({
          operation: "set_disabled",
          expected_disabled: true,
          disabled: false,
          before: { disabled: true },
          after: { disabled: false },
        });
        expect(JSON.stringify(transition)).not.toMatch(new RegExp(
          `(?:${fakePortalToken}|${signingSecretPrefix})`,
          "u",
        ));
        return transition.after;
      },
      harness.options,
    );

    expect(result.disabled).toBe(false);
    expect(harness.patchCalls()).toBe(1);
    expect(harness.patchedBodies).toEqual([{ disabled: false }]);
    await expect(escapedController.readExact()).rejects.toThrow(
      "without disclosing provider output",
    );
    await expect(escapedController.setDisabled(false, true)).rejects.toThrow(
      "without disclosing provider output",
    );
  });

  it.each(["malformed", "redirect", "timeout", "throw"] as const)(
    "fails a %s controller transition generically without echoing provider material",
    async (patchResponseMode) => {
      const marker = `CONTROLLER_${patchResponseMode.toUpperCase()}_MARKER`;
      const harness = providerHarness({
        endpoints: [exactEndpoint()],
        patchResponseMode,
        fetchFailureMarker: marker,
      });
      let message = "";
      await expect(withProductionClerkWebhookSecret(
        async ({ controller }) => {
          try {
            await controller.setDisabled(true, false);
          } catch (error) {
            message = error instanceof Error ? error.message : String(error);
            throw error;
          }
        },
        harness.options,
      )).rejects.toThrow("without disclosing provider output");
      expect(message).toBe(
        "Production Clerk webhook preparation failed without disclosing provider output",
      );
      expect(message).not.toMatch(new RegExp(
        `(?:${marker}|${fakePortalToken}|${signingSecretPrefix})`,
        "u",
      ));
      expect(harness.patchCalls()).toBe(1);
    },
  );

  it("refuses stale compare-and-set state and concurrent controller use before mutation", async () => {
    const harness = providerHarness({ endpoints: [exactEndpoint()] });
    await withProductionClerkWebhookSecret(async ({ controller }) => {
      await expect(controller.setDisabled(false, true)).rejects.toThrow(
        "without disclosing provider output",
      );
      expect(harness.patchCalls()).toBe(0);

      const first = controller.readExact();
      await expect(controller.readExact()).rejects.toThrow(
        "without disclosing provider output",
      );
      await first;
    }, harness.options);
  });

  it("rejects re-sealed final provider readback forgeries", async () => {
    const harness = providerHarness({ endpoints: [exactEndpoint()] });
    const base: any = await withProductionClerkWebhookSecret(
      async ({ receipt }) => receipt,
      harness.options,
    );
    const cases: Array<[string, (receipt: any) => void]> = [
      ["inventory", (receipt) => {
        receipt.final_provider_readback.endpoint_inventory_count = 2;
      }],
      ["endpoint id", (receipt) => {
        receipt.final_provider_readback.endpoint_id = "ep_forged123";
      }],
      ["description", (receipt) => {
        receipt.final_provider_readback.endpoint_description = "Forged";
      }],
      ["headers", (receipt) => {
        receipt.final_provider_readback.header_count = 1;
      }],
      ["transformation", (receipt) => {
        receipt.final_provider_readback.transformation_enabled = true;
      }],
    ];
    for (const [label, mutate] of cases) {
      const receipt = JSON.parse(JSON.stringify(base));
      mutate(receipt);
      const payload = Object.fromEntries(
        Object.entries(receipt).filter(([key]) => key !== "receipt_sha256"),
      );
      receipt.receipt_sha256 = computeSanitizedReceiptSha256(payload);
      expect(
        () => validateProductionClerkWebhookPreparationReceipt(receipt),
        label,
      ).toThrow("without disclosing provider output");
    }
  });

  it("uses fixed argv and an isolated environment with no secret inputs", async () => {
    const harness = providerHarness({ endpoints: [exactEndpoint()] }, {
      environment: {
        [productionClerkWebhookPreparationGate]: "1",
        PATH: "/usr/bin",
        HOME: "/tmp/fake-home",
        CLERK_SECRET_KEY: `${clerkSecretKeyPrefix}should-not-cross`,
        CLERK_AUTH_ENVIRONMENTS:
          `${clerkAuthEnvironmentPrefix}should-not-cross`,
        CLOUDFLARE_API_BASE_URL: "https://attacker.invalid",
      },
    });
    await withProductionClerkWebhookSecret(async () => undefined, harness.options);

    expect(harness.commandCalls).toHaveLength(6);
    expect(harness.commandCalls.map((call) => call.args)).toEqual([
      [...productionClerkWebhookCommands.version.args],
      [...productionClerkWebhookCommands.whoami.args],
      [...productionClerkWebhookCommands.userCount.args],
      [...productionClerkWebhookCommands.svixURL.args],
      [...productionClerkWebhookCommands.userCount.args],
      [...productionClerkWebhookCommands.userCount.args],
    ]);
    for (const call of harness.commandCalls) {
      expect(call.command).toBe("./node_modules/.bin/clerk");
      expect(call.args.join(" ")).not.toMatch(new RegExp(
        `(?:--secret-key|${clerkSecretKeyPrefix}|${clerkAuthEnvironmentPrefix}|${signingSecretPrefix})`,
        "u",
      ));
      expect(call.environment).toEqual({
        PATH: "/usr/bin",
        HOME: "/tmp/fake-home",
        CI: "1",
        NO_COLOR: "1",
        NPM_CONFIG_UPDATE_NOTIFIER: "false",
      });
    }
  });

  it("verifies the portal protocol before requesting the sensitive svix URL", async () => {
    const events: string[] = [];
    const harness = providerHarness({ endpoints: [exactEndpoint()] }, {
      onCommand: (specification) => {
        if (sameCommand(specification, productionClerkWebhookCommands.svixURL)) {
          events.push("svix_url");
        }
      },
      loadPortalProtocol: async () => {
        events.push("portal_protocol");
        return portalProtocolReceipt;
      },
    });
    await withProductionClerkWebhookSecret(async () => undefined, harness.options);
    expect(events).toEqual(["portal_protocol", "svix_url"]);
  });

  it.each([
    ["wrong CLI", { version: "2.2.1" }],
    ["wrong app", { whoami: whoami({ appId: "app_wrong" }) }],
    ["wrong production instance", {
      whoami: whoami({ productionInstanceId: "ins_wrong" }),
    }],
    ["nonzero initial users", { userCounts: [1] }],
    ["string user count", { rawUserCounts: ["0"] }],
  ])("fails %s before any Svix mutation", async (_label, configuration) => {
    const harness = providerHarness(configuration as HarnessConfiguration);
    await expect(withProductionClerkWebhookSecret(
      async () => undefined,
      harness.options,
    )).rejects.toThrow("without disclosing provider output");
    expect(harness.createCalls()).toBe(0);
    expect(harness.secretCalls()).toBe(0);
  });

  it("creates one exact disabled endpoint and never includes a secret", async () => {
    const harness = providerHarness({ endpoints: [] });
    const receipt = await withProductionClerkWebhookSecret(
      async ({ receipt: value }) => value,
      harness.options,
    );
    expect(harness.createCalls()).toBe(1);
    expect(harness.createdBodies).toEqual([{
      description: productionClerkWebhookTarget.endpointDescription,
      disabled: true,
      filterTypes: ["user.created", "user.updated", "user.deleted"],
      uid: productionClerkWebhookTarget.endpointUid,
      url: productionClerkWebhookTarget.endpointURL,
    }]);
    expect(JSON.stringify(harness.createdBodies)).not.toContain("secret");
    expect(receipt.operation).toBe("created");
  });

  it("re-lists after a lost create response and never repeats POST", async () => {
    const harness = providerHarness({
      endpoints: [],
      loseCreateResponse: true,
    });
    const receipt = await withProductionClerkWebhookSecret(
      async ({ receipt: value }) => value,
      harness.options,
    );
    expect(receipt.operation).toBe("created");
    expect(harness.createCalls()).toBe(1);
    expect(harness.listCalls()).toBe(3);
  });

  it.each([
    ["wrong URL", { ...exactEndpoint(), url: "https://wrong.example/webhooks/clerk" }],
    ["wrong events", { ...exactEndpoint(), filterTypes: ["user.created"] }],
    ["enabled", { ...exactEndpoint(), disabled: false }],
    ["channels", { ...exactEndpoint(), channels: ["unexpected"] }],
    ["metadata", { ...exactEndpoint(), metadata: { unexpected: "value" } }],
    ["throttle", { ...exactEndpoint(), throttleRate: 1 }],
  ])("fails a conflicting target endpoint with %s", async (_label, endpoint) => {
    const harness = providerHarness({ endpoints: [endpoint] });
    await expect(withProductionClerkWebhookSecret(
      async () => undefined,
      harness.options,
    )).rejects.toThrow("without disclosing provider output");
    expect(harness.createCalls()).toBe(0);
    expect(harness.secretCalls()).toBe(0);
  });

  it.each([
    ["one unrelated endpoint", [exactEndpoint({
      id: "ep_unrelated123",
      uid: "unrelated-production-endpoint",
      url: "https://unrelated.example/webhook",
    })]],
    ["the exact endpoint plus another endpoint", [
      exactEndpoint(),
      exactEndpoint({
        id: "ep_unrelated456",
        uid: "unrelated-production-endpoint",
        url: "https://unrelated.example/webhook",
      }),
    ]],
  ])("fails zero-legacy inventory with %s", async (_label, endpoints) => {
    const harness = providerHarness({ endpoints });
    await expect(withProductionClerkWebhookSecret(
      async () => undefined,
      harness.options,
    )).rejects.toThrow("without disclosing provider output");
    expect(harness.createCalls()).toBe(0);
    expect(harness.secretCalls()).toBe(0);
  });

  it("fails duplicate exact endpoints across bounded pages", async () => {
    const harness = providerHarness({
      pages: [
        { data: [exactEndpoint()], done: false, iterator: "next-page" },
        {
          data: [exactEndpoint({ id: "ep_refwatch456" })],
          done: true,
          iterator: null,
        },
      ],
    });
    await expect(withProductionClerkWebhookSecret(
      async () => undefined,
      harness.options,
    )).rejects.toThrow("without disclosing provider output");
    expect(harness.createCalls()).toBe(0);
  });

  it.each([
    ["missing capability", ["ManageEndpoint"]],
    ["unknown capability", [
      "ManageEndpoint",
      "ViewEndpointSecret",
      "UnknownCapability",
    ]],
  ])("fails token exchange for %s", async (_label, capabilities) => {
    const harness = providerHarness({ capabilities });
    await expect(withProductionClerkWebhookSecret(
      async () => undefined,
      harness.options,
    )).rejects.toThrow("without disclosing provider output");
    expect(harness.createCalls()).toBe(0);
  });

  it("fails a nonzero post-reconciliation user readback before reading the secret", async () => {
    const harness = providerHarness({
      endpoints: [exactEndpoint()],
      userCounts: [0, 0, 1],
    });
    await expect(withProductionClerkWebhookSecret(
      async () => undefined,
      harness.options,
    )).rejects.toThrow("without disclosing provider output");
    expect(harness.secretCalls()).toBe(0);
  });

  it.each([
    ["ordinary headers", { headers: { "x-review": "drift" }, sensitive: [] }, undefined],
    ["sensitive header names", { headers: {}, sensitive: ["authorization"] }, undefined],
    ["enabled transformation", undefined, { enabled: true }],
    ["transformation code", undefined, { enabled: false, code: "return payload" }],
    ["transformation variables", undefined, {
      enabled: false,
      variables: { environment: "production" },
    }],
    ["transformation timestamp", undefined, {
      enabled: false,
      updatedAt: "2026-07-21T09:00:00.000Z",
    }],
  ])("fails behavior-affecting endpoint state with %s", async (
    _label,
    endpointHeaders,
    endpointTransformation,
  ) => {
    const harness = providerHarness({
      endpoints: [exactEndpoint()],
      ...(endpointHeaders ? { endpointHeaders } : {}),
      ...(endpointTransformation ? { endpointTransformation } : {}),
    });
    await expect(withProductionClerkWebhookSecret(
      async () => undefined,
      harness.options,
    )).rejects.toThrow("without disclosing provider output");
    expect(harness.secretCalls()).toBe(0);
  });

  it.each([
    ["an additional endpoint", {
      finalEndpoints: [
        exactEndpoint(),
        exactEndpoint({
          id: "ep_unrelated789",
          uid: "unrelated-final-endpoint",
          url: "https://unrelated.example/final-webhook",
        }),
      ],
    }],
    ["a replaced endpoint ID", {
      finalEndpoints: [exactEndpoint({ id: "ep_replaced123" })],
    }],
    ["a changed description", {
      finalEndpoints: [exactEndpoint({ description: "Changed after secret" })],
    }],
    ["changed events", {
      finalEndpoints: [exactEndpoint({ filterTypes: ["user.created"] })],
    }],
    ["an enabled endpoint", {
      finalEndpoints: [exactEndpoint({ disabled: false })],
    }],
    ["new headers", {
      finalEndpointHeaders: { headers: { "x-final": "drift" }, sensitive: [] },
    }],
    ["a new transformation", {
      finalEndpointTransformation: { enabled: true },
    }],
  ])("fails final post-secret readback with %s", async (_label, drift) => {
    const harness = providerHarness({
      endpoints: [exactEndpoint()],
      ...drift,
    });
    const consumer = vi.fn();
    let error: unknown;
    try {
      await withProductionClerkWebhookSecret(consumer, harness.options);
    } catch (caught) {
      error = caught;
    }
    expect(String(error)).toBe(
      "Error: Production Clerk webhook preparation failed without disclosing provider output",
    );
    expect(String(error)).not.toContain(fakeSigningSecret);
    expect(harness.secretCalls()).toBe(1);
    expect(consumer).not.toHaveBeenCalled();
  });

  it.each([
    "redirect",
    "content-type",
    "declared-overflow",
    "streaming-overflow",
    "timeout",
  ] as const)("fails the authenticated fetch boundary for %s", async (mode) => {
    const marker = "SENSITIVE_FETCH_BOUNDARY_MARKER";
    const harness = providerHarness({
      exchangeResponseMode: mode,
      fetchFailureMarker: marker,
    });
    let error: unknown;
    try {
      await withProductionClerkWebhookSecret(
        async () => undefined,
        harness.options,
      );
    } catch (caught) {
      error = caught;
    }
    expect(String(error)).toBe(
      "Error: Production Clerk webhook preparation failed without disclosing provider output",
    );
    expect(String(error)).not.toContain(marker);
    expect(harness.listCalls()).toBe(0);
    expect(harness.createCalls()).toBe(0);
    expect(harness.secretCalls()).toBe(0);
  });

  it.each([
    "missing",
    "bad-prefix-value-123456789012345",
    `${signingSecretPrefix}short`,
    `${signingSecretPrefix}${"x".repeat(600)}`,
    `${signingSecretPrefix}contains\nnewline123456789`,
  ])("fails malformed signing secret %s without echo", async (secret) => {
    const harness = providerHarness({
      endpoints: [exactEndpoint()],
      signingSecret: secret,
    });
    let error: unknown;
    try {
      await withProductionClerkWebhookSecret(async () => undefined, harness.options);
    } catch (caught) {
      error = caught;
    }
    expect(String(error)).toBe(
      "Error: Production Clerk webhook preparation failed without disclosing provider output",
    );
    expect(String(error)).not.toContain(secret);
  });

  it.each([
    ["an extra property", `{"key":"${fakeSigningSecret}","extra":true}`],
    ["a duplicate key", `{"key":"${fakeSigningSecret}","key":"${fakeSigningSecret}"}`],
    ["an escaped value", `{"key":"${signingSecretPrefix}escaped\\u0031value-123456789"}`],
    ["an escaped key", `{"k\\u0065y":"${fakeSigningSecret}"}`],
    ["trailing JSON", `{"key":"${fakeSigningSecret}"}[]`],
  ])("rejects mutable-byte secret JSON with %s", async (_label, rawSecretResponseBody) => {
    const harness = providerHarness({
      endpoints: [exactEndpoint()],
      rawSecretResponseBody,
    });
    let error: unknown;
    try {
      await withProductionClerkWebhookSecret(
        async () => undefined,
        harness.options,
      );
    } catch (caught) {
      error = caught;
    }
    expect(String(error)).toBe(
      "Error: Production Clerk webhook preparation failed without disclosing provider output",
    );
    expect(String(error)).not.toContain(fakeSigningSecret);
  });

  it("wipes the signing Buffer when the consumer throws", async () => {
    const harness = providerHarness({ endpoints: [exactEndpoint()] });
    let buffer: Buffer | undefined;
    let error: unknown;
    try {
      await withProductionClerkWebhookSecret(async ({ secretMaterial }) => {
        buffer = secretMaterial;
        throw new Error(`consumer failed ${fakeSigningSecret}`);
      }, harness.options);
    } catch (caught) {
      error = caught;
    }
    expect(String(error)).toBe(
      "Error: Production Clerk webhook preparation failed without disclosing provider output",
    );
    expect(String(error)).not.toContain(fakeSigningSecret);
    expect(buffer?.every((byte) => byte === 0)).toBe(true);
  });

  it("rejects portal asset drift before an authenticated svix_url call", async () => {
    const fetchProvider = vi.fn(async (input: string | URL | Request) => {
      const url = String(input);
      if (url === "https://app.svix.com/login") {
        return textResponse(
          '<script type="module" src="/assets/index-drifted.js"></script>',
          "text/html",
        );
      }
      throw new Error("asset must not be fetched");
    });
    await expect(loadProductionClerkWebhookPortalProtocol({ fetchProvider }))
      .rejects.toThrow("without disclosing provider output");
    expect(fetchProvider).toHaveBeenCalledOnce();
  });

  it("rejects the pinned asset when its digest or protocol drifts", async () => {
    const fetchProvider = vi.fn(async (input: string | URL | Request) => {
      const url = String(input);
      if (url === "https://app.svix.com/login") {
        return textResponse(
          `<script type="module" src="${productionClerkWebhookPortalContract.assetPath}"></script>`,
          "text/html",
        );
      }
      return textResponse(
        "/api/v1/auth/one-time-token oneTimeToken ManageEndpoint ViewEndpointSecret",
        "text/javascript",
      );
    });
    await expect(loadProductionClerkWebhookPortalProtocol({ fetchProvider }))
      .rejects.toThrow("without disclosing provider output");
    expect(fetchProvider).toHaveBeenCalledTimes(2);
  });

  it.each([
    "http://app.svix.com/login#key=abc",
    "https://evil.example/login#key=abc",
    "https://app.svix.com/login?key=secret#key=abc",
    "https://app.svix.com/login#key=abc&key=def",
    magicURL({ region: "unknown" }),
    magicURL({ serverUrl: "https://evil.example" }),
    magicURL({ streamId: "stream_123", appId: undefined }),
  ])("rejects malformed magic URL without echo: %s", (value) => {
    expect(() => parseProductionClerkWebhookSvixURL(value))
      .toThrow("without disclosing provider output");
    try {
      parseProductionClerkWebhookSvixURL(value);
    } catch (error) {
      expect(String(error)).not.toContain(fakeOneTimeToken);
    }
  });

  it("settles after kill grace and wipes output when a timed-out child never closes", async () => {
    const child = fakeClerkChild();
    const marker = Buffer.from(fakeSigningSecret);
    const result = runProductionClerkWebhookPreparationCommand({
      command: "./node_modules/.bin/clerk",
      args: ["--version"],
      cwd: process.cwd(),
      environment: {},
    }, {
      spawnImpl: () => child as never,
      timeoutMs: 5,
      killGraceMs: 5,
    });
    child.stdout.emit("data", marker);
    await expect(result).rejects.toThrow("without disclosing provider output");
    expect(child.kill).toHaveBeenNthCalledWith(1, "SIGTERM");
    expect(child.kill).toHaveBeenNthCalledWith(2, "SIGKILL");
    expect(marker.every((byte) => byte === 0)).toBe(true);
  });

  it.each(["stdout", "stderr"] as const)(
    "fails %s overflow generically, wipes the marker, and forces termination",
    async (stream) => {
      const child = fakeClerkChild();
      const marker = Buffer.from(fakeSigningSecret);
      const result = runProductionClerkWebhookPreparationCommand({
        command: "./node_modules/.bin/clerk",
        args: ["--version"],
        cwd: process.cwd(),
        environment: {},
      }, {
        spawnImpl: () => child as never,
        timeoutMs: 2_000,
        maxOutputBytes: 8,
        killGraceMs: 5,
      });
      child[stream].emit("data", marker);
      let error: unknown;
      try {
        await result;
      } catch (caught) {
        error = caught;
      }
      expect(String(error)).toBe(
        "Error: Production Clerk webhook preparation failed without disclosing provider output",
      );
      expect(String(error)).not.toContain(fakeSigningSecret);
      expect(marker.every((byte) => byte === 0)).toBe(true);
      expect(child.kill).toHaveBeenNthCalledWith(1, "SIGTERM");
      expect(child.kill).toHaveBeenNthCalledWith(2, "SIGKILL");
    },
  );

  it.each(["nonzero", "error"] as const)(
    "fails a child %s generically and wipes captured stdout",
    async (failure) => {
      const child = fakeClerkChild();
      const marker = Buffer.from(fakeSigningSecret);
      const result = runProductionClerkWebhookPreparationCommand({
        command: "./node_modules/.bin/clerk",
        args: ["--version"],
        cwd: process.cwd(),
        environment: {},
      }, {
        spawnImpl: () => child as never,
        timeoutMs: 2_000,
        killGraceMs: 5,
      });
      child.stdout.emit("data", marker);
      if (failure === "nonzero") child.emit("close", 1);
      else child.emit("error", new Error(fakeSigningSecret));
      let error: unknown;
      try {
        await result;
      } catch (caught) {
        error = caught;
      }
      expect(String(error)).toBe(
        "Error: Production Clerk webhook preparation failed without disclosing provider output",
      );
      expect(String(error)).not.toContain(fakeSigningSecret);
      expect(marker.every((byte) => byte === 0)).toBe(true);
    },
  );

  it("fails a synchronous spawn error without echoing its marker", async () => {
    let error: unknown;
    try {
      await runProductionClerkWebhookPreparationCommand({
        command: "./node_modules/.bin/clerk",
        args: ["--version"],
        cwd: process.cwd(),
        environment: {},
      }, {
        spawnImpl: () => {
          throw new Error(fakeSigningSecret);
        },
      });
    } catch (caught) {
      error = caught;
    }
    expect(String(error)).toBe(
      "Error: Production Clerk webhook preparation failed without disclosing provider output",
    );
    expect(String(error)).not.toContain(fakeSigningSecret);
  });

  it("clears success timers and wipes captured chunks after returning a copy", async () => {
    const child = fakeClerkChild();
    const marker = Buffer.from(fakeSigningSecret);
    const result = runProductionClerkWebhookPreparationCommand({
      command: "./node_modules/.bin/clerk",
      args: ["--version"],
      cwd: process.cwd(),
      environment: {},
    }, {
      spawnImpl: () => child as never,
      timeoutMs: 5,
      killGraceMs: 5,
    });
    child.stdout.emit("data", marker);
    child.emit("close", 0);
    const completed = await result;
    expect(Buffer.from(completed.stdout).toString("utf8")).toBe(fakeSigningSecret);
    expect(marker.every((byte) => byte === 0)).toBe(true);
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 15));
    expect(child.kill).not.toHaveBeenCalled();
    if (Buffer.isBuffer(completed.stdout)) completed.stdout.fill(0);
  });
});

interface HarnessConfiguration {
  version?: string;
  whoami?: unknown;
  userCounts?: number[];
  rawUserCounts?: unknown[];
  capabilities?: string[];
  endpoints?: Record<string, unknown>[];
  pages?: Array<Record<string, unknown>>;
  endpointHeaders?: unknown;
  endpointTransformation?: unknown;
  finalEndpoints?: Record<string, unknown>[];
  finalEndpointHeaders?: unknown;
  finalEndpointTransformation?: unknown;
  signingSecret?: string;
  rawSecretResponseBody?: string;
  loseCreateResponse?: boolean;
  exchangeResponseMode?:
    | "redirect"
    | "content-type"
    | "declared-overflow"
    | "streaming-overflow"
    | "timeout";
  patchResponseMode?: "malformed" | "redirect" | "timeout" | "throw";
  fetchFailureMarker?: string;
}

function providerHarness(
  configuration: HarnessConfiguration = {},
  overrides: {
    environment?: NodeJS.ProcessEnv;
    onCommand?: (
      specification: ProductionClerkWebhookPreparationCommandSpecification,
    ) => void;
    loadPortalProtocol?: () => Promise<typeof portalProtocolReceipt>;
  } = {},
) {
  const commandCalls: ProductionClerkWebhookPreparationCommandSpecification[] = [];
  const counts = configuration.rawUserCounts
    ? [...configuration.rawUserCounts]
    : [...(configuration.userCounts ?? [0, 0, 0])].map((total_count) => ({
      object: "total_count",
      total_count,
    }));
  let userCountCallCount = 0;
  let endpointState = [...(configuration.endpoints ?? [])];
  let createCallCount = 0;
  let listCallCount = 0;
  let secretCallCount = 0;
  let patchCallCount = 0;
  let secretRead = false;
  const createdBodies: unknown[] = [];
  const patchedBodies: unknown[] = [];

  const runCommand = vi.fn(async (
    specification: ProductionClerkWebhookPreparationCommandSpecification,
  ) => {
    commandCalls.push({
      ...specification,
      args: [...specification.args],
      environment: { ...specification.environment },
    });
    overrides.onCommand?.(specification);
    if (sameCommand(specification, productionClerkWebhookCommands.version)) {
      return output(configuration.version ?? "2.2.0");
    }
    if (sameCommand(specification, productionClerkWebhookCommands.whoami)) {
      return output(configuration.whoami ?? whoami());
    }
    if (sameCommand(specification, productionClerkWebhookCommands.userCount)) {
      const value = counts[userCountCallCount] ?? counts.at(-1);
      userCountCallCount += 1;
      return output(value);
    }
    if (sameCommand(specification, productionClerkWebhookCommands.svixURL)) {
      return output({ svix_url: magicURL() });
    }
    throw new Error("unexpected command");
  });

  const fetchProvider = vi.fn(async (
    input: string | URL | Request,
    init?: RequestInit,
  ) => {
    const url = new URL(String(input));
    const method = init?.method ?? "GET";
    expect(init?.redirect).toBe("error");
    if (url.pathname === "/api/us/api/v1/auth/one-time-token") {
      expect(method).toBe("POST");
      expect(init?.headers).toMatchObject({
        authorization: "Bearer unused",
        "content-type": "application/json",
      });
      expect(JSON.parse(String(init?.body))).toEqual({
        oneTimeToken: fakeOneTimeToken,
      });
      const marker = configuration.fetchFailureMarker
        ?? "FETCH_BOUNDARY_MARKER";
      if (configuration.exchangeResponseMode === "redirect") {
        const response = jsonResponse({ marker });
        Object.defineProperty(response, "redirected", { value: true });
        return response;
      }
      if (configuration.exchangeResponseMode === "content-type") {
        return textResponse(marker, "text/plain");
      }
      if (configuration.exchangeResponseMode === "declared-overflow") {
        return new Response(JSON.stringify({ marker }), {
          status: 200,
          headers: {
            "content-length": String((512 * 1024) + 1),
            "content-type": "application/json",
          },
        });
      }
      if (configuration.exchangeResponseMode === "streaming-overflow") {
        return new Response(`${marker}${"x".repeat(512 * 1024)}`, {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      if (configuration.exchangeResponseMode === "timeout") {
        return await new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener(
            "abort",
            () => reject(new Error(marker)),
            { once: true },
          );
        });
      }
      return jsonResponse({
        token: fakePortalToken,
        capabilities: configuration.capabilities ?? [
          "ManageEndpoint",
          "ViewEndpointSecret",
        ],
      });
    }
    expect(init?.headers).toMatchObject({
      authorization: `Bearer ${fakePortalToken}`,
    });
    if (url.pathname.endsWith("/headers")) {
      return jsonResponse((secretRead
        ? configuration.finalEndpointHeaders
        : undefined) ?? configuration.endpointHeaders ?? {
        headers: {},
        sensitive: [],
      });
    }
    if (url.pathname.endsWith("/transformation")) {
      return jsonResponse((secretRead
        ? configuration.finalEndpointTransformation
        : undefined) ?? configuration.endpointTransformation ?? {
        enabled: false,
        code: null,
        variables: {},
        updatedAt: null,
      });
    }
    if (url.pathname.endsWith("/secret")) {
      secretCallCount += 1;
      secretRead = true;
      if (configuration.finalEndpoints) {
        endpointState = [...configuration.finalEndpoints];
      }
      if (configuration.rawSecretResponseBody !== undefined) {
        return new Response(configuration.rawSecretResponseBody, {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      return jsonResponse(configuration.signingSecret === "missing"
        ? {}
        : { key: configuration.signingSecret ?? fakeSigningSecret });
    }
    if (/\/endpoint\/ep_[A-Za-z0-9]+$/u.test(url.pathname)) {
      expect(method).toBe("PATCH");
      patchCallCount += 1;
      const body = JSON.parse(String(init?.body));
      patchedBodies.push(body);
      const marker = configuration.fetchFailureMarker
        ?? "CONTROLLER_FETCH_BOUNDARY_MARKER";
      if (configuration.patchResponseMode === "timeout") {
        return await new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener(
            "abort",
            () => reject(new Error(`${marker}:${fakePortalToken}`)),
            { once: true },
          );
        });
      }
      if (configuration.patchResponseMode === "throw") {
        throw new Error(`${marker}:${fakePortalToken}:${fakeSigningSecret}`);
      }
      if (configuration.patchResponseMode === "malformed") {
        return jsonResponse(exactEndpoint({ uid: "conflicting-endpoint" }));
      }
      const nextEndpoint = exactEndpoint({
        disabled: body.disabled,
        updatedAt: "2026-07-21T09:30:00.000Z",
      });
      endpointState = [nextEndpoint];
      const response = jsonResponse(nextEndpoint);
      if (configuration.patchResponseMode === "redirect") {
        Object.defineProperty(response, "redirected", { value: true });
      }
      return response;
    }
    if (!url.pathname.endsWith("/endpoint")) {
      throw new Error("unexpected provider URL");
    }
    if (method === "POST") {
      createCallCount += 1;
      const body = JSON.parse(String(init?.body));
      createdBodies.push(body);
      endpointState = [exactEndpoint()];
      if (configuration.loseCreateResponse) {
        throw new Error(`lost response ${fakeSigningSecret}`);
      }
      return jsonResponse(endpointState[0], 201);
    }
    listCallCount += 1;
    const page = configuration.pages?.[listCallCount - 1]
      ?? { data: endpointState, done: true, iterator: null };
    return jsonResponse(page);
  });

  return {
    options: {
      environment: overrides.environment ?? {
        [productionClerkWebhookPreparationGate]: "1",
      },
      runCommand,
      fetchProvider,
      loadSources: async () => reviewedSourceReceipt,
      loadPortalProtocol: overrides.loadPortalProtocol
        ?? (async () => portalProtocolReceipt),
      now: () => new Date("2026-07-21T10:00:00.000Z"),
      ...(configuration.exchangeResponseMode === "timeout"
        || configuration.patchResponseMode === "timeout"
        ? { fetchTimeoutMs: 5 }
        : {}),
    },
    commandCalls,
    createdBodies,
    createCalls: () => createCallCount,
    listCalls: () => listCallCount,
    secretCalls: () => secretCallCount,
    patchCalls: () => patchCallCount,
    patchedBodies,
    userCountCalls: () => userCountCallCount,
  };
}

function exactEndpoint(overrides: Record<string, unknown> = {}) {
  return {
    id: "ep_refwatch123",
    uid: productionClerkWebhookTarget.endpointUid,
    url: productionClerkWebhookTarget.endpointURL,
    description: productionClerkWebhookTarget.endpointDescription,
    disabled: true,
    filterTypes: ["user.created", "user.updated", "user.deleted"],
    channels: null,
    metadata: {},
    rateLimit: null,
    throttleRate: null,
    createdAt: "2026-07-21T09:00:00.000Z",
    updatedAt: "2026-07-21T09:00:00.000Z",
    version: 1,
    ...overrides,
  };
}

function whoami(overrides: {
  appId?: string;
  productionInstanceId?: string;
} = {}) {
  return {
    email: "redacted@example.invalid",
    linked: {
      appId: overrides.appId ?? productionClerkWebhookTarget.clerkApplicationId,
      appName: productionClerkWebhookTarget.clerkApplicationName,
      development: {
        id: productionClerkWebhookTarget.developmentClerkInstanceId,
        type: "string",
      },
      production: {
        id: overrides.productionInstanceId
          ?? productionClerkWebhookTarget.clerkInstanceId,
        type: "string",
      },
      resolvedVia: "remote",
    },
  };
}

function magicURL(overrides: Record<string, unknown> = {}) {
  const payload: Record<string, unknown> = {
    appId: "app_svixRefWatch123",
    region: "us",
    oneTimeToken: fakeOneTimeToken,
    ...overrides,
  };
  for (const key of Object.keys(payload)) {
    if (payload[key] === undefined) delete payload[key];
  }
  const key = Buffer.from(JSON.stringify(payload)).toString("base64");
  return `https://app.svix.com/login#key=${encodeURIComponent(key)}`;
}

function sameCommand(
  actual: ProductionClerkWebhookPreparationCommandSpecification,
  expected: { command: string; args: readonly string[] },
) {
  return actual.command === expected.command
    && JSON.stringify(actual.args) === JSON.stringify(expected.args);
}

function output(value: unknown) {
  return {
    stdout: Buffer.from(typeof value === "string" ? value : JSON.stringify(value)),
  };
}

function jsonResponse(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function fakeClerkChild() {
  const child = new EventEmitter() as EventEmitter & {
    stdout: PassThrough;
    stderr: PassThrough;
    kill: ReturnType<typeof vi.fn>;
  };
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  child.kill = vi.fn();
  return child;
}

function textResponse(value: string, contentType: string) {
  return new Response(value, {
    status: 200,
    headers: { "content-type": contentType },
  });
}

async function sourceInput() {
  const [packageJSON, packageLock, launchPacket] = await Promise.all([
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../package-lock.json", import.meta.url), "utf8"),
    readFile(new URL("../scripts/greenfield-launch-packet.mjs", import.meta.url)),
  ]);
  return { packageJSON, packageLock, launchPacket };
}
