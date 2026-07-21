import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import { describe, expect, it, vi } from "vitest";
import {
  ProductionRuntimeProvisioningError,
  assertRuntimePrivilegeReadback,
  productionRuntimeProvisioningTarget,
  provisionProductionRuntime,
  runCapturedCommand,
  verifyPlanetScaleRuntimePrivileges,
  type ProviderCommandRunner,
  type ProviderCommandSpecification,
  type RuntimePrivilegeClient,
  type RuntimePrivilegeReadback,
} from "../scripts/provision-production-runtime.mjs";

const existingRoleId = "vaqg84rqoedz";
const newRoleId = "a1b2c3d4e5f6";
const existingHyperdriveId = "5345de83edfa40b790d5b26df32f56ab";
const newHyperdriveId = "11111111111111111111111111111111";
const password = "TEST_ONLY_SECRET_PASSWORD_MARKER";
const rawProviderSecret = "RAW_PROVIDER_SECRET_MARKER";
const target = productionRuntimeProvisioningTarget;
const username = `pscale_api_${newRoleId}.${target.branchId}`;

describe("production runtime provisioning helper", () => {
  it("creates isolated resources, verifies them, and returns only a sanitized paired receipt", async () => {
    const runCommand = vi.fn(successfulCommandRunner());
    const verifyPrivileges = vi.fn(async (connection) => {
      expect(connection).toEqual({
        host: target.originHost,
        port: target.originPort,
        database: target.databaseName,
        username,
        password,
        expectedRoleId: newRoleId,
        expectedBranchId: target.branchId,
        expectedRuntimeMarker: target.runtimeMarker,
      });
      return safePrivilegeReadback();
    });

    const receipt = await provisionProductionRuntime({
      runCommand,
      verifyPrivileges,
      now: () => new Date("2026-07-20T08:00:00.000Z"),
    });

    expect(receipt).toMatchObject({
      schema_version: 1,
      receipt_type: "refwatch_production_runtime_provisioning",
      status: "prepared_unbound",
      observed_at_utc: "2026-07-20T08:00:00.000Z",
      production_target: {
        organization: "ibrahim-aka-ajax",
        database: "refwatch",
        branch: "main",
        branch_id: "w3g1f8vcbg34",
        runtime_marker: "refwatch:production:w3g1f8vcbg34",
        database_name: "postgres",
        cloudflare_account_id: "b08d54b822741dbf8e864503b50604a1",
      },
      planetscale: {
        role_id: newRoleId,
        role_name: target.roleName,
        durable: true,
        ttl: "0s",
        inherited_roles: ["pg_read_all_data", "pg_write_all_data"],
        effective_privileges: {
          read_all_data: true,
          write_all_data: true,
          administrator: false,
          create_database: false,
          create_role: false,
          create_schema: false,
        },
      },
      cloudflare: {
        hyperdrive_id: newHyperdriveId,
        hyperdrive_name: target.hyperdriveName,
        tls_mode: "require",
        caching_disabled: true,
        connection_limit: 10,
      },
      existing_resources: {
        preserved: true,
        changed: false,
        planetscale_role_count: 1,
        cloudflare_hyperdrive_count: 1,
      },
      candidate_config_update: {
        status: "pending_explicit_atomic_update",
        applied: false,
        must_update_together: true,
        changes: [
          {
            path: "env.production.hyperdrive[0].id",
            value: newHyperdriveId,
          },
          {
            path: "env.production.vars.EXPECTED_DATABASE_ROLE_ID",
            value: newRoleId,
          },
        ],
      },
    });

    const calls = commandCalls(runCommand);
    expect(calls.map(({ stage }) => stage)).toEqual([
      "cloudflare_account_preflight",
      "planetscale_role_preflight",
      "cloudflare_hyperdrive_preflight",
      "planetscale_role_create",
      "planetscale_role_readback",
      "cloudflare_hyperdrive_create",
      "cloudflare_hyperdrive_readback",
    ]);
    expect(commandAt(calls, "planetscale_role_create")).toEqual({
      command: "pscale",
      args: [
        "role",
        "create",
        "refwatch",
        "main",
        "refwatch-worker-production-greenfield-20260720",
        "--org",
        "ibrahim-aka-ajax",
        "--inherited-roles",
        "pg_read_all_data,pg_write_all_data",
        "--ttl",
        "0s",
        "--format",
        "json",
        "--no-color",
      ],
      stage: "planetscale_role_create",
    });

    const hyperdriveCreate = commandAt(
      calls,
      "cloudflare_hyperdrive_create",
    );
    expect(hyperdriveCreate).toEqual({
      command: "cf",
      args: [
        "--quiet",
        "hyperdrive",
        "create",
        "--name",
        "refwatch-planetscale-production-greenfield-20260720",
        "--origin-database",
        "postgres",
        "--origin-scheme",
        "postgresql",
        "--origin-user",
        username,
        "--origin-host",
        "aws-ap-southeast-2-1.pg.psdb.cloud",
        "--origin-port",
        "5432",
        "--origin-connection-limit",
        "10",
        "--mtls-sslmode",
        "require",
        "--caching-disabled",
      ],
      stage: "cloudflare_hyperdrive_create",
      stdin: `${password}\n`,
      environment: {
        CLOUDFLARE_ACCOUNT_ID: target.cloudflareAccountId,
      },
    });
    expect(hyperdriveCreate.args).not.toContain("--origin-password");
    expect(calls.filter(({ stdin }) => stdin !== undefined)).toEqual([
      hyperdriveCreate,
    ]);
    for (const call of calls) {
      expect(call.command).not.toContain(password);
      expect(call.args.join(" ")).not.toContain(password);
      expect(call.args.join(" ")).not.toContain(rawProviderSecret);
      if (call.command === "cf") {
        expect(call.environment).toEqual({
          CLOUDFLARE_ACCOUNT_ID: target.cloudflareAccountId,
        });
      }
    }

    const serialized = JSON.stringify(receipt);
    expect(serialized).not.toContain(password);
    expect(serialized).not.toContain(rawProviderSecret);
    expect(serialized).not.toContain("database_url");
    expect(serialized).not.toContain("access_host_url");
    expect(calls.some(({ stage }) => stage.includes("cleanup"))).toBe(false);
  });

  it("deletes only the new role when effective privilege verification fails", async () => {
    const runCommand = vi.fn(successfulCommandRunner());
    const forbidden = safePrivilegeReadback();
    forbidden.can_create_public_schema = true;

    const error = await capturedProvisioningError(provisionProductionRuntime({
      runCommand,
      verifyPrivileges: vi.fn(async () => forbidden),
    }));

    expect(error).toMatchObject({
      stage: "planetscale_privilege_verification",
      cleanup: {
        hyperdrive: "not_required",
        planetscaleRole: "deleted",
      },
    });
    const calls = commandCalls(runCommand);
    expect(calls.some(({ stage }) =>
      stage === "cloudflare_hyperdrive_create")).toBe(false);
    const deletion = commandAt(calls, "planetscale_role_cleanup");
    expect(deletion.args).toContain(newRoleId);
    expect(deletion.args).not.toContain(existingRoleId);
    expect(deletion.args).not.toContain(target.roleName);
  });

  it("discovers and deletes only newly named resources after a Hyperdrive create failure", async () => {
    let discoveryAttempt = 0;
    const runCommand = vi.fn(successfulCommandRunner({
      cloudflare_hyperdrive_create: async () => {
        throw new Error(`${rawProviderSecret}:${password}`);
      },
      cloudflare_hyperdrive_cleanup_discovery: async () => ({
        stdout: JSON.stringify(
          ++discoveryAttempt === 1
            ? [existingHyperdrive()]
            : [existingHyperdrive(), validHyperdriveReadback()],
        ),
      }),
    }));
    const sleep = vi.fn(async () => {});

    const error = await capturedProvisioningError(provisionProductionRuntime({
      runCommand,
      verifyPrivileges: vi.fn(async () => safePrivilegeReadback()),
      sleep,
    }));

    expect(error.toJSON()).toEqual({
      status: "failed",
      stage: "cloudflare_hyperdrive_create",
      cleanup: {
        hyperdrive: "deleted",
        planetscale_role: "deleted",
      },
    });
    expect(JSON.stringify(error.toJSON())).not.toContain(password);
    expect(JSON.stringify(error.toJSON())).not.toContain(rawProviderSecret);

    const calls = commandCalls(runCommand);
    const hyperdriveDeletion = commandAt(
      calls,
      "cloudflare_hyperdrive_cleanup",
    );
    expect(hyperdriveDeletion.args).toContain(newHyperdriveId);
    expect(hyperdriveDeletion.args).not.toContain(existingHyperdriveId);
    const roleDeletion = commandAt(calls, "planetscale_role_cleanup");
    expect(roleDeletion.args).toContain(newRoleId);
    expect(roleDeletion.args).not.toContain(existingRoleId);
    expect(discoveryAttempt).toBe(2);
    expect(sleep).toHaveBeenCalledOnce();
  });

  it("deletes the new Hyperdrive and role when exact readback settings drift", async () => {
    const mismatchedReadback = validHyperdriveReadback();
    mismatchedReadback.caching.disabled = false;
    const runCommand = vi.fn(successfulCommandRunner({
      cloudflare_hyperdrive_readback: async () => ({
        stdout: JSON.stringify(mismatchedReadback),
      }),
    }));

    const error = await capturedProvisioningError(provisionProductionRuntime({
      runCommand,
      verifyPrivileges: vi.fn(async () => safePrivilegeReadback()),
    }));

    expect(error).toMatchObject({
      stage: "cloudflare_hyperdrive_readback",
      cleanup: {
        hyperdrive: "deleted",
        planetscaleRole: "deleted",
      },
    });
    const calls = commandCalls(runCommand);
    expect(commandAt(calls, "cloudflare_hyperdrive_cleanup").args)
      .toContain(newHyperdriveId);
    expect(commandAt(calls, "planetscale_role_cleanup").args)
      .toContain(newRoleId);
  });

  it("recovers a created role ID by its unique new name when create output is unreadable", async () => {
    const runCommand = vi.fn(successfulCommandRunner({
      planetscale_role_create: async () => ({
        stdout: `not-json-${rawProviderSecret}`,
      }),
      planetscale_role_cleanup_discovery: async () => ({
        stdout: JSON.stringify([
          existingRole(),
          {
            id: newRoleId,
            name: target.roleName,
          },
        ]),
      }),
    }));

    const error = await capturedProvisioningError(provisionProductionRuntime({
      runCommand,
      verifyPrivileges: vi.fn(async () => safePrivilegeReadback()),
    }));

    expect(error).toMatchObject({
      stage: "planetscale_role_create",
      cleanup: {
        hyperdrive: "not_required",
        planetscaleRole: "deleted",
      },
    });
    const deletion = commandAt(
      commandCalls(runCommand),
      "planetscale_role_cleanup",
    );
    expect(deletion.args).toContain(newRoleId);
    expect(deletion.args).not.toContain(target.roleName);
    expect(JSON.stringify(error.toJSON())).not.toContain(rawProviderSecret);
  });

  it("refuses exact-name ambiguity before any create", async () => {
    const runCommand = vi.fn(successfulCommandRunner({
      planetscale_role_preflight: async () => ({
        stdout: JSON.stringify([
          existingRole(),
          { id: "bbbbbbbbbbbb", name: target.roleName },
        ]),
      }),
    }));

    const error = await capturedProvisioningError(provisionProductionRuntime({
      runCommand,
      verifyPrivileges: vi.fn(async () => safePrivilegeReadback()),
    }));

    expect(error).toMatchObject({
      stage: "resource_name_preflight",
      cleanup: {
        hyperdrive: "not_required",
        planetscaleRole: "not_required",
      },
    });
    expect(commandCalls(runCommand).some(({ stage }) =>
      stage.includes("create"))).toBe(false);
  });

  it("does not delete a baseline ID returned by a compromised create response", async () => {
    const compromised = createdRole();
    compromised.id = existingRoleId;
    compromised.username =
      `pscale_api_${existingRoleId}.${target.branchId}`;
    const runCommand = vi.fn(successfulCommandRunner({
      planetscale_role_create: async () => ({
        stdout: JSON.stringify(compromised),
      }),
    }));

    const error = await capturedProvisioningError(provisionProductionRuntime({
      runCommand,
      verifyPrivileges: vi.fn(async () => safePrivilegeReadback()),
    }));

    expect(error).toMatchObject({
      stage: "planetscale_role_create",
      cleanup: {
        planetscaleRole: "refused_existing_resource",
      },
    });
    expect(commandCalls(runCommand).some(({ stage }) =>
      stage === "planetscale_role_cleanup")).toBe(false);
  });

  it("fails before resource listing when the exact Cloudflare account is not active", async () => {
    const runCommand = vi.fn(successfulCommandRunner({
      cloudflare_account_preflight: async () => ({
        stdout: JSON.stringify({
          accountId: {
            value: "ffffffffffffffffffffffffffffffff",
            name: rawProviderSecret,
          },
        }),
      }),
    }));

    const error = await capturedProvisioningError(provisionProductionRuntime({
      runCommand,
      verifyPrivileges: vi.fn(async () => safePrivilegeReadback()),
    }));

    expect(error).toMatchObject({
      stage: "cloudflare_account_preflight",
      cleanup: {
        hyperdrive: "not_required",
        planetscaleRole: "not_required",
      },
    });
    expect(commandCalls(runCommand).map(({ stage }) => stage)).toEqual([
      "cloudflare_account_preflight",
    ]);
    expect(JSON.stringify(error.toJSON())).not.toContain(rawProviderSecret);
  });

  it("waits for child close and escalates to SIGKILL before rejecting a timeout", async () => {
    vi.useFakeTimers();
    try {
      const child = fakeChildProcess();
      const spawnImpl = vi.fn(() => child) as unknown as
        typeof import("node:child_process").spawn;
      const pending = runCapturedCommand({
        command: "provider-cli",
        args: ["create"],
        stage: "timeout_test",
      }, {
        spawnImpl,
        timeoutMs: 10,
        killGraceMs: 20,
      });
      let rejected = false;
      void pending.catch(() => {
        rejected = true;
      });

      await vi.advanceTimersByTimeAsync(10);
      expect(child.kill).toHaveBeenCalledWith("SIGTERM");
      expect(rejected).toBe(false);

      await vi.advanceTimersByTimeAsync(20);
      expect(child.kill).toHaveBeenCalledWith("SIGKILL");
      await expect(pending).rejects.toThrow("Provider command failed");
      expect(rejected).toBe(true);
    } finally {
      vi.useRealTimers();
    }
  });

  it("uses bounded PostgreSQL settings and rolls back an exact-marker write probe", async () => {
    const query = vi.fn(async (
      text: string,
      values?: readonly unknown[],
    ) => {
      if (text.startsWith("BEGIN")) return queryResult(null, []);
      if (text.includes("FROM public.runtime_database_markers")) {
        expect(values).toEqual([target.runtimeMarker]);
        return queryResult(1, [{
          marker: target.runtimeMarker,
          branch_id: target.branchId,
          environment: "production",
        }]);
      }
      if (text.includes("UPDATE public.runtime_database_markers")) {
        expect(text).toContain("WHERE marker = $1");
        expect(text).not.toContain("WHERE false");
        expect(values).toEqual([target.runtimeMarker]);
        return queryResult(1, [{ marker: target.runtimeMarker }]);
      }
      if (text.includes("FROM pg_roles role")) {
        return queryResult(1, [
          safePrivilegeReadback() as unknown as Record<string, unknown>,
        ]);
      }
      if (text === "ROLLBACK") return queryResult(null, []);
      throw new Error(`Unexpected SQL: ${text}`);
    });
    const client: RuntimePrivilegeClient = {
      connect: vi.fn(async () => {}),
      query,
      end: vi.fn(async () => {}),
    };
    let capturedConfig: Readonly<Record<string, unknown>> | undefined;

    const result = await verifyPlanetScaleRuntimePrivileges({
      host: target.originHost,
      port: target.originPort,
      database: target.databaseName,
      username,
      password,
      expectedRoleId: newRoleId,
      expectedBranchId: target.branchId,
      expectedRuntimeMarker: target.runtimeMarker,
    }, {
      clientFactory: (config) => {
        capturedConfig = config;
        return client;
      },
    });

    expect(capturedConfig).toMatchObject({
      host: target.originHost,
      port: 5432,
      database: "postgres",
      user: username,
      password,
      connectionTimeoutMillis: 10_000,
      query_timeout: 10_000,
      statement_timeout: 10_000,
      lock_timeout: 2_000,
    });
    expect(result).toMatchObject({
      runtime_marker: target.runtimeMarker,
      runtime_branch_id: target.branchId,
      runtime_environment: "production",
      rolled_back_write_row_count: 1,
    });
    expect(query.mock.calls.at(-1)?.[0]).toBe("ROLLBACK");
    expect(JSON.stringify(query.mock.calls)).not.toContain(password);
    expect(client.connect).toHaveBeenCalledOnce();
    expect(client.end).toHaveBeenCalledOnce();
  });

  it.each([
    "rolsuper",
    "rolcreaterole",
    "rolcreatedb",
    "rolreplication",
    "rolbypassrls",
    "can_assume_postgres",
    "can_assume_database_owner",
    "can_maintain",
    "can_execute_server_program",
    "can_read_server_files",
    "can_write_server_files",
    "can_create_database_objects",
    "can_create_public_schema",
  ] as const)("rejects forbidden privilege %s", (field) => {
    const readback = safePrivilegeReadback();
    readback[field] = true;
    expect(() =>
      assertRuntimePrivilegeReadback(
        readback,
        newRoleId,
        target.runtimeMarker,
        target.branchId,
      )).toThrow(
        "Runtime role has a forbidden administrative capability",
      );
  });

  it("requires exact role identity, durable lifetime, and both data memberships", () => {
    expect(() => assertRuntimePrivilegeReadback({
      ...safePrivilegeReadback(),
      current_user: "pscale_api_wrong",
    }, newRoleId, target.runtimeMarker, target.branchId)).toThrow(
      "Runtime role identity readback does not match",
    );
    expect(() => assertRuntimePrivilegeReadback({
      ...safePrivilegeReadback(),
      role_valid_until: "2026-07-21T00:00:00Z",
    }, newRoleId, target.runtimeMarker, target.branchId)).toThrow(
      "Runtime role is not durable read/write data access",
    );
    expect(() => assertRuntimePrivilegeReadback({
      ...safePrivilegeReadback(),
      can_write_all_data: false,
    }, newRoleId, target.runtimeMarker, target.branchId)).toThrow(
      "Runtime role is not durable read/write data access",
    );
    expect(() => assertRuntimePrivilegeReadback({
      ...safePrivilegeReadback(),
      runtime_branch_id: "wrong-branch",
    }, newRoleId, target.runtimeMarker, target.branchId)).toThrow(
      "Runtime role is not durable read/write data access",
    );
    expect(() => assertRuntimePrivilegeReadback({
      ...safePrivilegeReadback(),
      rolled_back_write_row_count: 0,
    }, newRoleId, target.runtimeMarker, target.branchId)).toThrow(
      "Runtime role is not durable read/write data access",
    );
  });
});

