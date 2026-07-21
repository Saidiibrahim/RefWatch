import { spawn } from "node:child_process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "pg";

const MAX_CAPTURED_OUTPUT_BYTES = 1024 * 1024;
const COMMAND_TIMEOUT_MS = 60_000;
const COMMAND_KILL_GRACE_MS = 2_000;
const PROVIDER_DISCOVERY_ATTEMPTS = 3;
const PROVIDER_DISCOVERY_DELAY_MS = 250;
const POSTGRES_CONNECTION_TIMEOUT_MS = 10_000;
const POSTGRES_QUERY_TIMEOUT_MS = 10_000;
const POSTGRES_LOCK_TIMEOUT_MS = 2_000;

export const productionRuntimeProvisioningTarget = Object.freeze({
  organization: "ibrahim-aka-ajax",
  database: "refwatch",
  branch: "main",
  branchId: "w3g1f8vcbg34",
  runtimeMarker: "refwatch:production:w3g1f8vcbg34",
  databaseName: "postgres",
  originHost: "aws-ap-southeast-2-1.pg.psdb.cloud",
  originPort: 5432,
  originScheme: "postgresql",
  roleName: "refwatch-worker-production-greenfield-20260720",
  inheritedRoles: Object.freeze([
    "pg_read_all_data",
    "pg_write_all_data",
  ]),
  roleTtl: "0s",
  hyperdriveName:
    "refwatch-planetscale-production-greenfield-20260720",
  cloudflareAccountId: "b08d54b822741dbf8e864503b50604a1",
  hyperdriveTlsMode: "require",
  hyperdriveCachingDisabled: true,
  hyperdriveConnectionLimit: 10,
  candidateConfigPaths: Object.freeze({
    hyperdriveId: "env.production.hyperdrive[0].id",
    expectedDatabaseRoleId:
      "env.production.vars.EXPECTED_DATABASE_ROLE_ID",
  }),
});

export class ProductionRuntimeProvisioningError extends Error {
  constructor(stage, cleanup) {
    super(`Production runtime provisioning failed at ${stage}`);
    this.name = "ProductionRuntimeProvisioningError";
    this.stage = stage;
    this.cleanup = Object.freeze({
      hyperdrive: cleanup.hyperdrive,
      planetscaleRole: cleanup.planetscaleRole,
    });
  }

  toJSON() {
    return {
      status: "failed",
      stage: this.stage,
      cleanup: {
        hyperdrive: this.cleanup.hyperdrive,
        planetscale_role: this.cleanup.planetscaleRole,
      },
    };
  }
}

