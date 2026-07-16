---
task_id: 03
plan_id: PLAN_backend-platform-migration
plan_file: ./PLAN_backend-platform-migration.md
title: Remove active Supabase dependencies and document deployment and cutover
phase: Phase 3 - Cutover and Evidence
---

- [x] Remove the active Supabase SDK/package dependency after Swift composition is cut over.
- [ ] Remove residual Supabase config/import compatibility and retire legacy Supabase-named repository/type/source paths without breaking the persisted SwiftData schema.
- [x] Update README, architecture, security/reliability, generated schema, assistant product spec, setup templates, and API deployment documentation.
- [x] Document required Clerk, Cloudflare, PlanetScale, Hyperdrive, and Wrangler secret names without values.
- [x] Document the Supabase data/account migration, disposable-branch validation, production cutover, and rollback framework.
- [ ] Complete production decisions. The auth-only `testing@refwatch.com` exclusion remains approved and pending final source confirmation. The owned replacement Clerk domain `refwatch.ibby.ai`, exact DNS set, certificates, and Worker key/issuer refresh are complete.
- [ ] Complete Clerk production setup. Production-capable managed resource `clerk-auth-2` now uses verified secondary domain `refwatch.ibby.ai`; DNS, SSL, and email DNS are complete. Authoritatively install the iOS public host/key, resolve the Apple App ID Prefix and signed Bundle ID before native registration, configure production Google OAuth, and create the signed webhook. Preserve the original `clerk-auth` development resource used by staging.
- [ ] Complete the operational rollback packet. The emergency write gate, bounded packet-shape validator, conditional Wrangler traffic commands, truthful external-ledger contract, zero owner-scope threshold, distributable-client requirement, and isolated provider ledger/replay/DLQ rehearsal are implemented and tested. The production environment and inactive Queue/DLQ/D1/local-key resources now exist behind an unrouted, write-disabled Worker with zero cron/consumers; organizational key escrow, separately approved functional ledger activation/probe, final owner, fixed window/threshold values, provider-verified candidate/last-known-good/write-guard versions, restricted production ledger location, and recovery build remain cutover-time evidence.
- [x] Run and record the available preliminary source/bundle secret audits plus API/iOS/Core/watch simulator verification and their bounded gaps.
- [x] Record a sanitized candidate Supabase transaction with exact 39-table counts/data hashes, schema/RLS/Auth digests, and approved auth-only re-observation. It is non-importable and does not replace the final quiesced encrypted export.
- [ ] Complete final production secret/readback audits, authenticated deployed verification, physical-device acceptance, and remaining gap closure.
- [x] Record timestamped source snapshot, disposable PlanetScale rehearsal, and independent reviewer findings with applied/deferred disposition under `evidence/`.
