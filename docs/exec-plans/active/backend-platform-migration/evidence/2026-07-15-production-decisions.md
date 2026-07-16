# Production Decisions — 2026-07-15

## Approval Receipt

At `2026-07-15T01:32:05Z`, the user replied `approve both` to the two explicit
production decisions presented in the active goal:

1. Use `auth.refwatch.com` as the Clerk production domain.
2. For preliminary auth-only `testing@refwatch.com`, record final cutover-bundle
   `action: "exclude"`; create no target Clerk mapping or empty `app_users` row
   or ownership UUID; preserve the source identity through rollback and the
   observation window; and archive it only afterward as a separate source-
   lifecycle operation.

## Supersession Receipt

At `2026-07-15T07:53:43Z`, the user explicitly confirmed that they do not own
`refwatch.com`. Decision 1 is therefore superseded before its DNS scope was
exercised. The old five Clerk CNAMEs must not be applied. A different owned
domain and a new exact Clerk-domain/DNS/publishable-key/issuer approval are
required. Decision 2 is unchanged.

## Scope and Remaining Proof

This historical approval selected only the domain and auth-only disposition
decisions. It authorized no provider mutation. Action 1 was later exercised as
recorded elsewhere; Action 2's domain-specific scope is now retired unexercised.
Identity/data/traffic cutover and write enablement remain later gates. The
decision approval does not prove or complete Clerk production configuration, DNS, native-app
configuration, credentials, webhook setup, the final source snapshot, the
42-user Clerk-subject mapping, the external mutation ledger, production Worker
or Hyperdrive resources, rollback versions, migrations/import, reconciliation,
deployment, authenticated checks, physical-device acceptance, compatibility
cleanup, or observation-window closeout.

Before applying the auth-only disposition, the final repeatable-read Supabase
snapshot must confirm that the exact identity remains the sole auth-only
identity and has no profile or owned data. The immediate validator action is
`exclude`; `archive` is not a cutover disposition and must not occur during
migration or rollback preservation.

## Later Domain Resolution

Superseded by `2026-07-17-production-clerk-domain.md` for the domain lane. The
user separately selected and authorized owned secondary domain
`refwatch.ibby.ai`; its Clerk change-domain operation, exact five DNS-only
CNAMEs, DNS/SSL/email-DNS checks, regenerated Worker publishable key, and issuer
refresh completed on 2026-07-17. The auth-only identity disposition above is
unchanged, and no identity/data/traffic/onboarding/ledger/write scope was added.
