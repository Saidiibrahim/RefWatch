# Production greenfield identity activation

Artifact family date: 2026-07-20
Implementation date: 2026-07-21 (Australia/Adelaide)

## Lifecycle state

- Local helper implementation, semantic-next-ID remediation, and
  disposable-database rehearsal: complete.
- Initial mandatory pre-execution code-risk review: historical closure;
  reviewer `/root/activation_preexec_code_review` returned `NO FINDINGS`
  before the first provider attempt.
- Initial mandatory pre-execution docs/evidence review: historical closure;
  reviewer `/root/activation_preexec_docs_review` returned `NO FINDINGS`
  before the first provider attempt.
- Fresh pre-attempt production PlanetScale and exact-instance Clerk readbacks:
  complete and bound below.
- First production attempt: failed closed without committing a receipt or
  activation; retained below as historical fail-closed evidence.
- Mandatory remediation code-risk and docs/evidence reviews: complete; both
  reviewers returned final exact `NO FINDINGS` before another provider attempt.
- Fresh retry PlanetScale and exact-instance Clerk readbacks: complete.
- Production activation and idempotent retry: complete; exactly one immutable
  receipt and activation are independently read back below.
- Mandatory post-execution reviews: complete; both final reviewers returned
  exact `NO FINDINGS` after the canonical-output and final scan receipts were
  corrected.

The retained 2026-07-20 filename groups this artifact with the authorized
greenfield cutover packet. It does not backdate the 2026-07-21 implementation
or provider actions. Authorization remains active, the operator has confirmed
the logical PlanetScale database is named `refwatch`, and no operator approval
or action is pending.

## One-shot helper contract

`api/scripts/activate-production-greenfield-identity.mjs` is an administrative
`pscale` helper, never a Worker endpoint. Production is impossible by default:

```sh
npm run identity:activate:production:check
REFWATCH_ALLOW_PRODUCTION_GREENFIELD_IDENTITY_ACTIVATION=1 \
  npm run identity:activate:production
```

`--check` loads and validates repository sources only. It does not spawn
`pscale` or contact production. Execution requires both `--execute` (provided
by the package script) and the exact non-secret technical gate above.

The only production child command is:

```text
pscale shell refwatch main --org ibrahim-aka-ajax --role admin --no-color
```

All SQL crosses stdin. The child receives
`PSCALE_ALLOW_NONINTERACTIVE_SHELL=1`, `PSQLRC=/dev/null`, and
`PSQL_HISTORY=/dev/null`. Captured stdout and stderr are never included in an
error. The helper emits one sanitized canonical JSON receipt only after the
database confirms commit.

The PlanetScale resource is the logical database `refwatch`. The PostgreSQL
catalog inside that resource authoritatively reports `current_database()` as
`postgres`; the prepared Hyperdrive also targets `postgres`. The transaction
asserts both layers separately and activates `SET LOCAL ROLE postgres`. The
isolated database rehearsal therefore uses its disposable cluster's exact
`postgres` catalog rather than adding a production-only bypass or inventing a
nonexistent physical catalog.

## Reviewed repository sources

The helper imports the production pins and receipt constants from
`greenfield-launch-packet.mjs`, the migration/history/stable-owner contract
from `apply-production-migration-0016.mjs`, and the physical PostgreSQL catalog
pin from `provision-production-runtime.mjs`. It validates these repository
sources before rendering SQL:

| Source | SHA-256 |
| --- | --- |
| `api/scripts/greenfield-schema-readback.sql` | `391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd` |
| `api/scripts/greenfield-clean-target-readback.sql` | `eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352` |
| `api/scripts/greenfield-ledger-readback.sql` | `0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b` |
| `api/src/db/migrations/0002_crazy_yellowjacket.sql` | `134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b` |
| `api/src/db/migrations/0016_careless_steel_serpent.sql` | `0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac` |
| `api/src/db/migrations/meta/0016_snapshot.json` | `5a84baea9a5aec9738c0bb207b0e5b417af5c7b5606706a434b7d1a5323ef500` |
| `api/src/db/migrations/meta/_journal.json` | `6bee16ebf32328698e91690932ca6a159fdc26c67422897032d96bc8ac80304a` |

