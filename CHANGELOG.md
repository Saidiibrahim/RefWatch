# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
