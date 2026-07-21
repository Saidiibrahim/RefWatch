# Production greenfield Clerk and Worker same-process cutover preparation

Date: 2026-07-21 (Australia/Adelaide)

## Status and scope

This is a pre-execution preparation artifact for the fail-closed production
Clerk lifecycle endpoint, Worker S/A/B/G/L lineage, and their same-process
cutover broker. It records the target contract, the locally verified staged
implementation, and a sanitized read-only provider preflight. The reviewed
provider-guard and bounded continuation wiring, mandatory review closures, and
production execution are still pending at this checkpoint.

No production Worker version, secret, deployment, route, custom domain, DNS
record, traffic allocation, Clerk resource, PlanetScale row, write/onboarding
mode, Queue/cron consumer, or mutation-ledger state was changed by this
implementation/documentation batch. No live Clerk lifecycle endpoint or S, A,
B, or G production Worker version has been created. Secret values were not
read, printed, persisted, or passed as command arguments.

## Closed database and identity prerequisites

The database and identity prerequisites are already closed separately:

- the logical PlanetScale database resource is `refwatch`, on branch `main`
  (`w3g1f8vcbg34`);
- authoritative SQL and Hyperdrive use the physical PostgreSQL catalog and
  `current_database()` value `postgres`, plus runtime marker
  `refwatch:production:w3g1f8vcbg34`;
- production is at exact migration `0017` with 18 migration rows, 36 public
  tables, and 383 public columns;
- the exact 5-competition/54-team deterministic seed remains present;
- one immutable `greenfield_zero_legacy_v1` receipt and activation are present,
  while the other 25 target categories remain zero; and
- the production mutation ledger remains inactive.

The immutable activation receipt remains a historical 0016/17-migration
snapshot. It is not a claim that the active catalog is still at 0016. Migration
0017 convergence and both of its mandatory post-execution reviews are closed
with final exact `NO FINDINGS`.

The database activation helper does not verify Clerk's live user count. The
staged Clerk preparation helper separately requires official-tooling zero-user
readbacks from exact production instance
`ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, but no provider execution or current count is
claimed by this artifact. Native application configuration and OAuth providers
remain separate later operations.

## Sanitized Cloudflare preflight

Read-only Cloudflare observations completed through
`2026-07-21T05:21:57.843Z`:

- account `b08d54b822741dbf8e864503b50604a1`, zone
  `955d108e63b6a9743e0e74206e2dbe09`, Worker `refwatch-api`;
- deployment `89cff719-0e19-4648-ab09-63a37d806c95` still assigns 100% to
  last-known-good version L
  `e966d6df-b5ff-4288-832c-c8d91e00ce48`;
- no version newer than L was present, so no production S, A, B, or G exists;
- L remains write-disabled and onboarding-disabled on the old read-only
  Hyperdrive `5345de83edfa40b790d5b26df32f56ab`, role
  `vaqg84rqoedz`, with the correct Clerk instance/issuer and script ETag
  `c7fe13feeaec6962e56ee072a7479b1ea022b21ded00bf2d21a04d4d5477ccc4`;
- the prepared write-capable Hyperdrive is
  `920ca5b108034b2bb8700cf0201ac55f`, role `hvk7iheytj62`, physical catalog
  `postgres`, TLS required, cache disabled, connection limit 10;
- Workers.dev and preview URLs remain disabled; no production route, custom
  domain, DNS record for `api.refwatch.ibby.ai`, cron schedule, or Queue
  consumer was observed; and
- the current secret-name inventory is exactly
  `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`,
  `MUTATION_LEDGER_ENCRYPTION_KEY`, and `OPENAI_API_KEY`.
  `CLERK_WEBHOOK_SIGNING_SECRET` and `CUTOVER_ACCEPTANCE_TOKEN` are not yet in
  that inventory. This is a names-only observation and says nothing about
  secret values or whether a Clerk endpoint exists.

L's sanitized readback SHA-256 is
`f6df7b7f655c45b174c2b413c6312eb897f3edc1f00133bb7a59f2b60696944e`;
its stable readable/non-secret binding SHA-256 is
`35256efb4865cdafa470b08bc505360f1ac0837c7b5711991cc5fac08524e9b7`.
Those values describe the old read-only L path; they are not candidate A/B
binding receipts.

## Fail-closed same-process implementation

The staged local implementation is split across:

- `api/scripts/prepare-production-clerk-webhook.mjs`, which prepares or accepts
  only one exact disabled Clerk endpoint and returns its signing secret to a
  callback as a Buffer;
- `api/scripts/prepare-production-greenfield-worker-lineage.mjs`, which exposes
  Worker mutation only through a callback-scoped, one-shot lease; and
- `api/scripts/execute-production-greenfield-cutover.mjs`, the outer broker for
  this Clerk/Worker lane and the only component in this lane permitted to
  request both nested operations in the same process.

The three package-level source checks are:

```sh
cd api
npm run clerk:webhook:production:check
npm run worker:lineage:production:check
npm run cutover:production:check
```

Each `--check` path is source-only and non-mutating: it must not call a provider,
read secret input, inspect secret values, create a Clerk endpoint, or create a
Worker version. Standalone `--execute` on either nested helper fails closed, and
there is no executable Clerk or lineage package script. For this Clerk/Worker
lane, the only package command that supplies explicit `--execute` is:

```sh
REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER=1 npm run cutover:production
```

The outer technical gate must equal `1`. The broker supplies the narrower Clerk
and lineage technical gates only inside its process; setting those nested gates
does not authorize or unlock standalone execution. The current outer CLI also
deliberately fails before provider work because its reviewed
`recheckProviderGuards` and `continueCutover` callbacks are not yet wired. Local
verification is complete below, but this package command must not run until
those callbacks are complete and both mandatory pre-execution reviews close.

### Exact disabled Clerk endpoint

The staged Clerk helper pins application `refwatch`, application ID
`app_3GWFGTs5EGNXyzQ4idk7p6JdsUP`, production instance
`ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, and exactly this endpoint:

