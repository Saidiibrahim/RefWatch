---
task_id: 02
plan_id: watch_ui_polish_beta_readiness
plan_file: ../../plans/watch_ui_polish/PLAN_watch_ui_polish.md
title: Improve team headers and guidance in TeamDetailsView
phase: Phase 1 – Team setup clarity
created: 2025-10-26
updated: 2025-10-26
status: Pending
priority: High
estimated_minutes: 60
dependencies: []
tags: [watchos, ui, match]
---

# Task 02: Improve Team Headers and Guidance in TeamDetailsView

## Objective
Display the configured team names with supportive guidance so referees instantly recognise which side they are managing while swiping between the home and away event grids.

## Context
- `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift` shows uppercase `"HOM"`/`"AWA"` headers regardless of match data and lacks descriptive copy.
- The view already receives `matchViewModel` and can read `homeTeamDisplayName` / `awayTeamDisplayName`.
- `watchLayoutScale` is injected for compact/expanded layouts; we must ensure any additional text respects space limitations on 41 mm devices.

## Steps
1. Replace the static header text with the appropriate display name and keep `.lineLimit(1)` plus `.minimumScaleFactor` to manage long names.
2. Add a supporting subtitle such as "Manage home events" / "Manage away events" styled with `theme.typography.cardMeta`, and ensure it collapses gracefully when text scales.
3. Update accessibility labels to announce both the team name and the role ("Home team", "Away team").
4. Re-run previews for compact and expanded layouts to verify typography, truncation, and spacing.

## Acceptance Criteria
- Team tabs display actual team names (or fallback to "Home"/"Away" when names are empty) with a descriptive subtitle.
- Accessibility VoiceOver announces the team name and role without relying on abbreviations.
- Layout remains intact on 41 mm and larger watch sizes with no overlapping text.

## Verification
- Use SwiftUI previews (`TeamDetailsView` compact and Ultra previews) to confirm truncation and layout.
- Optionally spot-check on a watch simulator to ensure the subtitle reads correctly and accessibility speaks the updated labels.
