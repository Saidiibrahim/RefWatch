#!/usr/bin/env node

import { verifyEncryptedCutoverBundle } from "./encrypted-cutover-bundle.mjs";

const [artifactPath, manifestPath, providerReceiptPath, ledgerReceiptPath, creatorReceiptPath] = process.argv.slice(2);
if (!artifactPath || !manifestPath || !providerReceiptPath || !ledgerReceiptPath || !creatorReceiptPath) {
  console.error("Usage: node scripts/validate-cutover-bundle.mjs <bundle.enc> <manifest.json> <provider-receipt.json> <ledger-receipt.json> <creator-receipt.json>");
  process.exit(2);
}

const key = process.env.CUTOVER_BUNDLE_KEY_B64;
const expectedQuerySha256 = process.env.CUTOVER_EXPECTED_QUERY_SHA256;
const expectedGeneratorSha256 = process.env.CUTOVER_EXPECTED_GENERATOR_SHA256;
const expectedCreatorReceiptSha256 = process.env.CUTOVER_EXPECTED_CREATOR_RECEIPT_SHA256;
const expectedAuthPasswordDigestCounts = {
  bcrypt_2a: Number(process.env.CUTOVER_EXPECTED_AUTH_BCRYPT_2A_COUNT),
  missing: Number(process.env.CUTOVER_EXPECTED_AUTH_PASSWORD_MISSING_COUNT),
};
const expectedAuthIdentityProviderCounts = {
  apple: Number(process.env.CUTOVER_EXPECTED_AUTH_APPLE_COUNT),
  email: Number(process.env.CUTOVER_EXPECTED_AUTH_EMAIL_COUNT),
  google: Number(process.env.CUTOVER_EXPECTED_AUTH_GOOGLE_COUNT),
};
if (!key || !expectedQuerySha256 || !expectedGeneratorSha256 || !expectedCreatorReceiptSha256 || Object.values(expectedAuthPasswordDigestCounts).some((value) => !Number.isInteger(value)) || Object.values(expectedAuthIdentityProviderCounts).some((value) => !Number.isInteger(value))) {
  console.error("The cutover key and reviewed query/generator hashes must be inherited from separate release-packet custody");
  process.exit(2);
}
const { result, manifest } = await verifyEncryptedCutoverBundle({ artifactPath, manifestPath, providerReceiptPath, ledgerReceiptPath, creatorReceiptPath, key, expectedQuerySha256, expectedGeneratorSha256, expectedCreatorReceiptSha256, expectedAuthPasswordDigestCounts, expectedAuthIdentityProviderCounts });
console.log(JSON.stringify(result.summary, null, 2));
if (!result.ok) {
  for (const error of result.errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(`Encrypted cutover bundle validation passed for ${manifest.exportId}.`);
