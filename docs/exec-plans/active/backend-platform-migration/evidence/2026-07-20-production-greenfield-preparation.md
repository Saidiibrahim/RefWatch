# Production Greenfield Target Preparation

Date: 2026-07-20 (Australia/Adelaide)

## Scope and outcome

This artifact records the authorized production target-preparation batch after
the separately reviewed read-only baseline closed:

- migration `0016_careless_steel_serpent` was applied atomically to
  `ibrahim-aka-ajax/refwatch/main` (`w3g1f8vcbg34`);
- the exact post-migration schema, clean target, deterministic seed, ownership,
  and inactive-ledger contracts were read back;
- a new durable least-privilege read/write-data PlanetScale role and paired
  cache-disabled, TLS-required Cloudflare Hyperdrive were provisioned;
- the production candidate configuration was updated to bind the new
  Hyperdrive and expected role together; and
- typecheck, unit, database, mounted-route, and production dry-run checks pass
  while both writes and onboarding remain disabled.

This batch did **not** deploy or route a Worker, activate the zero-legacy
receipt, create or test the Clerk webhook, enable writes/onboarding, create
users, send lifecycle events, cut traffic, mutate the inactive ledger, or
retire Supabase. The currently deployed Worker and its old read-only
Hyperdrive/role remain unchanged as the historical write-disabled path.

All provider commands used authenticated managed sessions. The durable database
password moved only from the PlanetScale create response held in process memory
to Cloudflare over the helper's non-echoing stdin channel. No secret value was
printed, passed as a command argument, written to this artifact, or placed in
Worker/iOS configuration.

## Exact production pins

| Item | Value |
| --- | --- |
| PlanetScale organization/database/branch | `ibrahim-aka-ajax/refwatch/main` |
| PlanetScale branch ID | `w3g1f8vcbg34` |
| Database/runtime marker | `postgres` / `refwatch:production:w3g1f8vcbg34` |
| Cloudflare account | `b08d54b822741dbf8e864503b50604a1` |
| Worker/environment | `refwatch-api` / `production` |
| Clerk instance/issuer | `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac` / `https://clerk.refwatch.ibby.ai` |

## Immediately preceding primary readback

At `2026-07-20T06:31:32.823Z`, a fresh read-only query forced to the production
primary reconfirmed every migration-helper precondition:

```json
{
  "runtime_marker_count": 1,
  "runtime_marker": "refwatch:production:w3g1f8vcbg34",
  "database_branch_id": "w3g1f8vcbg34",
  "migration_count": 16,
  "migration_head_id": 16,
  "migration_head_hash": "6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a",
  "migration_head_created_at": 1784091083000,
  "migration_history_md5": "9450c899586ef3a282897836d07c4cc4",
  "public_table_count": 35,
  "target_table_present": false,
  "clean_target_category_count": 26,
  "clean_target_total_rows": 0,
  "clean_target_nonzero": {},
  "reference_competitions_count": 5,
  "reference_teams_count": 54,
  "ledger_epoch_count": 0,
  "ledger_capture_enforced_count": 0,
  "mutation_revision_count": 0,
  "mutation_outbox_event_count": 0,
  "mutation_outbox_delivery_count": 0
}
```

No reset, deletion, or reseed was needed.

## Atomic production migration

The only production migration command was the previously reviewed helper:

```sh
cd api
npm run db:migrate:production:0016
```

It validated the checked-in journal and exact source digests, opened one
fail-fast transaction, asserted the exact `0015` production marker/history/
catalog preconditions, used `SET LOCAL ROLE postgres`, applied the verbatim
`0016` SQL plus the exact Drizzle history row, checked owners/catalog/history,
and committed only after every postcondition passed. It reported:
`Production migration 0016 applied and verified.`

The applied migration SHA-256 is
`0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac`;
the checked-in journal SHA-256 is
`774d1f958e728d6a456dfc7ddd27814505887fdaf4c3aa748498166786db3c9a`.

## Post-migration schema and ownership receipt

The exact checked-in schema query
`api/scripts/greenfield-schema-readback.sql` (SHA-256
`391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd`)
returned at `2026-07-20T06:32:25.167Z`:

| Contract | Count | MD5 |
| --- | ---: | --- |
| Migration history | 17; head ID 17 | `73ad9d2a055b09e83324a50f74ed94dd` |
| Public table names | 36 | `02e5f3fb7142644e853fe509447bfa6d` |
| Public table properties | 36 | `6bb3240a18426bb8a30066d6c94e732b` |
| Public columns | 382 | `5b81e30a8d05cea8c78649cf2be7e9cf` |
| Public constraints | 106 | `7e1563a29be11d524afea2c781611ba5` |
| Public indexes | 77 | `a30882f0a9b197ba37521f0d33a07e1b` |
| Public triggers | 32 | `ac33e05012c6461424ea1e4f33b99b46` |
| Public functions | 10 | `0c77e33ed70225750ae38a135a520bd2` |
| Public enum labels | 27 | `b2eda0943c2c27d19e9bfd5c673fea70` |
| Full catalog | — | `7bc279f12d67a0d7783cf44faa304061` |