function successfulCommandRunner(
  overrides: Partial<Record<
    string,
    (specification: ProviderCommandSpecification) =>
      Promise<{ stdout: string }>
  >> = {},
): ProviderCommandRunner {
  return async (specification) => {
    const override = overrides[specification.stage];
    if (override) return override(specification);
    switch (specification.stage) {
      case "cloudflare_account_preflight":
        return {
          stdout: JSON.stringify({
            accountId: {
              value: target.cloudflareAccountId,
              source: "config",
              path: `/non-secret/path/${rawProviderSecret}`,
              name: `account-${rawProviderSecret}`,
            },
          }),
        };
      case "planetscale_role_preflight":
        return { stdout: JSON.stringify([existingRole()]) };
      case "cloudflare_hyperdrive_preflight":
        return { stdout: JSON.stringify([existingHyperdrive()]) };
      case "planetscale_role_create":
        return { stdout: JSON.stringify(createdRole()) };
      case "planetscale_role_readback":
        return { stdout: JSON.stringify(roleReadback()) };
      case "cloudflare_hyperdrive_create":
        return {
          stdout: JSON.stringify({
            id: newHyperdriveId,
            name: target.hyperdriveName,
          }),
        };
      case "cloudflare_hyperdrive_readback":
        return { stdout: JSON.stringify(validHyperdriveReadback()) };
      case "cloudflare_hyperdrive_cleanup":
      case "planetscale_role_cleanup":
        return { stdout: "{}" };
      default:
        throw new Error(`Unexpected mock stage: ${specification.stage}`);
    }
  };
}

