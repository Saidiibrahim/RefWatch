# Production Cutover State Reconciliation

Date: 2026-07-17 (Australia/Adelaide)

## Current authoritative state

- Action 1's bounded foundation scope is applied and consumed: all 16
  migrations, exact 5/54 global seed, restricted roles, cache-disabled
  Hyperdrive, inactive Queue/DLQ/D1 resources, production secret names, and the
  unrouted write-disabled Worker exist. The Worker ledger-secret value is
  non-readable. The named local Keychain record exists but its 2026-07-17 audit
  found an empty payload, so recoverable key custody is not proved.
- The old `auth.refwatch.com` Action 2 domain scope remains retired
  unexercised.
- The separately authorized `refwatch.ibby.ai` domain/key/issuer batch is
  applied and consumed. Its five DNS-only CNAMEs, DNS, SSL, email DNS, Worker
  publishable-key refresh, and issuer coordination must not be repeated.
- Production remains unrouted with onboarding and writes disabled. No final
  source export, identity/data import, mapping activation, public traffic,
  production ledger activation, or user mutation has occurred.

Historical evidence that names Worker `3096a8cc-bec6-4be1-9943-dddd34d36b00`,
issuer `https://clerk.auth.refwatch.com`, or says Action 1 is not consumed is a
preserved point-in-time statement. It is superseded for current status by
`2026-07-17-production-clerk-domain.md`, the active plan, and this
reconciliation.

## Remaining approval matrix

| Gate | Prerequisite | Required authorization/evidence |
| --- | --- | --- |
| Recoverable production ledger-key source | Exact existing key in approved custody, or reviewed provider-state audit before remediation/rotation | New exact recovery/remediation authorization; current Keychain payload is empty and the Worker secret is non-readable |
| Cloudflare Secrets Store escrow copy | Valid non-empty source; approved store/permission metadata | Target selected and permissions verified, but no secret was created; later receipt must prove stored metadata without claiming value readability |
| Functional ledger-key recovery | Stored escrow plus reviewed binding/recovery-service procedure | Separate binding/use approval and non-disclosing equality/recovery receipt; `workers` scope alone is not a binding |
| Functional production ledger activation/probe | Recovery proof complete; reviewed bounded probe | Separate activation/probe approval and provider receipt |
| Native Clerk registration and iOS public config | Authoritative Apple App ID Prefix, signed Bundle ID, reviewed redirect URL, appropriate local/release config | Separate native-lane approval; do not infer identifiers or create a secret-bearing file |
| Production Google OAuth | Exact Google Cloud project/client contract and custodied credentials | Separate OAuth approval; use installed `gcloud` for Google Cloud/API work and `gws` only for Workspace operations; never output credentials |
| Signed Clerk webhook | Exact reachable HTTPS Worker endpoint, event allowlist, secure secret path, write-disabled non-mutating probe | Separate endpoint/secret/probe approval; only `user.created`, `user.updated`, and `user.deleted` |
| Final Supabase snapshot/export and approved auth-only exclusion confirmation | Quiescence, direct encrypted exporter, provider/ledger receipts | Exact final-export approval; no generic MCP full-row transport |
| Clerk identity plus application-data import/reconciliation | Validated encrypted bundle and reviewed 42-user subject map | Separate identity/data approvals and complete count/ownership/reference receipts |
| Rollback packet and provider-routed authenticated matrix | Escrow/ledger proof, verified versions, distributable recovery client, migrated identities/data | Exact guard/routing/probe approvals; local matrix is insufficient |
| Physical-device acceptance | Authenticated production path and migrated data ready | iPhone 15 Pro Max and Apple Watch Series 9 available; acceptance phase approved |
| Traffic, onboarding, and writes | Every earlier gate satisfied | Separate explicit approvals for traffic, onboarding, and write enablement |

The later native Clerk lane must also reconcile the callback scheme used by the
pinned ClerkKit version with the signed app's registered URL scheme. This is a
recorded blocker only; no identifier/config resolution or Clerk action was
started in this batch.

## Local process update

The installed Google CLIs were checked without contacting or mutating a Google
API: `gws 0.3.3` and Google Cloud SDK `574.0.0` are available. Future approved
Google work must use those CLIs as directed above and keep credentials out of
command output, evidence, and chat.

