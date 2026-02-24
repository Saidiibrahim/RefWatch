# Exec Plans Standard

Exec plans and their task files track all non-trivial feature work and refactors.

## Canonical Location
- Active work: `docs/exec-plans/active/<workstream>/`
- Completed work: `docs/exec-plans/completed/<workstream>/`
- Each workstream directory stores one `PLAN_*.md` file and related `TASK_*.md` files.

## Required Plan Sections
- Purpose / Big Picture
- Context and Orientation
- Plan of Work
- Concrete Steps
- Progress
- Surprises & Discoveries
- Decision Log
- Testing Approach
- Constraints & Considerations
- Outcomes & Retrospective

## Task File Frontmatter Template
```yaml
---
task_id: 01
plan_id: PLAN_{feature_name}
plan_file: ./PLAN_{feature_name}.md
title: Audit current implementation and define input mapping
phase: Phase 1 - Discovery
---
```

## Progress Rules
- Every work session updates `Progress`.
- Mark completed tasks explicitly.
- Split partially done work into done vs remaining entries.

## Documentation Hygiene
- Keep plan/task links valid.
- Update `docs/exec-plans/index.md` when active/completed status changes.
- Record tech debt in `docs/exec-plans/tech-debt-tracker.md` when work is intentionally deferred.

## Weekly Doc Gardening
- A weekly automation should audit docs freshness, broken links, and canonical-path drift.
- Automation output option 1: docs-only PR(s) with fixes.
- Automation output option 2: a no-op report when no change is required.
