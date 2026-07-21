# Production migration 0017 convergence

Date: 2026-07-21 (Australia/Adelaide)

## Lifecycle state

- Historical production preparation at migration `0016`/17 rows: complete.
- Authorization-bound zero-legacy receipt activation and its post-execution
  reviews: complete.
- Fail-closed migration-0017 helper, isolated database rehearsal, and active
  launch-validator repin: complete.
- Mandatory pre-execution code-risk and docs/evidence reviews: complete with
  final exact `NO FINDINGS`; supplemental SQL/session audit also closed with
  exact `NO FINDINGS`.
- Production migration execution, idempotent retry, and independent primary
  readback: complete.
- Mandatory post-execution code-risk and docs/evidence reviews: complete with
  final exact `NO FINDINGS` from `/root/activation_preexec_code_review` and
  `/root/activation_preexec_docs_review`.
- Production Worker version upload, deployment, routing, writes, onboarding,
  and mutation-ledger activation: unchanged and not part of this batch.

The active 2026-07-20 operator authorization covers this reviewed production
DDL operation. No new operator approval or action is required. The PlanetScale
resource is logically named `refwatch`; SQL executes against its physical
PostgreSQL catalog `postgres`. These names are not interchangeable.

## Why 0017 is a deployment prerequisite

The beta.3 Worker source reads and writes nullable
`app_users.clerk_profile_updated_at` to reject delayed or equal-time Clerk
profile events. Repository migration `0017_ambiguous_hedge_knight` adds that
column. Deploying the Worker while production remains at `0016` would create a
runtime schema mismatch, so no Worker version may be uploaded until this
migration is applied/read back and the launch validator is pinned to the
resulting exact catalog.

The completed activation receipt remains an immutable historical `0016`
receipt. `reviewedSchema0016` preserves that source and receipt contract.
The active `reviewedSchema` now pins source `0017`:

- migration count/head: `18` / `0017_ambiguous_hedge_knight` / ID `18`;
- migration SHA-256:
  `14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9`;
- journal SHA-256:
  `6bee16ebf32328698e91690932ca6a159fdc26c67422897032d96bc8ac80304a`;
- snapshot SHA-256:
  `0830ddcdde5afd629479f595fe3cc5c3e500491e5042428e50abed3209b9efb2`;
- migration-history MD5: `f2f3ddf416d58b2d9a60749e41af11f7`;
- full 0016 history `(id,hash,created_at)` SHA-256:
  `2ea7870b3abe8b5bbddfee93eb70a1eee959df6bb4bbaf1e028ca5ddf0f13093`;
- full 0017 history `(id,hash,created_at)` SHA-256:
  `4df5affeb9a55d1dd00437eb952f13f00afbb1f730bb368e3b2310d16edfa695`;
- catalog: 36 public tables, 383 public columns;
- public-columns MD5: `5fa4e25bcf19d7caf1f9adcfb4879344`;
- complete catalog-contract MD5: `99dca5e8c11b8ec23debfb7c698a74d7`.

## One-shot helper contract

`api/scripts/apply-production-migration-0017.mjs` is a Node/psql
administrative helper, never a Worker endpoint. It is non-mutating by default:

```sh
cd api
npm run db:migrate:production:0017:check
REFWATCH_ALLOW_PRODUCTION_MIGRATION_0017=1 \
  npm run db:migrate:production:0017
```

`--check` reads and digest-checks repository sources only. Production execution
requires both explicit `--execute` through the package script and the narrow
technical environment gate. The only child command is:

```text
pscale shell refwatch main --org ibrahim-aka-ajax --role admin --no-color
```

All SQL travels on stdin. The child receives
`PSCALE_ALLOW_NONINTERACTIVE_SHELL=1`, `PSQLRC=/dev/null`, and
`PSQL_HISTORY=/dev/null`; inherited `PGOPTIONS` is removed. Captured provider
stdout/stderr is never disclosed on failure.

One serializable transaction switches to stable role `postgres`, fixes the
search path, requires replication role `origin`, locks migration history plus
all 36 reviewed public tables, and takes the exact Clerk-instance
reconciliation advisory lock. It validates before any DDL:

- physical database `postgres`, exact branch/runtime marker, stable ownership,
  exact reviewed `0016` history/catalog, and an absent target column;
- every exact `(id, hash, created_at)` history tuple through the pinned full-
  history SHA-256, so non-head timestamp or hash drift cannot pass the legacy
  `id:hash` MD5 alone;
- the migration-history table's exact three columns, order, types, nullability,
  `id` default, primary key, table/sequence owners,
  `pg_get_serial_sequence` result, and auto/`OWNED BY` sequence dependency;
