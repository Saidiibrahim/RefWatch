# Beta 4 release preparation

Date: 2026-07-21

## Purpose

Prepare the source-only `v0.9.0-beta.4` prerelease after production identity
activation and migration `0017` convergence, plus the local v3 Clerk/Worker
cutover-preparation continuation. This artifact does not claim provider
execution, traffic cutover, or production acceptance.

## Safety and grouping

- `.projects/` is excluded wholesale. Stripe Projects cache, vault, and state
  files are not release inputs.
- The 54-file pre-release worktree is dependency-grouped as: schema/identity
  and packet contracts; fail-closed provider preparation; migration governance
  and evidence; then release metadata.
- Historical v2 packet validation remains available, but active closeout uses
  `greenfield_launch_v3` and `greenfield_destructive_v3` with the exact
  Cloudflare Custom Domain, zero conflicting zone routes, and no manual DNS
  origin.
- The original beta.3 release boundary remains unchanged; later production
  convergence is recorded only as append-only supersession.

## Verification

- `npm test` — 455/455 across 25 files.
- `npm run typecheck` — pass.
- `npm run test:db` — 43/43 across current-schema, exact-0016 activation, and
  migration-0017 suites.
- `npm run test:local:routes` — 19/19.
- `npm run clerk:webhook:production:check` — pass.
- `npm run worker:lineage:production:check` — pass.
- `npm run cutover:production:check` — pass.
- `npm run mutation:coverage` — pass: 36 schema tables, 23 captured, 13
  excluded, five application writers, and two control-plane writers.
- `npm run dry-run -- --env production` — pass with writes/onboarding disabled.
- `wrangler types --env production --check` — pass.
- Xcode 27.0 generic unsigned iOS Release build with embedded watch/widget —
  pass.
- Xcode 27.0 generic unsigned iOS Debug build with embedded watch/widget —
  pass.
- Built iOS, watch, and widget plists — `0.9.0 (4)`; watch background modes
  contain only `workout-processing`; the iOS plist contains no
  `OPENAI_API_KEY`.
- `git diff --check` — pass after v3 documentation reconciliation.

Per-group staged Gitleaks scans, the final beta.3-to-beta.4 commit-range scan,
exact remote-SHA verification, and the GitHub Secret Scan are publication
gates and are recorded by the release readback rather than claimed early here.

## Review dispositions

The initial code-risk and docs/evidence reviewers found four material release
issues: exposed `.projects` state, stale active-v2 wording, missing beta.4
version/evidence preparation, and an unclosed latest-delta review. All findings
were applied. The post-change code-risk and docs/evidence reviewers then
returned final exact `NO FINDINGS`, closing the local source/docs review gate
without authorizing provider execution.

## Release boundary

Publish only as a non-latest prerelease so stable `v0.8.2` remains Latest. The
outer `cutover:production` command remains fail-closed pending trusted
Cloudflare audit reading, live provider output fixtures, bounded continuation
wiring, and the active v3 review closure. No production Clerk endpoint or
S/A/B/G Worker version has been created by this source batch. No Worker upload,
deployment, route/domain mutation, write/onboarding enablement, traffic
promotion, Clerk lifecycle delivery, or mutation-ledger activation is claimed.
Physical iPhone 15 Pro Max, Apple Watch Series 9 (45mm), and production Release
acceptance remain later launch gates.
