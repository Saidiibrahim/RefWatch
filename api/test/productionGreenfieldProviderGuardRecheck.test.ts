import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import { describe, expect, it, vi } from "vitest";
import {
  ProductionGreenfieldProviderGuardMissingAuditEvidenceError,
  productionGreenfieldProviderGuardCommands,
  productionGreenfieldProviderGuardGate,
  recheckProductionGreenfieldCutoverProviderGuards,
  runProductionGreenfieldProviderGuardCLI,
  runProductionGreenfieldProviderGuardCommand,
  validateProductionGreenfieldProviderGuardSources,
} from "../scripts/recheck-production-greenfield-cutover-provider-guards.mjs";

const outerGate = "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER";

describe("production greenfield provider guard recheck", () => {
  it("pins exact local tool commands and scoped read-only provider arguments", () => {
    expect(productionGreenfieldProviderGuardCommands.wranglerVersion).toEqual({
      command: "./node_modules/.bin/wrangler",
      args: ["--version"],
    });
    expect(productionGreenfieldProviderGuardCommands.cloudflareVersion).toEqual({
      command: "cf",
      args: ["--version"],
    });
    expect(productionGreenfieldProviderGuardCommands.versionsList.args).toEqual([
      "versions", "list", "--name", "refwatch-api",
      "--env-file", "/dev/null", "--json",
    ]);
    expect(productionGreenfieldProviderGuardCommands.zoneRoutes.args).toEqual([
      "--quiet", "--zone", "955d108e63b6a9743e0e74206e2dbe09",
      "workers", "routes", "list",
    ]);
    expect(productionGreenfieldProviderGuardCommands.customDomains.args)
      .toContain("api.refwatch.ibby.ai");
    expect(productionGreenfieldProviderGuardCommands.dnsRecords.args)
      .toContain("--name-exact");
    expect(productionGreenfieldProviderGuardCommands.accessApplications.args)
      .toContain("--exact");
    for (const specification of Object.values(
      productionGreenfieldProviderGuardCommands,
    )) {
      expect(specification.args.join(" ")).not.toMatch(
        /(?:create|delete|update|patch|put|secret-key)/u,
      );
    }
  });

  it("accepts only exact pinned package/tool source versions", () => {
    const source = {
      packageJSON: JSON.stringify({
        devDependencies: { clerk: "2.2.0", wrangler: "^4.110.0" },
      }),
      packageLock: JSON.stringify({
        packages: {
          "node_modules/clerk": { version: "2.2.0" },
          "node_modules/wrangler": { version: "4.110.0" },
        },
      }),
      clerk: { clerkCliVersion: "2.2.0" },
      lineage: { manifestSha256: "a".repeat(64), fileCount: 80 },
    };
    expect(() => validateProductionGreenfieldProviderGuardSources(source))
      .not.toThrow();
    expect(() => validateProductionGreenfieldProviderGuardSources({
      ...source,
      packageJSON: source.packageJSON.replace("2.2.0", "2.2.1"),
    })).toThrow("reviewed sources drifted");
    expect(() => validateProductionGreenfieldProviderGuardSources({
      ...source,
      lineage: { ...source.lineage, fileCount: 0 },
    })).toThrow("reviewed sources drifted");
  });

  it("fails closed with an explicit sanitized state when audit evidence is absent", async () => {
    const runCommand = vi.fn();
    let error: unknown;
    try {
      await recheckProductionGreenfieldCutoverProviderGuards({} as any, {
        environment: {
          [outerGate]: "1",
          [productionGreenfieldProviderGuardGate]: "1",
        },
        runCommand,
      });
    } catch (caught) {
      error = caught;
    }
    expect(error).toBeInstanceOf(
      ProductionGreenfieldProviderGuardMissingAuditEvidenceError,
    );
    expect((error as ProductionGreenfieldProviderGuardMissingAuditEvidenceError)
      .toJSON()).toEqual({
      schema_version: 1,
      receipt_type: "refwatch_production_greenfield_provider_guard_blocker",
      status: "blocked_missing_audit_evidence",
      audit_source: "cloudflare_account_audit_logs_v2",
      route_mutation_count: null,
      access_mutation_count: null,
      provider_state_read_attempted: false,
    });
    expect(runCommand).not.toHaveBeenCalled();
  });

  it("keeps both technical gates closed before sources or providers", async () => {
    const loadSources = vi.fn();
    const runCommand = vi.fn();
    const readAuditEvidence = vi.fn();
    await expect(recheckProductionGreenfieldCutoverProviderGuards({} as any, {
      environment: { [outerGate]: "1" },
      loadSources,
      runCommand,
      readAuditEvidence,
    })).rejects.toThrow("without disclosing provider output");
    expect(loadSources).not.toHaveBeenCalled();
    expect(runCommand).not.toHaveBeenCalled();
    expect(readAuditEvidence).not.toHaveBeenCalled();
  });

  it("keeps the CLI source-only and standalone execution disabled", async () => {
    const checkSources = vi.fn(async () => ({}));
    const stdout = vi.fn();
    const stderr = vi.fn();
    expect(await runProductionGreenfieldProviderGuardCLI({
      args: ["--check"], checkSources, writeStdout: stdout, writeStderr: stderr,
    })).toBe(0);
    expect(checkSources).toHaveBeenCalledOnce();
    expect(await runProductionGreenfieldProviderGuardCLI({
      args: ["--execute"], checkSources, writeStdout: stdout, writeStderr: stderr,
    })).toBe(2);
    expect(checkSources).toHaveBeenCalledOnce();
    expect(stderr).toHaveBeenLastCalledWith(expect.stringContaining("disabled"));
  });

  it("bounds a hung command and never echoes captured provider output", async () => {
    vi.useFakeTimers();
    try {
      const marker = ["provider", "secret", "marker"].join("-");
      const child = new EventEmitter() as any;
      child.stdout = new PassThrough();
      child.stderr = new PassThrough();
      child.kill = vi.fn();
      const promise = runProductionGreenfieldProviderGuardCommand({
        command: "cf",
        args: ["--version"],
        cwd: "/tmp",
        environment: {},
      }, {
        spawnImpl: () => child,
        timeoutMs: 5,
        killGraceMs: 5,
      } as any);
      child.stderr.write(marker);
      const assertion = expect(promise).rejects.toThrow(
        "without disclosing provider output",
      );
      await vi.advanceTimersByTimeAsync(11);
      await assertion;
      expect(child.kill).toHaveBeenCalledWith("SIGTERM");
      expect(child.kill).toHaveBeenCalledWith("SIGKILL");
    } finally {
      vi.useRealTimers();
    }
  });
});
