---
plan_id: watch_ui_polish_beta_readiness
title: Watch UI Polish Plan
created: 2025-10-26
updated: 2025-10-26
status: In Progress
total_tasks: 2
completed_tasks: 0
priority: High
tags: [watchos, ui, polish]
---

# Watch UI Polish Plan

## Purpose / Big Picture
Polish the watchOS experience ahead of beta builds by removing unfinished affordances and clarifying the team setup tabs. We will 1) prevent referees from tapping a "Choose colours" option that only displays a placeholder alert, and 2) surface the actual team names with contextual copy inside the home/away event grids so referees immediately know which side they are editing.

## Surprises & Discoveries
- Observation: The "Choose colours" action in the in-match options sheet still triggers a "coming soon" alert, signalling unfinished work.  
  Evidence: `RefZoneWatchOS/Features/Timer/Views/MatchOptionsView.swift:37-69`
- Observation: Team tabs continue to render hard-coded `"HOM"`/`"AWA"` headers with no supporting guidance.  
  Evidence: `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift:55-76`

## Decision Log
- Decision: Hide the unfinished "Choose colours" action for testers and replace it with explanatory copy rather than a tappable card.  
  Rationale: Prevents accidental taps while acknowledging the feature roadmap without junk drawer alerts.  
  Date/Author: 2025-10-26 / Codex
- Decision: Promote actual `MatchViewModel` team names and add role hints ("Manage home events") directly in `TeamDetailsView`.  
  Rationale: Reinforces orientation during quick swipes between tabs, especially when synced library data supplies club names.  
  Date/Author: 2025-10-26 / Codex

## Outcomes & Retrospective
_To be populated once the plan is delivered._

## Context and Orientation
The watch app uses SwiftUI with feature-first folders and a shared theming environment.
- `RefZoneWatchOS/Features/Timer/Views/MatchOptionsView.swift` hosts the in-match options list, built from reused `ActionButton` rows and currently surfacing the placeholder colour picker alert.
- `RefZoneWatchOS/Core/Components/ActionButton.swift` defines the theming for those list rows; we can swap an action for static guidance without altering the component API.
- `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift` renders the home/away event grids; it already exposes `matchViewModel` with dynamic `homeTeamDisplayName` / `awayTeamDisplayName` plus `watchLayoutScale` for typography adjustments.
- `MatchViewModel` (see `RefZoneWatchOS/App/MatchRootView.swift`) persists the selected team names and is the single source of truth for display names across the watch app.

## Plan of Work
1. **Match options cleanup** — Remove the tappable "Choose colours" entry from the options list and replace it with static roadmap copy so the sheet only contains actionable controls.
2. **Team header improvements** — Swap the `"HOM"`/`"AWA"` labels for dynamic team names, add a short descriptive subtitle, and update accessibility to announce both name and role.

## Concrete Steps
Each implementation step is tracked in `.agent/tasks/watch_ui_polish/`.

## Progress
- [ ] (TASK_01_watch_ui_polish.md) Remove or gate the "Choose colours" action from MatchOptionsView.
- [ ] (TASK_02_watch_ui_polish.md) Replace "HOM/AWA" headers with contextual team info in TeamDetailsView.

## Testing Approach
- Use SwiftUI previews for `MatchOptionsView` and `TeamDetailsView` to validate layout on compact and expanded watch sizes.
- Spot-check on an Apple Watch Series 9 (41mm) simulator to ensure truncation, subtitles, and accessibility announcements behave as expected.

## Constraints & Considerations
- Avoid introducing feature flags that diverge from production; prefer static copy or conditional rows.
- Preserve the carousel list spacing so removal of a row does not collapse section padding.
- Ensure subtitle copy respects localization considerations (temporary English-only string acceptable for beta, but keep neutral tone).