The shared migration loader pins the complete journal bytes and additionally
validates the exact `0015`, `0016`, and `0017` entries. Source `0017` remains
unapplied; the activation helper requires production history to remain exactly
17 rows through `0016`. It also pins the Drizzle history sequence as a
non-cycling, cache-1, increment-1 `integer` sequence with start/minimum `1` and
maximum `2147483647`. Only exact states `(last_value=18,is_called=false)` and
`(last_value=17,is_called=true)` are accepted because each makes the next
generated history ID exactly `18`. The observed representation and derived
`next_value=18` are included in the sanitized receipt. The shared 0016 apply
helper retains its stricter apply-time postflight requirement of exactly
`(18,false)`; activation never calls `nextval`, changes, restarts, or repairs
the production sequence.

## Transaction and lock boundary

The helper renders one serializable transaction. Node keeps `COMMIT` withheld
until the exact database JSON row is parsed and type/shape/provenance validated.
Only then does Node send `COMMIT` through the same stdin stream and require a
committed sentinel. Malformed/truncated/oversized provider output, SQL failure,
timeout, or an invalid receipt causes rollback or connection termination. An
ambiguous transport loss after commit is resolved safely by the exact
idempotent retry path.

The transaction locks Drizzle history plus every table derived from the
digest-checked 0016 snapshot in `SHARE ROW EXCLUSIVE` mode before taking the
exact Clerk reconciliation advisory lock. This ordering blocks normal
`INSERT`/`UPDATE`/`DELETE` across the checked bootstrap window without creating
a lock inversion with migration 0016's `app_users` trigger.

Locked relations (37 total):

- `drizzle.__drizzle_migrations`
- `public.ai_attachments`, `public.ai_messages`, `public.ai_threads`,
  `public.ai_usage_daily`, `public.app_users`
- `public.clerk_user_deletion_tombstones`,
  `public.clerk_webhook_delivery_receipts`
- `public.competitions`, `public.idempotency_keys`
- `public.identity_reconciliation_activations`,
  `public.identity_reconciliation_legacy_mappings`,
  `public.identity_reconciliation_receipts`
- `public.match_assessments`, `public.match_events`, `public.match_metrics`,
  `public.match_periods`, `public.matches`
- `public.mutation_entity_revisions`, `public.mutation_ledger_epochs`,
  `public.mutation_outbox_deliveries`, `public.mutation_outbox_events`
- `public.pages`, `public.reference_competitions`,
  `public.reference_disciplinary_codes`,
  `public.reference_disciplinary_rules`, `public.reference_teams`
- `public.runtime_database_markers`, `public.scheduled_matches`,
  `public.team_members`, `public.team_officials`, `public.team_tags`,
  `public.teams`, `public.user_devices`, `public.venues`,
  `public.workout_presets`, `public.workout_sessions`

Within those locks, the transaction verifies the exact database/branch/runtime
marker, stable ownership, 0016/17-row history and reviewed 36-table catalog,
the exact 5-competition/54-team deterministic seed and three zero optional
global categories, every one of the 27 application/identity clean-target
categories, and inactive ledger/outbox state. Receipt/activation state must be
either absent/absent or exactly one immutable matching pair; partial or foreign
state fails closed.

Fresh execution inserts the exact authorization-bound
`greenfield_zero_legacy_v1` receipt and zero-mapping hash, then inserts the
activation. The database's migration-0016
`validate_and_protect_identity_activation()` trigger remains the shared final
enforcement boundary. Retry performs no update and preserves the receipt UUID
and all four database timestamps.

## Local proof on 2026-07-21

- Source-only helper check and Node syntax check: pass.
- Focused remediation unit tests: 19/19 across 2 files: 13 activation-helper
  cases plus 6 shared migration-0016 contract cases.
- Full API unit suite: 281/281 across 20 files.
- TypeScript typecheck: pass.
- Existing hermetic database suite: 23/23 across 3 files.
- Dedicated isolated activation database suite: 9/9 in its own cluster and
  physical `postgres` catalog.
- Mounted route matrix: 19/19.
- Mutation coverage: 36 schema tables, 23 trigger-captured, 13 explicit
  exclusions, five application writer files, two control-plane writer files.
- Production Wrangler dry-run: pass with writes/onboarding disabled and the
  prepared Hyperdrive; no deployment occurred.
