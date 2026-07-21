# Production Greenfield Read-Only Baseline

Date: 2026-07-20 (Australia/Adelaide)

## Scope and boundary

This append-only artifact records the first fresh production-provider inventory
after the greenfield authorization. It supersedes current-state assumptions
derived from the 2026-07-15 foundation and 2026-07-17 domain receipts without
changing either historical artifact.

The inventory used authenticated read-only provider/API/CLI operations,
non-mutating privilege probes, public TLS/DNS checks, local Apple signing
metadata, and local HTML parsing/rendering. PlanetScale MCP and `pscale`
necessarily issued temporary access credentials/roles for those operations;
none was selected as a durable application credential. The inventory did not
execute DML or DDL; create, rotate, expose, or delete a durable credential;
mutate application data or durable Clerk, PlanetScale, Cloudflare, Apple, or
Supabase configuration; deploy or route a Worker; activate the identity
receipt; enable onboarding, writes, traffic, or ledger capture; or inspect
`.projects`. Secret values and PII were neither printed nor recorded.

The 2026-07-20 authorization already covers the remaining ordered provider
operations. There is no operator approval to obtain before the next reviewed
cutover stage. Access and physical-device prerequisites remain distinct from
approval.

## PlanetScale production branch

The exact production target remains:

- organization `ibrahim-aka-ajax`, ID `3z35qza3nng5`;
- database `refwatch`, ID `5lxoyl0c9owd`;
- PostgreSQL branch `main`, ID `w3g1f8vcbg34`;
- region Sydney;
- ready, production, and default;
- no replica, no `read_only_reason`, and safe migrations disabled.

The branch itself is writable. The previously reported read-only state applies
to particular credentials, not to PlanetScale MCP as a whole and not to the
branch.

### Credential and tool distinction

| Access path | Fresh readback | Production interpretation |
| --- | --- | --- |
| PlanetScale MCP read query | A provider-issued temporary reader inherited `pg_read_all_data` | The query surface is intentionally read-only. Its short-lived role/credential is an access-session artifact, not a durable application role. The MCP also exposes a separate write-query tool; it was not invoked in this baseline. |
| `pscale` CLI `0.300.0`, ephemeral `readwriter` session | A `SELECT`-only privilege probe showed inherited `pg_write_all_data` | Authenticated temporary write capability is available without selecting or persisting a durable application role. No DML or DDL was run. |
| `pscale` CLI `0.300.0`, ephemeral `admin` session | A `SELECT`-only privilege probe showed provider `postgres` inheritance and schema-create capability | Authenticated temporary migration capability is available through a non-echoing path. No DML or DDL was run. |
| Durable Worker role `vaqg84rqoedz`, `refwatch-worker-production-v2` | Enabled, unexpired, and inherited only `pg_read_all_data` | This remains the role behind the current production Hyperdrive and cannot support application writes. |
| Durable verifier role `pz5z3l81py1y` | Enabled, unexpired, and inherited only `pg_read_all_data` | This remains an independent read-only verifier. |

There is no persistent production writer role. The next preparation stage may
apply the reviewed migration through the ephemeral non-echoing CLI path. Before
the Worker candidate can accept bounded writes, create a new least-privilege
writable runtime credential and a new Hyperdrive binding while preserving the
existing read-only Hyperdrive and old Worker version as the write-disabled
rollback path.

No operator action is required to unlock PlanetScale write tooling.

### Schema and migration delta

Current production has 16 Drizzle migration rows through
`0015_bound_ledger_capture_envelope`; that migration file has SHA-256
`6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a`.
The reviewed greenfield target has 17 rows through
`0016_careless_steel_serpent`; that migration file has SHA-256
`0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac`.

| Catalog measure | Current production (`0015` / 16 rows) | Reviewed target (`0016` / 17 rows) |
| --- | ---: | ---: |
| Tables | 35 | 36 |
| Columns | 371 | 382 |
| Constraints | 102 | 106 |
| Indexes | 75 | 77 |
| Triggers | 28 | 32 |
| Functions | 7 | 10 |
| Enum labels | 27 | 27 |
| Catalog MD5 | `d1407581d114ce212906df63dad8f38c` | `7bc279f12d67a0d7783cf44faa304061` |

