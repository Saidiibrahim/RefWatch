# Isolated mutation-ledger rehearsal — 2026-07-15

## Outcome

The approved isolated rehearsal completed successfully. Migration `0015`,
SHA-256 `6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a`,
was applied only to PlanetScale branch `ledger-rehearsal-20260715`. Worker
version `b745554c-a4e7-4d58-90f8-36bdedd94e7d` was deployed only to environment
`rehearsal`. Its health/readiness checks, v6 synthetic probe, independent
checker, two local restores, guarded poison proof, four remote D1 immutability
negative tests, and final sanitized readbacks passed.

No production mutation command was executed. PlanetScale `main`, the production
Worker, production data, DNS, traffic, identities, and Supabase lifecycle were
outside the approval and remained untouched by this batch. This is a qualified
non-touch statement based on the command audit and last prior production
readbacks; a fresh before/after production provider audit was not performed.

The canonical structured evidence and per-command receipts are in
`evidence/ledger-rehearsal-20260715/`.

## Resource and deployment binding

- PlanetScale: `refwatch/ledger-rehearsal-20260715`, branch ID `ng9tgmy4pyi5`.
- Schema owner role ID: `ys90863xh73y`; runtime role ID: `vwntz0ehq1yp`;
  restricted verifier role ID: `psf6epuvymjt`.
- Database marker: `refwatch:ledger-rehearsal-20260715:ng9tgmy4pyi5`.
- Hyperdrive: `c374273a5bb040d4b4950c28c6012ec5`, cache disabled.
- D1: `d6fd2757-0cfa-4468-97bc-c543de824917`; isolated Queue and DLQ retained.
- Deployment: `9c43008b-e2d0-4388-a589-c0ad124493d9`, 100% at
  `2026-07-15T05:05:43.533583Z`.
- Worker script etag:
  `c7fe13feeaec6962e56ee072a7479b1ea022b21ded00bf2d21a04d4d5477ccc4`.
- Encryption key ID: `rehearsal-20260715-v2`; secret value omitted.

Provider readback found 35 public tables, 16 applied Drizzle migrations, 22
effective capture triggers, 19 archived epochs, no open epoch, and no active
lease. The final ledger aggregate is 63 PostgreSQL delivery rows: 48 delivered,
nine deliberately quarantined, three pending, and three expired leased rows.
D1 contains 34 immutable events and three immutable dead-letter receipts.

## Enforced capture and delivery contract

- Epoch opening and repeatable-read baseline capture share an exclusive
  advisory-lock barrier with transactional domain capture, preventing an
  unbound opening race even for direct SQL writers.
- Migration `0015` constructs a conservative prospective plaintext envelope in
  the domain transaction and rejects it above 245,760 bytes with SQLSTATE
  `22001`. This leaves 16 KiB below the exact 262,144-byte asynchronous encrypted
  envelope ceiling. Real-PostgreSQL integration tests prove oversized inserts
  and updates roll back rather than commit unrecorded mutations.
- Startup requires Hyperdrive in rehearsal/production and verifies the exact
  database marker, branch, and runtime role before serving database work.
- Events are immutable; delivery rows use generation-fenced leases. Existing D1
  events and DLQ receipts are accepted only after exact immutable-field
  comparison. Integrity comparison covers source envelope and delivery identity
  fields; `materialized_at_utc` is a D1 observation timestamp and is excluded.
- AES-256-GCM envelopes bind key ID, nonce, ciphertext, and content digest. Raw
  plaintext, ciphertext, keys, URLs, credentials, and provider error bodies are
  absent from tracked evidence.
- The DLQ consumer requires a quarantined PostgreSQL delivery at the exact lease
  generation. A mismatched generation is marked stale.
- Replay ordering combines entity revisions with schema-contract foreign-key
  dependencies for parent creation, child reassignment, parent deletion, and
  composite keys. Mutation groups reject non-contiguous ordinals.
- Static coverage scans every migration trigger definition and the TypeScript
  AST. It found 35 schema tables, 22 captured domain tables, 13 explicit
  exclusions, six included writer files, and two control writer files. This
  proves routing and trigger installation, not every possible payload shape.
- The live scheduler excludes `integration-*` baselines unless an epoch is
  explicitly requested, keeping real-provider delivery separate from database
  integration fixtures.

## Replay-grade v6 epoch

Epoch `9d9c48ec-fde4-4df8-b967-ea9b890036b7` is the final proof bound to the
deployed runtime:

- Baseline: `planetscale:ng9tgmy4pyi5:2026-07-15T05:08:39.240Z`.
- Schema digest:
  `148ed9bb0a3d0cd2c6d2caeae23104f8b9a2408c73e976957a27acac7ce1ea68`.
