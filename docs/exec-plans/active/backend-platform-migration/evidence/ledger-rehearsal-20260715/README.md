# Ledger rehearsal receipt bundle — 2026-07-15

## Disposition

The approved isolated rehearsal is complete. Migration `0015` with SHA-256
`6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a`
was applied only to PlanetScale branch `ledger-rehearsal-20260715`. The final
runtime was deployed only as Worker environment `rehearsal`; its synthetic
probe, independent checker, two local restores, guarded poison proof, four D1
immutability negative tests, and sanitized readbacks passed.

No production mutation command was executed. PlanetScale `main`, the
production Worker, production data, DNS, traffic, identities, and Supabase
lifecycle were not changed. This non-touch claim is qualified: it is supported
by the command audit and the last prior provider readbacks, not a new
before/after production-state audit.

## Final proof binding

- Worker version: `b745554c-a4e7-4d58-90f8-36bdedd94e7d`.
- Deployment: `9c43008b-e2d0-4388-a589-c0ad124493d9`, 100% at
  `2026-07-15T05:05:43.533583Z`.
- Worker script etag:
  `c7fe13feeaec6962e56ee072a7479b1ea022b21ded00bf2d21a04d4d5477ccc4`.
- PlanetScale branch ID: `ng9tgmy4pyi5`; Hyperdrive ID:
  `c374273a5bb040d4b4950c28c6012ec5`.
- Restricted verifier role ID: `psf6epuvymjt`. The checker requires its exact
  `current_user`, a read-only transaction, and absence of effective DML on the
  22 captured domain tables. It does not cover the 13 control/excluded tables
  or schema-creation privileges.
- D1 ID: `d6fd2757-0cfa-4468-97bc-c543de824917`; Queue and DLQ remained the
  isolated rehearsal resources.
- Health returned `status=ok`; the cache-busted readiness probe returned
  `status=ready`, `database=reachable`, and `database_identity=verified`.

## Receipt layout

- `receipts.json` is the canonical structured summary.
- `commands/` contains one sanitized session receipt per verification operation.
  Each records a stable command ID, command shape, available tool/version and
  exit status, and the complete non-secret result used for review. Where the
  original shell start/end timestamps or raw ANSI/provider wrapper output were
  not retained, the receipt says so explicitly; it does not invent timestamps
  or represent a short prefix as a full artifact hash. Provider-issued times,
  exact digests, and current rerun times are retained where available.
- `manifest.sha256` binds this README, `receipts.json`, and every tracked command
  receipt after the bundle is final.
- Ciphertext-bearing raw D1 exports, plaintext baselines, database URLs, API
  tokens, role passwords, and encryption keys are intentionally omitted.
  Published checker and baseline SHA-256 digests permit comparison without
  disclosing those materials.

## Verified behavior

- Capture is database-transactional. Migration `0015` rejects a conservative
  prospective plaintext envelope above 245,760 bytes inside the domain
  transaction, leaving 16 KiB below the 262,144-byte asynchronous encrypted
  ceiling. Oversized insert and update tests prove rollback.
- The 35-table coverage classification resolves to 22 capture tables and 13
  explicit exclusions. Validation scans all migration trigger definitions and
  uses the TypeScript AST to verify included application DML is routed through
  the transaction receiver.
- Replay ordering incorporates live foreign-key dependencies, including parent
  creation, child reassignment, parent deletion, and composite keys.
- An existing D1 event or DLQ receipt is accepted only after exact immutable
  metadata comparison. D1 integrity comparison covers the source envelope and
  delivery identity fields; `materialized_at_utc` is intentionally not treated
  as source metadata.
- The final v6 epoch `9d9c48ec-fde4-4df8-b967-ea9b890036b7` delivered and
  replayed all three events with zero missing, unexpected, or mismatched rows
  and measured event RPO zero. Both local restore targets produced final digest
  `8bd4f1dd6dcbe48b887ec4e183f8d927f55b3a853381454304d6858e6d99c4f5`.
- The guarded poison epoch `b9edcf73-aa08-459e-8584-001e866822f2` produced the
  intended immutable D1 metadata conflict, a generation-one quarantine, and
  DLQ receipt `44c07a824abe6774d93e0b837543d7e5`.
- Remote D1 update and delete attempts against both events and dead letters all
  failed with exit code 1 and `SQLITE_CONSTRAINT_TRIGGER`.

## Epoch reconciliation

All 19 PlanetScale epochs are archived and have capture enforcement disabled.
There are no open epochs and no active leases. The final aggregate is 63
delivery rows: 48 delivered, nine deliberately quarantined, three pending, and
three expired leased rows. D1 holds 34 immutable events and three immutable DLQ
receipts.

The pending and expired leased rows belong only to archived `integration-*`
baseline fixtures created by earlier real-PostgreSQL test runs. Those tests use
a fake D1 adapter and are excluded from provider replay acceptance. A scheduler
race allowed some earlier integration rows to be observed by the live rehearsal
scheduler; the final scheduler now excludes `integration-*` epochs unless an
epoch ID is explicitly requested. The retained history is reported as-is and
was not rewritten to manufacture a clean aggregate.

## Local verification

- TypeScript typecheck: passed.
- Vitest: 61/61 across 12 files.
- Real PlanetScale PostgreSQL integration: 19/19 across three files.
- Coverage validator: 35/22/13 tables, six included writer files, two control
  writer files.
- Wrangler dry-run: 1,508.06 KiB total, 271.48 KiB gzip.

## Production limitations at rehearsal completion

This bundle is not production acceptance. At the time this rehearsal completed,
production still needed a separately approved, encrypted and access-controlled
baseline store with defined retention and deletion; production-specific
PlanetScale, Hyperdrive, Queue, D1, DLQ, and key custody; a populated rollback
packet; a reviewed reverse-import procedure; authenticated deployed route
checks; the final Supabase snapshot and reconciliation; exact identity mapping;
Clerk DNS, native-app, and webhook completion; and physical iPhone/watch
acceptance.

Later production-foundation and owned-domain work supersedes part of that
point-in-time list: the inactive production infrastructure exists and the
`refwatch.ibby.ai` Clerk domain is verified. Current remaining gates are recorded
in `../2026-07-15-production-foundation-execution.md`,
`../2026-07-17-production-clerk-domain.md`, and the active migration plan.
