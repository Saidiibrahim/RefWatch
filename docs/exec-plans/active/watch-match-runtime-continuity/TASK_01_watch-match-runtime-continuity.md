---
task_id: 01
plan_id: PLAN_watch-match-runtime-continuity
plan_file: ./PLAN_watch-match-runtime-continuity.md
title: Implement runtime continuity hardening for match flow states
phase: Implementation
---

- [x] Add a testable runtime-session wrapper and factory in `BackgroundRuntimeSessionController`.
- [x] Replace fixed restart count with reason-aware restart handling and bounded startup-failure retries.
- [x] Add simulator-explicit restart suppression logic for known runtime-session failure behavior.
- [x] Centralize runtime eligibility in `MatchViewModel` across in-play, halftime, ET waiting states, and penalties.
- [x] Add `MatchViewModel` reconciliation entrypoint for root scene-phase reactivation.
- [x] Add root-level scene-phase hook in `MatchRootView` to re-evaluate runtime protection on `.inactive` and `.active`.
- [x] Extend core runtime tests for halftime/ET/penalty continuity and inactive-state cancellation.
- [x] Add watch runtime-controller tests for restart behavior, proactive renewal, and idempotent end.
- [x] Update product spec, watch architecture doc, and release verification guidance.