The head hash is
`0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac`.
An independent primary owner readback at `2026-07-20T06:35:47.209Z` found:

- target table `clerk_webhook_delivery_receipts` owner `postgres`;
- all five migration-`0016` target functions present;
- zero target functions with an unexpected owner;
- zero public tables with an unexpected owner; and
- zero public functions with an unexpected owner.

## Clean target and deterministic seed receipt

The exact checked-in query
`api/scripts/greenfield-clean-target-readback.sql` (SHA-256
`eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352`)
was rerun in the same authenticated production session immediately after a
provider-clock observation at `2026-07-20T06:51:38.051Z`. It returned one exact
production marker, the unchanged reviewed seed, and zero rows in every target
category:

```json
{
  "deterministic_seed": {
    "reference_competitions_count": 5,
    "reference_competitions_business_md5": "d56166798ab11268a1758c5cc8162c01",
    "reference_teams_count": 54,
    "reference_teams_business_md5": "a562b3b7e9fb153e6e1c614a8df3d6cf",
    "reference_disciplinary_codes_count": 0,
    "reference_disciplinary_rules_count": 0,
    "global_workout_presets_count": 0
  },
  "clean_target_inventory": {
    "app_users": 0,
    "identity_reconciliation_receipts": 0,
    "identity_reconciliation_activations": 0,
    "identity_reconciliation_legacy_mappings": 0,
    "clerk_user_deletion_tombstones": 0,
    "clerk_webhook_delivery_receipts": 0,
    "user_devices": 0,
    "teams": 0,
    "team_members": 0,
    "team_officials": 0,
    "team_tags": 0,
    "competitions": 0,
    "venues": 0,
    "scheduled_matches": 0,
    "matches": 0,
    "match_periods": 0,
    "match_events": 0,
    "match_metrics": 0,
    "match_assessments": 0,
    "pages": 0,
    "user_owned_workout_presets": 0,
    "workout_sessions": 0,
    "idempotency_keys": 0,
    "ai_threads": 0,
    "ai_messages": 0,
    "ai_attachments": 0,
    "ai_usage_daily": 0
  }
}
```

No Supabase identity, UUID mapping, profile, or application row was imported.

## Post-preparation Clerk readback

At `2026-07-20T06:43:13.331Z`, official `@clerk/backend` `3.11.4` used the
managed `clerk-auth-2` production environment through a non-echoing in-memory
path and returned:

```json
{
  "instance_id": "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac",
  "environment_type": "production",
  "user_count": 0,
  "invitation_count": 0,
  "redirect_url_count": 0,
  "allowed_origin_count": 0
}
```

The managed environment value was neither printed nor persisted. This is the
post-preparation exact-instance/zero-user receipt; it does not enumerate
native applications, social OAuth settings, or webhook endpoints/subscriptions.

## Inactive-ledger receipt

The exact checked-in query `api/scripts/greenfield-ledger-readback.sql`
(SHA-256
`0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b`)
returned at `2026-07-20T06:32:41.128Z`:

```json
{
  "total_epoch_count": 0,
  "preparing_epoch_count": 0,
  "open_epoch_count": 0,
  "frozen_epoch_count": 0,
  "archived_epoch_count": 0,
  "capture_enforced_epoch_count": 0,
  "entity_revision_count": 0,
  "outbox_event_count": 0,
  "outbox_delivery_count": 0
}
```

Production ledger capture was not activated.

## Durable runtime and Hyperdrive receipt

The reviewed failure-atomic provisioning helper ran with its explicit
production opt-in and returned the sanitized receipt at
`2026-07-20T06:33:07.129Z`:

| Resource | Exact result |
| --- | --- |
| PlanetScale role | `hvk7iheytj62`, `refwatch-worker-production-greenfield-20260720` |
| Durability | TTL `0s` |
| Inherited data privileges | `pg_read_all_data`, `pg_write_all_data` |
| Rejected elevated capabilities | administrator, create database, create role, create schema, replication, and bypass RLS all false |
| Effective data proof | exact production marker read plus an exact-marker control-plane update returned inside an explicit rollback |
| Cloudflare Hyperdrive | `920ca5b108034b2bb8700cf0201ac55f`, `refwatch-planetscale-production-greenfield-20260720` |
| Origin | exact Sydney PlanetScale production host, port `5432`, database `postgres`, scheme `postgresql` |
| Transport/cache/limit | TLS `require`, cache disabled, connection limit `10` |

