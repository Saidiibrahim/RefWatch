import type { SpawnSyncReturns, SpawnSyncOptionsWithStringEncoding } from "node:child_process";

export interface ProductionMigration0016Source {
  journalText: string;
  previousMigrationSql: string;
  targetMigrationSql: string;
}

export interface ValidatedProductionMigration0016Source {
  journalSha256: string;
  previousMigrationSha256: string;
  targetMigrationSha256: string;
  targetMigrationSql: string;
  targetJournalTimestamp: number;
}

export interface ProductionMigration0016Contract {
  organization: string;
  database: string;
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
    publicTableCount: number;
  };
  target: {
    index: number;
    tag: string;
    journalTimestamp: number;
    historyId: number;
    fileSha256: string;
    migrationCount: number;
    migrationHistoryMd5: string;
    publicTableCount: number;
    tableName: string;
    functionNames: readonly string[];
  };
  successor: {
    index: number;
    tag: string;
    journalTimestamp: number;
    migrationCount: number;
  };
}

export const productionMigration0016Contract: Readonly<ProductionMigration0016Contract>;

export function loadProductionMigration0016Contract():
  Promise<Readonly<ValidatedProductionMigration0016Source>>;

export function validateProductionMigration0016Sources(
  source: ProductionMigration0016Source,
): Readonly<ValidatedProductionMigration0016Source>;

export function renderProductionMigration0016(
  source: ProductionMigration0016Source,
): string;

export function executeProductionMigration0016(options?: {
  spawnSyncImpl?: (
    command: string,
    args: readonly string[],
    options: SpawnSyncOptionsWithStringEncoding,
  ) => SpawnSyncReturns<string>;
}): Promise<void>;
