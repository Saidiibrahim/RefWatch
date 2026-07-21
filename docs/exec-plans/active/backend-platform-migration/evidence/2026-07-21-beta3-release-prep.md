# Beta 3 release preparation

Date: 2026-07-21

## Purpose

Prepare the source-only `v0.9.0-beta.3` prerelease after the greenfield runtime,
identity, collection-replay, and cutover-validator implementation batch. This
artifact does not claim a provider deployment or production cutover.

## Safety disposition

- `.projects/` remains excluded wholesale; local Stripe Projects cache, vault,
  and state files are not release inputs.
- Mandatory code-risk review found that delayed Clerk `user.updated` delivery
  could overwrite a newer profile. Source migration `0017` adds a dedicated
  nullable provider-event watermark, and onboarding now accepts only strictly
  newer profile events.
- The applied/hash-pinned production `0016` receipt is unchanged. Source `0017`
  is intentionally unapplied and must be applied/read back, followed by launch
  validator schema/history repinning, before this Worker source is deployed.
- Database coverage includes stale, equal-time, and concurrent reversed-order
  lifecycle deliveries. Delete remains terminal.
- Completed remediated-v2 task checkboxes are synchronized with their evidence.

## Verification

- `npm run typecheck` — pass.
- `npm test` — 268/268 across 19 files.
- `npm run test:db` — 23/23 across 3 files.
- `npm run test:local:routes` — 19/19.
- `npm run mutation:coverage` — pass: 36 schema tables, 23 captured, 13
  excluded, 5 included writer routes, and 2 control-plane routes.
- `npm run dry-run -- --env production` — pass with the expected candidate
  Hyperdrive and writes/onboarding disabled.
- `npm run db:migrate:production:0016:check` — pass; immutable applied `0016`
  and exact source successor `0017` verified.
- Focused `BackendCollectionCursorTests` on iPhone 15 Pro Max/iOS 18.5 — 5/5.
- Unsigned generic iOS Release build with embedded watch/widget — pass.
- Debug iPhone 15 Pro Max simulator build — pass.
- Built iOS, watch, and widget plists — `0.9.0 (3)`; watch workout background
  mode present; iOS bundle contains no `OPENAI_API_KEY`.
- `git diff --check` — pass before grouped commits.

## Release boundary

Production remains at migration `0016`/17 rows. The repository source is at
`0017`/18 rows. Do not deploy this prerelease Worker or continue activation
until the exact reviewed `0017` production apply/readback is recorded and the
launch validator is repinned. Publish as a non-latest GitHub prerelease so
stable `v0.8.2` remains Latest.

Append-only 2026-07-21 clarification: the separately review-gated one-shot
`greenfield_zero_legacy_v1` database receipt activation is authorized against
the exact production `0016`/17-row contract and may precede `0017` only after
both mandatory pre-execution reviews close. That identity control-row
activation does not deploy this source, enable writes or onboarding, route
traffic, or activate the mutation ledger. The `0017` stop continues to govern
Worker deployment and launch-validator repinning.

Append-only 2026-07-21 convergence update: a separately gated, fail-closed
production-0017 admin helper and isolated physical-`postgres` rehearsal are now
implemented locally, and the active launch validator is pinned to exact
0017/18 rows/383 columns while the activation receipt retains frozen 0016
pins. Production is still at 0016. Mandatory reviews, fresh primary gates,
apply/readback, idempotent retry, and post-execution review closure remain
required before any Worker version upload.

Append-only 2026-07-21 production-convergence supersession: mandatory pre-
execution code/docs reviews and the supplemental SQL review returned exact
`NO FINDINGS`, after which the reviewed stdin-only admin helper applied
production migration `0017` and an exact retry returned `idempotent_retry`.
Independent primary readbacks now prove 18/head-18 history, 36 tables, 383
columns and every pinned digest, full-history SHA-256
`4df5affeb9a55d1dd00437eb952f13f00afbb1f730bb368e3b2310d16edfa695`,
the exact Drizzle control catalog, sequence `(19,false)`, exact nullable
`timestamptz` watermark, unchanged identity UUID/timestamps, exact 5/54 seed,
zero other target rows, and inactive ledger. The earlier source-only statements
above remain truthful historical checkpoints but no longer describe current
production schema state. Post-execution reviews remain pending and must close
before any Worker upload; deployment, routing, writes, onboarding, traffic,
and mutation-ledger state remain unchanged.

Append-only 2026-07-21 review-closure supersession: both mandatory post-
execution reviewers returned final exact `NO FINDINGS`, closing migration-0017
convergence and removing that database prerequisite for Worker upload. The
earlier pending sentence immediately above is retained as a historical
checkpoint. No Worker version has yet been uploaded/deployed/routed; writes,
onboarding, traffic, Clerk configuration, mutation-ledger state, and every
later launch/acceptance gate remain unchanged.
