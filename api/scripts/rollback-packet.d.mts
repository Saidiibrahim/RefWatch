export type RollbackProfile =
  | "stateful_migration_v1"
  | "greenfield_destructive_v1"
  | "greenfield_destructive_v2"
  | "greenfield_destructive_v3";

export type RollbackRecoveryMode =
  | "stateful_ledger_recovery"
  | "destructive_reset_reseed_recreate";

export interface RollbackValidationResult {
  ok: boolean;
  errors: string[];
  summary: {
    rollbackProfile: RollbackProfile | null;
    owner: string | null;
    windowEndUTC: string | null;
    workerName: string | null;
    recoveryMode: RollbackRecoveryMode | null;
    clientRecovery: string | null;
  };
}

export function validateRollbackPacket(packet: unknown, options?: { now?: Date }): RollbackValidationResult;
export function validateHistoricalGreenfieldRollbackPacketV2(
  packet: unknown,
  options?: { now?: Date },
): RollbackValidationResult;
