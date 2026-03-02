---
task_id: 03
plan_id: PLAN_sa-npl-2026-readiness
plan_file: ./PLAN_sa-npl-2026-readiness.md
title: Add structured card reason metadata and second-yellow mapping
phase: Phase 3 - Discipline Event Integrity
---

## Objective
Extend card payload shape with reason metadata and map second caution dismissals to `card_second_yellow` persistence.

## Status
Done

## Notes
- Added `reasonCode` / `reasonTitle`.
- Updated iOS + watch card flows to pass template-derived metadata.
- Updated Supabase event type mapping for second yellow.
- Deferred follow-up: iOS currently resolves reasons from the default misconduct template because iOS has no active-template selection flow yet; watch can use user-selected templates. This is tracked as a medium risk for non-SA jurisdictions and requires a dedicated iOS settings/UI enhancement.
