# Rehearsal Database Integration — 2026-07-14

## Scope

The Hono match routes were exercised against the real PlanetScale Postgres
branch `cutover-rehearsal-20260714`. The harness injects an already-resolved
internal app-user identity and uses the production Drizzle route code. It does
not bypass route ownership predicates, but it does bypass Clerk token
verification; deployed authenticated coverage remains a separate gate.

The test covers:

- rejection of a foreign-owner team reference despite a spoofed client
  `owner_id`;
- two concurrent, identical match-ingest requests using one idempotency key,
  which both return HTTP 200 with the same cached body;
- reuse of that key with a different request body, which returns HTTP 409;
- owner-scoped list and delete behavior: the foreign owner sees no match and
  receives HTTP 404 on deletion, while the resolved owner reads the row with
  the server-derived `owner_id`.

## Credential and cleanup boundary

The `npm run test:db` runner creates a PlanetScale role inheriting
`pg_read_all_data,pg_write_all_data` with a 15-minute TTL. Its JSON result is
held in a shell variable, converted to a `verify-full` connection URL in
process memory, and passed only to the test process. The URL/password is never
printed or written. A shell trap deletes the role after each run.

The test itself requires a distinct integration URL and an explicit destructive
test opt-in. The allowed disposable PlanetScale branch ID is anchored in test
code rather than accepted from the caller. It validates the
`pscale_api_*.<branch-id>` username and `sslmode=verify-full` before any SQL.
Direct invocation without the managed-runner values fails rather than skips; a
production/main-branch URL fails the test-owned branch identity check.

The cleanup trap is installed before role creation. If create-response parsing
fails, it resolves the role by its unique generated name before deletion; the
15-minute provider TTL is the final fallback for an uncatchable interruption.

The final readback found:

- active roles named `integration-*`: `0`;
- residual fixture users: `0` (dependent rows cascade-cleaned).

## Commands and results

From `api/`:

```sh
npm run test:db
npm run typecheck
npm test -- --run
```

Final results:

- database integration: 1 file, 3 tests passed;
- normal API suite: 7 files, 37 tests passed;
- TypeScript typecheck: exit 0.

The first harness run used a single `pg.Client` for simultaneous request
transactions and returned one 200 plus one 409. Node-postgres also warned that
concurrent queries on one client are deprecated. That setup did not model
separate Worker requests. The harness was corrected to a four-connection pool;
the rerun passed 200/200 and the complete matrix above. No production database
or production Worker was touched.

## Remaining boundary

This closes real-Postgres match-ingest concurrency, idempotency, and focused
tenant-isolation proof. It does not prove Clerk JWT resolution, Hyperdrive
concurrency, the other CRUD route families, assistant/match-sheet calls,
webhooks, or the authenticated deployed route matrix.