The checked-in clean-target query correctly fails closed on current production
because migration `0016`'s `clerk_webhook_delivery_receipts` table does not
exist yet. This is the expected preparation delta, not evidence of target
drift.

### Reproducible `0015` baseline receipt

The exact current-state query is
`api/scripts/production-greenfield-baseline-readback-0015.sql`, SHA-256
`5cce6740a72f7336767215c8673f1ee760a1025db239db2f0edddc23ef41dd05`.
It is a standalone `SELECT` that preserves the target-only `0016` readbacks
unchanged. It emits the complete current schema contract, Postgres ownership
checks, exact 26-category pre-`0016` inventory, deterministic seed, target-only
table state, and inactive-ledger counts in one sanitized payload.

The exact read-only production execution at
`2026-07-20T05:46:26.916Z` returned:

```json
{
  "baseline_profile": "production_greenfield_baseline_0015_v1",
  "observed_at_utc": "2026-07-20T05:46:26.916Z",
  "database_name": "postgres",
  "database_branch_id": "w3g1f8vcbg34",
  "runtime_marker": "refwatch:production:w3g1f8vcbg34",
  "schema": {
    "migration_count": 16,
    "migration_head_id": 16,
    "migration_head_hash": "6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a",
    "migration_history_md5": "9450c899586ef3a282897836d07c4cc4",
    "public_table_count": 35,
    "public_table_names_md5": "e252fddcbf270161f624a0d956533227",
    "public_table_properties_count": 35,
    "public_table_properties_md5": "6a5c8b8d8618005bdbe882c2cae1dffe",
    "public_column_count": 371,
    "public_columns_md5": "06cceeded8737324cc47800dda433523",
    "public_constraint_count": 102,
    "public_constraints_md5": "ddb76108d87c99bf0fb354a382fae23f",
    "public_index_count": 75,
    "public_indexes_md5": "6d6627bbcc4828de8bbc00d70672a297",
    "public_trigger_count": 28,
    "public_triggers_md5": "c515fc920424b3610c7d104271145091",
    "public_function_count": 7,
    "public_functions_md5": "911389a2d978b924e87b389144267c07",
    "public_enum_label_count": 27,
    "public_enum_labels_md5": "b2eda0943c2c27d19e9bfd5c673fea70",
    "catalog_contract_md5": "d1407581d114ce212906df63dad8f38c",
    "postgres_owned_public_table_count": 35,
    "unexpected_public_table_owner_count": 0,
    "postgres_owned_public_function_count": 7,
    "unexpected_public_function_owner_count": 0
  },
  "deterministic_seed": {
    "reference_competitions_count": 5,
    "reference_competitions_business_md5": "d56166798ab11268a1758c5cc8162c01",
    "reference_teams_count": 54,
    "reference_teams_business_md5": "a562b3b7e9fb153e6e1c614a8df3d6cf",
    "reference_disciplinary_codes_count": 0,
    "reference_disciplinary_rules_count": 0,
    "global_workout_presets_count": 0
  },
  "clean_target_inventory_category_count": 26,
  "clean_target_inventory": {
    "app_users": 0,
    "identity_reconciliation_receipts": 0,
    "identity_reconciliation_activations": 0,
    "identity_reconciliation_legacy_mappings": 0,
    "clerk_user_deletion_tombstones": 0,
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
  },
  "target_only_table_state": {
    "clerk_webhook_delivery_receipts_present": false
  },
  "inactive_ledger": {
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
}
```

### Clean target, deterministic seed, and inactive ledger

The initial readback at `2026-07-20T05:12:27.103Z` and the reproducible
single-payload rerun above both showed:

- all 26 existing application, identity, and control inventory categories were
  zero;
- `app_users`, reconciliation receipts, activations, and legacy mappings were
  individually zero;
- the reviewed initial deterministic seed was exactly 5 reference competitions,
  business MD5 `d56166798ab11268a1758c5cc8162c01`, and 54 reference teams,
  business MD5 `a562b3b7e9fb153e6e1c614a8df3d6cf`; and
