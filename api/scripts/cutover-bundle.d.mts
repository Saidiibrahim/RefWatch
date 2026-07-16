export const sourceTables: readonly string[];
export const importOrder: readonly string[];
export const refWatchSupabaseProjectRef: string;

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
    identityReconciliation: {
      clerkInstanceId: string | null;
      receiptDigest: string;
      mappingHash: string;
      legacyMappingCount: number;
      excludedAuthCount: number;
    };
    importOrder: readonly string[];
  };
}

export function validateCutoverBundle(bundle: unknown, verifiedEvidence?: unknown): CutoverValidationResult;
export function computeCutoverDataSha256(tables: unknown): string;
export function computeSourceAuthSafeDigests(authUser: unknown, identities: unknown[]): {
  authUserSha256: string;
  authIdentitiesSha256: string;
};
