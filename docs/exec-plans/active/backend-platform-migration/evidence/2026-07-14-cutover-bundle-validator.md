# Cutover Bundle Validator — 2026-07-14

The final source export and identity map must never be written as plaintext,
including under ignored paths. The final export must stream from one read-only,
repeatable-read Supabase session directly into authenticated encryption under an
access-controlled `.cutover/` or `api/.cutover/` directory. Validate its
decrypted in-memory representation from `api/` without recording row data in
logs or evidence. Have the approved secret manager inject inherited
`CUTOVER_BUNDLE_KEY_B64`, `CUTOVER_EXPECTED_QUERY_SHA256`, and
`CUTOVER_EXPECTED_GENERATOR_SHA256`, and
`CUTOVER_EXPECTED_CREATOR_RECEIPT_SHA256`; never type values into shell history:

```sh
npm run cutover:validate -- \
  .cutover/final-bundle.enc \
  .cutover/final-bundle.manifest.json \
  .cutover/provider-quiescence-receipt.json \
  .cutover/ledger-quiescence-receipt.json \
  .cutover/artifact-creator-receipt.json
npm test -- --run test/cutoverBundle.test.ts
npm run typecheck
```

The executable verifier opens each file with no-follow semantics, requires the
current operator to own its `0700` directory and `0600` files, checks actual
ciphertext size/SHA-256, authenticates AES-256-GCM, decrypts only in memory,
checks the plaintext SHA-256, and hashes the actual provider/ledger receipts.
Their contents must bind the export ID, source project, query digest, write-
guard version, ledger watermark, and continuous quiescence interval. The core
validator rejects calls without this independently verified context. It pins
the source to RefWatch project `muwuzfbtmqwvwacqnofc`, compares query/generator
hashes to the independently injected release packet, and binds a hashed creator
receipt proving exclusive creation, file/directory fsync, manifest parity, and
atomic rename to the actual ciphertext.

The validator requires and cross-checks:

- an exact `supabase-secure-export` source marker, UTC capture/completion times,
  source project reference, and `REPEATABLE READ, READ ONLY` boundary;
- explicit `final`, import-eligibility, final-export-complete, and continuously
  quiesced source-write declarations; provider and ledger quiescence receipts;
- authenticated-encryption metadata, ciphertext digest/size, directory mode
  `0700`, file mode `0600`, no-symlink and atomic-write receipts, separate key
  custody, and named retention/deletion-verification ownership;
- query/generator/schema/RLS/data digests, including exact server/local data and
  manifest digest parity;
- an explicitly present exported row array, count, and table-specific
  import/seed/blocked/zero-row disposition for every one of the 39 live public
  tables; a non-empty table without a verified import contract hard-blocks
  cutover and cannot be accepted for archival;
- exact count parity between snapshot metadata and export arrays;
- exactly one non-empty opaque Clerk subject for every existing
  `public.users.id`, with no invented/unknown app-user UUID;
- the exact exported source Auth UUID set, its set difference from public users,
  and a reasoned disposition for every actual auth-only identity;
- encrypted allowlisted Auth-user and identity rows with exact count/UUID
  coverage, normalized emails, only the observed email/Apple/Google providers,
  bcrypt-only password-digest migration, no token/raw-metadata fields, and
  source-bound safe digests for the approved auth-only exclusion;
- the one approved auth-only identity bound to normalized email
  `testing@refwatch.com`, a provider identity, no public profile, zero owned or
  referenced rows, and exact `action: "exclude"`; no target mapping or empty app
  user is permitted;
- owner and foreign-key checks over exported rows, including currently verified
  imports plus blocked team children, devices, and AI rows; event team/member
  consistency; the reference catalog's composite competition/season key;
  schedules, matches, page-to-match owner consistency, workouts, and child rows;
- global-seed treatment for workout presets only when every row has
  `created_by = null`; user-owned rows require the import contract, and a mixed
  table requires exact, non-overlapping seed/import ID partitions;
- a deterministic dependency order covering every currently verified import
  table. Previously empty tables whose source/target shapes drift must remain
  zero or the cutover remains blocked until their import contract is added.

The validator requires exact key equality for all 39 table counts, row arrays,
and dispositions; extra as well as missing keys fail closed. Vitest covers a
valid complete bundle, candidate/plaintext/unquiesced and integrity-mismatched
exports, extra or missing table keys, missing/invented mappings, missing
zero-row arrays, an invented auth-only identity with a colliding migration,
unsupported import dispositions, a non-repeatable snapshot, count drift, and
relation/owner orphans, composite reference-season drift, cross-owner pages,
and user-owned presets mislabeled as global seeds. The complete API suite
passed 76/76 across 14 files at that checkpoint; the current superseding suite
passes 78/78 across 14 files as of 2026-07-15.

This tool is validation-only. No final bundle exists yet, it does not contact
PlanetScale, and it cannot replace the reviewed Clerk mapping, final quiesced
encrypted export, production import, or source/target reconciliation evidence.
The sanitized candidate transaction recorded on 2026-07-15 is deliberately
ineligible for this final contract.
