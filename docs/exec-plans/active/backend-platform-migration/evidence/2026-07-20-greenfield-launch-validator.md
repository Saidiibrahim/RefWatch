# Greenfield Launch and Destructive Rollback Validators — 2026-07-20

## Scope and boundary

This local batch adds a separate, fail-closed production promotion contract for
the authorized greenfield launch. It does not weaken or replace the retained
stateful Supabase export/import validators. It did not query or mutate
PlanetScale, Clerk, Cloudflare, Supabase, traffic, production configuration,
secrets, or physical devices, and it does not claim that migration `0016`, the
zero-legacy receipt, onboarding, writes, or production traffic are active.

The executable profiles are:

- launch packet: `greenfield_launch_v1`;
- identity receipt: `greenfield_zero_legacy_v1`; and
- destructive rollback packet: `greenfield_destructive_v1`.

The stateful rollback profile remains `stateful_migration_v1`. An older
profile-less rollback packet is still interpreted as that stateful profile for
compatibility. An omitted launch profile, an unknown explicit launch or
rollback profile, and mixed stateful/greenfield claims fail closed.

## Fixed production provenance

The launch validator pins the packet and every applicable embedded receipt to:

- Clerk instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`;
- Clerk domain `refwatch.ibby.ai`;
- Clerk issuer `https://clerk.refwatch.ibby.ai`;
- Worker `refwatch-api`, environment `production`;
- PlanetScale organization `ibrahim-aka-ajax`;
- database `refwatch`;
- branch `main`, branch ID `w3g1f8vcbg34`; and
- runtime marker `refwatch:production:w3g1f8vcbg34`.

The authorization pin is profile
`refwatch.greenfield-authorization.v1`, artifact
`docs/exec-plans/active/backend-platform-migration/evidence/2026-07-20-greenfield-cutover-authorization.md`,
and digest
`17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b`.
That digest is intentionally the SHA-256 of the exact UTF-8 bytes of the
single-line canonical JSON payload recorded inside the authorization artifact,
with no trailing newline. It is not a hash of the Markdown file bytes.

The identity section additionally pins receipt digest
`27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18`,
the canonical empty-mapping hash
`4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945`,
and exactly zero legacy mappings.

## Reviewed schema and executable provider readback

The reviewed repository target is:

- migration head `0016_careless_steel_serpent`;
- migration count and provider head ID `17`;
- migration `0016` SHA-256/head hash
  `0fc9bf140be01b0c1ce2c01b468ab370e0c8738f416d53c51bee011ac1705dac`;
- snapshot `api/src/db/migrations/meta/0016_snapshot.json`;
- snapshot SHA-256
  `5a84baea9a5aec9738c0bb207b0e5b417af5c7b5606706a434b7d1a5323ef500`;
- provider query `api/scripts/greenfield-schema-readback.sql`;
- provider-query SHA-256
  `391d26643ef17b2a342afdd10c47198733c84bd640ef923b997a618103b4c6cd`;
  and
- migration-history MD5 `73ad9d2a055b09e83324a50f74ed94dd`.

The provider query produces the following complete reviewed catalog contract.
The packet must carry these exact counts and digests rather than a
self-attested schema label:

| Catalog surface | Count | MD5 |
| --- | ---: | --- |
| Public table names | 36 | `02e5f3fb7142644e853fe509447bfa6d` |
| Public table properties, including RLS | 36 | `6bb3240a18426bb8a30066d6c94e732b` |
| Columns | 382 | `5b81e30a8d05cea8c78649cf2be7e9cf` |
| Constraints | 106 | `7e1563a29be11d524afea2c781611ba5` |
| Indexes | 77 | `a30882f0a9b197ba37521f0d33a07e1b` |
| Triggers | 32 | `ac33e05012c6461424ea1e4f33b99b46` |
| Functions | 10 | `0c77e33ed70225750ae38a135a520bd2` |
| Enum labels | 27 | `b2eda0943c2c27d19e9bfd5c673fea70` |

The combined catalog-contract MD5 is
`7bc279f12d67a0d7783cf44faa304061`. The catalog fields exclude volatile
object IDs, owners, privileges, and row contents while detecting drift in
table properties, columns/types/defaults, constraints, indexes, triggers,
functions, enums, and RLS state.

## Deterministic seed and clean target