| Field | Required value |
| --- | --- |
| UID | `refwatch-production-clerk-lifecycle-v1` |
| Description | `RefWatch production Clerk lifecycle` |
| URL | `https://api.refwatch.ibby.ai/webhooks/clerk` |
| Events | `user.created`, `user.updated`, `user.deleted` |
| State | disabled |
| Custom headers | zero |
| Transformation | absent/disabled |

It fail-closes unless the full endpoint inventory is either empty or contains
only that exact idempotent endpoint. It does not update, rotate, delete, or
accept an unrelated endpoint. It requires exact zero-user readbacks before and
after reconciliation, verifies the endpoint behavior, emits one sanitized
receipt, and makes the signing secret available only to its in-process callback
as a Buffer. This describes the local contract, not a live endpoint or current
Clerk count.

### Memory-only broker custody

The broker generates a 256-bit random acceptance token directly into a
lowercase-hex Buffer and carries it with the Clerk signing-secret Buffer into
the leased lineage executor. Neither value may enter argv, an environment
variable, a file, a sanitized receipt, or evidence. Both remain available in
the same process through the sanitized post-lineage review checkpoint, exact
review quorum, source recheck, fresh provider guard, and bounded continuation;
they are wiped on completion, error, or signal.

The checkpoint requires exactly two later reviews of its canonical digest:
`code_operational_risk` and `docs_evidence_consistency`, each with exact verdict
`NO FINDINGS` and a timestamp after the checkpoint. After those reviews, the
provider guard must still observe the same exact disabled zero-user Clerk
endpoint, unchanged 100% L deployment, exact six Worker secret names, and zero
route or Access mutations. Process loss after lineage is non-resumable because
the acceptance token is intentionally not provider-readable; recovery requires
a separately reviewed re-lineage with a new token.

### Worker lineage contract

The staged implementation reuses the checked-in production constants and
sanitizers from
`greenfield-launch-packet.mjs` and the current migration/activation contract
rather than copying target IDs, modes, bindings, or receipt schemas. Its source
contract digest-checks the governing Worker/configuration/imported sources and
package-script declarations so `--check` fails on source drift. The reciprocal
broker/lineage source pin normalizes only the reviewed lineage manifest-metadata
block rather than claiming an impossible self-hash.

Every Cloudflare mutation is bounded by exact pre/post version-history and
deployment readbacks. Any timeout, malformed provider response,
unexpected version/deployment delta, concurrent actor, binding drift, secret-
name drift, or source drift fails generically. Because Worker version creation
is not transactional, a partial provider outcome must not be blindly retried;
first reconcile the exact sanitized provider history and deployment state.

