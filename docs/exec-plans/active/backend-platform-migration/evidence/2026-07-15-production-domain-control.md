# Production domain control evidence — 2026-07-15

## Scope

Read-only registry, public-DNS, and authenticated Cloudflare-account checks for the approved Clerk production domain `auth.refwatch.com`. No registrar, DNS, Clerk, or Cloudflare resource was mutated.

## Findings

- Verisign RDAP returned `REFWATCH.COM` with registry delegation to:
  - `NS1.DOMAIN-IS-4-SALE-AT-DOMAINMARKET.COM`
  - `NS2.DOMAINMARKET.COM`
- RDAP reported `delegationSigned: false` and no DS records. DNSSEC is therefore not the cause of the failure.
- Google and Cloudflare DNS-over-HTTPS readbacks returned status `2` (`SERVFAIL`) for the apex and the five Clerk hostnames. The failure is zone-wide, not a single missing CNAME.
- A read-only Cloudflare Zones API query using the authenticated Wrangler OAuth session returned no `refwatch.com` zone in account `b08d54b822741dbf8e864503b50604a1`.
- The Clerk Backend API still reports the approved five CNAME targets, but they cannot be validated or receive certificates while authoritative domain control is unresolved.

## Disposition

At `2026-07-15T07:53:43Z`, the operator explicitly confirmed that they do not own `refwatch.com`. This supersedes the earlier assumption that the approved `auth.refwatch.com` domain could be completed.

The `auth.refwatch.com` decision and five-CNAME safe subset are retired unexercised. Do not purchase, transfer, delegate, or apply those records. A different owned production domain must be selected and separately bounded before updating Clerk.

Clerk's documented production-domain change can be performed with the existing securely custodied production Backend API key. It automatically generates a new publishable key, so the eventual approved batch must coordinate Clerk domain mutation, new DNS records/certificates, production Worker issuer/publishable-key pins, and iOS public configuration. The current Worker remains unrouted with writes and onboarding disabled.

## Later Resolution

This pending-replacement disposition is superseded by
`2026-07-17-production-clerk-domain.md`. The separately authorized owned
secondary domain `refwatch.ibby.ai`, exact five DNS-only CNAMEs, certificates,
regenerated Worker publishable key, and issuer refresh are complete. The old
`auth.refwatch.com` records remain retired unexercised.