- reference disciplinary codes, reference disciplinary rules, and creator-free
  global workout presets were each zero, as required by the reviewed
  greenfield launch profile.

The target is already clean and the reviewed 5/54 seed already matches. No
destructive reset or reseed is needed before migration `0016`; apply that
migration, then rerun the exact schema/seed/clean-target queries to produce
post-preparation launch receipts.

At `2026-07-20T05:09:34.992Z`, production ledger readback showed zero total,
preparing, open, frozen, archived, and capture-enforced epochs; zero revisions;
and zero mutation outbox and delivery rows. Production ledger capture is
inactive and remains deferred.

## Cloudflare production baseline

The exact provider target is Cloudflare account
`b08d54b822741dbf8e864503b50604a1` and active zone `ibby.ai`, zone ID
`955d108e63b6a9743e0e74206e2dbe09`. Authenticated Wrangler `4.110.0` and
`cf` `0.1.0` readbacks succeeded.

### Worker and exposure state

- Worker: `refwatch-api`.
- Current deployment: `89cff719-0e19-4648-ab09-63a37d806c95`, deployment
  number 14, created `2026-07-16T20:45:12.701Z`.
- The deployment sends 100% to version
  `e966d6df-b5ff-4288-832c-c8d91e00ce48`.
- Previous version:
  `3096a8cc-bec6-4be1-9943-dddd34d36b00`.
- `WRITE_MODE=disabled`,
  `NEW_USER_ONBOARDING_MODE=disabled`, and
  `ALLOW_UNMAPPED_CLERK_USERS=false`.
- Clerk instance and issuer pins match
  `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac` and
  `https://clerk.refwatch.ibby.ai`.
- Smart placement and logging are enabled.
- Sanitized secret-name inventory contains Clerk publishable/secret keys,
  `OPENAI_API_KEY`, and the historical ledger key. It does not contain
  `CLERK_WEBHOOK_SIGNING_SECRET`.
- The deployed version predates the greenfield identity work and does not
  declare the new identity-reconciliation receipt/mode variables.
- There are zero zone routes and zero custom domains. Workers.dev and preview
  URLs are disabled, and there are zero cron schedules.
- A workers.dev `/health` request returned `404`; because workers.dev exposure
  is disabled, this proves non-exposure only and is not a health/readiness
  result.

There is not yet a deployed greenfield candidate or a reviewed set of distinct
candidate, write-guard, and last-known-good version IDs. The exact unused
custom hostname `api.refwatch.ibby.ai` is the recommended public candidate
route for the next reviewed deployment batch; this baseline did not create it.

### Bound inactive resources

- Hyperdrive `5345de83edfa40b790d5b26df32f56ab`,
  `refwatch-planetscale-production`, targets branch `w3g1f8vcbg34` through
  read-only role `vaqg84rqoedz`; query caching is disabled, TLS is required,
  and the connection limit is 10.
- D1 `6d1a7bbb-ea9d-47b2-ae77-44f992b9e3d2`, region `OC`, size 69,632 bytes,
  has migrations `0001` through `0003`, four immutability triggers, and zero
  events, probes, or dead letters. Its trailing 24-hour telemetry had zero reads
  and zero writes.
- Queue `refwatch-mutation-ledger-production`, ID
  `8a45feb41dcf49159e3c14d19e57a254`, has the Worker producer binding and zero
  consumers.
- DLQ `refwatch-mutation-ledger-dlq-production`, ID
  `373237cf8b914573b420e227aa2f4361`, has zero producers and zero consumers.

The Cloudflare telemetry window ended at `2026-07-20T05:10:36.834Z`. Resource
existence does not make the ledger active: there is no cron schedule or Queue
consumer, both mutation modes are disabled, the Worker is unexposed, and the
production database has no active epoch or ledger rows.

The recommended preparation is to preserve this old version and read-only
Hyperdrive for emergency write denial, provision a separate writable
least-privilege Hyperdrive, and bind it only to the new write-disabled
candidate.

## Clerk production baseline

Public and authenticated readbacks agree on:

