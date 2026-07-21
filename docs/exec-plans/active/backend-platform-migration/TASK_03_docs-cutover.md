---
task_id: 03
plan_id: PLAN_backend-platform-migration
plan_file: ./PLAN_backend-platform-migration.md
title: Remove active Supabase dependencies and document deployment and cutover
phase: Phase 3 - Cutover and Evidence
---

- [x] Remove the active Supabase SDK/package dependency after Swift composition is cut over.
- [ ] Remove residual Supabase config/import compatibility and retire legacy
  Supabase-named repository/type/source paths only after accepted greenfield
  traffic, without breaking the persisted SwiftData schema.
- [x] Update README, architecture, security/reliability, generated schema, assistant product spec, setup templates, and API deployment documentation.
- [x] Document required Clerk, Cloudflare, PlanetScale, Hyperdrive, and Wrangler secret names without values.
- [x] Preserve the stateful Supabase data/account migration and encrypted
  validator framework as historical/future live-migration tooling.
- [x] Record the 2026-07-20 greenfield override: 43 Auth users, 42 profiles,
  1,106 source rows, and `testing@refwatch.com` are historical disposable facts,
  not launch gates. No final export, legacy mapping, or row reconciliation is
  required.
- [x] Record the local zero-legacy identity implementation, migration/harness
  hashes, exact test outcomes, bounded non-provider claim, and applied
  code-risk review in
  `evidence/2026-07-20-greenfield-identity-bootstrap.md`.
- [x] Record the explicit `greenfield_launch_v1` /
  `greenfield_destructive_v1` validation contract, exact production pins,
  executable schema/seed/clean/ledger readbacks, full catalog and clean-state
  digests, canonical receipt recomputation, strict chronology, current test
  outcomes, and both mandatory review dispositions in
  `evidence/2026-07-20-greenfield-launch-validator.md`. This stages validation
  tooling only; no provider execution or production activation is claimed.
- [x] Record and review the append-only v1 supersession plus active
  `greenfield_launch_v2` / `greenfield_destructive_v2` immutable-version
  lineage contract in
  `evidence/2026-07-20-greenfield-worker-version-lineage.md`: exact
  digest-checked sanitized A/B provider receipts and binding allowlist,
  A=100%/B=0% public disabled proof, protected override-only bounded B access,
  an exact one-token/zero-bypass Access `service_auth` receipt, temporary 100%
  G/L probes bracketed by canonical before/after provider readbacks with
  restoration before final A proof; exact nested standalone rollback
  validation; manually signed bounded webhook lifecycle; B=100% promotion;
  real three-subscription Clerk delivery and zero-count cleanup while Access
  stays active; provider-bound Access removal before deployment history/device
  testing; post-device production acceptance; unique receipt kinds/IDs; and
  final inactive-ledger/zero-consumer readback. Current verification is 108/108
  focused across 3 files (including six promoted-webhook adversarial tests),
  268/268 unit in 19 files, 23/23 database in 3 files, and 19/19 mounted routes
  in 1 file; typecheck and grouped plus complete-range redacted Gitleaks pass.
  The exact 83-file scan remains historical remediated-v2 evidence. Generated
  Wrangler types are part of the batch, both mandatory reviewers returned
  final `NO FINDINGS`, and
  no provider deployment or route mutation is claimed.
- [x] Record the superseding 19-case greenfield local mounted-route, collection
  cursor, monotonic version, and inactive-ledger proof in
  `evidence/2026-07-20-greenfield-local-route-matrix.md` while preserving the
  2026-07-17 partial checkpoint unchanged. This is local/simulator evidence,
  not deployed or physical-device acceptance.
- [x] Close mandatory review of the captured production baseline in
  `evidence/2026-07-20-production-greenfield-baseline.md`: exact PlanetScale
  schema/clean/seed/ledger and access-path distinctions; Cloudflare
  versions/routes/bindings/inactive resources; official Clerk SDK zero-state;
  Apple production identity and local Release gap; zero pending approvals; and
  absent physical devices. The exact then-current pre-preparation `0015`
  payload now has a hashed standalone query; provider-issued temporary access
  roles are distinguished from durable credentials and
  application/configuration mutation. Atomic
  migration and failure-atomic writable-runtime helper findings are applied,
  the final docs wording corrections are synchronized, and both mandatory
  reviewers returned `NO FINDINGS`. No provider preparation is claimed by this
  closeout.
- [x] Record and close mandatory review of the executed production target
  preparation in `evidence/2026-07-20-production-greenfield-preparation.md`.
  Migration `0016`, exact schema/owner/clean-seed/ledger readbacks, the durable
  writable role/Hyperdrive pair, coordinated local candidate binding, and
  disabled-mode dry-run are recorded without credentials. Both mandatory
  reviewers returned `NO FINDINGS` after every finding was applied.
- [ ] Complete the authorized Clerk production setup. Live Clerk state is
  authoritative: instance `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, domain
  `refwatch.ibby.ai`, issuer `https://clerk.refwatch.ibby.ai`. Do not repeat the
  completed DNS/certificate/key lane. The authoritative Apple identifiers are
  now resolved; remaining work is native registration readback/configuration,
  non-secret iOS public config, Apple/Google OAuth, and the exact signed webhook.
  Preserve development resource `clerk-auth`.
- [x] Defer production ledger escrow/recovery/activation as non-blocking for
  this launch. Keep capture inactive and use the reviewed destructive
  reset/reseed/recreate rollback; preserve the failed escrow audit unchanged.
- [x] Run and record the available preliminary source/bundle secret audits plus API/iOS/Core/watch simulator verification and their bounded gaps.
- [x] Record a sanitized candidate Supabase transaction with exact 39-table counts/data hashes, schema/RLS/Auth digests, and approved auth-only re-observation. It is non-importable and does not replace the final quiesced encrypted export.
- [ ] Record the remaining separate sanitized evidence for zero-legacy
  activation; Clerk native/OAuth/webhook; exact A/B/G/L provider
  versions/deployments/route/history; A disabled denial/no-mutation; protected
  bounded B automation with the exact Access receipt and manually signed
  webhook check; G/L bracketed temporary probes before final A proof; exact
  rollback packet; B=100% promotion; real Clerk-provider lifecycle/cleanup
  while Access remains active; provider-bound Access removal before
  history/devices; physical-device/Release exercise of promoted B;
  post-device production acceptance and observation; final inactive-ledger/
  zero-consumer readback; and post-acceptance retirement. Migration/schema/ownership,
  post-preparation clean target/seed, inactive ledger, and exact-instance
  zero-user Clerk readbacks are already captured in the reviewed preparation
  artifact. Authorization and captured preparation must never be presented as
  later activation/deployment/acceptance completion.
- [x] Record timestamped source snapshot, disposable PlanetScale rehearsal, and independent reviewer findings with applied/deferred disposition under `evidence/`.
