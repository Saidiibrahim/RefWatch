# Production foundation approval request — 2026-07-15

`MIGRATION_APPROVALS.html` now requests two bounded preparation actions. The
prior isolated-rehearsal approval is consumed. Neither new action is authorized
until the user pastes its exact approval text into the Codex conversation.

## Action 1 boundary

- Immediately re-read PlanetScale production branch `main`
  (`w3g1f8vcbg34`) and proceed only if it remains empty.
- Apply only PostgreSQL migrations `0000` through `0015`, including the sole
  data exception: migration `0002`'s deterministic global seed of exactly five
  reference competitions and 54 reference teams. Its SHA-256 is
  `134add3ba57288f2b0089791b1a77979ed004ef0a3fe52b1b3a3842376c0d78b`.
- Provision production Hyperdrive, restricted roles, Queue, DLQ, D1 ledger,
  encryption-key custody, and undisclosed Worker secrets.
- Deploy only a no-public-route production Worker with `WRITE_MODE=disabled`
  and onboarding disabled, then run sanitized readiness/write-denial/control
  readbacks.

The migration-manifest digest is SHA-256
`f0ed5af74e5fdde61eb84619c8f3514c647af29634606a8d38e0e3745535172f`.
It is reproducible from the repository root by hashing each sorted
`api/src/db/migrations/*.sql` file with `shasum -a 256`, then hashing that exact
manifest stream with `shasum -a 256`. Migration `0015` remains independently
bound to SHA-256
`6230b4e6f9986142166073c22f7522eca2b4a369d8a4975af6a0b7bbd8d6106a`.

## Action 2 boundary

- Apply only the five Clerk-provided CNAME records for `auth.refwatch.com` and
  verify production certificates.
- Register the native iOS application on existing production resource
  `clerk-auth-2`.
- Enable production email/password, Apple, and Google sign-in with separately
  custodied production OAuth credentials. Do not print, rotate, or revoke the
  source credentials during this action.
- Only after Action 1 proves the Worker is write-disabled, create and probe the
  reviewed signed user-lifecycle webhook.
- Do not create, import, update, merge, or delete a Clerk user.

## Explicitly excluded

Both actions forbid Supabase write-stop/lifecycle changes, final row export or
import, identity mapping activation, every production user/application-data
mutation other than the exact Action 1 global 5/54 reference seed, public API
traffic cutover, and production write enablement. Those require a later packet
bound to the actual final export, mapping, production resource IDs, rollback
versions, and reconciliation evidence.
