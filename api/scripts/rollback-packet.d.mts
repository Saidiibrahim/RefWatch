export interface RollbackValidationResult {
  ok: boolean;
  errors: string[];
  summary: {
    owner: string | null;
    windowEndUTC: string | null;
    workerName: string | null;
    clientRecovery: string | null;
  };
}

export function validateRollbackPacket(packet: unknown, options?: { now?: Date }): RollbackValidationResult;