- Gitleaks 8.30.1 scanned the exact 20-file activation batch through stdin with
  full redaction (389,357 bytes) and found zero leaks. `.projects` was excluded and
  uninspected.
- `git diff --check`: pass at this checkpoint.

The dedicated database cases prove first activation from the apply-time
`(18,false)` sequence state, successful production-equivalent `(17,true)`
activation, rejection without identity rows or sequence changes for
`(17,false)`, `(18,true)`, and catalog-parameter drift, millisecond-exact
timestamp/UUID-preserving retry, receipt-only and activation-only conflicts,
atomic rejection of nonzero application data, mapping/tombstone/webhook state,
active ledger state, a concurrent application write blocked outside the
bootstrap window, immunity to a hostile inherited search path, and fail-closed
rejection when trigger execution is disabled. Unit cases prove source drift,
the full migration-journal digest, exact fixed `pscale` arguments, stdin-only
SQL, stripped inherited `PGOPTIONS`, the technical gates, pre-commit output
validation, canonical Node hashing, and non-disclosing malformed, timeout,
output-limit, and lost-commit-sentinel failures with safe idempotent retry.

## Fresh pre-attempt provider gates

The database helper cannot inspect Clerk and makes no live-user-count claim.
The first attempt was preceded by these separately sanitized provider
readbacks:

- PlanetScale MCP readback beginning
  `2026-07-21T02:57:32.004Z` verified logical database `refwatch`, branch
  `main` (`w3g1f8vcbg34`), physical catalog `postgres`, exact 17-row history
  through `0016`, exact reviewed 36-table schema, unchanged 5-competition/
  54-team deterministic seed, zero optional global seed rows, and zero rows in
  all 27 clean-target categories, including receipts and activations.
- The ledger readback completed at `2026-07-21T02:57:39.888Z` with zero
  preparing/open/capture-enforced epochs, revisions, outbox events, and
  deliveries.
- Official Clerk tooling through the repository `sp-clerk` workflow completed
  at `2026-07-21T03:07:39.734Z`. It verified exact production instance
  `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, zero users, sole primary domain
  `refwatch.ibby.ai`, and Frontend API/issuer
  `https://clerk.refwatch.ibby.ai`. The credential was consumed only in process
  memory; no secret value was printed or persisted.

These receipts are bound only to the first attempt. They must not be reused for
the retry: another official exact-instance Clerk zero-user readback and fresh
PlanetScale schema/seed/clean/ledger/control readbacks are required immediately
before the reviewed retry.

## Fail-closed production attempt and remediation

The authorized first attempt occurred after the Clerk receipt above and before
the `2026-07-21T03:08:39.238Z` post-failure MCP readback. Its fixed tool chain
was the API package script, Node one-shot helper, and exact admin command:

```text
pscale shell refwatch main --org ibrahim-aka-ajax --role admin --no-color
```

The helper returned only its generic non-disclosing failure. No captured child
stdout or stderr was emitted. The post-failure MCP query at
`2026-07-21T03:08:39.238Z` proved exactly zero identity reconciliation receipts
and zero activations, so no identity-control row was committed. It does not by
itself re-prove the other clean-target, seed, or ledger categories.

A rollback-only diagnostic rendered the reviewed transaction to failure but
never sent `COMMIT`; it mapped the sanitized failure stage to
`history_sequence`. A separate read-only MCP query at
`2026-07-21T03:10:26.523Z` found `last_value=17,is_called=true`, whose next
generated value is `18`. The production-preparation evidence already recorded
that state as healthy. The failure was therefore a helper-contract mismatch,
not production database drift: the original helper recognized only the
apply-time `(18,false)` representation of the same next ID.

The remediation now pins the complete sequence catalog contract, accepts only
the two exact equivalent representations described above, binds the sanitized
observed state and derived next ID into the receipt, and fails closed on every
other state. No production sequence repair or normalization was performed or
is planned. The shared 0016 apply contract remains unchanged. No Worker
deployment, routing, write/onboarding enablement, Clerk configuration change,
traffic change, or mutation-ledger activation occurred in this attempt.

Both reopened mandatory remediation reviewers returned exact `NO FINDINGS`.

## Reviewed retry gates

The reviewed retry used new provider receipts rather than reusing the first
attempt's state:

