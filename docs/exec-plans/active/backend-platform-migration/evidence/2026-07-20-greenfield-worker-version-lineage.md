# Greenfield Worker Version-Lineage Contract

Date: 2026-07-20 (Australia/Adelaide)

## Scope

This artifact records a fail-closed correction made before production Worker
deployment. It supersedes `greenfield_launch_v1` and
`greenfield_destructive_v1` only as active greenfield closeout profiles.
Their earlier evidence remains point-in-time truth, and the stateful migration
validator behavior/contracts plus the stateful cutover artifacts remain
unchanged.

No production/provider Worker version, deployment, route, secret, webhook,
user, database row, or traffic configuration was mutated by this batch. The
verification suite used only disposable loopback PostgreSQL.

## Finding

The v1 launch packet required one immutable candidate Worker version to be:

- write-disabled during initial route verification; and
- write-enabled during bounded and accepted production traffic.

Cloudflare Worker versions include their bindings and settings. Changing
`WRITE_MODE` or `NEW_USER_ONBOARDING_MODE` therefore produces a different
version. One version ID cannot truthfully satisfy both v1 claims.

Sanitized read-only `wrangler versions view --json` observations completed by
`2026-07-20T07:17:55Z` confirmed:

| Version | Relevant configuration | Script ETag |
| --- | --- | --- |
| `e966d6df-b5ff-4288-832c-c8d91e00ce48` | correct production Clerk issuer; writes/onboarding disabled; historical read-only role/Hyperdrive | `c7fe13feeaec6962e56ee072a7479b1ea022b21ded00bf2d21a04d4d5477ccc4` |
| `3096a8cc-bec6-4be1-9943-dddd34d36b00` | stale Clerk issuer; writes/onboarding disabled; historical read-only role/Hyperdrive | `c7fe13feeaec6962e56ee072a7479b1ea022b21ded00bf2d21a04d4d5477ccc4` |

The equal provider script ETag across binding-only changes gives a usable code
lineage anchor. The stale-issuer version is not eligible as a launch fallback.
Provider author metadata and all secret values are omitted.

## Active v2 contract

`greenfield_launch_v2` uses schema version 2 and requires four pairwise-distinct
immutable Worker IDs:

1. disabled candidate A;
2. accepted/write-enabled candidate B;
3. emergency write guard G; and
4. last-known-good L.

A and B must have:

- the same 64-hex provider script ETag;
- the same reproducible stable-binding SHA-256;
- distinct creation timestamps and version IDs; and
- creation/readback chronology after the exact zero-legacy activation is
  observed.

The exported `sanitizeWorkerVersionReadback` helper in
`api/scripts/greenfield-launch-packet.mjs` converts each parsed
`wrangler versions view --json` response into an exact packet-safe A/B receipt:
version ID, creation/readback times, script ETag, approved resources and
bindings, stable-binding SHA-256, and a canonical receipt digest. Author
metadata and secret values are excluded. The validator digest-checks each
sanitized receipt and uses the exported `computeStableWorkerBindingSha256`
helper to recompute its stable hash; it does not accept a self-attested hash.
Only the values of `WRITE_MODE` and `NEW_USER_ONBOARDING_MODE` are normalized
for the A/B equality comparison, while their exact stage values remain
mandatory.

The exact production allowlist is enforced:

- plain bindings:
  `ALLOW_UNMAPPED_CLERK_USERS`, `CLERK_INSTANCE_ID`, `CLERK_ISSUER`,
  `EXPECTED_DATABASE_BRANCH_ID`, `EXPECTED_DATABASE_MARKER`,
  `EXPECTED_DATABASE_ROLE_ID`,
  `IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST`,
  `IDENTITY_RECONCILIATION_RECEIPT`, `MUTATION_LEDGER_DLQ_NAME`,
  `MUTATION_LEDGER_ENCRYPTION_KEY_ID`, `NEW_USER_ONBOARDING_MODE`,
  `REFWATCH_ENV`, and `WRITE_MODE`;