The only reviewed initial deterministic reference seed is migration
`api/src/db/migrations/0002_crazy_yellowjacket.sql`, SHA-256
`134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b`.
The required readback is:

- 5 `reference_competitions`, business MD5
  `d56166798ab11268a1758c5cc8162c01`;
- 54 `reference_teams`, business MD5
  `a562b3b7e9fb153e6e1c614a8df3d6cf`;
- 0 `reference_disciplinary_codes`;
- 0 `reference_disciplinary_rules`; and
- 0 creator-free global workout presets.

The sanitized read-only query is
`api/scripts/greenfield-clean-target-readback.sql`, SHA-256
`eaf6ed21ca5e534d57746da6a37f72a5e6dc09c192f451dffae2e91e2eac0352`.
It binds the exact database marker, recomputes the seed counts/digests, and
requires exactly zero rows in this pre-bootstrap application/control inventory:

```text
app_users
identity_reconciliation_receipts
identity_reconciliation_activations
identity_reconciliation_legacy_mappings
clerk_user_deletion_tombstones
clerk_webhook_delivery_receipts
user_devices
teams
team_members
team_officials
team_tags
competitions
venues
scheduled_matches
matches
match_periods
match_events
match_metrics
match_assessments
pages
user_owned_workout_presets
workout_sessions
idempotency_keys
ai_threads
ai_messages
ai_attachments
ai_usage_daily
```

The Clerk provider readback must separately prove zero target users before
bootstrap. Schema rows, the 5/54 deterministic seed, and inactive ledger history
are not incorrectly counted as user-owned application data.

## Inactive-ledger contract

The sanitized read-only ledger query is
`api/scripts/greenfield-ledger-readback.sql`, SHA-256
`0c952e3a585bde1aad3313b5e11de572e5c2408cc30988eaae729bc5e39a0d6b`.
The packet status must be `inactive_with_optional_history`. It requires:

- zero `preparing`, `open`, and capture-enforced epochs;
- zero Queue, cron, and D1 consumers;
- a complete epoch classification whose preparing/open/frozen/archived counts
  sum to the total; and
- non-negative classified epoch, entity-revision, outbox-event, and
  outbox-delivery counts.

Frozen or archived epochs and their inactive historical rows may remain. The
validator does not require deleting that history and does not claim or permit
production ledger activation.

## Receipt integrity and ordered acceptance

Provider, acceptance, device, release, rollback, and traffic receipts are not
trusted merely because they contain a SHA-looking string. The validator
canonicalizes each complete sanitized payload by recursively sorting object
keys, preserving array order, rejecting unsupported/undefined/non-finite
values, excluding only the digest field being checked, and recomputing its
SHA-256. The embedded digest must match that recomputation. Applicable receipts
also bind the exact candidate Worker version, Clerk instance, and PlanetScale
branch.

Major stages use strict, not simultaneous, chronology:

1. post-preparation schema, seed, clean-target, inactive-ledger, and Clerk
   readbacks precede candidate deployment; the deployed candidate's
   Worker-version, binding, and route readback then precedes its write-disabled
   traffic verification;
2. write-disabled candidate verification precedes bootstrap activation and its
   observation;
3. activation and its observation precede bounded acceptance;
4. all 14 check receipts fall within the bounded window;
5. the write-guard probe precedes rollback-packet validation, and both precede
   bounded acceptance;
6. physical iPhone, watch, and Release-configuration acceptance follows the
   automated bounded window;
7. production writes/traffic follow identity activation, bounded acceptance,
   write-disabled candidate verification, and every physical/release receipt;
8. production observation follows enablement and cannot be in the future at
   the validator's runtime `now`; and
9. the rollback window ends after production observation and after runtime
   `now`.

The bounded window requires `WRITE_MODE=enabled`,
`NEW_USER_ONBOARDING_MODE=greenfield_bootstrap`,
`traffic_scope=bounded_test_only`, a positive request/identity sample within
the configured bounds, and the exact zero-legacy receipt. The required checks
are health, missing-bearer rejection, invalid-bearer rejection, `/api/me`,
zero-legacy onboarding, tenant isolation, owner-spoof rejection, CRUD,
idempotency, tombstones, assistant streaming, match-sheet parsing, webhook
lifecycle, and a write round trip.

