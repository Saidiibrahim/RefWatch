# Provider Refresh and Clerk Production Provisioning — 2026-07-15

> **Superseded operating instructions:** This is point-in-time evidence from
> before the operator confirmed that `refwatch.com` is not owned. Do not apply
> the `auth.refwatch.com` DNS records or use the bundle ID shown below; that
> bundle ID was not authoritatively verified. The current owned-domain decision
> and completed DNS/certificate state are recorded in
> `2026-07-15-production-domain-control.md` and
> `2026-07-17-production-clerk-domain.md`. Native application identifiers must
> still be verified from authoritative Apple configuration before use.

## Scope and Secret Handling

This batch followed the approved production decisions and the repository's
Stripe Projects/Clerk guidance. No `.projects` file or credential value was
inspected or recorded. Stripe Projects managed its own `.env` and vault files;
those files remain uninspected. Clerk production metadata was consumed only in
process, secret-bearing environment blobs were removed before child processes,
and output was restricted to non-secret metadata and Boolean key presence.

## PlanetScale Read-only Refresh

Provider metadata and primary read-only queries confirmed:

- database `refwatch`: ready, Postgres, Sydney;
- production `main`: ready, production branch, 0 public base tables;
- `cutover-rehearsal-20260714`: ready, development branch, 26 public base
  tables, 6 Drizzle migration rows, and 5/54/30/3/20 reference competition,
  reference team, disciplinary code, disciplinary rule, and workout preset
  rows.

The queries used ephemeral read-only PlanetScale credentials. Production
`main` was not mutated. The rehearsal remains non-production evidence.

This readback preceded migrations `0006_nappy_blur.sql` and
`0007_military_sumo.sql` later the same day. It is superseded for current
rehearsal counts by `2026-07-15-post-reconciliation-onboarding.md`, which
records 30 public tables, 10 Drizzle migration rows, all three identity
validation/immutability triggers, empty onboarding-control tables after tests, and unchanged
5/54/30/3/20 reference counts. Production
`main` remains unchanged.

## Stripe Projects Refresh

Sanitized commands:

```sh
stripe projects llm-context
stripe projects status --json
stripe projects catalog Clerk --json
stripe projects services list --json
stripe projects env # values redacted by the CLI
```

Before provisioning, provider/service/plan linkage was complete and the only
service was development-only `clerk-auth` with `app_name: refwatch`. The exact
catalog slug was `Clerk/auth`; its schema accepts `app_name` and optional
`production_domain`.

## Production Provisioning Result

With user-approved configuration, Stripe Projects ran the exact catalog slug
with `app_name: refwatch` and `production_domain: auth.refwatch.com`. Rather
than updating `clerk-auth` in place, it created a second complete managed
resource:

- logical resource: `clerk-auth-2`;
- resource ID: `fres_61V2fgfXbMIWINMVB16TcwSJPC8S1spUXB9QI1HhwDkG`;
- production domain: `auth.refwatch.com`;
- production instance ID: `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`;
- domain ID: `dmn_3GWFGZlb37zxnXD21IbQwfANkMN`;
- production publishable/secret keys: present, values not displayed;
- DNS setup URL: present, value not displayed;
- DNS setup required: true.

The original `clerk-auth` resource remains intact because staging uses its
development instance and deletion/rotation was neither required nor safe.

## Required Clerk DNS

Sanitized Clerk Backend API readback returned the following required CNAMEs:

| Host | Target |
| --- | --- |
| `clerk.auth.refwatch.com` | `frontend-api.clerk.services` |
| `accounts.auth.refwatch.com` | `accounts.clerk.services` |
| `clkmail.auth.refwatch.com` | `mail.901rtps4p5gx.clerk.services` |
| `clk._domainkey.auth.refwatch.com` | `dkim1.901rtps4p5gx.clerk.services` |
| `clk2._domainkey.auth.refwatch.com` | `dkim2.901rtps4p5gx.clerk.services` |

The production Frontend API URL is `https://clerk.auth.refwatch.com`; the
accounts portal is `https://accounts.auth.refwatch.com`. Public DNS readback
did not show the required CNAMEs. Cloudflare records must be DNS-only, not
proxied, for Clerk verification.

## Remaining Clerk Gates

- DNS cannot be applied with the current Wrangler OAuth token: its Cloudflare
  scope includes zone read but not DNS write.
- Clerk dashboard automation is unavailable because the ChatGPT Chrome
  Extension is not reachable in the current Chrome profile. No alternate
  browser controller or OS scripting was used.
- Production native iOS registration still needs the app's Apple App ID prefix
  and bundle ID `com.IbrahimSaidi.RefWatch` confirmed in Clerk.
- DNS verification and production certificate deployment remain pending.
- A production Svix endpoint for the final Worker URL and events
  `user.created`, `user.updated`, and `user.deleted` remains pending. Its
  signing secret must be installed only as `CLERK_WEBHOOK_SIGNING_SECRET` and
  must not be printed or committed.
- The production instance is provisioned, but this is not identity mapping,
  deployment, migration, reconciliation, or production acceptance.