- PlanetScale control-plane readback confirmed the logical PostgreSQL resource
  `refwatch` is ready, its default production branch is exact `main`
  (`w3g1f8vcbg34`), it has zero replicas, and it has no read-only reason.
- Primary schema readback at `2026-07-21T03:36:00.023Z` verified physical
  catalog `postgres`, exact runtime marker, 17 migration rows through `0016`,
  all 36 reviewed public tables, and every reviewed catalog digest.
- The immediately preceding primary clean/ledger readback window completed at
  `2026-07-21T03:35:36.419Z`: deterministic seed remained exact 5/54 with zero
  disciplinary-code, disciplinary-rule, and global-workout-preset rows; all 27
  clean-target categories were zero; and every ledger/epoch/revision/outbox
  count was zero.
- The sequence/control readback pinned `integer`, start/minimum `1`, maximum
  `2147483647`, increment/cache `1`, non-cycling, `last_value=17`,
  `is_called=true`, derived `next_value=18`, zero receipts, and zero
  activations.
- Official `@clerk/backend@3.11.4` readback through `sp-clerk` completed at
  `2026-07-21T03:38:07.715Z`. Exact instance
  `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac` remained production with zero users and
  zero returned user rows. Its single primary non-satellite domain remained
  `refwatch.ibby.ai` with exact Frontend API/issuer
  `https://clerk.refwatch.ibby.ai`. The generated environment payload supplied
  the credential directly to process memory; no value was printed, persisted,
  or passed as an argument.

## Successful activation and idempotent retry

After the retry gates above, the authorized package script invoked the reviewed
Node helper and only this child command:

```text
pscale shell refwatch main --org ibrahim-aka-ajax --role admin --no-color
```

The first successful operation was `activated`. The database generated all
four immutable timestamps at `2026-07-21T03:38:21.452Z`. Node emitted the
complete canonical sanitized provider receipt. For readability, the JSON below
is a reduced, noncanonical evidence projection: it preserves the identifying
provider/receipt fields and exact outcome counts, but deliberately omits the
full `source_contract` and condenses the exact nested schema/seed/clean/ledger
objects. Do not hash this projection. Its `receipt_sha256` value is Node's hash
of the complete unabridged canonical payload, which the post-execution
code/operational reviewer independently reconstructed and matched exactly:

```json
{
  "operation": "activated",
  "receipt_type": "refwatch_production_greenfield_identity_activation",
  "status": "committed",
  "receipt_sha256": "64618af1e24a556ee1e0a5ec7fb5ae62cdaea1b73cf9374011b06b22a00f56b8",
  "provider_command": {
    "command": "pscale",
    "arguments": ["shell", "refwatch", "main", "--org", "ibrahim-aka-ajax", "--role", "admin", "--no-color"],
    "sql_transport": "stdin"
  },
  "production_target": {
    "organization": "ibrahim-aka-ajax",
    "logical_database": "refwatch",
    "postgres_database": "postgres",
    "branch": "main",
    "branch_id": "w3g1f8vcbg34",
    "runtime_marker": "refwatch:production:w3g1f8vcbg34",
    "stable_role": "postgres"
  },
  "identity_receipt": {
    "id": "428de9fc-1e6d-44a5-85a6-cbc0d15b7008",
    "receipt_digest": "27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18",
    "clerk_instance_id": "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac",
    "reconciliation_profile": "greenfield_zero_legacy_v1",
    "authorization_profile": "refwatch.greenfield-authorization.v1",
    "authorization_digest": "17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b",
    "clerk_issuer": "https://clerk.refwatch.ibby.ai",
    "clerk_domain": "refwatch.ibby.ai",
    "legacy_mapping_count": 0,
    "excluded_auth_count": 0,
    "mapping_hash": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945",
    "status": "verified",
    "snapshot_captured_at_utc": "2026-07-21T03:38:21.452Z",
    "reviewed_at_utc": "2026-07-21T03:38:21.452Z",
    "activated_at_utc": "2026-07-21T03:38:21.452Z"
  },
  "identity_activation": {
    "receipt_digest": "27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18",
    "clerk_instance_id": "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac",
    "activated_at_utc": "2026-07-21T03:38:21.452Z"
  },
  "verified_state": {
    "migration_count": 17,
    "migration_head_id": 17,
    "public_table_count": 36,
    "history_sequence": {"last_value": 17, "is_called": true, "next_value": 18},
    "reference_competitions_count": 5,
    "reference_teams_count": 54,
    "optional_global_seed_counts": [0, 0, 0],
    "identity_reconciliation_receipts": 1,
    "identity_reconciliation_activations": 1,
    "all_other_clean_target_counts": 0,
    "ledger_epoch_revision_outbox_counts": 0
  }
}
```

