---
task_id: TASK_02_substitution_nav
plan_id: PLAN_substitution_nav
plan_file: ../../plans/substitution_nav/PLAN_substitution_nav.md
title: Implement stable ids and hoist navigation destinations
phase: Phase 2 - Navigation stability
status: completed
---

- Replace UUID-based ids in `AdaptiveEventGridItem` with stable ids and update call sites (done).
- Hoist goal/substitution navigation destinations outside lazy grids to satisfy SwiftUI warning (done by moving goal input nav to `MatchSetupView`).