- the exact integer migration sequence catalog and only `(18,false)` or
  `(17,true)`, both deriving next history ID `18`;
- exactly one matching immutable greenfield receipt/activation pair;
- exact 5-competition/54-team seed and zero optional global seed rows;
- one receipt, one activation, and zero rows in the other 25 clean-target
  categories;
- inactive ledger with zero preparing/open/capture-enforced state and zero
  outbox events/deliveries.

The helper applies the digest-pinned migration SQL verbatim, inserts exact
history ID `18`/timestamp/hash, and transactionally restarts the history
sequence at `(19,false)`. Postflight requires the complete reviewed `0017`
catalog, exact nullable `timestamptz` column with no default, exact ownership,
the full 18-row tuple digest, unchanged history-table control contract,
unchanged seed/clean/ledger/identity state, and exact sequence parameters. The
sanitized receipt exposes the created-at-sensitive full-history digest and
control-catalog readback. A second run is an exact `idempotent_retry`; it does
not rerun DDL or mutate history, activation rows, or timestamps.

Node validates the single sanitized database receipt before sending `COMMIT`,
then requires exactly one `READY` and one post-commit `COMMITTED` sentinel
before emitting one canonical sanitized JSON wrapper and SHA-256. Malformed,
duplicate, or oversized output detected before the commit request receives an
explicit `ROLLBACK` only when commit is definitively unsent and stdin remains
writable. A timeout, child/stdio transport failure, or missing/invalid
`COMMITTED` sentinel at or after the commit request has ambiguous database
state: the helper emits only a generic non-echoing failure and never claims
success. The operational recovery is exact primary readback followed by the
same helper's exact idempotent retry; neither captured output nor a missing
sentinel is treated as proof that the transaction rolled back.

## Local proof

- Focused migration-0017 helper tests: 14/14.
- Full API unit suite: 296/296 across 21 files.
- TypeScript typecheck: pass.
- Existing hermetic current-schema database suite: 23/23 across 3 files.
- Isolated exact-0016 activation suite: 9/9.
- Dedicated physical-`postgres` migration-0017 suite: 11/11.
- Mounted route matrix after source migrations through 0017: 19/19.
- Mutation coverage: 36 tables, 23 trigger-captured, 13 explicitly excluded,
  five application writers, and two control-plane writers.
- Production Wrangler dry-run: pass at 1534.77 KiB / gzip 277.07 KiB with
  writes and onboarding disabled and Hyperdrive
  `920ca5b108034b2bb8700cf0201ac55f`; no upload occurred.
- `wrangler types --env production --check`: pass.
- Migration-0017 and historical activation source-only checks: pass.
- Node/shell syntax and `git diff --check`: pass.
- Gitleaks 8.30.1 fully redacted stdin scan: zero findings across the exact
  22-file, 681,948-byte migration-0017 post-execution evidence corpus.

The dedicated database suite proves first apply, immutable retry, both exact
next-18 sequence representations, atomic rejection of invalid `(17,false)` and
`(18,true)` pairs, sequence-catalog drift, non-head `created_at` drift, and
migration-history column/default/primary-key/serial/`OWNED BY` control drift. It
also proves rejection of nonzero application/mapping/tombstone/webhook state,
partial activation, and active-ledger state; rollback for both statement and
postflight failures; a clean retry after rollback; and that a concurrent
application writer cannot cross the locked bootstrap window. Unit transport
proof covers timeout and stdout/stderr limits, duplicate receipt/`READY`/
`COMMITTED` markers, and a lost post-commit sentinel followed by an exact
idempotent retry. The database suite rebuilds a disposable cluster's physical
`postgres` database and does not use a production-name bypass.

## Read-only production preflight

A primary PlanetScale MCP read at `2026-07-21T04:05:34.799Z` returned:

- physical database `postgres`;
- 17 migration rows, head ID `17`, exact 0016 hash/timestamp;
- history sequence `(17,true)`, so the next ID is exactly `18`;
- exactly one production runtime marker and no
  `clerk_profile_updated_at` column;
- one identity receipt and one activation;
- zero app users, mappings, tombstones, and webhook receipts;
- exact 5/54 deterministic seed; and
- zero active ledger epochs, outbox events, or deliveries.

That first implementation-phase observation predated the every-row history and
migration-control catalog remediation and was not treated as the final gate.

## Final primary pre-execution gate

After the final code-risk, docs/evidence, and supplemental SQL/session reviews
all returned exact `NO FINDINGS`, fresh primary-only PlanetScale MCP reads
completed immediately before execution:

- the checked-in schema readback at `2026-07-21T04:47:14.241Z` returned exact
  source-0016 state: 17 history rows/head ID 17, 36 public tables/382 columns,
  and every pinned 0016 catalog digest;
- the checked-in clean-target readback returned exact 5/54 deterministic seed,
  zero optional global seed rows, exactly one receipt/activation, and zero in
  every other target category;
- the checked-in ledger readback at `2026-07-21T04:47:22.894Z` returned zero
  epochs, revisions, outbox events, and deliveries;
- the control readback at `2026-07-21T04:48:11.141Z` returned the exact 17-row
  tuple list and full-history SHA-256
  `2ea7870b3abe8b5bbddfee93eb70a1eee959df6bb4bbaf1e028ca5ddf0f13093`,
  exact history-table columns/PK/default/serial/`OWNED BY` contract, owners
  `postgres`, sequence `(17,true)` with next ID 18, and an absent target
  column; and
- the immutable identity pair remained UUID
  `428de9fc-1e6d-44a5-85a6-cbc0d15b7008`, exact receipt digest
  `27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18`,
  and all timestamps `2026-07-21T03:38:21.452Z`.

The readback tool was PlanetScale MCP
`planetscale_execute_read_query`, forced to production `main` primary with
logical resource `refwatch` and physical catalog `postgres`. No replica result
was used.

## Production execution and idempotent retry

The authorized package script executed the reviewed helper. Its only child
command was:

```text
pscale shell refwatch main --org ibrahim-aka-ajax --role admin --no-color
```

SQL traveled only through stdin. The first canonical sanitized helper receipt
reported `operation=applied`, `status=committed`, and wrapper SHA-256
`d7a7dabb6a919459132d3820bc9728fd15226ee6880926f535899a733a1407be`.
The immediate second execution reported `operation=idempotent_retry`,
`status=committed`, and wrapper SHA-256
`aaac7e2585a3184ed7cc871b16a9109636db049de7cd6daf3850405a75b38a14`.
The expected wrapper difference is the operation field. Both receipts contain
the exact same database state, source contracts, immutable identity UUID and
timestamps, and no credential material.

Both receipts report:

- exact 18-row head ID 18/hash
  `14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9`
  at journal timestamp `1784597422601`;
- history MD5 `f2f3ddf416d58b2d9a60749e41af11f7` and full-history SHA-256
  `4df5affeb9a55d1dd00437eb952f13f00afbb1f730bb368e3b2310d16edfa695`;
- exact 36-table/383-column catalog digest
  `99dca5e8c11b8ec23debfb7c698a74d7` and nullable
  `app_users.clerk_profile_updated_at timestamptz` with no default;
- exact migration-control catalog and sequence `(19,false)`/next ID 19;
- exact 5/54 seed, zero optional global seed rows, one immutable identity
  receipt/activation, zero in the other 25 target categories, and inactive
  ledger/outbox state; and
- unchanged UUID `428de9fc-1e6d-44a5-85a6-cbc0d15b7008`, receipt digest
  `27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18`,
  authorization digest
  `17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b`,
  and all identity timestamps `2026-07-21T03:38:21.452Z`.

Complete canonical sanitized `applied` helper output follows. Its
`receipt_sha256` is Node's SHA-256 over this canonical object with the
`receipt_sha256` field omitted.