export async function provisionProductionRuntime(options = {}) {
  const runCommand = options.runCommand ?? runCapturedCommand;
  const verifyPrivileges =
    options.verifyPrivileges ?? verifyPlanetScaleRuntimePrivileges;
  const now = options.now ?? (() => new Date());
  const sleep = options.sleep ?? delay;
  const target = productionRuntimeProvisioningTarget;
  const state = {
    existingRoleIds: new Set(),
    existingHyperdriveIds: new Set(),
    roleCreateAttempted: false,
    hyperdriveCreateAttempted: false,
    roleId: undefined,
    hyperdriveId: undefined,
  };
  let stage = "preflight";

  try {
    stage = "cloudflare_account_preflight";
    const cloudflareContextOutput = await runCommand(cloudflareCommand(
      cloudflareContextShowArgs(),
      stage,
      undefined,
      target,
    ));
    assertCloudflareAccount(
      cloudflareContextOutput.stdout,
      target.cloudflareAccountId,
    );

    stage = "resource_name_preflight";
    const [roleListOutput, hyperdriveListOutput] = await Promise.all([
      runCommand(command(
        "pscale",
        planetscaleRoleListArgs(target),
        "planetscale_role_preflight",
      )),
      runCommand(cloudflareCommand(
        cloudflareHyperdriveListArgs(),
        "cloudflare_hyperdrive_preflight",
        undefined,
        target,
      )),
    ]);

    const existingRoles = parseNamedResources(
      roleListOutput.stdout,
      "PlanetScale role preflight",
      isPlanetScaleRoleId,
    );
    const existingHyperdrives = parseNamedResources(
      hyperdriveListOutput.stdout,
      "Cloudflare Hyperdrive preflight",
      isHyperdriveId,
    );
    state.existingRoleIds = new Set(existingRoles.map(({ id }) => id));
    state.existingHyperdriveIds = new Set(
      existingHyperdrives.map(({ id }) => id),
    );
    assertNameAvailable(existingRoles, target.roleName, "PlanetScale role");
    assertNameAvailable(
      existingHyperdrives,
      target.hyperdriveName,
      "Cloudflare Hyperdrive",
    );

    stage = "planetscale_role_create";
    state.roleCreateAttempted = true;
    const createdRoleOutput = await runCommand(command(
      "pscale",
      planetscaleRoleCreateArgs(target),
      stage,
    ));
    const credential = parseCreatedPlanetScaleRole(
      createdRoleOutput.stdout,
      target,
    );
    state.roleId = credential.id;
    assertNewId(
      credential.id,
      state.existingRoleIds,
      "PlanetScale role",
    );

    stage = "planetscale_role_readback";
    const roleReadbackOutput = await runCommand(command(
      "pscale",
      planetscaleRoleGetArgs(target, credential.id),
      stage,
    ));
    assertPlanetScaleRoleReadback(
      roleReadbackOutput.stdout,
      credential,
      target,
    );

    stage = "planetscale_privilege_verification";
    const privilegeReadback = await verifyPrivileges({
      host: credential.host,
      port: target.originPort,
      database: target.databaseName,
      username: credential.username,
      password: credential.password,
      expectedRoleId: credential.id,
      expectedBranchId: target.branchId,
      expectedRuntimeMarker: target.runtimeMarker,
    });
    assertRuntimePrivilegeReadback(
      privilegeReadback,
      credential.id,
      target.runtimeMarker,
      target.branchId,
    );

    stage = "cloudflare_hyperdrive_create";
    state.hyperdriveCreateAttempted = true;
    const hyperdriveCreateOutput = await runCommand(cloudflareCommand(
      cloudflareHyperdriveCreateArgs(target, credential.username),
      stage,
      `${credential.password}\n`,
      target,
    ));
    const createdHyperdrive = parseCreatedHyperdrive(
      hyperdriveCreateOutput.stdout,
      target,
    );
    state.hyperdriveId = createdHyperdrive.id;
    assertNewId(
      createdHyperdrive.id,
      state.existingHyperdriveIds,
      "Cloudflare Hyperdrive",
    );

    stage = "cloudflare_hyperdrive_readback";
    const hyperdriveReadbackOutput = await runCommand(cloudflareCommand(
      cloudflareHyperdriveGetArgs(createdHyperdrive.id),
      stage,
      undefined,
      target,
    ));
    const hyperdriveReadback = assertHyperdriveReadback(
      hyperdriveReadbackOutput.stdout,
      {
        id: createdHyperdrive.id,
        username: credential.username,
      },
      target,
    );

    return Object.freeze({
      schema_version: 1,
      receipt_type: "refwatch_production_runtime_provisioning",
      status: "prepared_unbound",
      observed_at_utc: strictUtcInstant(now()),
      production_target: Object.freeze({
        organization: target.organization,
        database: target.database,
        branch: target.branch,
        branch_id: target.branchId,
        runtime_marker: target.runtimeMarker,
        database_name: target.databaseName,
        cloudflare_account_id: target.cloudflareAccountId,
      }),
      planetscale: Object.freeze({
        role_id: credential.id,
        role_name: target.roleName,
        username: credential.username,
        origin_host: target.originHost,
        durable: true,
        ttl: target.roleTtl,
        inherited_roles: [...target.inheritedRoles],
        effective_privileges: Object.freeze({
          read_all_data: true,
          write_all_data: true,
          administrator: false,
          create_database: false,
          create_role: false,
          create_schema: false,
          replication: false,
          bypass_row_security: false,
        }),
      }),
      cloudflare: Object.freeze({
        hyperdrive_id: hyperdriveReadback.id,
        hyperdrive_name: target.hyperdriveName,
        origin: Object.freeze({
          host: target.originHost,
          port: target.originPort,
          database: target.databaseName,
          scheme: target.originScheme,
          user: credential.username,
        }),
        tls_mode: target.hyperdriveTlsMode,
        caching_disabled: target.hyperdriveCachingDisabled,
        connection_limit: target.hyperdriveConnectionLimit,
      }),
      existing_resources: Object.freeze({
        preserved: true,
        changed: false,
        planetscale_role_count: state.existingRoleIds.size,
        cloudflare_hyperdrive_count: state.existingHyperdriveIds.size,
      }),
      candidate_config_update: Object.freeze({
        status: "pending_explicit_atomic_update",
        applied: false,
        must_update_together: true,
        changes: Object.freeze([
          Object.freeze({
            path: target.candidateConfigPaths.hyperdriveId,
            value: hyperdriveReadback.id,
          }),
          Object.freeze({
            path: target.candidateConfigPaths.expectedDatabaseRoleId,
            value: credential.id,
          }),
        ]),
      }),
    });
  } catch {
    const cleanup = await cleanUpCreatedResources({
      runCommand,
      state,
      target,
      sleep,
    });
    throw new ProductionRuntimeProvisioningError(stage, cleanup);
  }
}