function existingRole() {
  return {
    id: existingRoleId,
    name: "refwatch-worker-production-v2",
  };
}

function createdRole() {
  return {
    id: newRoleId,
    name: target.roleName,
    username,
    password,
    access_host_url: target.originHost,
    database_url:
      `postgresql://${username}:${password}@${target.originHost}:5432/postgres`,
    with_replication: false,
  };
}

function roleReadback() {
  return {
    id: newRoleId,
    name: target.roleName,
    username,
    password: "",
    access_host_url: target.originHost,
    database_url:
      `postgresql://${username}:@${target.originHost}:5432/postgres`,
    with_replication: false,
  };
}

function existingHyperdrive() {
  return {
    id: existingHyperdriveId,
    name: "refwatch-planetscale-production",
  };
}

function validHyperdriveReadback() {
  return {
    id: newHyperdriveId,
    name: target.hyperdriveName,
    origin: {
      host: target.originHost,
      port: target.originPort,
      database: target.databaseName,
      scheme: target.originScheme,
      user: username,
    },
    origin_connection_limit: target.hyperdriveConnectionLimit,
    caching: {
      disabled: true,
    },
    mtls: {
      sslmode: "require",
    },
  };
}

function safePrivilegeReadback(): RuntimePrivilegeReadback {
  return {
    current_user: `pscale_api_${newRoleId}`,
    transaction_read_only: "off",
    role_valid_until: null,
    rolsuper: false,
    rolcreaterole: false,
    rolcreatedb: false,
    rolreplication: false,
    rolbypassrls: false,
    can_read_all_data: true,
    can_write_all_data: true,
    can_assume_postgres: false,
    can_assume_database_owner: false,
    can_maintain: false,
    can_execute_server_program: false,
    can_read_server_files: false,
    can_write_server_files: false,
    can_use_public_schema: true,
    can_select_runtime_marker: true,
    can_update_runtime_marker: true,
    can_create_database_objects: false,
    can_create_public_schema: false,
    runtime_marker: target.runtimeMarker,
    runtime_branch_id: target.branchId,
    runtime_environment: "production",
    rolled_back_write_row_count: 1,
  };
}