The final packet cannot validate until iPhone 15 Pro Max, Apple Watch Series 9
(45mm), and Release-configuration receipts all pass. Its accepted traffic state
must route the candidate as `production_active`, use
`WRITE_MODE=enabled`, use the greenfield onboarding mode and exact receipt,
declare production traffic scope, and carry a completed passing observation.
Before that state, its initial candidate receipt must show either an unrouted or
write-disabled route with writes and onboarding disabled.

## Destructive rollback and stateful compatibility

The greenfield rollback packet requires three distinct Worker version UUIDs and
the exact Worker name `refwatch-api` in `production`. It binds a validated
write-guard probe, an unexpired rollback window, an already distributable
recovery client, and this exact recovery sequence:

1. stop production traffic and writes;
2. route to the write-guard Worker;
3. roll back the Worker and client;
4. reset PlanetScale application state;
5. reseed deterministic reference data;
6. recreate test identities; and
7. rerun greenfield launch acceptance.

Ledger escrow, recovery, activation, and Supabase reverse import must all be
false. The launch packet recomputes the embedded rollback packet digest and
requires its candidate, write-guard, last-known-good, provider-readback, guard
probe, recovery flags, instructions, and window to agree.

The retained stateful cutover/encrypted-bundle validators remain byte-for-byte
unchanged as the historical/future export/import path. The rollback validator
now accepts an explicit `stateful_migration_v1` or
`greenfield_destructive_v1` while preserving the stateful branch's contract;
for compatibility only, an older packet with no `rollback_profile` is treated
as `stateful_migration_v1`. An explicitly unknown profile is rejected.

## Artifact integrity

- `api/scripts/greenfield-launch-packet.mjs` SHA-256:
  `89d4a573fa600a846a104af3b0b67fa302d04520edc25a73feddf6875032e1b8`;
- `api/scripts/greenfield-launch-packet.d.mts` SHA-256:
  `4ef8161c94b1cf4f56f59c4256a9e110ee557c07d1d8e070b0b3a41eb5b76d75`;
- `api/scripts/validate-greenfield-launch-packet.mjs` SHA-256:
  `6b2d747463fb94ff9477255cad836dbd25317728c39d4b085a678e946be8fc60`;
- `api/scripts/rollback-packet.mjs` SHA-256:
  `7736142100bb42b72dde5170824c5555446b0fd3f34988efc59f823e29bba1a4`;
- `api/scripts/rollback-packet.d.mts` SHA-256:
  `0584e783f4a5b26c7e826e5480c50030a7f802047daf8f7eaee4f62c84f1044d`;
  and
- `api/scripts/validate-rollback-packet.mjs` SHA-256:
  `a9b7f569bae73d85d2873dd1c94b032d018b5c14c2a119ed1d9256c72323bcd9`.

The retained stateful cutover artifacts remained at their pre-batch hashes:

- `api/scripts/cutover-bundle.mjs`:
  `2d8df4ce19b7221273248c4019f4bb6e0898018e53595f56a14011dab2e1d13b`;
- `api/scripts/cutover-bundle.d.mts`:
  `401ce6dab8be2161e8b42b48a6b0b4453b3751332f1e90f4f58f62bd0cbc9dc7`;
- `api/scripts/encrypted-cutover-bundle.mjs`:
  `3cf565ed6a39340e2f8c45b61ccae0336506d2b04b8a2450ef0eaec001071059`;
- `api/scripts/encrypted-cutover-bundle.d.mts`:
  `2e8ac982bb95776100438f6fdab355a54c64507ff3c57a89283770fa94e1c35d`;
- `api/scripts/validate-cutover-bundle.mjs`:
  `bac3eb8e816fb506fcb8231de05997ce0b042f6c58639df23f9c289f75fba0bd`;
- `api/test/cutoverBundle.test.ts`:
  `0114120a8310191c53b019fa3ee8a80f0843469cef7a7d1afc2c8762b0966cf1`;
  and
- `api/test/encryptedCutoverBundle.test.ts`:
  `a60f3785fa90ddb71a941b46c6bac51269f9ae780e094cbbd0581810e3017967`.

## Local verification

After all code-risk dispositions:

- focused validator suite: 69/69 tests passed — 49 greenfield-launch,
  17 rollback, and 3 CLI cases;
- full `npm test`: 193/193 tests passed;
- `npm run test:db`: fresh migrations `0000`–`0016`, 18/18 hermetic database
  cases passed;
