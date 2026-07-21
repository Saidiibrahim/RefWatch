import type { ChildProcess, SpawnOptions } from "node:child_process";

export interface ProductionGreenfieldIdentityActivationSource {
  schemaReadbackSQL: string;
  cleanTargetReadbackSQL: string;
  ledgerReadbackSQL: string;
  deterministicSeedMigrationSQL: string;
  migrationSnapshotJSON: string;
  migrationJournalJSON: string;
  previousMigrationSQL: string;
  targetMigrationSQL: string;
}

export interface ValidatedProductionGreenfieldIdentityActivationSource
  extends ProductionGreenfieldIdentityActivationSource {
  tableNames: readonly string[];
  schemaReadbackQuery: string;
  cleanTargetReadbackQuery: string;
  ledgerReadbackQuery: string;
}

export interface ProductionGreenfieldIdentityActivationSessionSpecification {
  command: string;
  args: readonly string[];
  sql: string;
  environment: NodeJS.ProcessEnv;
}

export type ProductionGreenfieldIdentityActivationReadback = Readonly<
  Record<string, unknown>
>;

export type ProductionGreenfieldIdentityActivationSessionRunner = (
  specification: ProductionGreenfieldIdentityActivationSessionSpecification,
  validateBeforeCommit: (
    value: unknown,
  ) => ProductionGreenfieldIdentityActivationReadback,
) => Promise<ProductionGreenfieldIdentityActivationReadback>;

export const productionGreenfieldIdentityActivationGate: string;
export const productionGreenfieldIdentityActivationCommand: Readonly<{
  command: "pscale";
  args: readonly string[];
}>;

export function loadProductionGreenfieldIdentityActivationSources(): Promise<
  Readonly<ValidatedProductionGreenfieldIdentityActivationSource>
>;

export function validateProductionGreenfieldIdentityActivationSources(
  source: ProductionGreenfieldIdentityActivationSource,
): Readonly<ValidatedProductionGreenfieldIdentityActivationSource>;

export function renderProductionGreenfieldIdentityActivationSQL(
  source:
    | ProductionGreenfieldIdentityActivationSource
    | ValidatedProductionGreenfieldIdentityActivationSource,
): string;

export function validateProductionGreenfieldIdentityActivationReadback(
  value: unknown,
): ProductionGreenfieldIdentityActivationReadback;

export function createProductionGreenfieldIdentityActivationReceipt(
  readback: unknown,
): ProductionGreenfieldIdentityActivationReadback;

export function executeProductionGreenfieldIdentityActivation(options?: {
  runSession?: ProductionGreenfieldIdentityActivationSessionRunner;
  environment?: NodeJS.ProcessEnv;
}): Promise<ProductionGreenfieldIdentityActivationReadback>;

export function runProductionGreenfieldIdentityActivationSession(
  specification: ProductionGreenfieldIdentityActivationSessionSpecification,
  validateBeforeCommit: (
    value: unknown,
  ) => ProductionGreenfieldIdentityActivationReadback,
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
): Promise<ProductionGreenfieldIdentityActivationReadback>;

export function runProductionGreenfieldIdentityActivationCLI(options?: {
  args?: readonly string[];
  environment?: NodeJS.ProcessEnv;
  writeStdout?: (value: string) => unknown;
  writeStderr?: (value: string) => unknown;
  checkSources?: () => Promise<unknown>;
  execute?: () => Promise<ProductionGreenfieldIdentityActivationReadback>;
}): Promise<number>;
