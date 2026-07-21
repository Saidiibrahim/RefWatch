import type { ChildProcess, SpawnOptions } from "node:child_process";

export interface ProductionClerkWebhookPreparationSourceInput {
  packageJSON: string;
  packageLock: string;
  launchPacket: string | NodeJS.ArrayBufferView;
}

export interface ValidatedProductionClerkWebhookPreparationSources {
  clerkBackendVersion: "3.11.4";
  clerkCliVersion: "2.2.0";
  clerkLockContractSha256: string;
  launchPacketSha256: string;
  portalAssetPath: string;
  portalAssetSha256: string;
}

export interface ProductionClerkWebhookPreparationCommandSpecification {
  command: "./node_modules/.bin/clerk";
  args: readonly string[];
  cwd: string;
  environment: NodeJS.ProcessEnv;
}

export interface ProductionClerkWebhookPreparationCommandResult {
  stdout: Uint8Array | string;
}

export type ProductionClerkWebhookPreparationCommandRunner = (
  specification: ProductionClerkWebhookPreparationCommandSpecification,
) => Promise<ProductionClerkWebhookPreparationCommandResult>;

export interface ProductionClerkWebhookPortalProtocolReceipt {
  portalOrigin: "https://app.svix.com";
  loginURL: "https://app.svix.com/login";
  assetPath: string;
  assetSha256: string;
}

export interface ProductionClerkWebhookFinalProviderReadback {
  svix_application_id: string;
  endpoint_inventory_count: number;
  endpoint_id: string;
  endpoint_uid: string;
  endpoint_url: string;
  endpoint_description: string;
  event_types: readonly string[];
  disabled: boolean;
  header_count: number;
  sensitive_header_name_count: number;
  transformation_enabled: boolean;
  transformation_present: boolean;
}

export type ProductionClerkWebhookPreparationReceipt = Readonly<
  Record<string, unknown> & {
    schema_version?: number;
    receipt_type?: string;
    status?: string;
    operation?: string;
    observed_at_utc?: string;
    clerk: Readonly<Record<string, unknown>>;
    svix: Readonly<Record<string, unknown>>;
    final_provider_readback:
      Readonly<ProductionClerkWebhookFinalProviderReadback>;
    receipt_sha256: string;
  }
>;

export interface ProductionClerkWebhookExactControllerReadback {
  observed_at_utc: string;
  clerk_cli_version: "2.2.0";
  clerk_application_id: "app_3GWFGTs5EGNXyzQ4idk7p6JdsUP";
  clerk_application_name: "refwatch";
  clerk_instance_id: "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac";
  user_count: 0;
  svix_application_id: string;
  endpoint_inventory_count: 1;
  endpoint_id: string;
  endpoint_uid: "refwatch-production-clerk-lifecycle-v1";
  endpoint_url: "https://api.refwatch.ibby.ai/webhooks/clerk";
  endpoint_description: "RefWatch production Clerk lifecycle";
  event_types: readonly ["user.created", "user.updated", "user.deleted"];
  disabled: boolean;
  header_count: 0;
  sensitive_header_name_count: 0;
  transformation_enabled: false;
  transformation_present: false;
  endpoint_created_at_utc: string;
  endpoint_updated_at_utc: string;
}

export interface ProductionClerkWebhookEndpointController {
  readExact(): Promise<Readonly<ProductionClerkWebhookExactControllerReadback>>;
  setDisabled(
    expected: boolean,
    next: boolean,
  ): Promise<Readonly<{
    operation: "set_disabled";
    expected_disabled: boolean;
    disabled: boolean;
    before: Readonly<ProductionClerkWebhookExactControllerReadback>;
    after: Readonly<ProductionClerkWebhookExactControllerReadback>;
  }>>;
}

export interface ProductionClerkWebhookSecretCallbackInput {
  secretMaterial: Buffer;
  receipt: ProductionClerkWebhookPreparationReceipt;
  controller: Readonly<ProductionClerkWebhookEndpointController>;
}