- application name `refwatch`;
- production instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`;
- domain `refwatch.ibby.ai`;
- Frontend API and issuer `https://clerk.refwatch.ibby.ai`;
- Account Portal `https://accounts.refwatch.ibby.ai`;
- email/password enabled and an empty public social-provider map; and
- the existing five CNAMEs and valid TLS/JWKS lane.

At `2026-07-20T05:22:53.839Z`, official `@clerk/backend` `3.11.4` used the
managed production environment through a non-echoing runtime path and returned:

- exact production instance provenance;
- zero users;
- zero invitations;
- zero redirect URLs; and
- zero allowed origins.

No managed environment value was printed. This authenticated SDK receipt
supersedes the initial access concern for those Backend API reads.

The webhook endpoint and subscription list were not authoritatively read in
this lane because the employed Backend API surface has no corresponding GET/list
operation. The missing Worker `CLERK_WEBHOOK_SIGNING_SECRET` proves only that
the current Worker is not ready to verify the production endpoint; it does not
prove that no Clerk webhook endpoint exists. Native-application registration
was likewise not authoritatively enumerated. Public social configuration is
empty, so Apple and Google sign-in are not currently available to the
production app.

Creating or changing social OAuth, native-app, or webhook administration still
requires an authenticated Clerk CLI/dashboard session unless the production
Backend API is first verified to support the exact operation. That is an access
prerequisite, not a request for another cutover approval. If interactive
authentication is ultimately required, the operator must authenticate without
pasting credentials into chat.

## Apple identifiers and local Release state

Authoritative installed signing metadata resolves the production native
identity:

- production Team ID and App ID Prefix: `6NV7X5BLU7`;
- Bundle ID: `com.IbrahimSaidi.RefWatch`;
- application identifier:
  `6NV7X5BLU7.com.IbrahimSaidi.RefWatch`; and
- native callback:
  `com.IbrahimSaidi.RefWatch://callback`.

App Store and development profiles for that production identity are valid
through `2027-02-24`, and the distribution certificate is installed. Separate
development team `UBJC4GQ4S4` is not the production Release team.

The checked-out local Release configuration is not aligned:

- bundle identifier `.RefWatch`;
- no resolved development team;
- localhost backend;
- test Clerk publishable-key placeholder;
- `clerk.localhost` public host; and
- no registered callback URL scheme.

These are public-configuration defects, not missing secret values. They must be
corrected in the non-secret local/release configuration before native Clerk
acceptance. No physical iPhone or Apple Watch is connected, so physical iPhone
15 Pro Max and Apple Watch Series 9 (45mm) acceptance remains an external
blocker after the automated/provider matrix. Device absence does not block the
other authorized cutover preparation.

## Operator-page verification

Chrome parsed and rendered `MIGRATION_OPERATOR_ACTIONS.html`,
`CLERK_DASHBOARD_ACTIONS.html`, and `MIGRATION_APPROVALS.html`. Each contained
its expected main/footer structure and visually reported zero pending approval
decisions. Screenshots remained local under `/tmp` only.

## Result and next boundary

The read-only baseline is internally consistent with a clean greenfield target:
zero Clerk users, zero target application/identity/control data, the exact
reviewed 5/54 seed, and no active ledger. The immediate ordered preparation is:

1. apply migration `0016` through the non-echoing ephemeral PlanetScale
   migration path;
2. rerun the pinned post-preparation schema, seed, clean-target, ledger, and
   Clerk readbacks;
3. provision a new least-privilege writable runtime credential and Hyperdrive
   while preserving the current read-only rollback path;
4. align public iOS Release identifiers/configuration;
5. complete Clerk native/OAuth administration when the exact authenticated
   surface is available; and
6. deploy and route a distinct write-disabled candidate before creating or
   probing the lifecycle webhook.

No application data or durable provider configuration/credential mutation
occurred in this baseline; only provider-issued temporary access sessions were
created for authenticated reads and privilege probes. No operator approval is
pending. Physical-device presence and, if needed, Clerk interactive
authentication are the only currently identified operator-controlled access
actions.

## Verification

- Provider reports were checked against the exact production pins in the
  greenfield launch validator and current `api/wrangler.jsonc`.