- secret names only: `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`,
  `CLERK_WEBHOOK_SIGNING_SECRET`, `CUTOVER_ACCEPTANCE_TOKEN`,
  `MUTATION_LEDGER_ENCRYPTION_KEY`, and `OPENAI_API_KEY`; and
- resources: `CF_VERSION_METADATA`, Hyperdrive
  `920ca5b108034b2bb8700cf0201ac55f`, D1
  `6d1a7bbb-ea9d-47b2-ae77-44f992b9e3d2`, and Queue
  `refwatch-mutation-ledger-production`.

The fixed production values additionally pin `REFWATCH_ENV=production`,
`ALLOW_UNMAPPED_CLERK_USERS=false`, Clerk instance
`ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, issuer
`https://clerk.refwatch.ibby.ai`, PlanetScale branch `w3g1f8vcbg34`, role
`hvk7iheytj62`, the exact database marker/authorization/activation receipt, and
the reviewed ledger DLQ/key ID. Unknown, missing, duplicated, or extra binding
types/names fail closed. Validator errors never interpolate an invalid binding
value; they name only the affected field/contract. Cloudflare does not expose
secret values, so A/B equality covers the readable/non-secret contract plus
secret names/types, not direct secret-value comparison.

`worker.secret_lineage` supplies the separate non-disclosing sequential-
inheritance proof derived from Wrangler's documented preservation behavior. It
is an exact digest-checked provider-history/operator receipt for:

1. non-echoing `wrangler versions secret put` with bytes on stdin only for
   newly required or changed secrets, including at least the webhook-signing
   secret and `CUTOVER_ACCEPTANCE_TOKEN`;
2. the resulting final secret-source Worker version S, which preserves
   unchanged existing secret bindings;
3. sequential upload of A from S; and
4. only then sequential upload of B from A.

The receipt pins S/A/B version IDs and creation times, both inheritance links,
its observation time, operator confirmation, and a canonical provider version-
history receipt ID/digest. Its secret-name array must contain exactly
`CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`,
`CLERK_WEBHOOK_SIGNING_SECRET`, `CUTOVER_ACCEPTANCE_TOKEN`,
`MUTATION_LEDGER_ENCRYPTION_KEY`, and `OPENAI_API_KEY`; that is the exact
sanitized name/type set on A/B. S is bounded by its exact ID/time, the
required-name operator confirmation, documented Wrangler preservation, and
provider history; it has no direct sanitized binding/value readback. This is
not a claim that all six values were reinstalled. The receipt requires zero
unexpected intervening versions, zero intervening secret mutations, zero
upload secret overrides, passed non-echoing
installation, and `secret_values_recorded=false`. S, A, B, G, and L are
pairwise distinct. Cloudflare list/view does not expose cryptographic parent
links or secret-value equality: the proof is provider-history-bounded and
operator-confirmed sequencing under documented preservation behavior. Direct
secret-value comparison is deliberately impossible. The deferred historical
ledger key is neither recovered nor rotated.

Before bounded acceptance, the initial deployment receipt must prove:

- public route `api.refwatch.ibby.ai/*` and the exact provider route/deployment
  IDs assign A=100% and B=0%;
- A has writes/onboarding disabled, and `/health` plus `/health/ready` report
  exact A;
- missing/invalid bearer tokens are rejected, API and Clerk-webhook mutations
  receive a retryable 503 denial, and identity/application mutation counts
  remain zero;
- Workers.dev and preview URLs are disabled; and
- the exact production Clerk instance and PlanetScale branch are bound.

B must receive no ordinary traffic in A=100%/B=0%. Its bounded lane is selected by
`Cloudflare-Workers-Version-Overrides`, protected by a Cloudflare Access
`service_auth` policy receipt at `api.refwatch.ibby.ai/api/*` with exactly one
service token and zero bypass rules, and independently gated inside the Worker
by `X-RefWatch-Cutover-Token` backed by the server-only
`CUTOVER_ACCEPTANCE_TOKEN` secret. The token is never placed in iOS
configuration or evidence; missing/invalid values return 403. The Access
application, policy, and service-token IDs must each be sanitized Cloudflare
provider IDs: either 32 hexadecimal characters or a canonical UUID.

