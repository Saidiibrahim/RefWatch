# SECURITY

Security baseline:
- Do not commit secrets or local credential files.
- Keep auth boundaries explicit across watchOS, iOS, and backend services.
- Prefer least-privilege data access and validate sensitive operations.
- Track security-relevant changes in exec plans and release notes.

## Backend migration boundary

- iOS may embed only the Worker base URL, Clerk publishable key, and Clerk Frontend API host.
- PlanetScale credentials, `DATABASE_URL`, `CLERK_SECRET_KEY`, `CLERK_JWT_KEY`,
  `CLERK_WEBHOOK_SIGNING_SECRET`, `CUTOVER_ACCEPTANCE_TOKEN`,
  `OPENAI_API_KEY`, and Cloudflare administrative tokens are server-side only.
- The Worker must verify a Clerk session token and resolve its subject to an internal `app_users.id` before database access.
- Every user-scoped query, mutation, nested foreign reference, and idempotency key must be scoped to that internal ID. A client-supplied `owner_id` is never authoritative.
- Referenced schedules, teams, team members, competitions, venues, matches, and
  assessment matches must be both owner-scoped and active; a soft-deleted row
  is not an authorized foreign reference.
- Team replacement normalizes child UUIDs, rejects duplicates and bounded-list
  overflow, upserts retained children, and deletes only explicit removals. This
  prevents retries from using foreign child IDs or erasing historical
  match-event/member attribution.
- Namespace-qualified entity locks and owner/match uniqueness locks serialize
  conflicting writes. Strictly increasing mutation timestamps keep a later
  update/delete/resurrection visible to the authenticated incremental-sync
  boundary.
- Clerk subjects are opaque strings and must not be parsed as UUIDs. The
  greenfield launch imports no legacy UUIDs; the server generates internal UUIDs
  transactionally and idempotently for genuinely new subjects only after the
  explicit zero-legacy bootstrap is activated.
- `greenfield_zero_legacy_v1` must bind its authorization digest and activation
  to production Clerk instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, domain
  `refwatch.ibby.ai`, and issuer `https://clerk.refwatch.ibby.ai`. Missing,
  unknown, mixed legacy/greenfield, or wrong-instance claims fail closed.
- Clerk webhooks require signature verification plus agreement between the
  signed raw `instance_id` and the exact configured instance, plus agreement
  between its event type/subject and the verified projection. The signed raw
  event timestamp must be positive safe-integer milliseconds. Durable
  instance-plus-Svix-ID receipts, subject locks, and deletion tombstones make
  retries conflict-safe and prevent silent resurrection.
- OpenAI proxy routes require authenticated, bounded requests. Model allowlists, payload/output limits, and per-user abuse controls are production gates.
- Production mutation must use the separately prepared least-privilege
  read/write-data role/Hyperdrive; do not broaden the historical read-only
  emergency path or mistake local binding/write authorization for deployed
  database acceptance.

## Live legacy risk (2026-07-14)

The source-of-truth Supabase MCP readback found RLS disabled on nine live public tables: `match_officials`, `match_assessments`, `trend_snapshots`, `workout_session_metrics`, `workout_intensity_profile`, `workout_segments`, `coaches`, `feedback_attachments`, and `ai_usage_daily`.

This remains a legacy security risk for any path that still permits direct
client access to those tables. The historical 43 Auth identities, 42 profiles,
1,106 application rows, and `testing@refwatch.com` are authorized disposable
state, not import/reconciliation gates. Until Supabase is retired, restrict its
exposure. The target PlanetScale design does not use Supabase RLS; equivalent
isolation must be proven in Worker/database-backed and deployed tests before
cutover.

## Required evidence before production cutover