export async function verifyPlanetScaleRuntimePrivileges(
  connection,
  options = {},
) {
  const clientConfig = {
    host: connection.host,
    port: connection.port,
    database: connection.database,
    user: connection.username,
    password: connection.password,
    ssl: { rejectUnauthorized: true },
    application_name: "refwatch-production-runtime-provisioner",
    connectionTimeoutMillis: POSTGRES_CONNECTION_TIMEOUT_MS,
    query_timeout: POSTGRES_QUERY_TIMEOUT_MS,
    statement_timeout: POSTGRES_QUERY_TIMEOUT_MS,
    lock_timeout: POSTGRES_LOCK_TIMEOUT_MS,
  };
  const client = options.clientFactory
    ? options.clientFactory(clientConfig)
    : new Client(clientConfig);
  let transactionStarted = false;

  try {
    await client.connect();
    await client.query(
      "BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ",
    );
    transactionStarted = true;
    const markerResult = await client.query(`
      SELECT marker, branch_id, environment
      FROM public.runtime_database_markers
      WHERE marker = $1
    `, [connection.expectedRuntimeMarker]);
    if (
      markerResult.rowCount !== 1
      || markerResult.rows[0]?.marker !== connection.expectedRuntimeMarker
      || markerResult.rows[0]?.branch_id !== connection.expectedBranchId
      || markerResult.rows[0]?.environment !== "production"
    ) {
      throw new Error("Runtime marker readback does not match");
    }
    const rolledBackWriteResult = await client.query(`
      UPDATE public.runtime_database_markers
      SET environment = environment
      WHERE marker = $1
      RETURNING marker
    `, [connection.expectedRuntimeMarker]);
    if (
      rolledBackWriteResult.rowCount !== 1
      || rolledBackWriteResult.rows[0]?.marker
        !== connection.expectedRuntimeMarker
    ) {
      throw new Error("Runtime rolled-back write probe does not match");
    }
    const result = await client.query(`
      SELECT
        current_user,
        current_setting('transaction_read_only') AS transaction_read_only,
        role.rolvaliduntil AS role_valid_until,
        role.rolsuper,
        role.rolcreaterole,
        role.rolcreatedb,
        role.rolreplication,
        role.rolbypassrls,
        pg_has_role(current_user, 'pg_read_all_data', 'member')
          AS can_read_all_data,
        pg_has_role(current_user, 'pg_write_all_data', 'member')
          AS can_write_all_data,
        pg_has_role(current_user, 'postgres', 'member')
          AS can_assume_postgres,
        pg_has_role(current_user, 'pg_database_owner', 'member')
          AS can_assume_database_owner,
        pg_has_role(current_user, 'pg_maintain', 'member')
          AS can_maintain,
        pg_has_role(current_user, 'pg_execute_server_program', 'member')
          AS can_execute_server_program,
        pg_has_role(current_user, 'pg_read_server_files', 'member')
          AS can_read_server_files,
        pg_has_role(current_user, 'pg_write_server_files', 'member')
          AS can_write_server_files,
        has_schema_privilege(current_user, 'public', 'USAGE')
          AS can_use_public_schema,
        has_table_privilege(
          current_user,
          'public.runtime_database_markers',
          'SELECT'
        ) AS can_select_runtime_marker,
        has_table_privilege(
          current_user,
          'public.runtime_database_markers',
          'UPDATE'
        ) AS can_update_runtime_marker,
        has_database_privilege(current_user, current_database(), 'CREATE')
          AS can_create_database_objects,
        has_schema_privilege(current_user, 'public', 'CREATE')
          AS can_create_public_schema
      FROM pg_roles role
      WHERE role.rolname = current_user
    `);
    if (result.rowCount !== 1 || !result.rows[0]) {
      throw new Error("Runtime role privilege readback is incomplete");
    }
    await client.query("ROLLBACK");
    transactionStarted = false;
    return {
      ...result.rows[0],
      runtime_marker: markerResult.rows[0].marker,
      runtime_branch_id: markerResult.rows[0].branch_id,
      runtime_environment: markerResult.rows[0].environment,
      rolled_back_write_row_count: rolledBackWriteResult.rowCount,
    };
  } finally {
    if (transactionStarted) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // The caller receives only the sanitized provisioning stage.
      }
    }
    try {
      await client.end();
    } catch {
      // Connection cleanup must not disclose provider details.
    }
  }
}

