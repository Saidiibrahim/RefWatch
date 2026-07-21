import type { ChildProcess, SpawnOptions } from "node:child_process";

export interface ProductionMigration0017Source {
  schemaReadbackSQL: string;
  cleanTargetReadbackSQL: string;
  ledgerReadbackSQL: string;
  deterministicSeedMigrationSQL: string;
  migrationJournalJSON: string;
  migrationHistoryContractJSON: string;
  previousMigrationSQL: string;
  targetMigrationSQL: string;
  targetSnapshotJSON: string;
}

export interface ValidatedProductionMigration0017Source
  extends ProductionMigration0017Source {
  tableNames: readonly string[];
  migrationHistoryRows: readonly Readonly<{
    id: number;
    hash: string;
    created_at: number;
  }>[];
  schemaReadbackQuery: string;
  cleanTargetReadbackQuery: string;
  ledgerReadbackQuery: string;
}

export interface ProductionMigration0017SessionSpecification {
  command: string;
  args: readonly string[];
  sql: string;
  environment: NodeJS.ProcessEnv;
}

export interface ProductionMigration0017Readback {
  schema_version: number;
  receipt_type: string;
  status: string;
  operation: "applied" | "idempotent_retry";
  provider_command: Readonly<Record<string, unknown>>;
  production_target: Readonly<Record<string, unknown>>;
  source_contract: Readonly<Record<string, unknown>>;
  verified_state: Readonly<{
    schema: Readonly<Record<string, unknown>>;
    migration_history: Readonly<{
      migration_count: number;
      head_id: number;
      head_hash: string;
      head_created_at: number;
      history_md5: string;
      full_history_sha256: string;
    }>;
    migration_history_catalog: Readonly<Record<string, unknown>>;
    history_sequence: Readonly<Record<string, unknown>>;
    target_column: Readonly<Record<string, unknown>>;
    deterministic_seed: Readonly<Record<string, unknown>>;
    clean_target_inventory: Readonly<Record<string, unknown>>;
    ledger: Readonly<Record<string, unknown>>;
  }>;
  identity_receipt: Readonly<Record<string, unknown>>;
  identity_activation: Readonly<Record<string, unknown>>;
  receipt_sha256?: string;
}

export interface ProductionMigration0017Contract {
  organization: string;
  logicalDatabase: string;
  postgresDatabase: string;
  branch: string;
  branchId: string;
  runtimeMarker: string;
  stableOwner: string;
  journalPath: string;
  journalSha256: string;
  historySequence: {
    schema: string;
    name: string;
    dataType: string;
    startValue: number;
    minimumValue: number;
    maximumValue: number;
    incrementBy: number;
    cacheSize: number;
    cycle: boolean;
    previousLastValue: number;
    previousIsCalled: boolean;
    preflightNextValue: number;
    targetRestartWith: number;
    targetIsCalled: boolean;
  };
  previous: {
    index: number;
    tag: string;
    journalTimestamp: number;
    historyId: number;
    fileSha256: string;
    migrationCount: number;
    migrationHistoryMd5: string;
    fullHistorySha256: string;
  };
  target: {
    index: number;
    tag: string;
    journalTimestamp: number;
    historyId: number;
    fileSha256: string;
    migrationCount: number;
    migrationHistoryMd5: string;
    fullHistorySha256: string;
    publicTableCount: number;
    publicColumnCount: number;
    publicColumnsMd5: string;
    catalogContractMd5: string;
    tableName: string;
    columnName: string;
    columnType: string;
    udtName: string;
  };
}

export type ProductionMigration0017SessionRunner = (
  specification: ProductionMigration0017SessionSpecification,
  validateBeforeCommit: (
    value: unknown,
  ) => ProductionMigration0017Readback,
) => Promise<ProductionMigration0017Readback>;

export const productionMigration0017Gate: string;
export const productionMigration0017Command: Readonly<{
  command: "pscale";
  args: readonly string[];
}>;
export const productionMigration0017Contract: Readonly<
  ProductionMigration0017Contract
>;

export function loadProductionMigration0017Sources(): Promise<
  Readonly<ValidatedProductionMigration0017Source>
>;

export function validateProductionMigration0017Sources(
  source: ProductionMigration0017Source,
): Readonly<ValidatedProductionMigration0017Source>;

export function renderProductionMigration0017SQL(
  source:
    | ProductionMigration0017Source
    | ValidatedProductionMigration0017Source,
): string;

export function validateProductionMigration0017Readback(
  value: unknown,
): ProductionMigration0017Readback;

export function createProductionMigration0017Receipt(
  readback: unknown,
): ProductionMigration0017Readback;

export function executeProductionMigration0017(options?: {
  runSession?: ProductionMigration0017SessionRunner;
  environment?: NodeJS.ProcessEnv;
}): Promise<ProductionMigration0017Readback>;

export function runProductionMigration0017Session(
  specification: ProductionMigration0017SessionSpecification,
  validateBeforeCommit: (
    value: unknown,
  ) => ProductionMigration0017Readback,
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
): Promise<ProductionMigration0017Readback>;

export function runProductionMigration0017CLI(options?: {
  args?: readonly string[];
  environment?: NodeJS.ProcessEnv;
  writeStdout?: (value: string) => unknown;
  writeStderr?: (value: string) => unknown;
  checkSources?: () => Promise<unknown>;
  execute?: () => Promise<ProductionMigration0017Readback>;
}): Promise<number>;
