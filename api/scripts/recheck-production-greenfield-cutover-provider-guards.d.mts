export interface ProductionGreenfieldProviderGuardCommandSpecification {
  command: string;
  args: readonly string[];
  cwd: string;
  environment: NodeJS.ProcessEnv;
  signal?: AbortSignal;
}

export interface ProductionGreenfieldProviderGuardCommandResult {
  stdout: Uint8Array | string;
}

export interface ProductionGreenfieldProviderGuardAuditEvidence {
  source: "cloudflare_account_audit_logs_v2";
  account_id: "b08d54b822741dbf8e864503b50604a1";
  complete: true;
  since_utc: string;
  before_utc: string;
  route_mutation_count: 0;
  access_mutation_count: 0;
}

export class ProductionGreenfieldProviderGuardMissingAuditEvidenceError
  extends Error {
  toJSON(): Readonly<{
    schema_version: 1;
    receipt_type: "refwatch_production_greenfield_provider_guard_blocker";
    status: "blocked_missing_audit_evidence";
    audit_source: "cloudflare_account_audit_logs_v2";
    route_mutation_count: null;
    access_mutation_count: null;
    provider_state_read_attempted: false;
  }>;
}

export const productionGreenfieldProviderGuardGate: string;
export const productionGreenfieldProviderGuardCommands: Readonly<{
  wranglerVersion: Readonly<{ command: string; args: readonly string[] }>;
  cloudflareVersion: Readonly<{ command: string; args: readonly string[] }>;
  cloudflareContext: Readonly<{ command: string; args: readonly string[] }>;
  versionsList: Readonly<{ command: string; args: readonly string[] }>;
  deploymentStatus: Readonly<{ command: string; args: readonly string[] }>;
  secretInventory: Readonly<{ command: string; args: readonly string[] }>;
  scriptSubdomain: Readonly<{ command: string; args: readonly string[] }>;
  zoneRoutes: Readonly<{ command: string; args: readonly string[] }>;
  customDomains: Readonly<{ command: string; args: readonly string[] }>;
  dnsRecords: Readonly<{ command: string; args: readonly string[] }>;
  accessApplications: Readonly<{ command: string; args: readonly string[] }>;
}>;

export function loadProductionGreenfieldProviderGuardSources(): Promise<
  Readonly<Record<string, unknown>>
>;
export function validateProductionGreenfieldProviderGuardSources(
  value: unknown,
): Readonly<Record<string, unknown>>;

export function recheckProductionGreenfieldCutoverProviderGuards(
  input: Readonly<{
    checkpoint: Readonly<Record<string, unknown>>;
    clerkWebhookPreparationReceipt: Readonly<Record<string, unknown>>;
    workerLineageReceipt: Readonly<Record<string, unknown>>;
    reviewQuorum: Readonly<Record<string, unknown>>;
    clerkController: Readonly<{ readExact(): Promise<unknown> }>;
    signal?: AbortSignal;
  }>,
  options?: {
    environment?: NodeJS.ProcessEnv;
    loadSources?: () => Promise<unknown>;
    runCommand?: (
      specification: ProductionGreenfieldProviderGuardCommandSpecification,
    ) => Promise<ProductionGreenfieldProviderGuardCommandResult>;
    readAuditEvidence?: (input: Readonly<Record<string, unknown>>) =>
      Promise<ProductionGreenfieldProviderGuardAuditEvidence>;
    now?: () => Date | string | number;
  },
): Promise<Readonly<Record<string, unknown>>>;

export function runProductionGreenfieldProviderGuardCommand(
  specification: ProductionGreenfieldProviderGuardCommandSpecification,
  options?: Readonly<Record<string, unknown>>,
): Promise<ProductionGreenfieldProviderGuardCommandResult>;

export function runProductionGreenfieldProviderGuardCLI(options?: {
  args?: readonly string[];
  writeStdout?: (value: string) => unknown;
  writeStderr?: (value: string) => unknown;
  checkSources?: () => Promise<unknown>;
}): Promise<number>;
