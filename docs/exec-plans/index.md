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
  provider-preparation reviewers returned `NO FINDINGS`. The historical local
  A/B/G/L v2 launch-contract correction is implemented and both mandatory
  reviewers returned final `NO FINDINGS`. The active v3 contract carries digest-checked sanitized
  A/B provider readbacks, requires ordinary traffic at A=100%/B=0%, protects
  bounded B access with Cloudflare version override + exact one-token/no-bypass
  Access `service_auth` receipt + Worker token gate, temporarily probes G and L
  at 100% between canonical before/after readbacks before final A proof, and
  treats bounded webhook lifecycle as manually signed rather than provider
  delivery. After B promotion, real three-subscription Clerk delivery and
  zero-count cleanup occur while Access remains active; only then is Access
  removed before history/devices. Local verification retains 108/108 focused
  launch/rollback cases across 3 files. The historical activation-closure
  checkpoint adds 19/19 focused remediation cases across 2 files (13
  activation-helper plus 6 shared migration-0016 contract cases), 281/281 unit
  across 20 files, and 9/9 isolated exact-0016 activation cases. The current
  migration-0017 convergence checkpoint is separately recorded as 296/296 unit
  across 21 files and 11/11 isolated physical-`postgres` migration cases,
  alongside 23/23 current-schema database cases and 19/19 mounted routes;
  production apply/retry, independent primary readback, and both mandatory
  post-execution reviews are complete with final exact `NO FINDINGS`.
  Beta.3 adds the reviewed Clerk profile-event
  watermark as migration `0017`; production now matches that exact catalog.
  The fail-closed one-shot 0016 zero-legacy activation helper and its isolated
  physical-`postgres` rehearsal are implemented locally. Both initial reviewers
  returned `NO FINDINGS`, after which the first production attempt failed
  closed with zero receipt/activation rows on an overly narrow history-sequence
  representation check. The semantic-next-ID remediation is implemented and
  both mandatory reviewers returned final `NO FINDINGS`. Fresh exact
  PlanetScale/Clerk gates then preceded successful activation and idempotent
  retry. Primary readback proves exactly one immutable receipt/activation at
  `2026-07-21T03:38:21.452Z`; every post-execution finding was applied and both
  final reviewers returned exact `NO FINDINGS`.
  The gated source-migration-0017 helper and active-validator repin are
  implemented and digest-pinned locally with 14/14 unit and 11/11 isolated
  physical-`postgres` cases. Mandatory pre-execution code/docs reviews and the
  supplemental SQL review returned exact `NO FINDINGS`; the reviewed fixed
  stdin-only command applied 0017, the retry was exactly idempotent, and primary
  readback proved 18/head-18 history, 36 tables/383 columns, sequence
  `(19,false)`, unchanged identity/seed state, and inactive ledger. Post-
  execution code/docs reviewers returned final exact `NO FINDINGS`, closing
  migration-0017 convergence and removing this prerequisite for Worker upload.
  This identity-control
  activation is separate from the still-forbidden mutation-ledger activation,
  and no later Worker/acceptance gate is implied complete by the now-closed 0017
  convergence prerequisite.
  Local production Clerk-endpoint preparation, Worker lineage, and their same-
  process cutover broker and provider guards are staged and locally verified:
  455/455 full unit across 25 files, 43/43 database, 19/19 mounted routes,
  typecheck, three source checks, production dry-run, Wrangler generated-types
  check, mutation coverage, a redacted changed-file credential scan excluding and
  not inspecting `.projects`, and diff check pass. Their package checks are
  source-only; standalone Clerk/lineage execution is disabled, and for this lane
  only the outer `cutover:production` command carries explicit `--execute` plus
  `REFWATCH_ALLOW_PRODUCTION_GREENFIELD_CUTOVER=1`. That outer CLI remains fail-
  closed until its trusted audit reader/live fixtures and bounded continuation
  are wired and the active v3 review closes. The earlier 131/131 focused and
  427/427 unit checkpoint remains historical. No live Clerk lifecycle
  endpoint or S/A/B/G Worker version is claimed.
  The only completed provider mutations in this lane are the reviewed
  zero-legacy identity receipt activation and database migration `0017`; no
  Clerk endpoint, Worker deployment, route/domain, write/onboarding, traffic,
  or ledger state changed.
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
