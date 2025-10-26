---
task_id: 02
plan_id: watch_beta_polish_readiness
plan_file: ../../plans/watch_beta_polish/PLAN.md
title: Fix substitution flow order handling
phase: Phase 2 – Match Events
created: 2025-02-15
updated: 2025-02-15
status: Completed
completed: 2025-02-15
priority: High
estimated_minutes: 75
dependencies: [01]
tags: [watchos, substitutions, bugfix]
---

# Task 02: Fix Substitution Flow Order Handling

## Objective

Respect the “player on first” preference when recording substitutions so both jersey numbers are captured and `recordSubstitution` always fires with valid data.

## Context

- `SubstitutionFlow` assumes the first prompt captures “player off,” regardless of settings. When the user sets `substitutionOrderPlayerOffFirst = false`, the first number goes into `playerOffNumber`, leaving `playerOnNumber` nil and blocking `recordSubstitution`.
- The flow must set the correct property, advance to the appropriate step, and only progress to confirmation/recording when both numbers exist.
- Watch out for confirmation mode (`settings.confirmSubstitutions`). The summary view should display the numbers in the right order with accessible labels.

## Steps

1. Adjust the first `PlayerNumberInputView` to map the captured number into `playerOnNumber` when “player on first” is enabled.
2. Update the state transitions (`step = ...`) so the second prompt is the opposite jersey field.
3. Ensure confirmation view strings remain accurate (`playerOffNumber` / `playerOnNumber` non-nil).
4. Add focused unit coverage (or at minimum UI test assertions) verifying both order paths succeed.
5. Verify haptics, dismissal, and accessibility remain unaffected.

## Acceptance Criteria

- Substitution flow successfully records numbers in both “off first” and “on first” modes.
- Confirmation screen (when enabled) shows the correct values; no `#0` placeholders.
- `matchViewModel.recordSubstitution` receives both jersey numbers and returns to the middle tab as before.

## Notes

- Consider adding a guard that surfaces a user-facing error if either number is still nil, though the corrected flow should prevent that state.

## Outcome

- `SubstitutionFlow` now advances between “player on/off” steps using helper transitions, capturing both jersey numbers before confirmation or persistence regardless of user preference.