- Baseline data digest:
  `b8b76e7856a654e4c936eb07095860c81ade0b543feb946a448e3843b08ebf88`.
- Request: `ledger-probe-7d45e47d-9f6c-4568-b097-de5d91253df7`.
- Sequences 70–72: `app_users` insert, `teams` insert, `teams` update.
- Event IDs: `01632415-38f9-4159-9ebf-691bf4f1e9e6`,
  `817b3247-8c30-48aa-85bd-aa08f442d83c`, and
  `32a7204d-aec3-4d1f-9d08-533a2656ef9e`.

The independent checker pinned exact verifier role `psf6epuvymjt`, opened a
read-only transaction, rejected effective DML privileges on all 22 captured
domain tables, compared two stable primary D1 reads, and verified the DLQ. It
did not prove absence of DML on 13 control/excluded tables or schema-creation
privileges. At frozen watermark 72 it found 3/3
expected/delivered, zero missing/unexpected/metadata mismatch, zero active
leases, and event RPO zero. Stable D1 digest was
`aafc1f1020245885840900b78bb19d22fb1509d3844db7fa63a3729464a146e6`.
The epoch was archived only after the checker and both restores passed.

| Local disposable target | Replayed | Missing/unexpected/mismatched | Schema | Final source/target digest | Procedure | RPO |
| --- | ---: | --- | --- | --- | ---: | ---: |
| Same schema, port 55436 | 3/3 | 0/0/0 | exact | `8bd4f1dd6dcbe48b887ec4e183f8d927f55b3a853381454304d6858e6d99c4f5` | 1.647 s | 0 |
| Second same contract, port 55437 | 3/3 | 0/0/0 | exact | `8bd4f1dd6dcbe48b887ec4e183f8d927f55b3a853381454304d6858e6d99c4f5` | 1.563 s | 0 |

Both local PostgreSQL targets were stopped afterward. Neither was Supabase.
These narrow script timings are not a production recovery-time objective.

## Guarded poison and D1 immutability proof

The final guarded poison script enforces exact branch and D1 allowlists plus an
explicit opt-in. It created epoch `b9edcf73-aa08-459e-8584-001e866822f2`, event
`9f055164-9a70-476f-a552-0308fe287596`, sequence 73, then wrote the deliberate
D1 conflict `worker_version_id=intentional-poison-conflict` before releasing
delivery.

PostgreSQL ended at `quarantined`, generation 1, attempt 1, no active lease, and
sanitized error `queue_attempt=6; code=d1_metadata_conflict`. Primary D1 readback
found immutable receipt `44c07a824abe6774d93e0b837543d7e5`, generation 1,
consumer attempt 1, disposition `quarantined`, received at
`2026-07-15T05:13:30.530Z`. The epoch was archived.

Four separate remote D1 commands attempted event update, event delete, dead
letter update, and dead letter delete. Every command failed as expected with
exit code 1 and `SQLITE_CONSTRAINT_TRIGGER`; there were no unexpected successes.

## Per-epoch reconciliation

The receipt bundle lists all 19 epochs and their exact PostgreSQL/D1 counts.
Provider replay epochs reconcile exactly. Poison epochs intentionally retain a
conflicting D1 event and a quarantined delivery/DLQ receipt. Integration epochs
are marked `integration-baseline`, use a fake D1 test adapter, and are excluded
from provider replay acceptance.

Three archived integration epochs retain one pending row each; one also retains
three expired leased rows. No lease is active. Earlier test/scheduler overlap
also materialized a subset of integration fixtures into D1. These historical
rows remain immutable and are reported rather than rewritten. The scheduler
filter added during remediation prevents recurrence.

## Verification totals

- Typecheck passed.
- Vitest passed 61/61 across 12 files.
- Real PlanetScale PostgreSQL integration passed 19/19 across three files.
- Coverage passed at 35/22/13 with six included and two control writer files.
- Wrangler 4.110.0 dry-run passed at 1,508.06 KiB total / 271.48 KiB gzip.
- `git diff --check` passed before the evidence bundle update and is rerun during
  final closeout.

## Remaining production blockers

This rehearsal does not complete the production migration. Production requires
its own separately approved resources, roles, marker, Queue/D1/DLQ, encryption
key escrow/rotation, and an encrypted access-controlled baseline store with
defined retention/deletion. It also requires a populated rollback packet,
reviewed table-specific reverse-import procedure, final Supabase snapshot and
reconciliation, exact Clerk identity mapping and approved exclusion, production
import/deployment, authenticated route matrix, Clerk DNS/native-app/webhook
completion, and physical iPhone/watch acceptance.
