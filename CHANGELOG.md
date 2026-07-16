# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0-beta.2] - 2026-07-17

### Added
- Database-enforced identity reconciliation, deletion tombstones, and guarded post-reconciliation onboarding.
- An immutable mutation ledger with Queue/D1 delivery, dead-letter receipts, replay ordering, and rehearsal verification.
- Encrypted final-cutover bundle validation and a minimized Supabase candidate snapshot contract.
- Production-foundation, Clerk-domain, rollback, and operator evidence for the next migration checkpoint.

### Changed
- Production Worker configuration is pinned to the expected database identity and remains unrouted, write-disabled, and onboarding-disabled.
- Retired `auth.refwatch.com` instructions are now explicitly historical; the verified owned Clerk domain is `refwatch.ibby.ai`.

### Release status
- This remains an engineering checkpoint prerelease. Final identity/data migration, authenticated production route proof, rollback completion, traffic/write enablement, and physical-device acceptance remain gated.

## [0.9.0-beta.1] - 2026-07-14

### Added
- A Cloudflare Worker API backed by Hono, Drizzle, Hyperdrive, and PlanetScale Postgres.
- Clerk-backed iOS authentication and authenticated backend repository adapters.
- Team references in shared match-event sync contracts.
- Migration, rehearsal, rollback, and verification documentation.

### Changed
- iOS cloud services now target the authenticated Worker boundary instead of connecting directly to Supabase.
- Watch lifecycle recovery and simulator acceptance coverage are more robust.

### Release status
- This is an engineering checkpoint prerelease. Production database and identity cutover, authenticated end-to-end proof, and physical-device acceptance remain incomplete.

## [0.8.2] - 2026-04-03

### Added
- Initial changelog structure.
