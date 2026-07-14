export const sourceTables: readonly string[];
export const importOrder: readonly string[];

export interface CutoverValidationResult {
  ok: boolean;
  errors: string[];
  summary: {
    capturedAtUTC: string | null;
    publicTables: number;
    exportedRows: number;
    publicUsers: number;
    clerkMappings: number;
    authOnlyUsers: number;
    importOrder: readonly string[];
  };
}

export function validateCutoverBundle(bundle: unknown): CutoverValidationResult;
