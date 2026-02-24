---
plan_id: PLAN_substitution_nav
author: codex
created_at: 2025-12-03
related_issue: "watchOS substitution flow requires double-tap to navigate"
status: in_progress
---

## Purpose / Big Picture
Ensure substitution entry on watchOS navigates to the keypad on the first tap and remains stable across renders; remove navigation warnings so future SwiftUI releases do not ignore destinations.

## Context and Orientation
- watchOS match flow lives under `RefWatchWatchOS/Features/MatchSetup/Views/MatchSetupView.swift` with left/right team event grids feeding the timer.
- Event buttons are built by `RefWatchWatchOS/Core/Components/AdaptiveEventGrid.swift` (uses `LazyVGrid`).
- Substitution UI: `RefWatchWatchOS/Features/Events/Views/SubstitutionFlow.swift` (currently wraps its own `NavigationStack`).
- Goal number input navigation is defined in `RefWatchWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift` via `navigationDestination(isPresented:)`.
- View model hooks: `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift` and `MatchSetupViewModel.swift`.
- Logged warning: navDestination inside lazy container; observed bug: first tap on "Sub" pops back, second works.

## Plan of Work
1) Stabilize event button identity: refactor `AdaptiveEventGridItem` to take an explicit stable `id` and update call sites to use deterministic ids so navigation links are not invalidated mid-transition.
2) Hoist navigation destinations out of lazy contexts: attach goal/substitution destinations to a parent container that is not created lazily (e.g., wrap `MatchSetupView` in a navigation destination for player input) and remove inline `navigationDestination` from inside the grid host.
3) Simplify flows to avoid nested `NavigationStack`: turn `SubstitutionFlow` (and card flow if touched) into plain content views relying on the parent navigation stack; ensure back button works and confirmation path still behaves.
4) Validation: reproduce on simulator, verify first tap navigates to keypad, no nav warnings in console; outline/add a light UI test if feasible.

## Progress
- [x] TASK_01_substitution_nav.md – Audit current navigation + reproduce bug (code review + warning analysis; sim repro pending)
- [x] TASK_02_substitution_nav.md – Implement stable ids + destination hoist
- [x] TASK_03_substitution_nav.md – Flatten substitution flow navigation
- [ ] TASK_04_substitution_nav.md – Validation notes / testing

## Surprises & Discoveries
- (fill during work)

## Decision Log
- (record as decisions are made)

## Testing Approach
Manual: watchOS sim with active match, tap Sub once and ensure keypad stays visible; verify goal flow still navigates; watch console for navDestination warnings. Add UI test if time permits.

## Constraints & Considerations
- Keep code SwiftUI idioms (NavigationStack + navigationDestination).
- Avoid changing haptic or business logic; focus on navigation stability.
- Maintain 2-space indent, single-type per file.

## Outcomes & Retrospective
- (populate at completion)
