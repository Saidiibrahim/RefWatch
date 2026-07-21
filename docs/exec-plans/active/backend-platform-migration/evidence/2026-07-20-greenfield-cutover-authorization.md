# Greenfield cutover authorization

Date: 2026-07-20

Decision status: authorized; execution evidence remains separate

Launch profile: `refwatch.greenfield-authorization.v1`

## Decision

RefWatch is a greenfield production launch. The operator confirms that there are
no real production users, no active production writers, and no irreplaceable
production data.

- All source identities, profiles, and application rows are disposable. This
  includes the historical 43 Supabase Auth users, 42 public profiles, 1,106
  source application rows, and `testing@refwatch.com`.
- Existing target test identities and user-owned application rows are
  disposable.
- No legacy UUID-to-Clerk-subject mapping, identity import, or application-data
  migration is required for launch.
- Deterministic global reference data required by the application must be
  seeded from reviewed repository sources. It is distinct from disposable
  user-owned data.
- Mutation-ledger escrow, recovery proof, and activation are deferred and are
  not launch gates. The inaccessible historical key does not need to be
  recovered. No production ledger epoch is to be activated for this launch.
- Initial recovery may stop traffic and writes, route to the emergency
  write-disabled Worker, roll back the Worker or client, reset and reseed
  PlanetScale, recreate test identities, and rerun the greenfield launch.
- All cutover and provider operations that were previously approval-gated are
  authorized within the security and architecture boundaries of the active
  plan. Authorization does not assert that any operation has completed.
- Secret values remain non-disclosing: they must not be printed, passed as
  command arguments, committed, or written into evidence.
- Commits and publishing remain outside this authorization.

Working Clerk production provenance is fixed to:

- instance: `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`
- issuer/frontend API: `https://clerk.refwatch.ibby.ai`
- domain: `refwatch.ibby.ai`

The completed domain, DNS, certificate, and key-coordination lane is not to be
repeated unless a diagnosed cutover requirement makes a change necessary.

## Canonical authorization payload

The SHA-256 digest below is computed over the exact UTF-8 bytes of the
single-line canonical JSON payload, with no trailing newline. It is a
non-secret deployment pin for the zero-legacy bootstrap profile.

```json
{"schema":"refwatch.greenfield-authorization.v1","authorized_on":"2026-07-20","production_clerk_instance_id":"ins_3GWFGUd1rI6hx5lWlUxMYAkxdac","production_clerk_issuer":"https://clerk.refwatch.ibby.ai","production_clerk_domain":"refwatch.ibby.ai","source_identities_disposition":"disposable","source_application_rows_disposition":"disposable","target_test_identities_and_rows_disposition":"disposable","legacy_identity_mapping_required":false,"legacy_data_migration_required":false,"ledger_escrow_recovery_activation_required":false,"rollback_mode":"destructive_reset_reseed_recreate","provider_cutover_operations_authorized":true,"secret_handling":"non_disclosing","commits_and_publishing":"out_of_scope"}
```

SHA-256:
`17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b`

## Scope boundary

This artifact supersedes prior approval gates and preservation assumptions. It
does not rewrite earlier point-in-time evidence, activate writes or traffic,
prove provider configuration, or complete production acceptance. Those facts
must be recorded in later sanitized evidence at the time each operation is
performed.
