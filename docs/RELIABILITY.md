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
- Incremental synchronization uses inclusive `updated_at >= updatedAfter`
  replay and deletion tombstones. Collection cursors advance only after a
  completed pull, first/relaunch pulls start at the Unix epoch, and later pulls
  overlap by 15 minutes. Replayed rows apply only when strictly newer and never
  overwrite dirty local state. The overlap assumes request-scoped,
  database-only writes settle within the window; longer-running writers require
  a server-issued monotonic cursor/revision or separately reviewed equivalent.
- Each mutable collection entity uses a namespace-qualified transaction lock
  and `max(now, persisted updated_at + 1 millisecond)` so update, delete, and
  resurrection remain strictly ordered even at the same clock instant.
- Match ingest must atomically persist matches, periods, events, and metrics and must be concurrency-safe for repeated match IDs and `Idempotency-Key` values.
- Hyperdrive/runtime connection pressure, Clerk verification failures, sync backlog age, webhook failures, and OpenAI upstream status should be observable during staging and cutover.
- The initial production identity state is an explicit
  `greenfield_zero_legacy_v1` receipt bound to Clerk instance
  `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, not an unmapped-user bypass. It must remain
  fail-closed until zero legacy mappings and clean target user/data counts are
  transactionally activated. Lifecycle delivery receipts are immutable and
  transactionally coupled to create/update/delete effects; exact retries are
  idempotent, conflicting delivery-ID reuse fails closed, and deletion wins
  across delayed or concurrent lifecycle events.
- Production writes require a reviewed least-privilege write-capable database
  role. The historical read-only Hyperdrive role remains the emergency
  write-denial path. The prepared separate read/write-data role/Hyperdrive has
  passed rolled-back write and exact-config proof, but does not satisfy
  mutation acceptance until deployed and exercised through the bounded matrix.
- Ledger capture is not part of initial recovery. Normal transactions must
  commit with no active capture-enforced epoch and create no outbox/delivery
  rows; isolated tests must continue to prove strict capture when an epoch is
  deliberately opened.

## Cutover evidence

Local compilation, API tests, and a Wrangler dry-run are necessary but do not
prove production readiness. The greenfield launch additionally needs sanitized
provider readbacks for reviewed schema/deterministic seed, zero app users/
user-owned rows and zero legacy mappings before bootstrap, zero preparing/open/
capture-enforced ledger epochs and zero Queue/cron/D1 consumers, exact
disabled-candidate/accepted-candidate/write-guard/last-known-good Worker
versions, routing/configuration, authenticated tenant/onboarding/write
behavior, and traffic observation. Candidate A/B must have equal provider
script ETags and stable-binding hashes derived from packet-carried sanitized
version readbacks; the validator recomputes the hashes and enforces the exact
approved production binding/secret-name allowlist. A digest-checked
`worker.secret_lineage` separately proves the non-echoing Wrangler stdin
updates only newly required/changed secrets, source S preserves unchanged
bindings, and operator-confirmed sequential S→A→B uploads are bounded by a
provider-history digest. Sanitized A/B readbacks must expose exactly the six
allowed secret names/types. S is bounded by exact ID/time, the required-name
operator confirmation, documented preservation, and provider history, with
zero intervening versions/mutations/overrides and no recorded values. This is
not cryptographic parent-link or value-equality proof,
and it does not recover or rotate the deferred ledger key. The provider sequence must
publicly route A=100%/B=0% and prove its exact served version, health/readiness, auth
rejection, retryable API/webhook denial, and zero mutations. B must remain at zero
ordinary traffic while bounded requests select it with Cloudflare's version
override behind an exact Access `service_auth` receipt with one service token
and zero bypass, plus the Worker-only `CUTOVER_ACCEPTANCE_TOKEN` header gate.
Both guard and LKG are temporarily deployed at 100%; canonical provider
readback digests/timestamps bracket each exact-version probe, launch validation
waits for the after-readbacks, and the final A=100%/B=0% proof follows. Both
probes must be inside the rollback window, complete by validation time, share
the initial A route, use unique receipts, and satisfy G-after < L-before.
Bounded `webhook_lifecycle` records `manual_signed_harness`, exact
override/token headers present, and valid/invalid signature outcomes; it is not
provider delivery. Passing bounded automation promotes B to 100% with no
competitor while `/api/*` Access remains active. A separate promoted-webhook
receipt must prove real Clerk delivery without override/token headers, exactly
three subscriptions, signature/create/update/delete/retry/delete-wins behavior,
and cleanup to zero test identity/application rows. Only then may a
provider-bound Access-removal receipt precede deployment history and
device/release testing. Production acceptance follows those device receipts
and final closeout repeats the inactive-ledger/zero-consumer readback.
Workers.dev and preview URLs remain disabled throughout. Global reference rows
are not user-owned target data.

Initial rollback is destructive: stop traffic and writes, route to the emergency
write-disabled Worker, restore the Worker/client version, reset and reseed
PlanetScale from reviewed repository sources, recreate disposable test
identities, and rerun acceptance. The stateful Supabase/ledger rollback
validators remain historical/future tooling, not greenfield launch gates. If the
iPhone 15 Pro Max or Apple Watch Series 9 (45mm) is unavailable, record that
external blocker and continue every other safe check.

The v2 launch receipt embeds the exact standalone
`greenfield_destructive_v2` packet, its digest, rollback window, thresholds,
probe results, and recovery-client contract. The launch validator invokes the
standalone rollback validator, and all receipt kinds and IDs must be unique.

Reference diagnostics and release runbooks in `docs/references/process` and `docs/references/backend-migration-cutover.md`.