The bounded `acceptance.checks.webhook_lifecycle` receipt is a manually signed
create/update/delete/retry/delete-wins lifecycle with
`delivery_source=manual_signed_harness`, endpoint `/webhooks/clerk`, exact
header names `Cloudflare-Workers-Version-Overrides` and
`X-RefWatch-Cutover-Token`, both header-presence booleans true, and both
valid-signature acceptance and invalid-signature rejection passed. It proves
the bounded Worker path, not delivery from the Clerk provider.

The activated zero-legacy receipt remains bound to the exact Clerk instance and
database branch. Automated acceptance binds B. Its closure promotes B to 100%
with no competing version on the exact public route/deployment while `/api/*`
Access remains active. The real Clerk endpoint must then deliver without
override or cutover-token headers. The
`traffic_and_writes.promoted_webhook_acceptance` receipt binds exactly
`user.created`, `user.updated`, and `user.deleted`; proves signature,
create/update/delete/retry/delete-wins behavior; and cleans test identities and
application rows back to zero. A provider-bound Access-removal receipt must
follow that provider delivery before the exact deployment-history readback and
every physical-device/Release receipt.
Physical-device and Release evidence then exercises promoted B, not A, G, or L;
production acceptance follows those receipts.

The launch rollback section carries the exact standalone
`greenfield_destructive_v2` packet, its canonical digest, validation timestamp,
window, thresholds, G/L probes, distributable client contract, and destructive
recovery sequence. Launch validation calls the standalone rollback validator;
it does not duplicate or weaken that contract. G and L each require an exact
provider deployment receipt with a canonical readback digest before and after
the operational probe while that same fallback remains at 100% with no
competitor. Health/readiness must report the probed version, and disabled API/
webhook denial must preserve zero mutations. Only after each fallback's after-
readback may A=100%/B=0% be restored and recorded in a separate proof. Both
bracketed probes must lie strictly inside the rollback window and complete by
validation time; G's after-readback must be strictly earlier than L's before-
readback. G/L use the same exact production route and distinct deployment IDs,
probe receipt IDs, and provider receipt IDs. Launch validation also binds their
shared route ID to the initial A route and waits for each same-deployment after-
readback and separate restoration. Receipt kinds and IDs must be unique. The stateful profile and
`greenfield_destructive_v1` remain accepted for historical compatibility.

## Intended deployment chronology

1. Activate and observe the exact zero-legacy receipt only after the clean
   target and exact Clerk readbacks.
2. Install only newly required/changed secrets—at least webhook signing and
   cutover acceptance—with non-echoing `wrangler versions secret put` stdin.
   Let final source version S preserve unchanged existing bindings; do not
   recover or rotate the deferred ledger key. Then upload A followed
   sequentially by B. Carry the digest-checked provider-history/operator
   `worker.secret_lineage` plus sanitized A/B name/type readbacks. Bound S by
   exact ID/time, required-name operator confirmation, documented preservation,
   and provider history; no secret value enters arguments, evidence, or iOS.
3. Pin pairwise-distinct G/L and the exact S/A/B/G/L chronology.
4. Temporarily deploy G at 100% with no competitor. Capture canonical G-before,
   run its exact-version health/readiness and retryable-denial/no-mutation
   probe, then capture G-after while that same deployment remains active. Only
   then restore A=100%/B=0% and capture a separate restoration proof. The proof
   must be inside the rollback window and complete by validation time.
5. After G restoration, repeat the exact sequence for L: L=100%, L-before,
   probe, L-after, then a separate A=100%/B=0% restoration proof. Use the same
   route, distinct deployment/probe/provider receipt IDs, and require G-after
   strictly before L-before.
6. Publicly route A=100%/B=0%; prove exact A health/readiness, auth rejection,
   retryable API/webhook denial, zero mutation, and disabled
   Workers.dev/preview exposure.
7. Validate the exact nested standalone `greenfield_destructive_v2` packet and
   digest, including window, thresholds, G/L probes, client, and destructive
   reset/reseed/recreate instructions.