Complete canonical sanitized `activated` helper output. Its
`receipt_sha256` is computed over this canonical object with the
`receipt_sha256` field omitted: the committed payload before the helper adds
the wrapper digest field.

```json
{"identity_activation":{"activated_at_utc":"2026-07-21T03:38:21.452Z","clerk_instance_id":"ins_3GWFGUd1rI6hx5lWlUxMYAkxdac","receipt_digest":"27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18"},"identity_receipt":{"activated_at_utc":"2026-07-21T03:38:21.452Z","authorization_digest":"17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b","authorization_profile":"refwatch.greenfield-authorization.v1","clerk_domain":"refwatch.ibby.ai","clerk_instance_id":"ins_3GWFGUd1rI6hx5lWlUxMYAkxdac","clerk_issuer":"https://clerk.refwatch.ibby.ai","excluded_auth_count":0,"id":"428de9fc-1e6d-44a5-85a6-cbc0d15b7008","legacy_mapping_count":0,"mapping_hash":"4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945","receipt_digest":"27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18","reconciliation_profile":"greenfield_zero_legacy_v1","reviewed_at_utc":"2026-07-21T03:38:21.452Z","snapshot_captured_at_utc":"2026-07-21T03:38:21.452Z","status":"verified"},"operation":"activated","production_target":{"branch":"main","branch_id":"w3g1f8vcbg34","logical_database":"refwatch","organization":"ibrahim-aka-ajax","postgres_database":"postgres","runtime_marker":"refwatch:production:w3g1f8vcbg34","stable_role":"postgres"},"provider_command":{"arguments":["shell","refwatch","main","--org","ibrahim-aka-ajax","--role","admin","--no-color"],"command":"pscale","sql_transport":"stdin"},"receipt_sha256":"64618af1e24a556ee1e0a5ec7fb5ae62cdaea1b73cf9374011b06b22a00f56b8","receipt_type":"refwatch_production_greenfield_identity_activation","schema_version":1,"source_contract":{"clean_target_readback_path":"api/scripts/greenfield-clean-target-readback.sql","clean_target_readback_sha256":"eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352","ledger_readback_path":"api/scripts/greenfield-ledger-readback.sql","ledger_readback_sha256":"0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b","migration_count":17,"migration_head":"0016_careless_steel_serpent","migration_head_hash":"0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac","migration_journal_path":"api/src/db/migrations/meta/_journal.json","migration_journal_sha256":"6bee16ebf32328698e91690932ca6a159fdc26c67422897032d96bc8ac80304a","migration_snapshot_path":"api/src/db/migrations/meta/0016_snapshot.json","migration_snapshot_sha256":"5a84baea9a5aec9738c0bb207b0e5b417af5c7b5606706a434b7d1a5323ef500","schema_readback_path":"api/scripts/greenfield-schema-readback.sql","schema_readback_sha256":"391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd","seed_migration_path":"api/src/db/migrations/0002_crazy_yellowjacket.sql","seed_migration_sha256":"134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b"},"status":"committed","verified_state":{"clean_target_inventory":{"ai_attachments":0,"ai_messages":0,"ai_threads":0,"ai_usage_daily":0,"app_users":0,"clerk_user_deletion_tombstones":0,"clerk_webhook_delivery_receipts":0,"competitions":0,"idempotency_keys":0,"identity_reconciliation_activations":1,"identity_reconciliation_legacy_mappings":0,"identity_reconciliation_receipts":1,"match_assessments":0,"match_events":0,"match_metrics":0,"match_periods":0,"matches":0,"pages":0,"scheduled_matches":0,"team_members":0,"team_officials":0,"team_tags":0,"teams":0,"user_devices":0,"user_owned_workout_presets":0,"venues":0,"workout_sessions":0},"deterministic_seed":{"global_workout_presets_count":0,"reference_competitions_business_md5":"d56166798ab11268a1758c5cc8162c01","reference_competitions_count":5,"reference_disciplinary_codes_count":0,"reference_disciplinary_rules_count":0,"reference_teams_business_md5":"a562b3b7e9fb153e6e1c614a8df3d6cf","reference_teams_count":54},"history_sequence":{"cache_size":1,"cycle":false,"data_type":"integer","increment_by":1,"is_called":true,"last_value":17,"maximum_value":2147483647,"minimum_value":1,"next_value":18,"start_value":1},"ledger":{"archived_epoch_count":0,"capture_enforced_epoch_count":0,"database_branch_id":"w3g1f8vcbg34","database_name":"postgres","entity_revision_count":0,"frozen_epoch_count":0,"open_epoch_count":0,"outbox_delivery_count":0,"outbox_event_count":0,"preparing_epoch_count":0,"runtime_marker":"refwatch:production:w3g1f8vcbg34","total_epoch_count":0},"schema":{"catalog_contract_md5":"7bc279f12d67a0d7783cf44faa304061","database_branch_id":"w3g1f8vcbg34","database_name":"postgres","migration_count":17,"migration_head_hash":"0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac","migration_head_id":17,"migration_history_md5":"73ad9d2a055b09e83324a50f74ed94dd","public_column_count":382,"public_columns_md5":"5b81e30a8d05cea8c78649cf2be7e9cf","public_constraint_count":106,"public_constraints_md5":"7e1563a29be11d524afea2c781611ba5","public_enum_label_count":27,"public_enum_labels_md5":"b2eda0943c2c27d19e9bfd5c673fea70","public_function_count":10,"public_functions_md5":"0c77e33ed70225750ae38a135a520bd2","public_index_count":77,"public_indexes_md5":"a30882f0a9b197ba37521f0d33a07e1b","public_table_count":36,"public_table_names_md5":"02e5f3fb7142644e853fe509447bfa6d","public_table_properties_count":36,"public_table_properties_md5":"6bb3240a18426bb8a30066d6c94e732b","public_trigger_count":32,"public_triggers_md5":"ac33e05012c6461424ea1e4f33b99b46","runtime_marker":"refwatch:production:w3g1f8vcbg34"}}}
```