### Exact command targeting

- Direct reads and secret writes target `--name refwatch-api` with no
  `--env`. This avoids Wrangler's legacy `refwatch-api-production` name
  expansion.
- Secret bytes use only stdin with `wrangler versions secret put`; they never
  enter argv, environment variables, files, logs, receipts, or evidence.
- Config-driven uploads use `wrangler versions upload --env production` with no
  `--name`, plus `--env-file /dev/null`, `--strict`,
  `--no-experimental-provision`, and `--no-experimental-auto-create`.
- Every command sets `WRANGLER_WRITE_LOGS=0`,
  `WRANGLER_LOG_SANITIZE=true`, `WRANGLER_SEND_METRICS=false`, and
  `NO_COLOR=1`.
- Uploads never use `--keep-vars`, `--secrets-file`, preview aliases, secret
  overrides, or generic `wrangler deploy`.

The two direct secret operations use these exact names/tags/messages, with the
corresponding secret bytes on stdin only:

| Secret name | Tag | Message |
| --- | --- | --- |
| `CLERK_WEBHOOK_SIGNING_SECRET` | `greenfield-webhook-secret-source` | `Install RefWatch production Clerk webhook signing secret` |
| `CUTOVER_ACCEPTANCE_TOKEN` | `greenfield-cutover-secret-source` | `Install RefWatch production cutover acceptance token` |

The three config-driven uploads use the common flags above and these exact
stage values/tags/messages:

| Version | `WRITE_MODE` | `NEW_USER_ONBOARDING_MODE` | Tag | Message |
| --- | --- | --- | --- | --- |
| A | `disabled` | `disabled` | `greenfield-disabled-a` | `RefWatch greenfield disabled candidate A` |
| B | `enabled` | `greenfield_bootstrap` | `greenfield-accepted-b` | `RefWatch greenfield accepted candidate B` |
| G | `disabled` | `disabled` | `greenfield-write-guard-g` | `RefWatch greenfield write guard G` |

The exact allowed secret-name set on sanitized A/B readback is:

- `CLERK_PUBLISHABLE_KEY`;
- `CLERK_SECRET_KEY`;
- `CLERK_WEBHOOK_SIGNING_SECRET`;
- `CUTOVER_ACCEPTANCE_TOKEN`;
- `MUTATION_LEDGER_ENCRYPTION_KEY`; and
- `OPENAI_API_KEY`.

Only the two newly required names are installed. Each expected secret mutation
must have its own exact one-version history delta: the first produces one
intermediate secret-source version and the second produces final S. Existing
secret bindings,
including the inaccessible historical ledger-key binding, are inherited without
requesting or rotating their values. The exact creation order is intermediate
secret-source→S→A→B→G while existing L is read unchanged. Source S is the
final secret-source version after the first two mutations; A, B, and G are the
three subsequent config-driven uploads. A uses
`WRITE_MODE=disabled` and `NEW_USER_ONBOARDING_MODE=disabled`; B uses
`WRITE_MODE=enabled` and
`NEW_USER_ONBOARDING_MODE=greenfield_bootstrap`; G returns both modes to
`disabled`. S, A, B, G, and L must be pairwise distinct. A/B must share the
exact script ETag and normalized stable readable/non-secret binding hash.

The helper therefore creates exactly five new versions total: one intermediate
secret-source version, S, A, B, and G, with zero unexpected versions. It reads
the existing immutable L; it does not create a deployment,
assign traffic, create a route or Access policy, probe a public endpoint, enable
writes/onboarding for ordinary traffic, mutate Clerk, or activate the mutation
ledger. It emits at most one canonical sanitized JSON receipt after validating
the entire sequence. Execution and receipt fields remain pending until
mandatory reviews close and the helper is run.

## Completed local verification checkpoint

The final review remediation adds a post-secret singleton endpoint/core/header/
transformation reread, binds that state into the Clerk receipt and broker guard,
parses the bounded signing-secret response directly from mutable bytes, and
extends the child-runner failure and zeroization matrix. The pinned 80-file
source-manifest SHA-256 is
`9e78d824ce63696b881969e703b5e5098848894ca6f97345b32480fa379177b3`;
the normalized lineage-helper SHA-256 is
`ba90f2217dd7fe6cbfed6573bc14ce35f1a08dd1cc8043d20eef5eb077047476`;
the lineage declaration SHA-256 is
`760f6956b94d3a74960861e6214c7534c4a864410f20f853b34e9b10d955c47f`.

