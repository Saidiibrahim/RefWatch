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
- [ ] Complete the operational rollback packet. The emergency write gate, bounded packet-shape validator, conditional Wrangler traffic commands, required external-ledger contract/receipts, zero owner-scope threshold, and distributable-client requirement are implemented and tested. The production environment, actual mutation ledger/probe, final owner, fixed window/threshold values, provider-verified candidate/last-known-good/write-guard versions, restricted ledger location, and recovery build remain cutover-time evidence.
- [ ] Run source/bundle secret audits, API/iOS/core/watch verification, and record gaps.
- [x] Record timestamped source snapshot, disposable PlanetScale rehearsal, and independent reviewer findings with applied/deferred disposition under `evidence/`.