export function assertRuntimePrivilegeReadback(
  readback,
  expectedRoleId,
  expectedRuntimeMarker,
  expectedBranchId,
) {
  const expectedCurrentUser = `pscale_api_${expectedRoleId}`;
  if (!isRecord(readback) || readback.current_user !== expectedCurrentUser) {
    throw new Error("Runtime role identity readback does not match");
  }
  if (
    readback.transaction_read_only !== "off"
    || readback.role_valid_until !== null
    || readback.can_read_all_data !== true
    || readback.can_write_all_data !== true
    || readback.can_use_public_schema !== true
    || readback.can_select_runtime_marker !== true
    || readback.can_update_runtime_marker !== true
    || readback.runtime_marker !== expectedRuntimeMarker
    || readback.runtime_branch_id !== expectedBranchId
    || readback.runtime_environment !== "production"
    || readback.rolled_back_write_row_count !== 1
  ) {
    throw new Error("Runtime role is not durable read/write data access");
  }

  const forbiddenCapabilities = [
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
  ];
  if (forbiddenCapabilities.some((field) => readback[field] !== false)) {
    throw new Error("Runtime role has a forbidden administrative capability");
  }
}

export function runCapturedCommand(specification, options = {}) {
  return new Promise((resolvePromise, rejectPromise) => {
    const spawnImpl = options.spawnImpl ?? spawn;
    const timeoutMs = options.timeoutMs ?? COMMAND_TIMEOUT_MS;
    const killGraceMs = options.killGraceMs ?? COMMAND_KILL_GRACE_MS;
    const child = spawnImpl(specification.command, [...specification.args], {
      env: {
        ...process.env,
        ...(specification.environment ?? {}),
      },
      shell: false,
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let capturedBytes = 0;
    let settled = false;
    let terminationRequested = false;
    let overflowed = false;
    let killEscalation;

    const timeout = setTimeout(() => {
      requestTermination();
    }, timeoutMs);

    const capture = (chunk) => {
      capturedBytes += chunk.length;
      if (capturedBytes > MAX_CAPTURED_OUTPUT_BYTES) {
        overflowed = true;
        requestTermination();
        return;
      }
      stdout += chunk.toString("utf8");
    };

    const requestTermination = () => {
      if (settled || terminationRequested) return;
      terminationRequested = true;
      child.kill("SIGTERM");
      killEscalation = setTimeout(() => {
        if (!settled) child.kill("SIGKILL");
      }, killGraceMs);
    };

    child.stdout.on("data", capture);
    child.stderr.on("data", (chunk) => {
      capturedBytes += chunk.length;
      if (capturedBytes > MAX_CAPTURED_OUTPUT_BYTES) {
        overflowed = true;
        requestTermination();
      }
    });
    child.on("error", requestTermination);
    child.on("close", (code, signal) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (killEscalation !== undefined) clearTimeout(killEscalation);
      if (
        code !== 0
        || signal !== null
        || overflowed
        || terminationRequested
      ) {
        rejectPromise(new Error("Provider command failed"));
        return;
      }
      resolvePromise({ stdout });
    });

    child.stdin.on("error", requestTermination);
    child.stdin.end(specification.stdin ?? "");
  });
}

function command(commandName, args, stage, stdin, environment) {
  const specification = { command: commandName, args, stage };
  if (stdin !== undefined) specification.stdin = stdin;
  if (environment !== undefined) specification.environment = environment;
  return specification;
}

function cloudflareCommand(args, stage, stdin, target) {
  return command("cf", args, stage, stdin, {
    CLOUDFLARE_ACCOUNT_ID: target.cloudflareAccountId,
  });
}

function planetscaleRoleListArgs(target) {
  return [
    "role",
    "list",
    target.database,
    target.branch,
    "--org",
    target.organization,
    "--format",
    "json",
    "--no-color",
  ];
}

function planetscaleRoleCreateArgs(target) {
  return [
    "role",
    "create",
    target.database,
    target.branch,
    target.roleName,
    "--org",
    target.organization,
    "--inherited-roles",
    target.inheritedRoles.join(","),
    "--ttl",
    target.roleTtl,
    "--format",
    "json",
    "--no-color",
  ];
}

function planetscaleRoleGetArgs(target, roleId) {
  return [
    "role",
    "get",
    target.database,
    target.branch,
    roleId,
    "--org",
    target.organization,
    "--format",
    "json",
    "--no-color",
  ];
}

function planetscaleRoleDeleteArgs(target, roleId) {
  return [
    "role",
    "delete",
    target.database,
    target.branch,
    roleId,
    "--org",
    target.organization,
    "--force",
    "--format",
    "json",
    "--no-color",
  ];
}

function cloudflareHyperdriveListArgs() {
  return ["--quiet", "hyperdrive", "list"];
}

function cloudflareContextShowArgs() {
  return ["--quiet", "context", "show"];
}

function cloudflareHyperdriveCreateArgs(target, username) {
  return [
    "--quiet",
    "hyperdrive",
    "create",
    "--name",
    target.hyperdriveName,
    "--origin-database",
    target.databaseName,
    "--origin-scheme",
    target.originScheme,
    "--origin-user",
    username,
    "--origin-host",
    target.originHost,
    "--origin-port",
    String(target.originPort),
    "--origin-connection-limit",
    String(target.hyperdriveConnectionLimit),
    "--mtls-sslmode",
    target.hyperdriveTlsMode,
    "--caching-disabled",
  ];
}

function cloudflareHyperdriveGetArgs(hyperdriveId) {
  return ["--quiet", "hyperdrive", "get", hyperdriveId];
}

function cloudflareHyperdriveDeleteArgs(hyperdriveId) {
  return [
    "--quiet",
    "hyperdrive",
    "delete",
    hyperdriveId,
    "--force",
  ];
}

function parseCreatedPlanetScaleRole(stdout, target) {
  const value = parseJsonRecord(stdout, "PlanetScale role create");
  const id = requireOpaqueId(value.id, isPlanetScaleRoleId);
  const username = requireString(value.username);
  const password = requireString(value.password);
  const host = requireString(value.access_host_url);

  if (
    value.name !== target.roleName
    || username !== `pscale_api_${id}.${target.branchId}`
    || host !== target.originHost
    || password.length === 0
    || value.with_replication !== false
  ) {
    throw new Error("Created PlanetScale role does not match");
  }

  return { id, username, password, host };
}

function assertCloudflareAccount(stdout, expectedAccountId) {
  const value = parseJsonRecord(stdout, "Cloudflare account preflight");
  if (
    !isRecord(value.accountId)
    || value.accountId.value !== expectedAccountId
  ) {
    throw new Error("Cloudflare account preflight does not match");
  }
}

function assertPlanetScaleRoleReadback(stdout, credential, target) {
  const value = parseJsonRecord(stdout, "PlanetScale role readback");
  if (
    value.id !== credential.id
    || value.name !== target.roleName
    || value.username !== credential.username
    || value.access_host_url !== target.originHost
    || value.with_replication !== false
    || (typeof value.password === "string" && value.password.length !== 0)
  ) {
    throw new Error("PlanetScale role readback does not match");
  }
}

function parseCreatedHyperdrive(stdout, target) {
  const value = parseJsonRecord(stdout, "Cloudflare Hyperdrive create");
  const id = requireOpaqueId(value.id, isHyperdriveId);
  if (value.name !== target.hyperdriveName) {
    throw new Error("Created Cloudflare Hyperdrive does not match");
  }
  return { id };
}

function assertHyperdriveReadback(stdout, expected, target) {
  const value = parseJsonRecord(stdout, "Cloudflare Hyperdrive readback");
  const origin = value.origin;
  const caching = value.caching;
  const mtls = value.mtls;
  if (
    value.id !== expected.id
    || value.name !== target.hyperdriveName
    || !isRecord(origin)
    || origin.host !== target.originHost
    || origin.port !== target.originPort
    || origin.database !== target.databaseName
    || origin.scheme !== target.originScheme
    || origin.user !== expected.username
    || (typeof origin.password === "string" && origin.password.length !== 0)
    || value.origin_connection_limit !== target.hyperdriveConnectionLimit
    || !isRecord(caching)
    || caching.disabled !== target.hyperdriveCachingDisabled
    || !isRecord(mtls)
    || mtls.sslmode !== target.hyperdriveTlsMode
  ) {
    throw new Error("Cloudflare Hyperdrive readback does not match");
  }
  return { id: expected.id };
}

async function cleanUpCreatedResources({ runCommand, state, target, sleep }) {
  const hyperdrive = state.hyperdriveCreateAttempted
    ? await cleanUpHyperdrive({ runCommand, state, target, sleep })
    : "not_required";
  const planetscaleRole = state.roleCreateAttempted
    ? await cleanUpPlanetScaleRole({ runCommand, state, target, sleep })
    : "not_required";
  return { hyperdrive, planetscaleRole };
}

async function cleanUpHyperdrive({ runCommand, state, target, sleep }) {
  let candidateId = state.hyperdriveId;
  if (candidateId === undefined) {
    const discovered = await discoverCreatedResource({
      runCommand,
      specification: cloudflareCommand(
        cloudflareHyperdriveListArgs(),
        "cloudflare_hyperdrive_cleanup_discovery",
        undefined,
        target,
      ),
      expectedName: target.hyperdriveName,
      existingIds: state.existingHyperdriveIds,
      idValidator: isHyperdriveId,
      sleep,
    });
    if (discovered.status !== "found") return discovered.status;
    candidateId = discovered.id;
  }
  if (state.existingHyperdriveIds.has(candidateId)) {
    return "refused_existing_resource";
  }
  try {
    await runCommand(cloudflareCommand(
      cloudflareHyperdriveDeleteArgs(candidateId),
      "cloudflare_hyperdrive_cleanup",
      undefined,
      target,
    ));
    return "deleted";
  } catch {
    return "delete_failed";
  }
}

async function cleanUpPlanetScaleRole({ runCommand, state, target, sleep }) {
  let candidateId = state.roleId;
  if (candidateId === undefined) {
    const discovered = await discoverCreatedResource({
      runCommand,
      specification: command(
        "pscale",
        planetscaleRoleListArgs(target),
        "planetscale_role_cleanup_discovery",
      ),
      expectedName: target.roleName,
      existingIds: state.existingRoleIds,
      idValidator: isPlanetScaleRoleId,
      sleep,
    });
    if (discovered.status !== "found") return discovered.status;
    candidateId = discovered.id;
  }
  if (state.existingRoleIds.has(candidateId)) {
    return "refused_existing_resource";
  }
  try {
    await runCommand(command(
      "pscale",
      planetscaleRoleDeleteArgs(target, candidateId),
      "planetscale_role_cleanup",
    ));
    return "deleted";
  } catch {
    return "delete_failed";
  }
}

async function discoverCreatedResource({
  runCommand,
  specification,
  expectedName,
  existingIds,
  idValidator,
  sleep,
}) {
  let lastStatus = "not_found";
  for (
    let attempt = 1;
    attempt <= PROVIDER_DISCOVERY_ATTEMPTS;
    attempt += 1
  ) {
    try {
      const output = await runCommand(specification);
      const resources = parseNamedResources(
        output.stdout,
        "cleanup discovery",
        idValidator,
      );
      const matches = resources.filter(({ name }) => name === expectedName);
      if (matches.length > 1) return { status: "ambiguous" };
      const candidate = matches[0];
      if (candidate) {
        if (existingIds.has(candidate.id)) {
          return { status: "refused_existing_resource" };
        }
        return { status: "found", id: candidate.id };
      }
      lastStatus = "not_found";
    } catch {
      lastStatus = "discovery_failed";
    }
    if (attempt < PROVIDER_DISCOVERY_ATTEMPTS) {
      await sleep(PROVIDER_DISCOVERY_DELAY_MS * attempt);
    }
  }
  return { status: lastStatus };
}

function parseNamedResources(stdout, label, idValidator) {
  const value = parseJson(stdout, label);
  const collection = Array.isArray(value)
    ? value
    : isRecord(value) && Array.isArray(value.result)
      ? value.result
      : undefined;
  if (!collection) throw new Error(`${label} is not a resource list`);
  return collection.map((resource) => {
    if (!isRecord(resource)) {
      throw new Error(`${label} includes an invalid resource`);
    }
    return {
      id: requireOpaqueId(resource.id, idValidator),
      name: requireString(resource.name),
    };
  });
}

function parseJsonRecord(stdout, label) {
  const value = parseJson(stdout, label);
  const record = isRecord(value) && isRecord(value.result)
    ? value.result
    : value;
  if (!isRecord(record)) throw new Error(`${label} is not an object`);
  return record;
}

function parseJson(stdout, label) {
  if (typeof stdout !== "string") throw new Error(`${label} is not text`);
  const stripped = stdout.replace(
    // eslint-disable-next-line no-control-regex
    /\u001B(?:\[[0-?]*[ -/]*[@-~]|\][^\u0007]*(?:\u0007|\u001B\\))/gu,
    "",
  ).trim();
  const starts = [];
  for (let index = 0; index < stripped.length; index += 1) {
    if (stripped[index] === "{" || stripped[index] === "[") {
      starts.push(index);
    }
  }
  for (const start of starts) {
    try {
      return JSON.parse(stripped.slice(start));
    } catch {
      // A prompt can precede the final JSON document.
    }
  }
  throw new Error(`${label} is not JSON`);
}

function assertNameAvailable(resources, expectedName, label) {
  if (resources.some(({ name }) => name === expectedName)) {
    throw new Error(`${label} name already exists`);
  }
}

function assertNewId(id, existingIds, label) {
  if (existingIds.has(id)) {
    throw new Error(`${label} create returned a pre-existing ID`);
  }
}

function requireOpaqueId(value, validator) {
  const id = requireString(value);
  if (!validator(id)) throw new Error("Provider returned an invalid opaque ID");
  return id;
}

function requireString(value) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error("Provider returned an invalid string");
  }
  return value;
}