## Ledger-key escrow preflight correction

The operator selected Cloudflare Secrets Store and authorized a non-disclosing
copy with no binding, deployment, rotation, ledger activation, or writes.
Wrangler authenticated to the expected account, reported Secrets Store write
permission, and listed the existing default store. Fail-closed source
validation then found that the CLI emitted only its newline delimiter and zero
recovered characters after trimming, not the required 32-byte Base64 key. The
proposed Secrets Store target was absent before and after the check. No secret
was created and no retry is authorized. See
`2026-07-17-production-ledger-key-escrow-audit.md`.

## Batch boundary

This reconciliation changed repository code/docs/tests and used authenticated
Wrangler only for the approved Cloudflare Secrets Store account/store/permission
metadata readback. It did not inspect or edit `.projects`, change
Clerk/DNS/certificates, create or modify a secret/binding, rotate keys, deploy a
Worker, mutate PlanetScale/Supabase/Google, create users, activate a
ledger/mapping, add traffic, or enable onboarding/writes.

## Review disposition

- The mandatory code-risk review narrowed the disabled webhook probe to
  routing/write-denial evidence, aligned the gated iOS configuration language,
  bounded the local delete claim, and removed immediate production
  native/OAuth/webhook/provisioning instructions from the top-level quick start.
  All findings were applied.
- The mandatory docs/evidence review separated the applied/consumed Action 1
  foundation from the pending escrow/functional-ledger gate, classified the
  2026-07-15 provider result as historical and not rerun after current route
  changes, corrected the live-Clerk/managed-metadata distinction, and recorded
  the local PostgreSQL prerequisite. All findings were applied.
- Current executable proof for this batch is exactly 93/93 unit tests plus 4/4
  hermetic local cases. No provider test or provider mutation was performed;
  the later Cloudflare interaction was metadata-only authenticated readback.
- The final ledger-key escrow reviews found no high-severity boundary breach.
  Their consistency findings were applied: metadata-only Cloudflare readback is
  acknowledged, the one recovery-path decision is aligned across operator
  pages, and successful payload inspection is distinguished from the failed
  source precondition. No escrow write or other provider mutation occurred.

## 2026-07-20 Greenfield supersession

This section is append-only. The 2026-07-17 body above remains point-in-time
truth for the stateful migration plan and operations completed on that date.
The later operator decision in
`2026-07-20-greenfield-cutover-authorization.md` supersedes its approval and
preservation gates for the active launch:

- RefWatch is a greenfield production launch with no real production users,
  active writers, or irreplaceable data.
- The historical 43 Supabase Auth users, 42 public profiles, 1,106 application
  rows, `testing@refwatch.com`, and existing target test state are disposable.
- No final Supabase export, auth-only exclusion confirmation, 42-user
  UUID-to-Clerk mapping, identity import, application-row import, or
  source/target row reconciliation is required.
- The target clean-state claim means zero `app_users`, zero legacy mappings, and
  zero user-owned application rows. It does not mean absent schema/control rows
  or absent deterministic global reference data. The complete required seed
  must come from reviewed repository sources and be evidenced separately.
- Ledger escrow, recovery proof, and production activation are deferred and
  non-blocking. The failed 2026-07-17 escrow audit remains unchanged. Existing
  ledger resources may remain inert or be reviewed for later cleanup; launch
  requires no active capture-enforced epoch, cron, or Queue consumer.
- Stop/guard/reset/reseed/recreate is the accepted initial recovery model.
- All previously gated provider/cutover operations are authorized in their
  ordered phases. Authorization is not execution, and each transition still
  requires sanitized evidence plus no-findings confirmation from both mandatory
  review roles.
- Secret values remain non-disclosing. Commits and publishing remain outside
  scope. The completed `refwatch.ibby.ai` domain/DNS/certificate/key lane must
  not be repeated without a diagnosed requirement.

Accordingly, the “Remaining approval matrix” above is historical and has zero
pending approval decisions for the active greenfield launch. Its operational
prerequisites and security boundaries still apply where they protect the
ordered cutover. Physical iPhone 15 Pro Max and Apple Watch Series 9 (45mm)
availability may still block physical acceptance and final traffic cutover, but
does not block other safe preparation.
