# Rollback Control Preparation — 2026-07-14

## Implemented Control

The Worker now supports an explicit `WRITE_MODE=disabled` emergency version.
When active, it returns `503 writes_temporarily_disabled` with `Retry-After:
300` for every mutating `/api/*` and `/webhooks/*` request. Health endpoints,
`OPTIONS`, and mapped-user authenticated reads remain available. Auth-side
unmapped-user creation is also disabled. Missing configuration preserves normal
development behavior; any explicit value other than `enabled` fails closed.

Staging explicitly sets `WRITE_MODE=enabled`. Production must do the same in
its eventual environment block. The rollback operator must upload a separate
guard version before cutover; setting a local variable is not itself a remote
traffic change.

## Required Access-Controlled Packet

Create `.cutover/rollback-packet.json`; `.cutover/` is gitignored. The packet
must be approved and contain:

- named operator and approval timestamp;
- fixed UTC rollback-window start/end;
- numeric auth-failure, Worker 5xx, sync-backlog age, and database-pressure
  thresholds, with owner-scope violations fixed at zero;
- distinct candidate, last-known-good, and write-guard Worker version IDs plus
  provider-readback and guard-probe receipt identifiers;
- a restricted external write-ledger location, complete versioned ledger
  schema, and provider probe/readback receipt;
- an already distributable App Store, TestFlight, or managed-distribution
  recovery client with operator instructions.

Validate it before any production migration or traffic change:

```sh
cd api
npm run rollback:validate -- ../.cutover/rollback-packet.json
```

Drafts, expired/non-UTC windows, impossible percentage thresholds, duplicate
Worker IDs, missing provider/ledger receipt fields, incomplete ledger contracts,
unsafe owner-scope thresholds, and merely planned client builds fail local
validation. The validator checks packet structure and bounds only; it cannot
prove that a Worker version, ledger, or receipt exists. Provider readback and an
actual ledger probe remain mandatory independent evidence.

## Conditional Production Wrangler Commands

These commands fail today because `wrangler.jsonc` intentionally has no
production environment. After that environment, Hyperdrive binding, and
secrets exist, upload but do not route the write-guard version:

```sh
cd api
npx wrangler versions upload --env production --keep-vars \
  --var WRITE_MODE:disabled --tag rollback-write-guard \
  --message 'Pre-cutover emergency write guard'
npx wrangler versions list --env production --json
```

Copy the returned guard version UUID into the access-controlled packet and
revalidate it. At a threshold breach, route 100% to the pre-recorded guard:

```sh
npx wrangler versions deploy "$WRITE_GUARD_WORKER_VERSION_ID@100%" \
  --env production --yes --message 'Disable writes for RefWatch rollback'
npx wrangler deployments status --env production --json
```

Verify `/health` and `/health/ready` remain successful, authenticated reads
remain available, and a controlled mutation receives the documented 503 before
considering writes stopped. Drain in-flight requests, freeze the ledger, and
reconcile every post-cutover committed mutation from the external ledger before
restoring another version. The Worker does not yet emit that ledger; its
transactional capture and provider probe are production blockers.

After reconciliation and explicit operator approval, route to the recorded
last-known-good Worker:

```sh
npx wrangler versions deploy "$LAST_KNOWN_GOOD_WORKER_VERSION_ID@100%" \
  --env production --yes --message 'Restore last-known-good RefWatch Worker'
npx wrangler deployments status --env production --json
```

Do not reopen Supabase writes or reverse-import PlanetScale rows without the
reviewed table-specific reconciliation procedure. iOS binaries cannot be
downgraded remotely, so the packet deliberately rejects a recovery client that
is only planned rather than already distributable. Because the write guard
returns 503 to Clerk, drain and reconcile queued webhook retries before
reopening writes.

## Verification

- API typecheck: passed
- Vitest: 9 files, 47 tests passed
- Write-gate coverage: disabled API and webhook mutations, available health and
  read paths, and enabled-mode pass-through
- Rollback-validator coverage: approved packet, strict UTC/bounded thresholds,
  distinct version IDs, declared provider/ledger receipts, ledger contract,
  distributable client, and unexpired window
- Wrangler `4.110.0` staging dry-run: passed with `WRITE_MODE="enabled"`

This is tested local rollback-control preparation, not executable production
rollback readiness. The production environment, transactional external ledger
and probe, provider-verified versions/guard behavior, final owner/window/
thresholds, populated packet, and distributable recovery build remain required.
