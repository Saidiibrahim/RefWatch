import type { CutoverValidationResult } from "./cutover-bundle.mjs";

export interface EncryptedCutoverInput {
  artifactPath: string;
  manifestPath: string;
  providerReceiptPath: string;
  ledgerReceiptPath: string;
  creatorReceiptPath: string;
  key: string | Buffer;
  expectedQuerySha256: string;
  expectedGeneratorSha256: string;
  expectedCreatorReceiptSha256: string;
  expectedAuthPasswordDigestCounts: { bcrypt_2a: number; missing: number };
  expectedAuthIdentityProviderCounts: { apple: number; email: number; google: number };
}

export function verifyEncryptedCutoverBundle(input: EncryptedCutoverInput): Promise<{
  result: CutoverValidationResult;
  manifest: { exportId: string; artifactSha256: string };
}>;