export const productionClerkWebhookPreparationGate: string;

export const productionClerkWebhookTarget: Readonly<{
  clerkApplicationId: "app_3GWFGTs5EGNXyzQ4idk7p6JdsUP";
  clerkApplicationName: "refwatch";
  developmentClerkInstanceId: "ins_3GWFGUvUfsAjzPeVYjDjckfls0a";
  clerkInstanceId: "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac";
  endpointUid: "refwatch-production-clerk-lifecycle-v1";
  endpointDescription: "RefWatch production Clerk lifecycle";
  endpointURL: "https://api.refwatch.ibby.ai/webhooks/clerk";
  eventTypes: readonly ["user.created", "user.updated", "user.deleted"];
  disabled: true;
}>;

export const productionClerkWebhookCommands: Readonly<{
  version: Readonly<{
    command: "./node_modules/.bin/clerk";
    args: readonly string[];
  }>;
  whoami: Readonly<{
    command: "./node_modules/.bin/clerk";
    args: readonly string[];
  }>;
  userCount: Readonly<{
    command: "./node_modules/.bin/clerk";
    args: readonly string[];
  }>;
  svixURL: Readonly<{
    command: "./node_modules/.bin/clerk";
    args: readonly string[];
  }>;
}>;

export const productionClerkWebhookPortalContract: Readonly<{
  portalOrigin: "https://app.svix.com";
  loginURL: "https://app.svix.com/login";
  assetPath: string;
  assetSha256: string;
  exchangePath: "/api/v1/auth/one-time-token";
  requiredCapabilities: readonly ["ManageEndpoint", "ViewEndpointSecret"];
  supportedCapabilities: readonly string[];
  supportedRegions: readonly ["au", "ca", "eu", "in", "us"];
}>;

export function loadProductionClerkWebhookPreparationSources(): Promise<
  Readonly<ValidatedProductionClerkWebhookPreparationSources>
>;

export function validateProductionClerkWebhookPreparationSources(
  source: ProductionClerkWebhookPreparationSourceInput,
): Readonly<ValidatedProductionClerkWebhookPreparationSources>;

export function loadProductionClerkWebhookPortalProtocol(options?: {
  fetchProvider?: typeof fetch;
  fetchTimeoutMs?: number;
}): Promise<Readonly<ProductionClerkWebhookPortalProtocolReceipt>>;

export function parseProductionClerkWebhookSvixURL(value: string): Readonly<{
  appId: string;
  region: string;
  oneTimeToken: string;
}>;

export function withProductionClerkWebhookSecret<T>(
  consumer: (
    input: ProductionClerkWebhookSecretCallbackInput,
  ) => Promise<T> | T,
  options?: {
    environment?: NodeJS.ProcessEnv;
    loadSources?: () => Promise<ValidatedProductionClerkWebhookPreparationSources>;
    runCommand?: ProductionClerkWebhookPreparationCommandRunner;
    fetchProvider?: typeof fetch;
    fetchTimeoutMs?: number;
    loadPortalProtocol?: () => Promise<
      ProductionClerkWebhookPortalProtocolReceipt
    >;
    now?: () => Date | string | number;
  },
): Promise<T>;

export function runProductionClerkWebhookPreparationCommand(
  specification: ProductionClerkWebhookPreparationCommandSpecification,
  options?: {
    spawnImpl?: (
      command: string,
      args: readonly string[],
      options: SpawnOptions,
    ) => ChildProcess;
    timeoutMs?: number;
    maxOutputBytes?: number;
    killGraceMs?: number;
  },
): Promise<ProductionClerkWebhookPreparationCommandResult>;

export function validateProductionClerkWebhookPreparationReceipt(
  value: unknown,
): ProductionClerkWebhookPreparationReceipt;

export function runProductionClerkWebhookPreparationCLI(options?: {
  args?: readonly string[];
  writeStdout?: (value: string) => unknown;
  writeStderr?: (value: string) => unknown;
  checkSources?: () => Promise<unknown>;
}): Promise<number>;
