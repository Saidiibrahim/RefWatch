# Architecture

RefWatch is a watch-first product with an iOS companion app, sharing core domain logic and services.

## System Shape

- The Swift watchOS app owns in-match execution, continuity, and local recovery without depending on cloud availability.
- The Swift/SwiftUI iOS companion owns planning, analysis, and cloud-backed features. It uses SwiftData as its offline-first local store and synchronizes through backend repository adapters.
- Protected application traffic crosses an authenticated HTTP boundary to the Cloudflare Worker under `api/`. The iOS client sends a Clerk session token; watchOS does not connect directly to the Worker or cloud database.
- Hono owns Worker routing, middleware, request handling, and HTTP responses; route-local schemas validate request payloads.
- Drizzle ORM owns the typed PlanetScale Postgres schema and application data queries inside the Worker. Drizzle Kit generates and applies the SQL migrations under `api/src/db/migrations`.
- Deployed Worker runtime reaches PlanetScale Postgres through Cloudflare Hyperdrive. Local/direct runtime may fall back to `DATABASE_URL`; migration commands require a separate migration-role `DATABASE_URL`.

The deployed application-data path is:

```text
iOS Swift client -> Hono Worker API -> Drizzle ORM -> pg client -> Hyperdrive -> PlanetScale Postgres
```

## Security and Ownership Boundary

Swift clients are untrusted API clients. They may hold public app configuration and short-lived Clerk session tokens, but never database credentials, Clerk server or webhook secrets, or OpenAI credentials. For protected `/api/*` routes, the Worker verifies the Clerk session, resolves the Clerk subject to the internal `app_users.id`, and derives the authoritative `owner_id` server-side. Client-supplied ownership values are not trusted. Health routes and the signed Clerk webhook are separate public Worker surfaces.

## Migration Status

Clerk + Cloudflare Workers/Hono + Drizzle + PlanetScale Postgres is the active
target architecture, not a claim of completed production cutover. The authorized
2026-07-20 launch is greenfield: historical Supabase identities/application rows
are disposable, no UUID/subject mapping or data import is required, and new Clerk
subjects receive server-generated internal UUIDs through the fail-closed
`greenfield_zero_legacy_v1` bootstrap. Production is bound to Clerk instance
`ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, domain `refwatch.ibby.ai`, and issuer
`https://clerk.refwatch.ibby.ai`.

Migration `0016` implements the database contract for exact zero-legacy
receipts, immutable activation and webhook-delivery receipts, serialized
bootstrap, and preserved stateful-migration tooling. The lifecycle handler
requires the signed raw Clerk instance to match configuration, its type and
subject to match the verified SDK projection, and its timestamp to be positive
safe-integer milliseconds before transactional idempotent create/update/delete
processing. The 2026-07-20 production preparation applied that migration and
provisioned a separate least-privilege read/write-data role/Hyperdrive pair;
the local production candidate binds it with writes/onboarding disabled while
the deployed Worker remains unchanged. A separate one-shot admin helper now
implements the fail-closed production zero-legacy activation transaction. It
distinguishes logical PlanetScale database `refwatch` from physical PostgreSQL
catalog `postgres`, locks the exact 0016 catalog plus migration history, and
withholds commit until Node validates the sanitized immutable receipt. The
history sequence is catalog-pinned and must be one of the two exact states
whose next ID is `18`; the activation path never advances or repairs it. Its
local isolated rehearsal is complete. A first production attempt failed closed
without an identity row because the original helper accepted only one of those
equivalent sequence states. Both remediated mandatory reviews closed with
`NO FINDINGS`; fresh database and separate Clerk readbacks then gated a
successful activation plus idempotent retry. Independent primary readback now
proves one immutable receipt and activation while application data remains
zero.
This is not deployed provider acceptance or traffic cutover, and it never
activates the mutation ledger.

Migration `0017` is the additive beta.3 source migration for Clerk profile
event ordering. It adds a nullable provider-event watermark so delayed or
equal-time lifecycle deliveries cannot overwrite newer profile state, while an
auth-created row can still accept its first webhook. The fail-closed one-shot
admin helper and physical-`postgres` rehearsal passed mandatory pre-execution
code/docs reviews and the supplemental SQL review with exact `NO FINDINGS`,
then applied migration `0017` through the fixed stdin-only PlanetScale admin
shell. Primary readback now proves exact `0017`/18 rows, 36 tables, 383 columns,
the full pinned catalog/history contract, sequence `(19,false)`, and the
nullable `timestamptz` watermark while preserving the immutable activation
pair, 5/54 seed, zero other target rows, and inactive ledger.
`reviewedSchema0016` still preserves the immutable activation receipt; the
active launch contract remains pinned to current `0017`. Both mandatory post-
execution reviewers returned final exact `NO FINDINGS`, closing migration-0017
convergence and removing this database prerequisite for Worker upload. No
Worker version has yet been uploaded/deployed/routed, and writes, onboarding,
traffic, Clerk configuration, and mutation-ledger state remain unchanged; all
later launch gates still apply.

