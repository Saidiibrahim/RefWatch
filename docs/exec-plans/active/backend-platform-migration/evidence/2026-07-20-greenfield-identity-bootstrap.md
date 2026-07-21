# Greenfield Zero-Legacy Identity Bootstrap — 2026-07-20

## Scope and boundary

This batch converts the runtime identity gate from a required positive legacy
mapping registry to an explicit, fail-closed greenfield bootstrap while
preserving the stateful migration path. It used only disposable loopback
PostgreSQL and local Worker tooling. It did not query or mutate PlanetScale,
Clerk, Cloudflare, Supabase, Google, traffic, production secrets, or physical
devices.

The non-secret anchors are:

- authorization profile: `refwatch.greenfield-authorization.v1`;
- authorization digest:
  `17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b`;
- reconciliation profile: `greenfield_zero_legacy_v1`;
- reconciliation receipt:
  `27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18`;
- canonical empty-mapping hash:
  `4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945`;
- production Clerk instance: `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`;
- issuer: `https://clerk.refwatch.ibby.ai`; and
- domain: `refwatch.ibby.ai`.

These values identify reviewed decisions and provider resources. They are not
credentials.

## Implemented contract

- Migration `0016_careless_steel_serpent.sql` permits zero mappings only for the
  exact authorization-bound greenfield profile. Stateful receipts still require
  a positive mapping count.
- Greenfield activation requires the exact verified receipt, zero legacy
  mappings, the canonical empty hash, and zero `app_users`. One immutable
  activation is allowed per Clerk instance. Repeating the exact activation is
  idempotent before and after new users exist.
- Receipt, activation, legacy-mapping, and Clerk-delivery trigger paths share
  deterministic advisory-lock ordering. An `app_users` insert takes the
  production reconciliation lock even when an in-flight receipt is not yet
  visible, preventing activation from racing ahead of a pre-receipt user.
- New Clerk subjects receive only database-generated internal UUIDs.
  Instance-plus-subject locks make concurrent creates converge on one row.
  Durable deletion tombstones make delete-before-create, delayed update, and
  concurrent create/delete permutations deletion-wins.
- The production runtime mode is explicitly `greenfield_bootstrap`. It requires
  enabled writes plus the exact receipt, authorization digest, Clerk instance,
  and issuer. `ALLOW_UNMAPPED_CLERK_USERS` remains inert.
- Bearer JWT issuer/instance verification remains fail closed. Auth verifier
  exceptions now log only a generic message.
- After Clerk signature verification, the lifecycle handler parses the same
  signed raw event and requires its `object`, `instance_id`, event type, Clerk
  subject, and millisecond event timestamp before database access. The instance
  must match exact configuration, type and subject must match the verified SDK
  projection, and timestamp must be a positive safe integer.
- Immutable delivery receipts are keyed by Clerk instance plus Svix ID. An exact
  retry is acknowledged once; changed type, subject, or payload hash under the
  same ID is rejected. The receipt and lifecycle effect share one mutation
  transaction.
- The new delivery table participates in strict mutation capture when an
  isolated capture-enforced epoch is deliberately opened. With no active epoch,
  normal transactions create no mutation outbox or delivery rows.
- `npm run test:db` is now hermetic and loopback-only. The former PlanetScale
  rehearsal remains available only as
  `test:db:historical:planetscale-rehearsal`.

## Artifact integrity

- migration `0016` SHA-256:
  `0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac`;
- identity-profile source SHA-256:
  `996ea269526516ffffadc1bd4c185cd4d129debc048f1c2952a3124233168619`;
- hermetic database runner SHA-256:
  `7691df88aef124e13f06cd214abc5d63bd091e885a78baf4a02fb60082ed497f`;
- Drizzle generation readback: 36 tables and no schema changes remaining.

## Local verification

From `api/` after all code-risk dispositions:

- `npm run typecheck`: passed.
- `npm test`: 14 files, 129 tests passed.
- `npm run test:db`: fresh migrations `0000`–`0016`, 1 file, 17 tests passed.
- `npm run test:local:routes`: fresh migrations `0000`–`0016`, 1 file,
  4 tests passed.
- `npm run mutation:coverage`: 36 schema tables, 23 capture-trigger tables,
  13 explicit control/reference exclusions, 5 included writer files, and
  2 ledger control-plane writers; passed.
- `wrangler types --env production`: passed and regenerated the exact production
  binding/variable types.
- `wrangler deploy --dry-run --env production`: passed for Worker
  `refwatch-api`; `WRITE_MODE` and onboarding remained disabled. Queue and D1
  bindings remain declared but were not activated or used.
- `git diff --check`: passed.
- Gitleaks scans of the tracked diff and the explicitly enumerated untracked
  batch files passed. The Stripe Projects `.projects` directory was not
  inspected.

The database cases cover exact/malformed receipt profiles, pre-receipt
activation serialization, pre-activation transactional rollback, activation
idempotence after onboarding, immutable receipt/activation/mapping/delivery
state, eight-way concurrent provisioning, eight-way same-Svix retry, conflicting
delivery reuse, disabled-write deletion denial, lifecycle create/update/delete,
atomic receipt/effect rollback, and delete-wins concurrency. The inactive path
committed lifecycle mutations with zero outbox/delivery rows. An isolated opened
epoch captured exactly the lifecycle delivery receipt and `app_users` insert,
then froze and archived locally.

The mounted local fetch matrix runs without a ledger key, Queue consumer, D1
consumer, cron trigger, or live provider. This is local runtime behavior proof,
not a current production control-plane readback.

## Mandatory code-risk review

The interim code-risk review found:

1. missing signed raw Clerk envelope provenance validation;
2. a direct deletion lifecycle write-mode bypass;
3. a pre-receipt user/activation visibility race;
4. missing strict-capture coverage for delivery receipts;
5. missing same-Svix and pre-receipt concurrency tests;
6. verifier exception details in logs;
7. non-deterministic cross-instance mapping lock order; and
8. non-idempotent repeated activation after the first user existed.

All findings were applied and regression-proved. The final code-risk re-review
reported `NO FINDINGS`.

## Mandatory docs/evidence consistency review

The reviewer found four documentation inconsistencies:

1. webhook timestamp agreement was stronger than the implemented validation;
2. the inactive-ledger proof remained unchecked in the task file;
3. several current-result statements still used the historical 93-test
   checkpoint; and
4. this review closure trail was missing.

All findings were applied: timestamp validation is stated exactly, the
inactive-ledger task is complete, the 93-test result is explicitly historical,
and the current 129/17/4 checkpoint plus this disposition are synchronized
across the plan and evidence. The final docs/evidence re-review reported
`NO FINDINGS`.

## Remaining boundary

This artifact does not claim that migration `0016` is applied to production,
that the production target is clean, that the zero-legacy receipt is inserted or
activated in PlanetScale, that the runtime role is writable, or that the Clerk
webhook exists. Fresh provider baseline, target preparation, Clerk/native/OAuth
configuration, write-disabled deployment/routing, signed webhook acceptance,
the full authenticated route matrix, iOS/watch acceptance, traffic cutover, and
legacy retirement remain separate ordered batches.
