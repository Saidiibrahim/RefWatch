---
task_id: 05
plan_id: PLAN_mode-switcher-ux
plan_file: ./PLAN_mode-switcher-ux.md
title: Add tests for mode switching flows
phase: Testing
---

- [ ] Extend `AppModeControllerTests` to cover first-run default, allowDismiss logic, persistence after selection, and overrideForActiveSession behavior.
- [ ] Add watchOS UI/integration test covering: first-run presentation + optional dismiss, switch confirmation/haptic stub, and blocked switching during active match.
- [ ] Add reliability test around session persistence before switching (simulate active match/workout state where applicable).
- [ ] Document manual test checklist for simulator validation (back affordance consistency, learn-more flow, confirmation timing).
- [ ] Add UI test to verify the centralized guard prevents mode switcher presentation during active sessions and shows the chosen hint; add parity for workout active session if applicable.