- The standalone production-`0015` query was executed through a temporary
  read-only PlanetScale session and its complete sanitized payload is retained
  above.
- Local migration SHA-256 values were recomputed from the checked-in files.
- No Markdown link target was introduced; referenced local artifacts exist,
  and fenced-code structure was checked.
- `git diff --check` passed for this documentation batch.

## Mandatory review status

The first independent code-level review reported two unresolved preparation
risks:

- **High — migration ownership/history atomicity.** A generic ephemeral
  `npm run db:migrate` can leave new objects owned by a transient PlanetScale
  role, while piping only migration `0016` under `SET ROLE postgres` omits the
  Drizzle history row. The required remediation is an atomic helper that
  asserts the exact `0015` head/hash, uses local role `postgres`, applies the
  verbatim `0016` SQL and exact Drizzle hash/timestamp insert in one
  transaction, rolls back on any mismatch, and postchecks owners, catalog, and
  history.
- **Medium — writable credential-to-Hyperdrive handoff.** The preparation path
  must keep the password in memory through a non-echoing channel, never place it
  in an argument, stdout, or file, automatically delete the new PlanetScale
  password if Cloudflare creation/readback fails, prove read/write data access
  without admin capability plus exact branch/TLS/cache/connection-limit
  settings, preserve the old role/Hyperdrive/version, and update candidate
  `HYPERDRIVE` plus `EXPECTED_DATABASE_ROLE_ID` together.

Both findings are applied. The exact-head helper
`api/scripts/apply-production-migration-0016.mjs` pins the `0015`/`0016`
sources and journal, sends one non-interactive transaction to fixed
`pscale shell` arguments over stdin, assumes `postgres` only locally, and
postchecks history and ownership. Its disposable PostgreSQL rehearsal proves
success plus precondition, mid-statement, and postflight rollback paths.
The paired-runtime helper `api/scripts/provision-production-runtime.mjs`
pins the exact PlanetScale branch/host and Cloudflare account, creates only a
new durable read/write-data role without admin capability, transfers its
password only from captured memory to Cloudflare stdin, verifies the exact
marker and a rolled-back row write with bounded PostgreSQL timeouts, verifies
TLS/cache/connection-limit readback, and cleans up only newly observed opaque
IDs on failure while preserving the old path. Candidate
`HYPERDRIVE`/`EXPECTED_DATABASE_ROLE_ID` changes remain deliberately pending
until the provider-preparation batch.

The final code-risk reviewer found and had applied an additional high
non-interactive `pscale` opt-in/startup-file issue, a medium missing postflight
rollback proof, a high provider-timeout cleanup race, and medium Cloudflare
account, effective-write, and PostgreSQL-timeout gaps. Focused helper tests
pass 30/30; the full API suite passes 223/223; the hermetic database suite
passes 22/22; the mounted-route matrix passes 19/19; and typecheck, source
contract, syntax, and `git diff --check` pass. Final reviewer
`/root/baseline_final_code_risk` returned exactly `NO FINDINGS`.

The first docs/evidence review reported three medium findings: premature
completed lifecycle markers, overbroad no-credential/no-provider-mutation
wording, and an unreproducible pre-`0016` 26-category receipt. This revision
applies those findings through open lifecycle markers, explicit temporary
access-session classification, and the hashed standalone query/full payload
above. Its final re-review found two medium cross-document wording issues:
`docs/exec-plans/index.md` still called the already captured baseline pending,
and the runbook conflated readwriter DML capability with admin migration
capability. Both are applied. Final reviewer
`/root/baseline_final_docs_review` returned exactly `NO FINDINGS`.

The closure-only consistency pass then found stale wording in `api/README.md`
that still described the captured production baseline as future work, plus
runbook wording that still described the two reviewed helpers as unreviewed or
open. Those statements now distinguish the closed read-only baseline from the
authorized but not-yet-executed provider-preparation batch. The closure-only
code-risk and docs/evidence re-reviews both returned exactly `NO FINDINGS`.

The production read-only baseline batch is closed. No migration, durable
credential/Hyperdrive creation, Worker configuration/deployment/routing,
identity activation, or write enablement occurred in this batch.
