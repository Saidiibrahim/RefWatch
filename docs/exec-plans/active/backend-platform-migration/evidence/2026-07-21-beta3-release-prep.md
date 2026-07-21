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
