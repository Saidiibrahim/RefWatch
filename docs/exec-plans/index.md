# Exec Plans Index

Execution plans and granular task files are the canonical workflow tracker for non-trivial changes.

## Structure
- Active work: `active/`
- Completed work: `completed/`
- Tech debt ledger: `tech-debt-tracker.md`

## Active Plans
- `active/backend-platform-migration/PLAN_backend-platform-migration.md` —
  greenfield production cutover authorized on 2026-07-20. Historical 43 Auth
  users, 42 profiles, 1,106 source rows, and target test state are disposable;
  no legacy mapping/import/reconciliation is required. Active work is the
  authorization-bound zero-legacy bootstrap, staged launch/rollback packets,
  complete reviewed seed, writable least-privilege runtime, Clerk
  native/OAuth/webhook setup, mounted and production acceptance matrices,
  physical devices, traffic observation, and post-acceptance cleanup. Ledger
  escrow/recovery/activation is deferred; production capture must remain
  inactive. The fresh read-only provider baseline and its mandatory reviews
  are complete. Migration `0016` plus the dedicated writable role/Hyperdrive
  pair are prepared and verified with writes/onboarding still disabled; both
  provider-preparation reviewers returned `NO FINDINGS`. The local immutable
  A/B/G/L v2 launch-contract correction is implemented and both mandatory
  reviewers returned final `NO FINDINGS`. Its current contract carries digest-checked sanitized
  A/B provider readbacks, requires ordinary traffic at A=100%/B=0%, protects
  bounded B access with Cloudflare version override + exact one-token/no-bypass
  Access `service_auth` receipt + Worker token gate, temporarily probes G and L
  at 100% between canonical before/after readbacks before final A proof, and
  treats bounded webhook lifecycle as manually signed rather than provider
  delivery. After B promotion, real three-subscription Clerk delivery and
  zero-count cleanup occur while Access remains active; only then is Access
  removed before history/devices. Local verification is 108/108 focused across 3
  files, 268/268 unit across 19 files, 23/23 database across 3 files, and 19/19
  mounted routes in 1 file. Beta.3 adds the reviewed Clerk profile-event
  watermark as source migration `0017`; production remains at `0016`.
  No provider deployment or route mutation is claimed by the local v2 batch.
- `active/assistant-multimodal-refresh/PLAN_assistant-multimodal-refresh.md`
- `active/match-records-confirmation/PLAN_match-records-confirmation.md`
- `active/match-sheet-import/PLAN_match-sheet-import.md`
- `active/match-timer-ux/PLAN_match-timer-ux.md`
- `active/match-lifecycle-haptics/PLAN_match-lifecycle-haptics.md`
- `active/multi-substitution-watchos/PLAN_multi-substitution-watchos.md`
- `active/multi-substitution-watchos-speed-polish/PLAN_multi-substitution-watchos-speed-polish.md`
- `active/mode-switcher-ux/PLAN_mode-switcher-ux.md`
- `active/sa-npl-2026-readiness/PLAN_sa-npl-2026-readiness.md`
- `active/schedule-match-sheets/PLAN_schedule-match-sheets.md`
- `active/substitution-nav/PLAN_substitution_nav.md`
- `active/watch-match-runtime-continuity/PLAN_watch-match-runtime-continuity.md`
- `active/watch-timer-readability/PLAN_watch-timer-readability.md`

## Completed Plans
- `completed/mode-switcher-navigation/PLAN_mode_switcher_navigation.md`
- `completed/reports/early-tester-issues-2025-12-02.md`
- `completed/reports/undo-event-bug-investigation-2025-12-02.md`

## Process Rule
Each active plan must have task files in the same directory and keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current.
