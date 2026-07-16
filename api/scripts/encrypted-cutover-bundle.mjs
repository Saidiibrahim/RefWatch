import { constants, lstat, open } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { createDecipheriv, createHash } from "node:crypto";
import { refWatchSupabaseProjectRef, validateCutoverBundle } from "./cutover-bundle.mjs";

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function mode(stat) {
  return (stat.mode & 0o777).toString(8).padStart(4, "0");
}

async function readSecureFile(path, { requireDirectory0700 = true } = {}) {
  const absolute = resolve(path);
  const parent = dirname(absolute);
  const [fileStat, directoryStat] = await Promise.all([
    lstat(absolute),
    lstat(parent),
  ]);
  if (!fileStat.isFile() || fileStat.isSymbolicLink()) throw new Error(`${path}: must be a regular non-symlink file`);
  if (!directoryStat.isDirectory() || directoryStat.isSymbolicLink()) throw new Error(`${path}: parent path must be a real non-symlink directory`);
  if (mode(fileStat) !== "0600") throw new Error(`${path}: file mode must be 0600`);
  if (requireDirectory0700 && mode(directoryStat) !== "0700") throw new Error(`${path}: directory mode must be 0700`);
  if (typeof process.getuid === "function" && (fileStat.uid !== process.getuid() || directoryStat.uid !== process.getuid())) {
    throw new Error(`${path}: file and directory must be owned by the current operator`);
  }
  const handle = await open(absolute, constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0));
  try {
    const openedStat = await handle.stat();
    if (openedStat.dev !== fileStat.dev || openedStat.ino !== fileStat.ino) throw new Error(`${path}: file changed during secure open`);
    const bytes = await handle.readFile();
    return {
      bytes,
      sha256: sha256(bytes),
      byteSize: bytes.length,
      mode: mode(openedStat),
      directoryMode: mode(directoryStat),
      noSymlink: true,
      ownerVerified: true,
    };
  } finally {
    await handle.close();
  }
}

function parseJson(bytes, label) {
  try {
    return JSON.parse(bytes.toString("utf8"));
  } catch {
    throw new Error(`${label}: invalid JSON`);
  }
}

function decodeBase64(value, expectedLength, label) {
  if (typeof value !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) throw new Error(`${label}: invalid base64`);
  const decoded = Buffer.from(value, "base64");
  if (decoded.length !== expectedLength) throw new Error(`${label}: expected ${expectedLength} bytes`);
  return decoded;
}

export async function verifyEncryptedCutoverBundle({ artifactPath, manifestPath, providerReceiptPath, ledgerReceiptPath, creatorReceiptPath, key, expectedQuerySha256, expectedGeneratorSha256, expectedCreatorReceiptSha256, expectedAuthPasswordDigestCounts, expectedAuthIdentityProviderCounts }) {
  const [artifactFile, manifestFile, providerFile, ledgerFile, creatorFile] = await Promise.all([
    readSecureFile(artifactPath),
    readSecureFile(manifestPath),
    readSecureFile(providerReceiptPath),
    readSecureFile(ledgerReceiptPath),
    readSecureFile(creatorReceiptPath),
  ]);
  const manifest = parseJson(manifestFile.bytes, "manifest");
  const providerReceipt = parseJson(providerFile.bytes, "provider receipt");
  const ledgerReceipt = parseJson(ledgerFile.bytes, "ledger receipt");
  const creatorReceipt = parseJson(creatorFile.bytes, "creator receipt");
  if (!/^[0-9a-f]{64}$/.test(expectedCreatorReceiptSha256 ?? "") || creatorFile.sha256 !== expectedCreatorReceiptSha256) throw new Error("creator receipt is not approved by the release packet");
  if (manifest.version !== 1 || manifest.cipher !== "aes-256-gcm") throw new Error("manifest: unsupported encrypted bundle format");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(manifest.export_id ?? "")) throw new Error("manifest: invalid export_id");
  if (manifest.source_project_ref !== refWatchSupabaseProjectRef) throw new Error("manifest: wrong RefWatch source_project_ref");
  if (!/^[0-9a-f]{64}$/.test(expectedQuerySha256 ?? "") || manifest.query_sha256 !== expectedQuerySha256) throw new Error("manifest: query_sha256 is not approved by the release packet");
  if (!/^[0-9a-f]{64}$/.test(expectedGeneratorSha256 ?? "") || manifest.generator_sha256 !== expectedGeneratorSha256) throw new Error("manifest: generator_sha256 is not approved by the release packet");
  if (!/^[0-9a-f]{64}$/.test(manifest.plaintext_sha256 ?? "")) throw new Error("manifest: invalid plaintext_sha256");
  if (manifest.artifact_sha256 !== artifactFile.sha256 || manifest.byte_size !== artifactFile.byteSize) throw new Error("manifest: ciphertext digest or size mismatch");
  const keyBytes = Buffer.isBuffer(key) ? key : decodeBase64(key, 32, "CUTOVER_BUNDLE_KEY_B64");
  if (keyBytes.length !== 32) throw new Error("cutover key must contain exactly 32 bytes");
  const nonce = decodeBase64(manifest.nonce_base64, 12, "manifest nonce");
  const tag = decodeBase64(manifest.tag_base64, 16, "manifest authentication tag");
  let plaintext;
  try {
    const decipher = createDecipheriv("aes-256-gcm", keyBytes, nonce);
    decipher.setAuthTag(tag);
    plaintext = Buffer.concat([decipher.update(artifactFile.bytes), decipher.final()]);
  } catch {
    throw new Error("encrypted cutover bundle authentication failed");
  }
  if (manifest.plaintext_sha256 !== sha256(plaintext)) throw new Error("manifest: decrypted bundle digest mismatch");
  const bundle = parseJson(plaintext, "decrypted bundle");
  for (const [field, manifestField] of [["export_id", "export_id"], ["source_project_ref", "source_project_ref"], ["query_sha256", "query_sha256"], ["generator_sha256", "generator_sha256"]]) {
    if (bundle?.snapshot?.[field] !== manifest[manifestField]) throw new Error(`manifest: ${manifestField} does not match decrypted bundle`);
  }
  if (providerReceipt.receipt_type !== "provider-write-quiescence") throw new Error("provider receipt: wrong receipt_type");
  if (ledgerReceipt.receipt_type !== "mutation-ledger-quiescence") throw new Error("ledger receipt: wrong receipt_type");
  const result = validateCutoverBundle(bundle, {
    verified: true,
    artifact: {
      ...artifactFile,
      cipher: manifest.cipher,
      plaintextSha256: manifest.plaintext_sha256,
    },
    providerReceipt: { sha256: providerFile.sha256, data: providerReceipt },
    ledgerReceipt: { sha256: ledgerFile.sha256, data: ledgerReceipt },
    creatorReceipt: { sha256: creatorFile.sha256, data: creatorReceipt },
    manifestSha256: manifestFile.sha256,
    releasePolicy: {
      querySha256: expectedQuerySha256,
      generatorSha256: expectedGeneratorSha256,
      creatorReceiptSha256: expectedCreatorReceiptSha256,
      authPasswordDigestCounts: expectedAuthPasswordDigestCounts,
      authIdentityProviderCounts: expectedAuthIdentityProviderCounts,
    },
  });
  return { result, manifest: { exportId: manifest.export_id, artifactSha256: artifactFile.sha256 } };
}