The implementation batch completed this non-provider verification checkpoint:

| Check | Result |
| --- | --- |
| Focused Clerk/lineage/broker tests | 131/131 passed |
| Full `npm test` | 427/427 passed across 24 files |
| `npm run test:db` | 43/43 passed: 23 current-schema + 9 exact-0016 activation + 11 migration-0017 |
| Mounted routes | 19/19 passed |
| Typecheck | passed |
| `clerk:webhook:production:check` | passed, source-only |
| `worker:lineage:production:check` | passed, source-only |
| `cutover:production:check` | passed, source-only |
| Production Wrangler dry-run | passed |
| Wrangler generated-types check | passed |
| Mutation-coverage check | passed |
| Fully redacted credential scan | passed across the exact 43-file batch; `.projects` excluded and uninspected |
| `git diff --check` | passed |

These results prove the local source and harness contract only. They do not
prove a live Clerk count or endpoint, a Cloudflare version/secret/deployment,
routing, traffic, write/onboarding enablement, authenticated acceptance, or
physical-device behavior. Any later source or documentation edit requires the
affected checks to be rerun before provider execution.

## G/L operational proof order

The later rollback proof must use this exact order for G:

1. deploy G at 100% with no competitor;
2. read back that same G deployment as the canonical G-before receipt;
3. run the exact-version health/readiness and disabled-denial/no-mutation probe;
4. read back the same still-active G deployment as the canonical G-after
   receipt;
5. restore A=100%/B=0% and record a separate restoration proof.

Only after G restoration is independently proved may the exact sequence repeat
for L. L-before must be strictly later than G-after. L also receives its own
same-deployment before/probe/after triplet before a separate A=100%/B=0%
restoration proof. The final public disabled proof is collected only after both
restorations. Neither fallback after-readback may hash the restored A
deployment.

## Gates before production cutover execution

Before running the outer broker:

1. the reviewed live provider-guard and bounded acceptance/route continuation
   callbacks must be wired so the sole outer execution surface is complete;
2. the completed local checkpoint above must remain green, with every affected
   check rerun after any source or documentation change;
3. exact live PlanetScale schema/seed/clean/ledger state, the exact production
   Clerk instance and zero-user count, and Worker/version/deployment/route/
   binding/secret-name/inactive-consumer state must be refreshed;
4. an independent code/operational-risk reviewer and an independent
   docs/evidence-consistency reviewer must each return final exact
   `NO FINDINGS`; and
5. no provider execution may occur while either initial review remains open.

After the endpoint and lineage are prepared, the same still-running process
must pause on the sanitized checkpoint for the separate exact review quorum,
then recheck source and provider guards before any route or acceptance work.

Production execution, its sanitized provider receipt, and the post-execution
review round are deliberately not claimed here.

## Post-review continuation checkpoint — handoff only

After the reviewed preparation checkpoint above closed, a separate local-only
continuation changed the active immutable launch and destructive profiles to
`greenfield_launch_v3` and `greenfield_destructive_v3`. The v3 contract binds
the exact Cloudflare Custom Domain through A, bounded B, B100, G/L fallback,
and rollback proofs; the route-based v2 validators remain historical-only. The
same continuation added a callback-scoped Clerk endpoint controller and a
fail-closed provider-guard reader. The provider guard still requires a trusted
bounded Cloudflare audit-evidence reader and live CLI output-shape fixtures, and
it is not yet wired into the broker's default continuation callbacks.

The resulting 80-file Worker source manifest is
`dedf2578b002865aa05486cf6fd329714140563235d97b5c8ddf1c3248b5aa36`.
The three source-only checks pass, full `npm test` passes 455/455 across 25
files, typecheck passes, the fully redacted changed/untracked-file Gitleaks scan
passes with `.projects` excluded and uninspected, and `git diff --check` passes.
The new provider-guard files are locally tested but are not part of the 80-file
executable source manifest until the broker imports and uses them.

This continuation made no provider mutation. The earlier final exact
`NO FINDINGS` reviews cover only the preparation checkpoint above; they do not
cover this later v3/controller/provider-guard delta. Both mandatory independent
reviews, every remediation, and final exact `NO FINDINGS` must be completed for
this delta before any production execution.