The immediate second execution returned `operation=idempotent_retry` with the
same database receipt UUID, receipt digest, activation, and all four timestamps.
Its complete unabridged canonical wrapper SHA-256 was
`6d92ca5b70af2722b623e4d1d268de25b7de191ecd0ddf2c0fb6f91ae2fbf779`;
the expected difference is the sanitized `operation` field. The same reviewer
independently reconstructed and matched this second full-payload hash. No
database row or timestamp changed.

Complete canonical sanitized `idempotent_retry` helper output. As above, its
`receipt_sha256` is computed over the canonical object with the
`receipt_sha256` field omitted.

```json
{"identity_activation":{"activated_at_utc":"2026-07-21T03:38:21.452Z","clerk_instance_id":"ins_3GWFGUd1rI6hx5lWlUxMYAkxdac","receipt_digest":"27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18"},"identity_receipt":{"activated_at_utc":"2026-07-21T03:38:21.452Z","authorization_digest":"17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b","authorization_profile":"refwatch.greenfield-authorization.v1","clerk_domain":"refwatch.ibby.ai","clerk_instance_id":"ins_3GWFGUd1rI6hx5lWlUxMYAkxdac","clerk_issuer":"https://clerk.refwatch.ibby.ai","excluded_auth_count":0,"id":"428de9fc-1e6d-44a5-85a6-cbc0d15b7008","legacy_mapping_count":0,"mapping_hash":"4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945","receipt_digest":"27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18","reconciliation_profile":"greenfield_zero_legacy_v1","reviewed_at_utc":"2026-07-21T03:38:21.452Z","snapshot_captured_at_utc":"2026-07-21T03:38:21.452Z","status":"verified"},"operation":"idempotent_retry","production_target":{"branch":"main","branch_id":"w3g1f8vcbg34","logical_database":"refwatch","organization":"ibrahim-aka-ajax","postgres_database":"postgres","runtime_marker":"refwatch:production:w3g1f8vcbg34","stable_role":"postgres"},"provider_command":{"arguments":["shell","refwatch","main","--org","ibrahim-aka-ajax","--role","admin","--no-color"],"command":"pscale","sql_transport":"stdin"},"receipt_sha256":"6d92ca5b70af2722b623e4d1d268de25b7de191ecd0ddf2c0fb6f91ae2fbf779","receipt_type":"refwatch_production_greenfield_identity_activation","schema_version":1,"source_contract":{"clean_target_readback_path":"api/scripts/greenfield-clean-target-readback.sql","clean_target_readback_sha256":"eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352","ledger_readback_path":"api/scripts/greenfield-ledger-readback.sql","ledger_readback_sha256":"0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b","migration_count":17,"migration_head":"0016_careless_steel_serpent","migration_head_hash":"0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac","migration_journal_path":"api/src/db/migrations/meta/_journal.json","migration_journal_sha256":"6bee16ebf32328698e91690932ca6a159fdc26c67422897032d96bc8ac80304a","migration_snapshot_path":"api/src/db/migrations/meta/0016_snapshot.json","migration_snapshot_sha256":"5a84baea9a5aec9738c0bb207b0e5b417af5c7b5606706a434b7d1a5323ef500","schema_readback_path":"api/scripts/greenfield-schema-readback.sql","schema_readback_sha256":"391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd","seed_migration_path":"api/src/db/migrations/0002_crazy_yellowjacket.sql","seed_migration_sha256":"134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b"},"status":"committed","verified_state":{"clean_target_inventory":{"ai_attachments":0,"ai_messages":0,"ai_threads":0,"ai_usage_daily":0,"app_users":0,"clerk_user_deletion_tombstones":0,"clerk_webhook_delivery_receipts":0,"competitions":0,"idempotency_keys":0,"identity_reconciliation_activations":1,"identity_reconciliation_legacy_mappings":0,"identity_reconciliation_receipts":1,"match_assessments":0,"match_events":0,"match_metrics":0,"match_periods":0,"matches":0,"pages":0,"scheduled_matches":0,"team_members":0,"team_officials":0,"team_tags":0,"teams":0,"user_devices":0,"user_owned_workout_presets":0,"venues":0,"workout_sessions":0},"deterministic_seed":{"global_workout_presets_count":0,"reference_competitions_business_md5":"d56166798ab11268a1758c5cc8162c01","reference_competitions_count":5,"reference_disciplinary_codes_count":0,"reference_disciplinary_rules_count":0,"reference_teams_business_md5":"a562b3b7e9fb153e6e1c614a8df3d6cf","reference_teams_count":54},"history_sequence":{"cache_size":1,"cycle":false,"data_type":"integer","increment_by":1,"is_called":true,"last_value":17,"maximum_value":2147483647,"minimum_value":1,"next_value":18,"start_value":1},"ledger":{"archived_epoch_count":0,"capture_enforced_epoch_count":0,"database_branch_id":"w3g1f8vcbg34","database_name":"postgres","entity_revision_count":0,"frozen_epoch_count":0,"open_epoch_count":0,"outbox_delivery_count":0,"outbox_event_count":0,"preparing_epoch_count":0,"runtime_marker":"refwatch:production:w3g1f8vcbg34","total_epoch_count":0},"schema":{"catalog_contract_md5":"7bc279f12d67a0d7783cf44faa304061","database_branch_id":"w3g1f8vcbg34","database_name":"postgres","migration_count":17,"migration_head_hash":"0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac","migration_head_id":17,"migration_history_md5":"73ad9d2a055b09e83324a50f74ed94dd","public_column_count":382,"public_columns_md5":"5b81e30a8d05cea8c78649cf2be7e9cf","public_constraint_count":106,"public_constraints_md5":"7e1563a29be11d524afea2c781611ba5","public_enum_label_count":27,"public_enum_labels_md5":"b2eda0943c2c27d19e9bfd5c673fea70","public_function_count":10,"public_functions_md5":"0c77e33ed70225750ae38a135a520bd2","public_index_count":77,"public_indexes_md5":"a30882f0a9b197ba37521f0d33a07e1b","public_table_count":36,"public_table_names_md5":"02e5f3fb7142644e853fe509447bfa6d","public_table_properties_count":36,"public_table_properties_md5":"6bb3240a18426bb8a30066d6c94e732b","public_trigger_count":32,"public_triggers_md5":"ac33e05012c6461424ea1e4f33b99b46","runtime_marker":"refwatch:production:w3g1f8vcbg34"}}}
```