```json
{"identity_activation":{"activated_at_utc":"2026-07-21T03:38:21.452Z","clerk_instance_id":"ins_3GWFGUd1rI6hx5lWlUxMYAkxdac","receipt_digest":"27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18"},"identity_receipt":{"activated_at_utc":"2026-07-21T03:38:21.452Z","authorization_digest":"17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b","authorization_profile":"refwatch.greenfield-authorization.v1","clerk_domain":"refwatch.ibby.ai","clerk_instance_id":"ins_3GWFGUd1rI6hx5lWlUxMYAkxdac","clerk_issuer":"https://clerk.refwatch.ibby.ai","excluded_auth_count":0,"id":"428de9fc-1e6d-44a5-85a6-cbc0d15b7008","legacy_mapping_count":0,"mapping_hash":"4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945","receipt_digest":"27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18","reconciliation_profile":"greenfield_zero_legacy_v1","reviewed_at_utc":"2026-07-21T03:38:21.452Z","snapshot_captured_at_utc":"2026-07-21T03:38:21.452Z","status":"verified"},"operation":"applied","production_target":{"branch":"main","branch_id":"w3g1f8vcbg34","logical_database":"refwatch","organization":"ibrahim-aka-ajax","postgres_database":"postgres","runtime_marker":"refwatch:production:w3g1f8vcbg34","stable_role":"postgres"},"provider_command":{"arguments":["shell","refwatch","main","--org","ibrahim-aka-ajax","--role","admin","--no-color"],"command":"pscale","sql_transport":"stdin"},"receipt_sha256":"d7a7dabb6a919459132d3820bc9728fd15226ee6880926f535899a733a1407be","receipt_type":"refwatch_production_migration_0017","schema_version":1,"source_contract":{"clean_target_readback_path":"api/scripts/greenfield-clean-target-readback.sql","clean_target_readback_sha256":"eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352","ledger_readback_path":"api/scripts/greenfield-ledger-readback.sql","ledger_readback_sha256":"0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b","migration_journal_path":"api/src/db/migrations/meta/_journal.json","migration_journal_sha256":"6bee16ebf32328698e91690932ca6a159fdc26c67422897032d96bc8ac80304a","previous_full_history_sha256":"2ea7870b3abe8b5bbddfee93eb70a1eee959df6bb4bbaf1e028ca5ddf0f13093","previous_migration":"0016_careless_steel_serpent","previous_migration_sha256":"0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac","schema_readback_path":"api/scripts/greenfield-schema-readback.sql","schema_readback_sha256":"391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd","seed_migration_path":"api/src/db/migrations/0002_crazy_yellowjacket.sql","seed_migration_sha256":"134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b","target_full_history_sha256":"4df5affeb9a55d1dd00437eb952f13f00afbb1f730bb368e3b2310d16edfa695","target_migration":"0017_ambiguous_hedge_knight","target_migration_sha256":"14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9","target_snapshot_path":"api/src/db/migrations/meta/0017_snapshot.json","target_snapshot_sha256":"0830ddcdde5afd629479f595fe3cc5c3e500491e5042428e50abed3209b9efb2"},"status":"committed","verified_state":{"clean_target_inventory":{"ai_attachments":0,"ai_messages":0,"ai_threads":0,"ai_usage_daily":0,"app_users":0,"clerk_user_deletion_tombstones":0,"clerk_webhook_delivery_receipts":0,"competitions":0,"idempotency_keys":0,"identity_reconciliation_activations":1,"identity_reconciliation_legacy_mappings":0,"identity_reconciliation_receipts":1,"match_assessments":0,"match_events":0,"match_metrics":0,"match_periods":0,"matches":0,"pages":0,"scheduled_matches":0,"team_members":0,"team_officials":0,"team_tags":0,"teams":0,"user_devices":0,"user_owned_workout_presets":0,"venues":0,"workout_sessions":0},"deterministic_seed":{"global_workout_presets_count":0,"reference_competitions_business_md5":"d56166798ab11268a1758c5cc8162c01","reference_competitions_count":5,"reference_disciplinary_codes_count":0,"reference_disciplinary_rules_count":0,"reference_teams_business_md5":"a562b3b7e9fb153e6e1c614a8df3d6cf","reference_teams_count":54},"history_sequence":{"cache_size":1,"cycle":false,"data_type":"integer","increment_by":1,"is_called":false,"last_value":19,"maximum_value":2147483647,"minimum_value":1,"next_value":19,"start_value":1},"ledger":{"archived_epoch_count":0,"capture_enforced_epoch_count":0,"database_branch_id":"w3g1f8vcbg34","database_name":"postgres","entity_revision_count":0,"frozen_epoch_count":0,"open_epoch_count":0,"outbox_delivery_count":0,"outbox_event_count":0,"preparing_epoch_count":0,"runtime_marker":"refwatch:production:w3g1f8vcbg34","total_epoch_count":0},"migration_history":{"full_history_sha256":"4df5affeb9a55d1dd00437eb952f13f00afbb1f730bb368e3b2310d16edfa695","head_created_at":1784597422601,"head_hash":"14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9","head_id":18,"history_md5":"f2f3ddf416d58b2d9a60749e41af11f7","migration_count":18},"migration_history_catalog":{"columns":[{"column_name":"id","data_type":"integer","default_expression":"nextval('drizzle.__drizzle_migrations_id_seq'::regclass)","not_null":true,"ordinal_position":1},{"column_name":"hash","data_type":"text","default_expression":null,"not_null":true,"ordinal_position":2},{"column_name":"created_at","data_type":"bigint","default_expression":null,"not_null":false,"ordinal_position":3}],"owned_by_dependency":{"column_name":"id","dependency_type":"a","sequence_name":"__drizzle_migrations_id_seq","sequence_schema":"drizzle","table_name":"__drizzle_migrations","table_schema":"drizzle"},"primary_key":{"constraint_name":"__drizzle_migrations_pkey","definition":"PRIMARY KEY (id)","key_attnums":[1]},"sequence_owner":"postgres","serial_sequence":"drizzle.__drizzle_migrations_id_seq","table_owner":"postgres"},"schema":{"catalog_contract_md5":"99dca5e8c11b8ec23debfb7c698a74d7","database_branch_id":"w3g1f8vcbg34","database_name":"postgres","migration_count":18,"migration_head_hash":"14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9","migration_head_id":18,"migration_history_md5":"f2f3ddf416d58b2d9a60749e41af11f7","public_column_count":383,"public_columns_md5":"5fa4e25bcf19d7caf1f9adcfb4879344","public_constraint_count":106,"public_constraints_md5":"7e1563a29be11d524afea2c781611ba5","public_enum_label_count":27,"public_enum_labels_md5":"b2eda0943c2c27d19e9bfd5c673fea70","public_function_count":10,"public_functions_md5":"0c77e33ed70225750ae38a135a520bd2","public_index_count":77,"public_indexes_md5":"a30882f0a9b197ba37521f0d33a07e1b","public_table_count":36,"public_table_names_md5":"02e5f3fb7142644e853fe509447bfa6d","public_table_properties_count":36,"public_table_properties_md5":"6bb3240a18426bb8a30066d6c94e732b","public_trigger_count":32,"public_triggers_md5":"ac33e05012c6461424ea1e4f33b99b46","runtime_marker":"refwatch:production:w3g1f8vcbg34"},"target_column":{"column_default":null,"column_name":"clerk_profile_updated_at","data_type":"timestamp with time zone","nullable":true,"table_name":"app_users","table_owner":"postgres","table_schema":"public","udt_name":"timestamptz","udt_schema":"pg_catalog"}}}
```

