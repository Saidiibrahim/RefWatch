# Partial Local Mounted-Route and Owner-Isolation Matrix

Date: 2026-07-17 (Australia/Adelaide)

## Scope

Close two local cutover-safety defects without using Clerk, PlanetScale,
Cloudflare, Supabase, Google, or any other provider credential or mutation:

- HTTP mutations now require the exact normalized `WRITE_MODE=enabled` value;
  missing, blank, disabled, or unknown values fail closed before auth/database
  work.
- Team, competition, venue, and scheduled-match conflict updates now enforce
  the resolved owner atomically and never update `owner_id`. A foreign team
  conflict returns before members, officials, or tags can be replaced.

The default Wrangler target is now the separate
`refwatch-api-development` Worker. Production remains `refwatch-api` with
`WRITE_MODE=disabled`.

## Hermetic test boundary

`npm run test:local:routes` creates a mode-restricted temporary directory,
starts PostgreSQL bound only to `127.0.0.1` on an unused high port, applies the
checked-in migrations `0000` through `0015`, runs one Vitest file, stops the
server, and deletes the temporary directory through a shell trap. The test
refuses a non-loopback host, unexpected database name, missing opt-in, or an
SSL mode other than the runner's local `disable` setting.

The four cases prove:

- missing `WRITE_MODE` denies mutation before the injected verifier runs;
- a deterministic injected session verifier maps two opaque subjects through
  the mounted Clerk middleware and `/api/me`;
- authenticated local reads return exactly 5 reference competitions and 54
  reference teams for 2026;
- team/member/official/tag, competition, venue, and scheduled-match writes are
  owner-scoped, client owner spoofing is ignored, foreign references and
  upserts fail, the foreign scheduled-match delete fails, foreign rows remain
  unchanged, and schedule tombstones appear only on incremental sync.
  Team/competition/venue delete
  isolation remains covered by route predicates and existing unit/code review,
  not this four-case database matrix.

## Verification

- `npm run typecheck`: passed.
- `npm test`: 14 files, 93 tests passed.
- `npm run test:local:routes`: 1 file, 4 tests passed after all 16 migrations.
- `npm run mutation:coverage`: 35 schema tables classified; 22 captured and 13
  explicitly excluded.
- Development Wrangler dry-run: passed for `refwatch-api-development` with
  explicit `WRITE_MODE=enabled`.
- Production Wrangler dry-run: passed for `refwatch-api` with
  `WRITE_MODE=disabled` and the expected production bindings.
- No deploy, provider readback, provider credential use, or external mutation
  occurred.

## Evidence boundary

This is partial local mounted-route and owner-isolation evidence. It does not
prove real Clerk JWT verification, PlanetScale, Hyperdrive, runtime-role or
database pins, a deployed Worker, webhook signatures, OpenAI routes,
match-sheet parsing, match/assessment CRUD, idempotency, the full authenticated
matrix, or production rollback readiness. Those remain open and separately
gated.

## Mandatory review dispositions

- Code-risk planning findings — default-open write mode, non-atomic owner
  upserts, per-request concurrent `pg.Client` queries, an incorrect assistant
  test path, and incomplete child-row assertions: applied.
- Docs/evidence findings — default development and production shared a Worker
  name, and the local matrix could be mistaken for deployed acceptance:
  applied through Worker-name isolation and this explicit boundary.
- Final code-risk re-review: no remaining high/medium finding.
- Final docs/evidence code/config re-review: no remaining high/medium finding;
  canonical status/supersession updates are recorded separately.
