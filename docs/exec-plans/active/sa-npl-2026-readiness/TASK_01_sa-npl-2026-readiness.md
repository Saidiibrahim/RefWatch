---
task_id: 01
plan_id: PLAN_sa-npl-2026-readiness
plan_file: ./PLAN_sa-npl-2026-readiness.md
title: Create SA 2026 reference + sanctions + import migrations
phase: Phase 1 - Schema & Data
---

## Objective
Create migrations `0017`, `0018`, and `0019` with deterministic seeds, extensive comments, and verification snippets.

## Status
Done

## Notes
- Includes NPLSA men, SL1 men, SL2 north/south men, and WNPL women 2026 references.
- Includes disciplinary code/rule baseline and import RPC for owner-scoped team library.
- `reference_disciplinary_rules` enforces natural-key uniqueness and upserts by `(jurisdiction, season_year, rule_type, recipient_type)` to avoid duplicate rows on wording-only edits.