8. Create the exact Cloudflare Access `service_auth` policy receipt for
   `api.refwatch.ibby.ai/api/*` with one service token and zero bypass rules.
   Keep ordinary deployment A=100%/B=0% while the version-override header plus
   Access and Worker token gates select B only for bounded automated acceptance.
   Exercise `acceptance.checks.webhook_lifecycle` with
   `manual_signed_harness`, both exact header names/presence flags, and valid/
   invalid signature outcomes; do not call this provider delivery.
9. After the complete bounded matrix passes on B, promote B to 100% with no
   competing version and close the override lane while `/api/*` Access remains
   active. Collect real Clerk-provider webhook acceptance without override/
   token headers for the exact three subscriptions, full signed lifecycle/
   retry/delete-wins behavior, and cleanup to zero test rows.
10. Remove Access only after that provider receipt; capture the provider-bound
    removal receipt and then the exact deployment-history readback.
11. Exercise promoted B with the iPhone 15 Pro Max, Apple Watch Series 9
    (45mm), and production Release configuration.
12. Record production acceptance only after those device/release receipts,
    then complete the monitored observation window.
13. After observation and before rollback-window expiry, capture the final
    production readback proving no active ledger epoch and zero Queue, cron,
    D1, or other consumers.

The ordinary pre-promotion deployment must be A=100%/B=0%; B is uploaded and
held at zero ordinary traffic, not described as simply unrouted. Any
unprotected B access, a bounded webhook mislabeled as provider delivery,
premature promotion, competitor at B promotion, Access removal before promoted
provider-webhook acceptance/zero-count cleanup, Workers.dev/preview exposure,
device evidence before the Access-removal/history sequence, or production
acceptance before device/release evidence is rejected.

## Verification

- Current focused launch/rollback/CLI validators: 108/108 pass across 3 files.
- Full unit suite: 19 files, 268/268 pass.
- `npm run typecheck`, Node syntax checks, and
  `wrangler types --env production --check`: pass.
- `npm run test:db`: 3 files, 22/22 pass.
- `npm run test:local:routes`: 1 file, 19/19 pass.
- Production dry-run: pass at 1534.42 KiB, gzip 276.99 KiB.
- Mutation coverage: 36 schema tables, 23 captured tables, 13 explicit
  exclusions, five application writers, and two control-plane writers.
- Gitleaks 8.30.1: exact 83 current modified/untracked files, fully redacted,
  `.projects` excluded and uninspected; pass.
- Scoped `git diff --check`: pass after documentation reconciliation.

## Mandatory review status

Closed on 2026-07-20 after every finding was applied:

- `/root/v2_code_risk_review`: final `NO FINDINGS`.
- `/root/v2_docs_review`: final `NO FINDINGS`.

The closure covers the local immutable-version/rollback/acceptance contract
only. It does not claim a provider deployment, route mutation, production
identity activation, authenticated acceptance, or physical-device result.

## 2026-07-21 preparation continuation

The database/identity prerequisites have since closed at active migration
`0017`/18 with 36 tables and 383 columns. The separate preparation artifact
`2026-07-21-production-greenfield-worker-lineage-preparation.md` records a new
read-only Cloudflare preflight and the pending fail-closed one-shot helper. At
that checkpoint, L remains
`e966d6df-b5ff-4288-832c-c8d91e00ce48`; no production S/A/B/G version has been
created, and no provider mutation or current Clerk-user-count claim is made.
The operational-order wording above is clarified so each G/L after-readback
unambiguously hashes the same 100% fallback deployment as its before-readback;
the A restoration is a later, separate proof.

## 2026-07-21 v3 supersession

The later source-only continuation supersedes active closeout with
`greenfield_launch_v3` and `greenfield_destructive_v3`. Production uses the
exact `api.refwatch.ibby.ai` Cloudflare Custom Domain, so v3 binds that edge
resource through A, bounded B, B100, G/L fallback, and rollback proof while
requiring zero conflicting zone routes and no manual DNS origin. The v2
contract and its review closure above remain truthful historical evidence, but
v2 is no longer accepted for active launch closeout. The v3 continuation has
its own review and execution gates and claims no provider mutation.
