---
task_id: 03
plan_id: PLAN_backend-platform-migration
plan_file: ./PLAN_backend-platform-migration.md
title: Remove active Supabase dependencies and document deployment and cutover
phase: Phase 3 - Cutover and Evidence
---

- [x] Remove the active Supabase SDK/package dependency after Swift composition is cut over.
- [ ] Separately gated — remove residual Supabase config/import compatibility and retire legacy Supabase-named repository/type/source paths only after rollback/reconciliation prerequisites permit it, without breaking the persisted SwiftData schema.
- [x] Update README, architecture, security/reliability, generated schema, assistant product spec, setup templates, and API deployment documentation.
- [x] Document required Clerk, Cloudflare, PlanetScale, Hyperdrive, and Wrangler secret names without values.
- [x] Document the Supabase data/account migration, disposable-branch validation, production cutover, and rollback framework.
- [ ] Separately gated — apply the approved auth-only `testing@refwatch.com` exclusion only after final source confirmation. The owned replacement Clerk domain `refwatch.ibby.ai`, exact DNS set, certificates, and Worker key/issuer refresh are complete and must not be repeated.
- [ ] Separately gated; do not start automatically — complete Clerk production setup only after each exact prerequisite and approval. The live production Clerk instance associated with managed resource `clerk-auth-2` uses verified `refwatch.ibby.ai`; the managed Stripe Projects metadata may retain its historical domain. DNS, SSL, and email DNS are complete. The unresolved later work is authoritative Apple identifiers/native registration, iOS public configuration, production Google OAuth, and the signed webhook. Preserve development resource `clerk-auth`.
- [ ] Separately gated — production ledger-key escrow is blocked because the named Keychain record has an empty payload and the Worker secret is non-readable. Recoverable source remediation, escrow storage, functional recovery through a later binding/procedure, and production activation/probe are distinct approval gates. Complete the operational rollback packet only after those proofs, final owner/window/thresholds, provider-verified candidate/last-known-good/write-guard versions, restricted ledger location, and a distributable recovery build exist. Current local validators, fail-closed write gate, inactive resources, and isolated rehearsal do not authorize activation or routing.
- [x] Run and record the available preliminary source/bundle secret audits plus API/iOS/Core/watch simulator verification and their bounded gaps.
- [x] Record a sanitized candidate Supabase transaction with exact 39-table counts/data hashes, schema/RLS/Auth digests, and approved auth-only re-observation. It is non-importable and does not replace the final quiesced encrypted export.
- [ ] Separately gated — complete final production secret/readback audits, authenticated deployed verification, physical-device acceptance, and remaining gap closure only in their approved phases.
- [x] Record timestamped source snapshot, disposable PlanetScale rehearsal, and independent reviewer findings with applied/deferred disposition under `evidence/`.
