import { afterEach, describe, expect, it } from "vitest";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createCipheriv, createHash, randomBytes } from "node:crypto";
import { verifyEncryptedCutoverBundle } from "../scripts/encrypted-cutover-bundle.mjs";
import { computeCutoverDataSha256, computeSourceAuthSafeDigests, sourceTables } from "../scripts/cutover-bundle.mjs";

const created: string[] = [];
const sha256 = (value: Buffer) => createHash("sha256").update(value).digest("hex");

afterEach(async () => {
  await Promise.all(created.splice(0).map((path) => rm(path, { recursive: true, force: true })));
});

async function fixture(snapshotOverrides: Record<string, string> = {}, complete = false) {
  const directory = await mkdtemp(join(tmpdir(), "refwatch-cutover-"));
  created.push(directory);
  await chmod(directory, 0o700);
  const key = randomBytes(32);
  const nonce = randomBytes(12);
  const bundle: any = {
    snapshot: {
      export_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f30",
      source_project_ref: "muwuzfbtmqwvwacqnofc",
      query_sha256: "a".repeat(64),
      generator_sha256: "b".repeat(64),
    },
  };
  Object.assign(bundle.snapshot, snapshotOverrides);
  const userId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2a";
  const authOnlyId = "0190f8f4-5914-7b6c-9d6a-469a29f92f2b";
  const migratedUserIds = [userId, ...Array.from({ length: 41 }, (_, index) => `0190f8f4-5914-7b6c-9d6a-${(0x469a29f93000 + index).toString(16)}`)];
  const tables = Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? migratedUserIds.map((id) => ({ id })) : []]));
  const providerReceipt: Record<string, unknown> = { receipt_type: "provider-write-quiescence" };
  const ledgerReceipt: Record<string, unknown> = { receipt_type: "mutation-ledger-quiescence" };
  if (complete) {
    const localDataSha256 = computeCutoverDataSha256(tables);
    const sourceAuthUsers = [...migratedUserIds, authOnlyId].map((id, index) => ({
      id,
      email: id === authOnlyId ? "testing@refwatch.com" : index === 0 ? "owner@example.com" : `user${index}@example.com`,
      encrypted_password: index < 13 ? "$2a$10$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ01234" : null,
      password_hasher: index < 13 ? "bcrypt" : null,
      created_at: "2026-07-15T02:00:00Z",
      updated_at: "2026-07-15T02:00:00Z",
      email_confirmed_at: "2026-07-15T02:00:00Z",
      last_sign_in_at: null,
      banned_until: null,
      deleted_at: null,
      is_sso_user: false,
      is_anonymous: false,
    }));
    const identityFor = (id: string, user: any, provider: string, suffix: number) => ({
      id, user_id: user.id, provider, provider_id: `${provider}-${suffix}`, email: user.email,
      created_at: "2026-07-15T02:00:00Z", updated_at: "2026-07-15T02:00:00Z", last_sign_in_at: null,
    });
    const sourceAuthIdentities = [
      identityFor("0190f8f4-5914-7b6c-9d6a-469a29f92f40", sourceAuthUsers[0], "email", 0),
      identityFor("0190f8f4-5914-7b6c-9d6a-469a29f92f41", sourceAuthUsers[42], "google", 42),
      ...sourceAuthUsers.slice(1, 13).map((user, index) => identityFor(`0190f8f4-5914-7b6c-9d6a-${(0x469a29f94000 + index).toString(16)}`, user, "email", index + 1)),
      ...sourceAuthUsers.slice(13, 34).map((user, index) => identityFor(`0190f8f4-5914-7b6c-9d6a-${(0x469a29f95000 + index).toString(16)}`, user, "apple", index)),
      ...sourceAuthUsers.slice(34, 42).map((user, index) => identityFor(`0190f8f4-5914-7b6c-9d6a-${(0x469a29f96000 + index).toString(16)}`, user, "google", index)),
      identityFor("0190f8f4-5914-7b6c-9d6a-469a29f92f42", sourceAuthUsers[0], "apple", 99),
    ];
    const authOnlyDigests = computeSourceAuthSafeDigests(sourceAuthUsers[42], [sourceAuthIdentities[1]]);
    Object.assign(bundle, {
      production_clerk_instance_id: "ins_production123",
      tables,
      table_dispositions: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? "import" : "exclude_zero"])),
      clerk_mappings: migratedUserIds.map((id, index) => ({ app_user_id: id, clerk_user_id: `user_reviewed_subject_${index}` })),
      source_auth_users: sourceAuthUsers,
      source_auth_identities: sourceAuthIdentities,
      auth_only_users: [{
        auth_user_id: authOnlyId,
        action: "exclude",
        reason: "No application profile or owned data",
        normalized_email: "testing@refwatch.com",
        public_profile_present: false,
        owned_row_count: 0,
        provider_identity_count: 1,
        auth_user_safe_sha256: authOnlyDigests.authUserSha256,
        auth_identity_safe_sha256: authOnlyDigests.authIdentitiesSha256,
      }],
    });
    Object.assign(bundle.snapshot, {
      source: "supabase-secure-export",
      status: "final",
      final: true,
      eligible_for_import: true,
      writes_quiesced: true,
      final_export_complete: true,
      transaction_isolation: "repeatable read",
      read_only: true,
      captured_at_utc: "2026-07-15T03:00:00Z",
      completed_at_utc: "2026-07-15T03:00:01Z",
      schema_contract_sha256: "e".repeat(64),
      rls_contract_sha256: "f".repeat(64),
      server_data_sha256: localDataSha256,
      local_data_sha256: localDataSha256,
      artifact: {
        encrypted: true,
        retention_owner: "migration-owner",
        retention_event: "observation closeout",
        deletion_verification_required: true,
      },
      auth_user_count: 43,
      auth_identity_count: 44,
      auth_password_digest_counts: { bcrypt_2a: 13, missing: 30 },
      auth_identity_provider_counts: { apple: 22, email: 13, google: 9 },
      auth_user_ids: [...migratedUserIds, authOnlyId],
      public_table_counts: Object.fromEntries(sourceTables.map((table) => [table, table === "users" ? 42 : 0])),
      quiescence: {
        write_mode_disabled: true,
        source_writes_stopped: true,
        ledger_watermark: 0,
        write_guard_version_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f2c",
        required_through_utc: "2026-07-15T03:00:02Z",
      },
    });
    const receiptFields = {
      source_project_ref: bundle.snapshot.source_project_ref,
      export_id: bundle.snapshot.export_id,
      query_sha256: bundle.snapshot.query_sha256,
      generator_sha256: bundle.snapshot.generator_sha256,
      write_guard_version_id: bundle.snapshot.quiescence.write_guard_version_id,
      write_mode_disabled: true,
      source_writes_stopped: true,
      ledger_watermark: 0,
      quiescence_started_at_utc: "2026-07-15T02:59:59Z",
      quiescence_observed_through_utc: "2026-07-15T03:00:02Z",
    };
    Object.assign(providerReceipt, receiptFields);
    Object.assign(ledgerReceipt, receiptFields);
    bundle.snapshot.quiescence.provider_receipt_sha256 = sha256(Buffer.from(JSON.stringify(providerReceipt)));
    bundle.snapshot.quiescence.ledger_receipt_sha256 = sha256(Buffer.from(JSON.stringify(ledgerReceipt)));
  }
  const plaintext = Buffer.from(JSON.stringify(bundle));
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const manifest = {
    version: 1,
    cipher: "aes-256-gcm",
    export_id: bundle.snapshot.export_id,
    source_project_ref: bundle.snapshot.source_project_ref,
    query_sha256: bundle.snapshot.query_sha256,
    generator_sha256: bundle.snapshot.generator_sha256,
    nonce_base64: nonce.toString("base64"),
    tag_base64: cipher.getAuthTag().toString("base64"),
    artifact_sha256: sha256(ciphertext),
    byte_size: ciphertext.length,
    plaintext_sha256: sha256(plaintext),
  };
  const paths = {
    artifactPath: join(directory, "bundle.enc"),
    manifestPath: join(directory, "manifest.json"),
    providerReceiptPath: join(directory, "provider.json"),
    ledgerReceiptPath: join(directory, "ledger.json"),
    creatorReceiptPath: join(directory, "creator.json"),
  };
  const manifestBytes = Buffer.from(JSON.stringify(manifest));
  const creatorReceipt = {
    receipt_type: "encrypted-artifact-creation",
    export_id: bundle.snapshot.export_id,
    source_project_ref: bundle.snapshot.source_project_ref,
    query_sha256: bundle.snapshot.query_sha256,
    generator_sha256: bundle.snapshot.generator_sha256,
    cipher: manifest.cipher,
    artifact_sha256: manifest.artifact_sha256,
    byte_size: manifest.byte_size,
    manifest_sha256: sha256(manifestBytes),
    exclusive_create: true,
    fsync_file: true,
    fsync_directory: true,
    atomic_rename: true,
  };
  await Promise.all([
    writeFile(paths.artifactPath, ciphertext, { mode: 0o600 }),
    writeFile(paths.manifestPath, manifestBytes, { mode: 0o600 }),
    writeFile(paths.providerReceiptPath, JSON.stringify(providerReceipt), { mode: 0o600 }),
    writeFile(paths.ledgerReceiptPath, JSON.stringify(ledgerReceipt), { mode: 0o600 }),
    writeFile(paths.creatorReceiptPath, JSON.stringify(creatorReceipt), { mode: 0o600 }),
  ]);
  return {
    ...paths,
    key,
    expectedQuerySha256: bundle.snapshot.query_sha256,
    expectedGeneratorSha256: bundle.snapshot.generator_sha256,
    expectedCreatorReceiptSha256: sha256(Buffer.from(JSON.stringify(creatorReceipt))),
    expectedAuthPasswordDigestCounts: { bcrypt_2a: 13, missing: 30 },
    expectedAuthIdentityProviderCounts: { apple: 22, email: 13, google: 9 },
    directory,
  };
}

