# RELIABILITY

Reliability expectations:
- Define failure modes and fallback behavior for every critical flow.
- Ensure active-session state can be recovered after interruptions.
- Include regression checks in tests and release checklist.
- Record reliability-impacting changes in active exec plans.

## Backend migration reliability

- watchOS match timing, haptics, lifecycle, and unfinished-session recovery must remain independent of Clerk, Worker, PlanetScale, and OpenAI availability.
- iOS SwiftData remains the local source for offline operation. Remote failures stay in a retryable backlog and must not discard a locally completed match.
- Clerk subject resolution through `/api/me` must complete before internal owner metadata is published to repositories; Clerk IDs are never UUID-parsed.
- Incremental synchronization must carry deletion tombstones or use an explicitly documented full-reconciliation protocol. Filtering deleted rows out of `updatedAfter` responses is insufficient for multi-device convergence.
- Match ingest must atomically persist matches, periods, events, and metrics and must be concurrency-safe for repeated match IDs and `Idempotency-Key` values.
- Hyperdrive/runtime connection pressure, Clerk verification failures, sync backlog age, webhook failures, and OpenAI upstream status should be observable during staging and cutover.

## Cutover evidence

Local compilation, API tests, and a Wrangler dry-run are necessary but do not prove production readiness. Staging Worker/Hyperdrive `select 1` connectivity and disposable PlanetScale readback are recorded separately; production binding/deployment, source-to-target reconciliation, staging authenticated CRUD/streaming, iOS offline/logout tests, and watch regression evidence remain. Preserve a Supabase rollback window until reconciliation is complete.

Reference diagnostics and release runbooks in `docs/references/process` and `docs/references/backend-migration-cutover.md`.