The helper observed five pre-existing PlanetScale roles and twelve pre-existing
Hyperdrives before creation and preserved them unchanged. After creation,
provider list/get readbacks showed the new sixth role and exact new Hyperdrive.
The old production role `vaqg84rqoedz`, verifier role `pz5z3l81py1y`, and old
read-only Hyperdrive `5345de83edfa40b790d5b26df32f56ab` remain available.

`api/wrangler.jsonc` now updates the production candidate pair together:

- `env.production.vars.EXPECTED_DATABASE_ROLE_ID=hvk7iheytj62`;
- `env.production.hyperdrive[0].id=920ca5b108034b2bb8700cf0201ac55f`;
- `NEW_USER_ONBOARDING_MODE=disabled`; and
- `WRITE_MODE=disabled`.

This is repository candidate configuration only. Provider deployment readback
after preparation still reports unchanged deployment
`89cff719-0e19-4648-ab09-63a37d806c95` at 100% version
`e966d6df-b5ff-4288-832c-c8d91e00ce48`; the new pair is not yet bound to a
deployed Worker.

The code-risk review identified that the execution-time helper had used the
Drizzle serial default for history ID 17. Production is healthy: an independent
primary readback at `2026-07-20T06:54:39.649Z` shows 17 history rows, head ID
17 with the exact `0016` hash, sequence `last_value=17`, `is_called=true`, and
therefore next generated ID 18. The helper remediation for future destructive
reset/retry paths uses explicit ID 17 plus a transactional sequence restart and
now proves that a postflight rollback restores the pre-`0016` sequence before a
successful retry. No production repair or rerun was required.

## Verification

- `npm run typecheck` — pass.
- `npm test` — 18 files, 223/223 pass.
- `npm run test:db` — 3 files, 22/22 pass.
- `npm run test:local:routes` — 1 file, 19/19 pass.
- `npm run db:migrate:production:0016:check` — exact source/journal contract
  pass after provider execution.
- `npm run mutation:coverage` — pass: 36 schema tables, 23 trigger-captured
  tables, 13 explicit exclusions, five included application writer files, and
  two control-plane writer files.
- Node syntax checks for both production preparation helpers — pass.
- `npm run dry-run -- --env production` — pass with Wrangler `4.110.0`;
  upload `1532.36 KiB`, gzip `276.43 KiB`.
- Production dry-run lists the exact new Hyperdrive and expected role, Clerk
  production pins, D1 and Queue-producer bindings, and version metadata while
  onboarding and writes are disabled. It declares no cron or Queue consumer.
- PlanetScale role and Cloudflare Hyperdrive list/get readbacks match the
  sanitized provisioning receipt.
- The deployed Worker version remained unchanged after preparation.
- Fresh Cloudflare readback at `2026-07-20T06:51:59.896Z` reports zero
  `refwatch-api` custom domains, zero zone routes, and zero cron schedules.
  Queue `refwatch-mutation-ledger-production`
  (`8a45feb41dcf49159e3c14d19e57a254`) has one already classified inactive
  Worker producer and zero consumers; queue
  `refwatch-mutation-ledger-dlq-production`
  (`373237cf8b914573b420e227aa2f4361`) has zero producers and zero consumers.
- Gitleaks `8.30.1` scanned the thirteen files changed by this preparation
  batch with full redaction and found zero leaks.
- A repo-root actual-value scan loaded one available managed production
  fingerprint only in memory; it excluded `.git`, `.projects`, `node_modules`,
  `.env`, `.dev.vars`, symlinks, and existing `.xcresult` bundles, checked
  10,269 files, and found zero hits. Unavailable Worker/database secret values
  were not fingerprinted.
- `git diff --check` — pass.

## Mandatory review status

Provider preparation and its mandatory reviews are closed.

- Code-level risk reviewer `/root/prep_code_risk_review` found a medium
  failure/retry risk in relying on the Drizzle serial default and an imprecise
  description of the rolled-back privilege probe. The helper now writes exact
  history ID 17, transactionally restarts the sequence for ID 18, proves a
  postflight rollback restores the pre-`0016` sequence, then proves a successful
  retry. The evidence now calls the probe an exact-marker control-plane update.
  Focused tests pass 30/30 and the database suite passes 22/22. The final
  reviewer verdict was exactly `NO FINDINGS`.
- Docs/evidence consistency reviewer `/root/prep_docs_review` found missing
  observation timestamps and exact Queue identities, stale pre-`0016` current
  language, completed preparation evidence still labeled pending, inconsistent
  scan counts, the older Clerk receipt used in current summaries, and one
  incorrect chronology phrase. Exact timestamps and Queue names/IDs are now
  recorded; baseline claims are explicitly historical; completed versus
  pending states, scan corpora, and post-preparation Clerk chronology are
  synchronized. A focused stale-current scan also corrected the last baseline
  sentence in the plan. The final reviewer verdict was exactly `NO FINDINGS`.

No finding was deferred.