The active launch contract models Cloudflare's immutable configuration
honestly: disabled candidate A and accepted candidate B are distinct Worker
versions with the same script ETag and stable readable/non-secret binding
contract hash. The packet carries exact, sanitized, digest-checked
`wrangler versions view --json` receipts for A and B; the validator recomputes
their stable hashes and enforces the approved production binding and
secret-name allowlist without reading secret values. A and B must derive from
an exact digest-checked `worker.secret_lineage`: non-echoing Wrangler stdin
updates only newly required/changed secrets, final source S preserves unchanged
bindings, and operator-confirmed sequential S→A→B uploads are bounded by the
provider version history. Sanitized A/B readbacks expose exactly six allowed
secret names/types. S is bounded by its exact ID/time, the required-name
operator confirmation, documented Wrangler preservation, and provider history,
with zero intervening versions/secret mutations/upload overrides and
`secret_values_recorded=false`. Cloudflare does not expose cryptographic
parent links or value equality; direct comparison is deliberately impossible,
and the deferred ledger key is not recovered or rotated. Only the readable values of
`WRITE_MODE` and `NEW_USER_ONBOARDING_MODE` may differ.
The provider sequence must publicly route A=100%/B=0%. B must receive no ordinary
traffic before promotion and is reachable for bounded automation only through the Cloudflare
version-override header, a Cloudflare Access service-token policy on
`api.refwatch.ibby.ai/api/*` whose exact `service_auth` receipt has one service
token and zero bypass, and the Worker-only
`CUTOVER_ACCEPTANCE_TOKEN` header gate. Workers.dev and preview URLs remain
disabled. Emergency guard G and last-known-good L are distinct versions, each
temporarily deployed at 100%, with canonical provider readback digests and
timestamps bracketing the probe inside the rollback window. Both complete by
validation time, use the initial A route with unique deployment/probe/provider
receipts, and satisfy G-after < L-before before final A proof.
The bounded webhook lifecycle is manually signed and reaches B through the
exact override/token headers with both present; it records
`manual_signed_harness` and valid/invalid signature outcomes, not provider
delivery. After bounded
automation passes, B is promoted to 100% with no competing version while
`/api/*` Access remains active. The real Clerk endpoint must then prove exactly
the three configured subscriptions without override/cutover-token headers,
including signature, create/update/delete, retry/delete-wins, and cleanup to
zero test identity/application rows. Only afterward may Access be removed and
its provider receipt precede deployment history and device/release acceptance.
Those devices exercise promoted B, production acceptance follows their
receipts, and final closeout re-proves inactive ledger capture and zero
consumers.

Validator diagnostics never echo rejected binding values. Cloudflare Access
application, policy, and service-token IDs are retained only in sanitized
32-hex or canonical-UUID provider-ID shapes.

User-owned collection synchronization is tombstone-based and replay-safe. The
Worker derives ownership, returns an inclusive `updated_at >= updatedAfter`
window, and serializes each namespaced entity mutation so its version is
strictly greater than the persisted version. The iOS repositories advance
high-water cursors only from completed pulls, start first/relaunch
reconciliation at the Unix epoch, overlap later pulls by 15 minutes, and apply
only strictly newer remote state without overwriting dirty local rows. The
overlap is a bounded contract for request-scoped database-only writes; a future
longer-running writer requires a server-issued monotonic cursor/revision.

Clean target state means zero `app_users`, zero legacy mappings, and zero
user-owned rows before bootstrap; it does not mean deleting schema/control rows
or deterministic global reference data reviewed from repository sources. Ledger
escrow/recovery/activation is deferred: the active launch path requires zero
preparing, open, or capture-enforced epochs and zero Queue, cron, or D1
consumers, although inactive resources may remain. Initial recovery is
intentionally destructive: stop traffic/writes, route to a write-disabled
Worker, restore Worker/client versions, reset/reseed PlanetScale, recreate test
identities, and rerun the launch.
Provider cutover operations are authorized but remain incomplete until their
sanitized evidence and acceptance checks pass. Secrets stay server-side and
non-disclosing; commits and publishing remain outside this work.

## Where To Read
- Canonical architecture index: `docs/design-docs/index.md`
- Core architectural beliefs: `docs/design-docs/core-beliefs.md`
- System breakdown: `docs/design-docs/architecture/overview.md`
- Platform details: `docs/design-docs/architecture/watchos.md` and `docs/design-docs/architecture/ios.md`
- Shared services: `docs/design-docs/architecture/shared-services.md`
- Backend implementation and operations: `api/README.md`
- Active backend migration state: `docs/exec-plans/active/backend-platform-migration/PLAN_backend-platform-migration.md`
- Migration and production cutover gates: `docs/references/backend-migration-cutover.md`
- Source and target database evidence: `docs/generated/db-schema.md`

## Working Rule
All architecture changes must update the relevant design doc and, when non-trivial, be tracked in an active exec plan under `docs/exec-plans/active`.
