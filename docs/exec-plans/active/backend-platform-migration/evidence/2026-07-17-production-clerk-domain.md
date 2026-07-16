# Production Clerk Domain Replacement

Date: 2026-07-17 (Australia/Adelaide)

## Scope

Replace the invalid, unowned `auth.refwatch.com` production Clerk domain with
the operator-selected owned secondary application domain `refwatch.ibby.ai`.
No identity, application-data, traffic-route, onboarding-mode, or write-mode
mutation was authorized or performed.

## Clerk

- Production instance: `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`.
- `POST /v1/instance/change_domain` returned `202` for
  `https://refwatch.ibby.ai` with `is_secondary=true`.
- Sanitized readback returned domain `dmn_3GbJi4EHhbqVbWMFyzcpq603KzD`,
  Frontend API `https://clerk.refwatch.ibby.ai`, and Account Portal
  `https://accounts.refwatch.ibby.ai`.
- The regenerated `pk_live_` publishable key was derived from Clerk's verified
  public-key host encoding and installed without printing its value. The
  production secret key was neither printed nor rotated.

## Cloudflare DNS

The active `ibby.ai` zone received exactly five CNAME records, all with
`proxied=false` and Cloudflare automatic TTL:

| Host | Target | Cloudflare record ID |
| --- | --- | --- |
| `clerk.refwatch.ibby.ai` | `frontend-api.clerk.services` | `d04c2c27f791a54131f4ad482d6b409e` |
| `accounts.refwatch.ibby.ai` | `accounts.clerk.services` | `f96032eb727e0d1ff8b42b0e98a94dff` |
| `clkmail.refwatch.ibby.ai` | `mail.5510u3rpvrex.clerk.services` | `a07cf510308a475e4ec53cbaa06ca44f` |
| `clk._domainkey.refwatch.ibby.ai` | `dkim1.5510u3rpvrex.clerk.services` | `76315a8574818e2d07381a8084796df3` |
| `clk2._domainkey.refwatch.ibby.ai` | `dkim2.5510u3rpvrex.clerk.services` | `fa1eb6d8d9cf3dc93f480b86ce20e013` |

Cloudflare API readback and public `1.1.1.1` CNAME resolution matched all five
targets. Clerk CLI verification subsequently reported DNS and email DNS
complete with no pending DNS records.

The authenticated `cf` CLI held `dns_records:edit` and performed the bounded
record creation. Refreshed Wrangler OAuth had zone-read but not DNS-edit access;
use `cf` for any future separately approved Cloudflare DNS work. The temporary
managed-credential staging directory `/tmp/refwatch-clerk-domain-op` was deleted
after completion.

## Worker coordination

- `CLERK_PUBLISHABLE_KEY` was replaced through non-echoing Wrangler stdin.
- `CLERK_ISSUER` is now `https://clerk.refwatch.ibby.ai`.
- Production Worker version `e966d6df-b5ff-4288-832c-c8d91e00ce48` deployed
  with `WRITE_MODE=disabled`, `NEW_USER_ONBOARDING_MODE=disabled`,
  `workers_dev=false`, and `preview_urls=false`.

## Remaining gates

Final Clerk CLI verification reported DNS, SSL, and email DNS complete with
zero pending DNS records. HTTPS probes returned a valid certificate and
`200` from the Frontend API JWKS endpoint. Clerk's overall deploy remains
`oauth_pending` only because Google production OAuth credentials are not yet
configured. Native iOS registration, the signed lifecycle webhook, iOS public
configuration, identity migration, public routing, onboarding, and writes
remain separate gates.

## Managed-service metadata caveat

Stripe Projects resource `clerk-auth-2` may continue to display historical
`production_domain: auth.refwatch.com`. Live Clerk Backend API and official
Clerk CLI readbacks are authoritative for the completed `refwatch.ibby.ai`
domain. Do not recreate, remove, or rotate the managed resource merely to align
that stale metadata without a separate investigation and approval.
