export interface ProviderCommandSpecification {
  command: string;
  args: readonly string[];
  stage: string;
  stdin?: string;
  environment?: Readonly<Record<string, string>>;
}

export interface ProviderCommandResult {
  stdout: string;
}

export type ProviderCommandRunner = (
  specification: ProviderCommandSpecification,
) => Promise<ProviderCommandResult>;

export interface RuntimePrivilegeConnection {
  host: string;
  port: number;
  database: string;
  username: string;
  password: string;
  expectedRoleId: string;
  expectedBranchId: string;
  expectedRuntimeMarker: string;
}

export interface RuntimePrivilegeReadback {
  current_user: string;
  transaction_read_only: string;
  role_valid_until: null | Date | string;
  rolsuper: boolean;
  rolcreaterole: boolean;
  rolcreatedb: boolean;
  rolreplication: boolean;
  rolbypassrls: boolean;
  can_read_all_data: boolean;
  can_write_all_data: boolean;
  can_assume_postgres: boolean;
  can_assume_database_owner: boolean;
  can_maintain: boolean;
  can_execute_server_program: boolean;
  can_read_server_files: boolean;
  can_write_server_files: boolean;
  can_use_public_schema: boolean;
  can_select_runtime_marker: boolean;
  can_update_runtime_marker: boolean;
  can_create_database_objects: boolean;
  can_create_public_schema: boolean;
  runtime_marker: string;
  runtime_branch_id: string;
  runtime_environment: string;
  rolled_back_write_row_count: number;
}

export interface RuntimePrivilegeClient {
  connect(): Promise<void>;
  query(
    text: string,
    values?: readonly unknown[],
  ): Promise<{
    rowCount: number | null;
    rows: Array<Record<string, unknown>>;
  }>;
  end(): Promise<void>;
}

export interface ProductionRuntimeProvisioningTarget {
  organization: string;
  database: string;
  branch: string;
  branchId: string;
  runtimeMarker: string;
  databaseName: string;
  originHost: string;
  originPort: number;
  originScheme: string;
  roleName: string;
  inheritedRoles: readonly string[];
  roleTtl: string;
  hyperdriveName: string;
  cloudflareAccountId: string;
  hyperdriveTlsMode: string;
  hyperdriveCachingDisabled: boolean;
  hyperdriveConnectionLimit: number;
  candidateConfigPaths: {
    hyperdriveId: string;
    expectedDatabaseRoleId: string;
  };
}

export interface ProductionRuntimeReceipt {
  schema_version: 1;
  receipt_type: "refwatch_production_runtime_provisioning";
  status: "prepared_unbound";
  observed_at_utc: string;
  production_target: {
    organization: string;
    database: string;
    branch: string;
    branch_id: string;
    runtime_marker: string;
    database_name: string;
    cloudflare_account_id: string;
  };
  planetscale: {
    role_id: string;
    role_name: string;
    username: string;
    origin_host: string;
    durable: true;
    ttl: string;
    inherited_roles: string[];
    effective_privileges: {
      read_all_data: true;
      write_all_data: true;
      administrator: false;
      create_database: false;
      create_role: false;
      create_schema: false;
      replication: false;
      bypass_row_security: false;
    };
  };
  cloudflare: {
    hyperdrive_id: string;
    hyperdrive_name: string;
    origin: {
      host: string;
      port: number;
      database: string;
      scheme: string;
      user: string;
    };
    tls_mode: string;
    caching_disabled: boolean;
    connection_limit: number;
  };
  existing_resources: {
    preserved: true;
    changed: false;
    planetscale_role_count: number;
    cloudflare_hyperdrive_count: number;
  };
  candidate_config_update: {
    status: "pending_explicit_atomic_update";
    applied: false;
    must_update_together: true;
    changes: readonly [
      { path: string; value: string },
      { path: string; value: string },
    ];
  };
}

export interface ProvisionProductionRuntimeOptions {
  runCommand?: ProviderCommandRunner;
  verifyPrivileges?: (
    connection: RuntimePrivilegeConnection,
  ) => Promise<RuntimePrivilegeReadback>;
  now?: () => Date;
  sleep?: (milliseconds: number) => Promise<void>;
}

export const productionRuntimeProvisioningTarget:
  Readonly<ProductionRuntimeProvisioningTarget>;

export class ProductionRuntimeProvisioningError extends Error {
  readonly stage: string;
  readonly cleanup: Readonly<{
    hyperdrive: string;
    planetscaleRole: string;
  }>;
  toJSON(): {
    status: "failed";
    stage: string;
    cleanup: {
      hyperdrive: string;
      planetscale_role: string;
    };
  };
}

export function provisionProductionRuntime(
  options?: ProvisionProductionRuntimeOptions,
): Promise<Readonly<ProductionRuntimeReceipt>>;

export function verifyPlanetScaleRuntimePrivileges(
  connection: RuntimePrivilegeConnection,
  options?: {
    clientFactory?: (
      config: Readonly<Record<string, unknown>>,
    ) => RuntimePrivilegeClient;
  },
): Promise<RuntimePrivilegeReadback>;

export function assertRuntimePrivilegeReadback(
  readback: unknown,
  expectedRoleId: string,
  expectedRuntimeMarker: string,
  expectedBranchId: string,
): void;

export function runCapturedCommand(
  specification: ProviderCommandSpecification,
  options?: {
    spawnImpl?: typeof import("node:child_process").spawn;
    timeoutMs?: number;
    killGraceMs?: number;
  },
): Promise<ProviderCommandResult>;
