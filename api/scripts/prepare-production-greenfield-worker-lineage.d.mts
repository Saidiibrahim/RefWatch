import type { ChildProcess, SpawnOptions } from "node:child_process";
import type { Readable } from "node:stream";
import type { ProductionClerkWebhookPreparationReceipt } from
  "./prepare-production-clerk-webhook.mjs";

export interface ProductionGreenfieldWorkerLineageSourceEntry {
  path: string;
  content: string | NodeJS.ArrayBufferView;
}

export interface ProductionGreenfieldWorkerLineageSources {
  entries: ProductionGreenfieldWorkerLineageSourceEntry[];
}

export interface ValidatedProductionGreenfieldWorkerLineageSources {
  manifestSha256: string;
  fileCount: number;
  wranglerConfigSha256: string;
  packageLockSha256: string;
  greenfieldLaunchPacketSha256: string;
  greenfieldLaunchPacketDeclarationSha256: string;
  productionClerkWebhookPreparationSha256: string;
  productionClerkWebhookPreparationDeclarationSha256: string;
  productionRuntimeProvisioningSha256: string;
  productionRuntimeProvisioningDeclarationSha256: string;
  rollbackPacketSha256: string;
  rollbackPacketDeclarationSha256: string;
  manifest: readonly Readonly<{
    path: string;
    byte_count: number;
    sha256: string;
  }>[];
}

export interface ProductionGreenfieldWorkerLineageSecretMaterial {
  clerkWebhookSigningSecret: Uint8Array;
  cutoverAcceptanceToken: Uint8Array;
}

export interface ProductionGreenfieldWorkerLineageCommandSpecification {
  command: string;
  args: readonly string[];
  cwd: string;
  environment: NodeJS.ProcessEnv;
  stdin?: Uint8Array;
  signal?: AbortSignal;
}

export interface ProductionGreenfieldWorkerLineageCommandResult {
  stdout: Uint8Array | string;
}

export type ProductionGreenfieldWorkerLineageCommandRunner = (
  specification: ProductionGreenfieldWorkerLineageCommandSpecification,
) => Promise<ProductionGreenfieldWorkerLineageCommandResult>;

export type ProductionGreenfieldWorkerLineageReceipt = Readonly<
  Record<string, unknown>
>;

export const productionGreenfieldWorkerLineageGate: string;

export const productionGreenfieldWorkerLineageOrchestration: Readonly<{
  executionMode: "reviewed_same_process_cutover_orchestrator";
  outerTechnicalGate: "REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER";
  clerkTechnicalGate: "REFWATCH_ALLOW_PRODUCTION_CLERK_WEBHOOK_PREPARATION";
  lineageTechnicalGate: string;
}>;

export const productionGreenfieldWorkerLineageCommands: Readonly<{
  wranglerCommand: "./node_modules/.bin/wrangler";
  cloudflareCommand: "cf";
  wranglerVersion: Readonly<{ command: string; args: readonly string[] }>;
  cloudflareVersion: Readonly<{ command: string; args: readonly string[] }>;
  versionsList: Readonly<{ command: string; args: readonly string[] }>;
  deploymentStatus: Readonly<{ command: string; args: readonly string[] }>;
  secretInventory: Readonly<{ command: string; args: readonly string[] }>;
  webhookSecretPut: Readonly<{ command: string; args: readonly string[] }>;
  cutoverSecretPut: Readonly<{ command: string; args: readonly string[] }>;
  candidateUpload: Readonly<{ command: string; args: readonly string[] }>;
  acceptedUpload: Readonly<{ command: string; args: readonly string[] }>;
  writeGuardUpload: Readonly<{ command: string; args: readonly string[] }>;
}>;

export function productionGreenfieldWorkerVersionViewCommand(
  versionId: string,
): Readonly<{ command: string; args: readonly string[] }>;

export function loadProductionGreenfieldWorkerLineageSources(): Promise<
  Readonly<ValidatedProductionGreenfieldWorkerLineageSources>
>;

export function loadProductionGreenfieldWorkerLineageSourceInput(): Promise<
  ProductionGreenfieldWorkerLineageSources
>;

export function validateProductionGreenfieldWorkerLineageSources(
  source: ProductionGreenfieldWorkerLineageSources,
): Readonly<ValidatedProductionGreenfieldWorkerLineageSources>;

export function executeProductionGreenfieldWorkerLineage(options?: {
  environment?: NodeJS.ProcessEnv;
  loadSources?: () => Promise<ValidatedProductionGreenfieldWorkerLineageSources>;
  clerkWebhookPreparationReceipt: ProductionClerkWebhookPreparationReceipt;
  secretMaterial: ProductionGreenfieldWorkerLineageSecretMaterial;
  runCommand?: ProductionGreenfieldWorkerLineageCommandRunner;
  now?: () => Date | string | number;
  delay?: (milliseconds: number) => Promise<unknown>;
  signal?: AbortSignal;
}): Promise<ProductionGreenfieldWorkerLineageReceipt>;

export function withProductionGreenfieldWorkerLineageLease<T>(
  consumer: (
    execute: (options: {
      clerkWebhookPreparationReceipt: ProductionClerkWebhookPreparationReceipt;
      secretMaterial: ProductionGreenfieldWorkerLineageSecretMaterial;
      loadSources?: () => Promise<ValidatedProductionGreenfieldWorkerLineageSources>;
      runCommand?: ProductionGreenfieldWorkerLineageCommandRunner;
      now?: () => Date | string | number;
      delay?: (milliseconds: number) => Promise<unknown>;
      signal?: AbortSignal;
    }) => Promise<ProductionGreenfieldWorkerLineageReceipt>,
  ) => Promise<T> | T,
  options?: { environment?: NodeJS.ProcessEnv },
): Promise<T>;

export function validateProductionGreenfieldWorkerLineageReceipt(
  value: unknown,
): ProductionGreenfieldWorkerLineageReceipt;

export function runProductionGreenfieldWorkerLineageCommand(
  specification: ProductionGreenfieldWorkerLineageCommandSpecification,
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
): Promise<ProductionGreenfieldWorkerLineageCommandResult>;

export function readProductionGreenfieldWorkerLineageSecretMaterial(
  input: AsyncIterable<Uint8Array | string>,
): Promise<ProductionGreenfieldWorkerLineageSecretMaterial>;

export function runProductionGreenfieldWorkerLineageCLI(options?: {
  args?: readonly string[];
  environment?: NodeJS.ProcessEnv;
  stdin?: Readable;
  writeStdout?: (value: string) => unknown;
  writeStderr?: (value: string) => unknown;
  checkSources?: () => Promise<unknown>;
}): Promise<number>;