describe("encrypted cutover bundle verification", () => {
  it("authenticates and decrypts only in memory before schema validation", async () => {
    const input = await fixture();
    const verified = await verifyEncryptedCutoverBundle(input);
    expect(verified.manifest.exportId).toBe("0190f8f4-5914-7b6c-9d6a-469a29f92f30");
    expect(verified.result.ok).toBe(false);
    expect(verified.result.errors).not.toContain("encrypted artifact and quiescence evidence must be independently verified");
  });

  it("passes a complete encrypted bundle with real creator and quiescence files", async () => {
    const input = await fixture({}, true);
    const verified = await verifyEncryptedCutoverBundle(input);
    expect(verified.result.ok).toBe(true);
    expect(verified.result.summary).toMatchObject({ publicTables: 39, publicUsers: 42, clerkMappings: 42 });
  });

  it("rejects insecure permissions and ciphertext tampering", async () => {
    const insecure = await fixture();
    await chmod(insecure.artifactPath, 0o644);
    await expect(verifyEncryptedCutoverBundle(insecure)).rejects.toThrow("file mode must be 0600");

    const tampered = await fixture();
    await writeFile(tampered.artifactPath, Buffer.from("tampered"), { mode: 0o600 });
    await expect(verifyEncryptedCutoverBundle(tampered)).rejects.toThrow("ciphertext digest or size mismatch");
  });

  it("rejects the wrong project and release-packet exporter hashes", async () => {
    const wrongProject = await fixture({ source_project_ref: "abcdefghijklmnopqrst" });
    await expect(verifyEncryptedCutoverBundle(wrongProject)).rejects.toThrow("wrong RefWatch source_project_ref");

    const wrongQueryPolicy = await fixture();
    wrongQueryPolicy.expectedQuerySha256 = "c".repeat(64);
    await expect(verifyEncryptedCutoverBundle(wrongQueryPolicy)).rejects.toThrow("query_sha256 is not approved");

    const wrongGeneratorPolicy = await fixture();
    wrongGeneratorPolicy.expectedGeneratorSha256 = "d".repeat(64);
    await expect(verifyEncryptedCutoverBundle(wrongGeneratorPolicy)).rejects.toThrow("generator_sha256 is not approved");
  });

  it("rejects creator-policy, manifest-parity, atomic, and receipt-file drift", async () => {
    const wrongCreatorPolicy = await fixture({}, true);
    wrongCreatorPolicy.expectedCreatorReceiptSha256 = "0".repeat(64);
    await expect(verifyEncryptedCutoverBundle(wrongCreatorPolicy)).rejects.toThrow("creator receipt is not approved");

    const wrongManifest = await fixture({}, true);
    const creator = JSON.parse(await readFile(wrongManifest.creatorReceiptPath, "utf8"));
    creator.manifest_sha256 = "0".repeat(64);
    const creatorBytes = Buffer.from(JSON.stringify(creator));
    await writeFile(wrongManifest.creatorReceiptPath, creatorBytes, { mode: 0o600 });
    wrongManifest.expectedCreatorReceiptSha256 = sha256(creatorBytes);
    expect((await verifyEncryptedCutoverBundle(wrongManifest)).result.errors).toContain("artifact creator receipt does not match detached manifest");

    const nonAtomic = await fixture({}, true);
    const nonAtomicCreator = JSON.parse(await readFile(nonAtomic.creatorReceiptPath, "utf8"));
    nonAtomicCreator.atomic_rename = false;
    const nonAtomicBytes = Buffer.from(JSON.stringify(nonAtomicCreator));
    await writeFile(nonAtomic.creatorReceiptPath, nonAtomicBytes, { mode: 0o600 });
    nonAtomic.expectedCreatorReceiptSha256 = sha256(nonAtomicBytes);
    expect((await verifyEncryptedCutoverBundle(nonAtomic)).result.errors).toContain("artifact creator receipt must prove exclusive create, fsync, and atomic rename");

    const receiptDrift = await fixture({}, true);
    const provider = JSON.parse(await readFile(receiptDrift.providerReceiptPath, "utf8"));
    provider.ledger_watermark = 9;
    await writeFile(receiptDrift.providerReceiptPath, JSON.stringify(provider), { mode: 0o600 });
    expect((await verifyEncryptedCutoverBundle(receiptDrift)).result.errors).toContain("provider receipt digest does not match verified file");
  });
});
