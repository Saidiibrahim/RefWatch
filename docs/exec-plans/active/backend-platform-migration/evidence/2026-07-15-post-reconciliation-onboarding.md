# Post-Reconciliation New-User Gate — 2026-07-15

## Reason for the batch

Independent code-risk review identified a production contradiction: rejecting
every unmapped Clerk subject protects legacy UUID ownership, but would also make
every genuinely new post-cutover signup unusable. A generic allow-unmapped flag
would solve the latter by weakening the former. The implementation now separates
those lifecycle phases with a durable, exact reconciliation receipt.

## Implemented contract

- The final cutover-bundle validator requires the exact production Clerk
  instance ID and emits a deterministic SHA-256 receipt over that instance,
  the normalized legacy identity mapping, its count, and the approved auth-only
  exclusions. It also emits the normalized per-subject mapping registry. The
  approved preliminary auth-only disposition must be exactly `action: "exclude"`.
- `identity_reconciliation_receipts` stores the reviewed receipt digest,
  production Clerk instance, mapping hash/counts, review timestamp, and an
  insertion-time `activated_at` default. That database timestamp is receipt
  insertion metadata, not proof that runtime onboarding variables were
  installed. Migration `0006_nappy_blur.sql` creates the table, checks, and
  indexes.
- Migration `0007_military_sumo.sql` adds the receipt-linked exact legacy
  mapping registry, a separate activation table, and durable deletion
  tombstones keyed by Clerk instance and subject. The activation helper writes
  an activation row only after a transaction verifies registry count/hash and
  every subject-to-preserved-UUID `app_users` row.
- Runtime onboarding remains closed unless writes are enabled, mode is exactly
  `post_reconciliation`, the configured receipt is a 64-hex digest, the exact
  Clerk instance and issuer match request provenance, and the database contains
  the matching verified receipt plus activation row and complete registry.
- When open, a database transaction uses the schema's server-side UUID default
  and `ON CONFLICT DO NOTHING`; concurrent middleware/webhook retries converge
  on one `app_users` row. The client never supplies `owner_id` or the internal
  UUID.
- A subject found in the legacy registry can never receive a replacement UUID;
  a missing or mismatched imported row fails closed. A subject found in deletion
  tombstones can never be provisioned.
- Premature unmapped `user.created` and `user.updated` webhooks return `503`
  with `Retry-After: 300` and are not silently acknowledged. Unknown deletes
  record tombstones without inventing `app_users` mappings. Subject-scoped
  advisory transaction locks serialize create/delete races so deletion wins.
- Bearer JWT `iss` must equal `CLERK_ISSUER`, and runtime provenance passed to
  onboarding must equal `CLERK_INSTANCE_ID`. The installed Clerk SDK's verified
  webhook event contract contains no instance-ID field. Webhook provenance must
  therefore be evidenced by creating the endpoint in the reviewed production
  instance, installing only that endpoint's signing secret, and requiring
  `CLERK_INSTANCE_ID` before any database access.
- `WRITE_MODE=disabled` closes onboarding. The deprecated
  `ALLOW_UNMAPPED_CLERK_USERS` variable never authorizes this production path.

## Verification

From `api/`:

```sh
npm run typecheck
npm test
npm run test:db
```

Results:

- TypeScript typecheck: passed.
- Local Vitest: 10 files, 52 tests passed.
- Real PlanetScale Postgres: 2 files, 8 tests passed, including activation
  count/hash validation, missing-receipt and write-stop rejection, corrupted
  legacy mapping rejection, concurrent idempotent creation, delete-before-create,
  and concurrent deletion-wins behavior.

Migrations `0006_nappy_blur.sql`, `0007_military_sumo.sql`, and custom migrations
`0008_immutable_identity_registry.sql` and
`0009_harden_identity_registry_trigger.sql` were applied only to disposable branch
`cutover-rehearsal-20260714`. Primary readback returned:

- 30 public base tables;
- 10 Drizzle migration rows and all three identity validation/immutability triggers;
- 0 receipts, activations, legacy mappings, or deletion tombstones after tests;
- reference counts unchanged at 5/54/30/3/20.

Production `main` readback remained 0 public base tables. The initial `0007`
attempt rolled back without partial DDL because a fresh ephemeral role could not
reference tables owned by the expired `0006` role. Provider-supported ownership
reassignment moved that role's objects to `postgres`; role `536x2hl13314` was
then deleted. The successful apply used an ephemeral role with `SET ROLE
postgres`; its cleanup succeeded. Sanitized role readback shows neither
migration role remains. Integration-test roles also cleaned up. No credential
value was retained or recorded.

## Remaining production gates

This evidence does not activate onboarding. The final repeatable-read source
snapshot, 42-user mapping, approved exclusion, import/count reconciliation,
deterministic receipt/registry review, verified receipt insertion, transactional
activation, production secret/instance/issuer variable installation, signed
webhook, authenticated deployment proof, and
rollback controls all remain required. The final Supabase snapshot was
intentionally not captured during this batch because it must immediately bound
the final export.

## Independent review disposition

The mandatory docs/evidence re-review found no high-severity issue. Its four
medium findings and two low findings are applied; the previously pending role
cleanup is now provider-verified complete, and earlier 26/6 and 27/7 readbacks
are superseded by 30 tables / 10 migrations plus three triggers.

The mandatory code-risk re-review found two high issues and one medium issue:
an aggregate receipt could not distinguish a missing legacy mapping from a new
subject, an unknown delete could be followed by resurrection, and request
provenance needed an exact production binding. The high issues are applied through
the exact receipt-linked registry/activation transaction, durable tombstones
plus subject locks. Bearer auth uses issuer/instance checks. For webhooks, the
reviewer's suggested event `instance_id` is unavailable in the installed SDK;
the production endpoint's unique signing secret plus provider installation
receipt and required instance configuration form the enforceable binding. Its low activation-timestamp
wording issue is handled by the separate activation table. The unreachable
legacy auth-only migration branches remain harmless cleanup debt in the
validator; every accepted auth-only action is still exactly `exclude`.

A final code-risk pass found one remaining medium: the activated registry was
not database-immutable, so a privileged same-count subject swap could displace
a legacy identity after hash activation. Custom migration
`0008_immutable_identity_registry.sql` adds triggers that reject all mutations
to activated registry rows and identity-changing updates/deletes to their
preserved `app_users`. The real-Postgres suite proves both attempted mutations
fail and the preserved legacy UUID still resolves.

The subsequent concurrency pass found activation and direct identity mutation
were not serialized, and activation rows themselves were mutable. Migration
`0009_harden_identity_registry_trigger.sql` makes registry/app-user writers and
activation share the same transaction advisory lock, validates count/hash and
app-user identity again in the activation trigger, and rejects activation
update/delete. A deterministic real-Postgres race holds an in-flight registry
mutation before activation; activation waits, then fails after observing the
mutation. The disposable test harness uses an explicitly guarded, inherited
`postgres` role only for teardown of immutable fixtures; production runtime
credentials must not inherit `postgres`.
