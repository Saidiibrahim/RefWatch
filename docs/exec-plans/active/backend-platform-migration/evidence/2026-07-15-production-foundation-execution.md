# Production foundation execution — 2026-07-15

## Approval boundary

The operator approved the exact two-action packet in root
`MIGRATION_APPROVALS.html`. This execution did not stop Supabase writes, export
or import user/application rows, create or change identities, activate mappings,
enable Worker writes, or add public traffic routes. Migration `0002`'s reviewed
5-competition/54-team global catalog is the only production data exception.

## PlanetScale main

Immediate primary readback confirmed production/default branch `main`
(`w3g1f8vcbg34`) had zero public base tables. The operator-bound migration
manifest and seed hashes were reproduced before execution:

- migrations `0000`–`0015`: `f0ed5af74e5fdde61eb84619c8f3514c647af29634606a8d38e0e3745535172f`
- migration `0002`: `134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b`
- migration `0015`: `6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a`

Drizzle applied all 16 migration rows successfully. Sanitized primary readback
then proved 35 public base tables, 5 reference competitions, 54 reference
teams, 28 non-internal triggers (22 mutation-capture and 6 guard triggers),
four `refwatch_*` functions, zero `app_users`, and zero mutation events.
Temporary migration/readback roles were deleted; migration-owned objects were
reassigned to provider role `postgres` before cleanup.

Durable restricted roles are:

- Worker runtime role ID `vaqg84rqoedz`, inheriting read-all data only for the
  write-disabled foundation. A later approval must provision narrowly scoped
  write privileges before write enablement.
- Independent verifier role ID `pz5z3l81py1y`, inheriting read-all data only.

Primary provider readback confirms both roles are non-superuser, cannot create
roles or databases, cannot replicate, and cannot bypass RLS. Only these two
durable production roles remain; all ephemeral execution roles were removed.

## Cloudflare production resources

- Hyperdrive `5345de83edfa40b790d5b26df32f56ab`, cache disabled, TLS required,
  connection limit 10, bound to the exact runtime role and production branch.
- D1 `6d1a7bbb-ea9d-47b2-ae77-44f992b9e3d2` in Oceania, with all three ledger
  migrations, four immutability triggers, zero events, and zero dead letters.
- Queue `refwatch-mutation-ledger-production` and DLQ
  `refwatch-mutation-ledger-dlq-production`.
- A new 256-bit ledger key was generated only in memory, stored separately in
  the macOS login Keychain under key ID `production-20260715-v1`, and streamed
  to Worker secret `MUTATION_LEDGER_ENCRYPTION_KEY`. No key value entered a
  command argument, file, log, or evidence artifact.

Worker `refwatch-api` version `52d2af57-9770-417d-b696-16cb73827122` initially deployed
with `WRITE_MODE=disabled`, `NEW_USER_ONBOARDING_MODE=disabled`,
`ALLOW_UNMAPPED_CLERK_USERS=false`, `workers_dev=false`, `preview_urls=false`,
and no route. Startup time was 82 ms. Cloudflare's script-subdomain API readback
returned `workers_dev_enabled=false` and `previews_enabled=false`.

## Probes

Because the Worker intentionally has no public or preview URL, the production
config was executed on localhost using a directly injected production runtime
role connection as Hyperdrive's documented local-development substitute, with
the exact production role/marker pins. This proves the production config and
database pin locally; it is not a deployed Worker-to-Hyperdrive request.
Sanitized results:

| Probe | Result |
| --- | --- |
| `/health` | 200, production |
| `/health/ready` | 200, database reachable and identity verified |
| `POST /api/matches` | 503 `writes_temporarily_disabled` |
| `POST /webhooks/clerk` | 503 `writes_temporarily_disabled` |

The deployed configuration and Hyperdrive were separately read back from
Cloudflare's control plane.
The API suite passes 78/78 across 14 files, TypeScript passes, Wrangler type
generation passes, and the production deployment dry-run lists only the
reviewed bindings.

## Remaining foundation work

The original operator objective explicitly identified `OPENAI_API_KEY` in the
root local `.env` as an authorized Worker-secret source. At
`2026-07-15T07:24:28Z`, a fail-closed local parser streamed only that value
directly to `wrangler secret put OPENAI_API_KEY --env production`; it did not
print, log, stage, or copy the value.

Stripe Projects guidance identifies separately prefixed environment bundles for
managed Clerk resources. A first production-key attempt selected the original
development resource variable, failed its domain validation, but Wrangler still
accepted empty stdin and created two empty secret entries. Both entries were
immediately deleted before use and secret-name readback re-confirmed their
absence. The corrected fail-closed implementation parsed only
`CLERK_AUTH_2_ENVIRONMENTS`, validated the exact production domain, DNS-required
flag, and `pk_live_`/`sk_live_` prefixes before spawning Wrangler, and streamed
each key directly over child-process stdin. No key or bundle value was printed,
logged, staged, or passed as an argument.

Production Worker `3096a8cc-bec6-4be1-9943-dddd34d36b00` now binds only the
sanitized secret names `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`,
`OPENAI_API_KEY`, and `MUTATION_LEDGER_ENCRYPTION_KEY`. It also pins production
instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac` and issuer
`https://clerk.auth.refwatch.com`, retains `WRITE_MODE=disabled`,
`NEW_USER_ONBOARDING_MODE=disabled`, the read-only Hyperdrive role, and all
reviewed bindings. Production config/control-plane still disable preview URLs
and workers.dev; deploy output exposed no route. Queue readback still shows zero
production Queue/DLQ consumers. TypeScript, 78/78 tests, generated types, and a
production dry-run passed before deployment.

Action 1 is not yet marked fully consumed because organizational KMS
escrow/recovery and a separately approved functional production ledger
activation/probe remain required before capture/writes. The future Clerk
webhook signing secret does not exist until the approved endpoint is created.
Resource existence, zero-row D1 readback, and immutability triggers are not
claimed as the functional probe.

Provider readback after explicit cleanup shows zero cron schedules and zero
consumers on both the production Queue and DLQ. The primary Queue retains only
the inert Worker producer binding; with no public/preview route, writes disabled,
and no scheduler/consumer, the deployed foundation has no active mutation path.
Both durable PlanetScale roles inherit only `pg_read_all_data`; the superseded
read/write runtime role was deleted.

During initial verifier-role provisioning, the CLI's normal human output
returned that unused credential to the operator transcript. It was treated as
disclosed and deleted immediately before any use. The current verifier role is
a separately created credential whose secret was captured without output.

Action 2 has not started. A controllable isolated Chrome page reaches Clerk's
sign-in screen, but it has no authenticated session; the authenticated-profile
autoconnect path remains unavailable. No sign-in interaction was attempted and
no Clerk user, configuration, DNS record, certificate, native app, OAuth
credential, or webhook was mutated.

## Continuation refresh

At `2026-07-15T07:20:38Z`, a fresh PlanetScale MCP query against the production
primary re-confirmed 35 public base tables, 16 Drizzle migration rows, exactly
5 reference competitions and 54 reference teams, zero application users, zero
mutation outbox events, and zero ledger epochs. A redacted Stripe Projects CLI
refresh still reported the Clerk provider and `clerk-auth-2` service as
`complete` for `auth.refwatch.com`; it exposed no usable production secret
values and did not advance DNS, certificates, native-app registration, or the
webhook. No provider mutation occurred during this refresh.