function isPlanetScaleRoleId(value) {
  return /^[a-z0-9]{12}$/u.test(value);
}

function isHyperdriveId(value) {
  return /^[a-f0-9]{32}$/u.test(value);
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function strictUtcInstant(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new Error("Receipt clock is invalid");
  }
  return value.toISOString();
}

function delay(milliseconds) {
  return new Promise((resolvePromise) => {
    setTimeout(resolvePromise, milliseconds);
  });
}

async function main() {
  if (
    process.argv.length !== 3
    || process.argv[2] !== "--execute"
    || process.env.REFWATCH_ALLOW_PRODUCTION_RUNTIME_PROVISIONING !== "1"
  ) {
    process.stderr.write(
      `${JSON.stringify({
        status: "refused",
        reason: "explicit_execution_opt_in_required",
      })}\n`,
    );
    process.exitCode = 1;
    return;
  }

  try {
    const receipt = await provisionProductionRuntime();
    process.stdout.write(`${JSON.stringify(receipt)}\n`);
  } catch (error) {
    const failure = error instanceof ProductionRuntimeProvisioningError
      ? error.toJSON()
      : { status: "failed", stage: "unknown" };
    process.stderr.write(`${JSON.stringify(failure)}\n`);
    process.exitCode = 1;
  }
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : undefined;
if (invokedPath === fileURLToPath(import.meta.url)) {
  await main();
}