The complete canonical `idempotent_retry` output is identical to the object
above except for the two exact fields
`"operation":"idempotent_retry"` and
`"receipt_sha256":"aaac7e2585a3184ed7cc871b16a9109636db049de7cd6daf3850405a75b38a14"`.
Both post-execution reviewers reconstructed the receipt contract during final
closure and returned exact `NO FINDINGS`.

## Independent post-execution primary readback

Independent primary PlanetScale MCP reads after both helper executions proved:

- at `2026-07-21T04:49:05.169Z`, exact 18-row/head-0017 schema, 36 public
  tables/383 columns, and every reviewed public catalog digest;
- exact 5/54 seed, zero optional global seed rows, exactly one receipt and one
  activation, and zero in all other target categories;
- at `2026-07-21T04:49:12.975Z`, zero total/preparing/open/frozen/archived/
  capture-enforced epochs, zero revisions, and zero outbox events/deliveries;
- at `2026-07-21T04:49:49.613Z`, the exact 18-row tuple list, full-history
  SHA-256 `4df5affeb9a55d1dd00437eb952f13f00afbb1f730bb368e3b2310d16edfa695`,
  exact history-table control catalog, sequence `(19,false)`, and the exact
  nullable `timestamptz` target column owned by `postgres`; and
- the same immutable activation UUID and timestamp recorded above.

No Worker version was uploaded, deployed, or routed. Writes, onboarding,
traffic, Cloudflare resources, Clerk configuration, and mutation-ledger state
remain unchanged. Both mandatory post-execution reviewers returned final exact
`NO FINDINGS`, so migration-0017 no longer blocks Worker upload. No Worker
version has yet been uploaded, deployed, or routed, and no write/onboarding,
traffic, Clerk, or mutation-ledger state changed in this closure.

## Review trail

- Pre-execution code-level/operational-risk review:
  `/root/activation_preexec_code_review` — final exact `NO FINDINGS`.
- Pre-execution docs/evidence review:
  `/root/activation_preexec_docs_review` — final exact `NO FINDINGS` after the
  earlier baseline-subset wording was corrected.
- Supplemental SQL/session audit: `/root/migration0017_sql_audit` — final exact
  `NO FINDINGS` after the full tuple and migration-control remediations.
- Mandatory post-execution code-risk review:
  `/root/activation_preexec_code_review` — final exact `NO FINDINGS`.
- Mandatory post-execution docs/evidence review:
  `/root/activation_preexec_docs_review` — final exact `NO FINDINGS`.

The production migration-0017 convergence batch is closed. This removes only
the database-schema prerequisite for Worker upload; all later Worker lineage,
Clerk/OAuth/webhook, acceptance, write/onboarding, traffic-cutover, cleanup, and
physical-device gates retain their own requirements and current statuses.

No credential, administrative connection string, secret value, or iOS secret
configuration is recorded here. `.projects/` remains excluded and uninspected.
