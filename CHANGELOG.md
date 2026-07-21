# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0-beta.4] - 2026-07-21

### Added
- Fail-closed production helpers and isolated database coverage for zero-legacy identity activation and migration `0017` delivery.
- Source-only Clerk webhook, immutable Worker-lineage, provider-guard, and same-process cutover preparation tooling.
- Active v3 launch and destructive-recovery contracts bound to the exact Cloudflare Custom Domain.

### Changed
- Production schema convergence evidence now records migration `0017` applied, independently read back, and review-closed.
- Launch and rollback validation reject historical route-shaped v2 packets for active closeout and require zero conflicting zone routes and no manual DNS origin.
- Migration architecture, operator runbooks, execution plans, and evidence indexes now match the v3 source contract.

### Release status
- This remains a source-only engineering checkpoint prerelease. The production cutover command stays fail-closed pending trusted provider audit reading, live output fixtures, bounded continuation wiring, and final v3 review closure; no Clerk endpoint, S/A/B/G Worker version, deployment, routing, write/onboarding enablement, traffic promotion, or ledger activation is claimed.

## [0.9.0-beta.3] - 2026-07-21

### Added
- A greenfield zero-legacy identity bootstrap with immutable activation and Clerk webhook delivery receipts.
- Production migration, readback, runtime-provisioning, and immutable Worker-version launch validation tooling.
- Replay-safe collection synchronization with tombstone reconciliation and monotonic server mutation versions.

### Changed
- The production candidate now uses the least-privilege runtime Hyperdrive while writes and new-user onboarding remain disabled.
- Delayed Clerk profile webhooks no longer overwrite newer profile state.
- Greenfield cutover governance now requires bounded candidate acceptance, rollback proof, real Clerk lifecycle delivery, and physical-device acceptance before production closeout.

### Release status
- This remains an engineering checkpoint prerelease. Provider deployment, traffic promotion, write/onboarding activation, real Clerk delivery acceptance, and physical-device sign-off remain gated.

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