- `npm run typecheck`: passed;
- Node syntax checks for both validators and both CLIs: passed; and
- `git diff --check`: passed.

The focused/full/database verification shorthand is 69/193/18.

The pre-remediation validator checkpoint recorded 15/15 mounted routes. The
later 19-case route batch is recorded separately in
`2026-07-20-greenfield-local-route-matrix.md`; it does not retroactively change
this validator checkpoint. This validator evidence does not close or accept the
route matrix.

## Mandatory code-risk review

The initial code-risk review reported six findings:

1. schema and seed claims were self-attested, and the fixture used a stale
   1,106-row migration-era state plus a nonexistent source path;
2. the packet lacked exact PlanetScale target identity and per-table clean
   counts;
3. acceptance, identity, device, release, and traffic receipts were not bound
   to the candidate/Clerk/database, and bounded write configuration plus final
   observation were incomplete;
4. invalid CLIs could disclose input-derived content or print unvalidated
   summaries, including rollback JSON parse details;
5. the launch claim was not bound to the validated rollback packet; and
6. requiring an explicit rollback profile broke older profile-less stateful
   packets.

All six were applied.

The second review reported four further findings:

1. provider schema proof was self-attested/non-executable because it copied a
   repository snapshot digest rather than deriving a provider schema/migration
   readback;
2. receipt digests were packet assertions rather than recomputations over the
   actual sanitized receipt payloads;
3. clean-target validation incorrectly rejected authorized frozen/archived
   ledger history; and
4. schema, seed, clean-target, ledger, and write-disabled candidate baselines
   were not ordered before bootstrap and acceptance.

All four were applied. A later high finding showed that table names and
migration history alone would not detect manual catalog drift; the full
catalog contract now covers table properties/RLS, columns, constraints,
indexes, triggers, functions, and enums. The final high finding showed that
future timestamps and simultaneous major-stage timestamps could pass; typed
runtime `now`, future-observation rejection, strict stage ordering, and an
unexpired rollback-window bound now close that gap.

A preliminary alert that the authorization digest was stale was withdrawn:
the pinned `17e08...` value is correctly the canonical authorization-payload
digest, not a Markdown-file digest. Every substantive finding was applied and
regression-tested. Final reviewer `/root/validator_code_risk_review` returned
`NO FINDINGS`.

## Mandatory docs/evidence review

The independent docs/evidence review found five consistency issues:

1. the runbook activated identity and described webhook/CRUD acceptance before
   the required post-preparation readbacks, disabled candidate, write guard,
   rollback proof, and bounded writes-enabled window;
2. the focused validator total remained 52 instead of the current 69
   (49 launch, 17 rollback, and 3 CLI);
3. route summaries treated a transient added-case count as current instead of
   preserving only the 15/15 pre-remediation validator checkpoint and keeping
   the separate expanded route batch open;
4. the API acceptance checklist omitted `write_round_trip`; and
5. overview ledger summaries did not state the exact zero
   preparing/open/capture-enforced epoch and zero Queue/cron/D1 consumer
   contract.

All five findings were applied. Final reviewer
`/root/validator_docs_consistency_review` returned `NO FINDINGS`.

## Remaining boundary

This artifact proves the local packet contracts and their code-risk closure
only. A real launch packet cannot pass until fresh sanitized provider readbacks,
zero-target/seed proof, migration and receipt activation, distinct Worker
versions, bounded production acceptance, physical-device acceptance, write and
traffic activation, and completed observation exist. The later local route
batch has its own evidence and review lifecycle. No provider execution or
production activation is claimed here.

## 2026-07-20 append-only supersession note

Before production Worker deployment, live sanitized Cloudflare version
readback proved that bindings are immutable version resources. The active v1
closeout contract was therefore impossible because it required one version ID
to be both write-disabled and write-enabled. Do not use
`greenfield_launch_v1` or `greenfield_destructive_v1` for the production
greenfield closeout.

The active successor is `greenfield_launch_v2` plus
`greenfield_destructive_v2`, recorded in
`2026-07-20-greenfield-worker-version-lineage.md`. It requires distinct
disabled and accepted candidates with equal script ETags and stable-binding
hashes, an unexposed accepted version before bounded acceptance, distinct
write-guard/LKG versions, and both fallback probes. This note does not rewrite
the earlier v1 review or claim any provider deployment.