function fakeChildProcess() {
  const child = new EventEmitter() as EventEmitter & {
    stdin: PassThrough;
    stdout: PassThrough;
    stderr: PassThrough;
    kill: ReturnType<typeof vi.fn>;
  };
  child.stdin = new PassThrough();
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  child.kill = vi.fn((signal: NodeJS.Signals) => {
    if (signal === "SIGKILL") {
      queueMicrotask(() => child.emit("close", null, "SIGKILL"));
    }
    return true;
  });
  return child;
}

function queryResult(
  rowCount: number | null,
  rows: Array<Record<string, unknown>>,
) {
  return { rowCount, rows };
}

function commandCalls(
  mock: ReturnType<typeof vi.fn<ProviderCommandRunner>>,
): ProviderCommandSpecification[] {
  return mock.mock.calls.map(([specification]) => specification);
}

function commandAt(
  calls: ProviderCommandSpecification[],
  stage: string,
): ProviderCommandSpecification {
  const found = calls.find((call) => call.stage === stage);
  if (!found) throw new Error(`Missing command stage ${stage}`);
  return found;
}

async function capturedProvisioningError(
  promise: ReturnType<typeof provisionProductionRuntime>,
): Promise<ProductionRuntimeProvisioningError> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof ProductionRuntimeProvisioningError) return error;
    throw error;
  }
  throw new Error("Expected provisioning to fail");
}