Independent primary MCP readback then proved:

- at `2026-07-21T03:39:23.125Z`, exactly one receipt and one activation with
  UUID `428de9fc-1e6d-44a5-85a6-cbc0d15b7008`, the exact receipt/
  authorization/mapping digests, exact Clerk pins, zero mappings/exclusions,
  and all timestamps still `2026-07-21T03:38:21.452Z`;
- at `2026-07-21T03:39:15.374Z`, exact 17-migration/36-table reviewed schema;
- in the same post-execution window, the exact 5/54 seed, receipt/activation
  counts `1/1`, every other clean-target category `0`, and unchanged pinned
  sequence `(17,true)` with derived next ID `18`;
- at `2026-07-21T03:39:30.375Z`, zero total/preparing/open/frozen/archived/
  capture-enforced epochs, revisions, outbox events, and deliveries.

No Worker deployment, route, write/onboarding gate, Clerk configuration,
traffic, Queue consumer, cron, or mutation-ledger setting changed in this
activation batch.

## Mandatory review trail

- Planning code-risk audit identified the physical/logical database split,
  all-table locking, lock-order deadlock boundary, exact 0016 fixture, and
  validate-before-commit protocol. The implementation applies those findings.
- Planning docs/evidence audit required the beta.3 deployment-boundary
  clarification, pre- versus post-activation count distinction, separate Clerk
  readback, actual 2026-07-21 timestamps, and explicit non-ledger activation
  wording. These are applied here and in synchronized docs.