- Source, config, built-bundle, and log scans show no forbidden server credentials in iOS.
- Database-backed tests cover cross-user reads, writes, deletes, references, idempotency races, and `/api/me` identity creation/resolution.
- Invalid Clerk tokens and webhook signatures fail closed without leaking verifier details.
- The zero-legacy receipt/activation proves exact-instance binding, zero legacy
  mappings, zero pre-bootstrap app users/user-owned rows, preserved deterministic
  global reference data, subject locking, tombstones, concurrent create/delete
  safety, and idempotent retries.
- Production binding/readiness evidence shows Hyperdrive with no plaintext
  database URL and an appropriately scoped write-capable role before writes.
- Launch evidence records zero preparing, open, or capture-enforced ledger
  epochs and zero Queue, cron, or D1 consumers. It does not falsely claim that
  inactive ledger resources are absent or activate the inaccessible historical
  key.
- Secret values are installed only through non-echoing paths and never printed,
  passed as command arguments, placed in iOS configuration, or written to
  evidence/chat.
- The write-enabled Worker version receives zero ordinary traffic before
  promotion. The provider sequence must establish A=100%/B=0%; bounded `/api/*`
  requests select B only
  through `Cloudflare-Workers-Version-Overrides`, a Cloudflare Access
  `service_auth` policy receipt on `api.refwatch.ibby.ai/api/*` with exactly one
  service token and zero bypass, and the Worker-enforced
  `X-RefWatch-Cutover-Token` value sourced from the server-only
  `CUTOVER_ACCEPTANCE_TOKEN` secret. That value never enters iOS configuration
  or evidence. Missing/invalid tokens fail with 403, and Workers.dev/preview
  exposure remains disabled. The bounded manually signed webhook lifecycle also
  requires the override and Worker token but is not Clerk-provider proof.
- After B=100% promotion, `/api/*` Access remains active while the real Clerk
  endpoint delivers without override or cutover-token headers. The promoted
  receipt must bind exactly `user.created`, `user.updated`, and `user.deleted`,
  prove signature/create/update/delete/retry/delete-wins behavior, and clean
  test identities/application rows back to zero. Only then may a
  provider-bound Access removal receipt precede deployment-history and device
  evidence.
- Packet-carried sanitized A/B version readbacks include no author metadata or
  secret values. The validator recomputes each stable binding hash, checks its
  digest and exact version, and enforces the approved production plain/resource
  bindings plus secret-name/type set. Only the two reviewed mode values may
  differ. Error messages identify only the invalid field/contract and never
  echo a rejected binding value.
- Because Cloudflare cannot return secret values, `worker.secret_lineage`
  provides exact non-disclosing provenance: only newly required/changed secrets
  (at least webhook signing and cutover acceptance) use
  `wrangler versions secret put` via stdin; final source S preserves unchanged
  existing bindings; then operator-confirmed S→A→B sequential uploads are
  bounded by a digest-checked provider history. Sanitized A/B readbacks expose
  exactly the six allowed secret names/types. S is bounded by exact ID/time,
  the required-name operator confirmation, documented preservation, and
  provider history, with zero unexpected versions/secret mutations/upload
  overrides and `secret_values_recorded=false`. Cloudflare
  does not expose cryptographic parent links or value equality, so direct
  comparison is deliberately impossible. The inaccessible historical ledger
  key is neither recovered nor rotated.
- Access application, policy, and service-token IDs in evidence must match a
  sanitized Cloudflare provider-ID shape (32 hexadecimal characters or a
  canonical UUID); credentials and secret token values are never evidence.
- Live Supabase remains an explicit disposable legacy risk until its identities,
  data, functions, and credentials are retired. Initial rollback uses the
  write-disabled Worker plus PlanetScale reset/reseed and test-identity
  recreation, not Supabase data preservation or production ledger recovery.

The encrypted cutover-bundle, legacy mapping, and stateful ledger/rollback
validators remain intact as historical/future live-migration tooling. Their
preservation requirements do not gate this authorized greenfield launch.

Operational details and setup guidance live in `docs/references/backend-migration-cutover.md`.