- The initial mandatory code-risk review found that the shared 0016 loader
  pinned only the journal tail rather than the complete journal bytes. The
  shared migration and activation contracts now pin the full journal SHA-256,
  and an earlier-entry drift case proves source-only rejection.
- An independent SQL/transport audit found an inherited-search-path and
  disabled-trigger risk, timestamp precision loss in the canonical receipt,
  and missing ambiguous-commit/timeout/output-limit regression cases. The
  transaction now fixes `search_path`, requires `session_replication_role` to
  remain `origin`, strips inherited `PGOPTIONS`, stores millisecond-exact
  timestamps, and proves every transport path with generic non-disclosing
  failures plus safe idempotent retry.
- The initial mandatory docs/evidence review found premature review-closure
  wording, an unqualified current production count, a stale scan receipt, a
  missing `psql` prerequisite, and an ambiguous receipt-UUID phrase. Each
  finding is applied; the final 20-file scan receipt above supersedes the
  earlier intermediate corpus.
- Initial pre-attempt code-risk closure:
  `/root/activation_preexec_code_review` returned exact `NO FINDINGS` after the
  original dispositions and regression receipts. This is retained as a
  historical receipt rather than applied to the remediation.
- Initial pre-attempt docs/evidence closure:
  `/root/activation_preexec_docs_review` returned exact `NO FINDINGS` after the
  original consistency dispositions and stable credential-scan receipt. This
  is retained as a historical receipt rather than applied to the remediation.
- Reopened remediation code-risk review: the reviewer required exact sequence
  catalog pins, acceptance only of `(18,false)` or `(17,true)`, rejection of
  all other pairs and catalog drift, and receipt binding of observed/derived
  state. The implementation and tests apply those findings; reviewer
  `/root/activation_preexec_code_review` returned final exact `NO FINDINGS`.
- Reopened remediation docs/evidence review: the reviewer required this
  append-only failed-attempt receipt, semantic-next-ID classification, narrow
  post-failure claims, refreshed totals/scan, synchronized lifecycle wording,
  and fresh provider gates before retry. Its re-review additionally required
  the explicit 19/19 focused-test split and unambiguous logical-`refwatch` /
  physical-`postgres` runbook wording. Every disposition is applied; reviewer
  `/root/activation_preexec_docs_review` returned final exact `NO FINDINGS`.
- Independent SQL/transport remediation re-audit and full itemized activation
  contract audit both returned exact `NO FINDINGS`.
- Final post-execution code-risk review: every finding was applied; reviewer
  `/root/activation_preexec_code_review` returned exact `NO FINDINGS`.
- Final post-execution docs/evidence review: every finding was applied;
  reviewer `/root/activation_preexec_docs_review` returned exact
  `NO FINDINGS`.
