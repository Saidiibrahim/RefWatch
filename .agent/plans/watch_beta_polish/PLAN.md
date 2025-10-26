---
plan_id: watch_beta_polish_readiness
title: Watch Beta Polish Plan
created: 2025-02-15
updated: 2025-02-15
status: Completed
total_tasks: 4
completed_tasks: 4
priority: High
tags: [watchos, match, ux, sync, polish]
---

# Watch Beta Polish Plan

## Purpose / Big Picture

Before inviting early testers, we need to close several polish gaps in the watch experience: restore standard match duration choices, make substitution flows reliable under all settings combinations, surface real team names throughout kickoff and event flows, and present a confident sync experience on the home and settings screens. Tightening these will prevent first-run frustration and reinforce that the watch app is field-ready.

## Surprises & Discoveries

- Match duration picker lost the canonical 90-minute option during a prior refactor, forcing awkward 40–50 minute selections.
- The substitution flow assumes "player off first," so choosing the alternate order leaves one of the jersey numbers `nil` and the record never saves.
- Kickoff and goal flows still show placeholder "HOM"/"AWA" labels after match selection, which feels unpolished when testing synced library matches.
- Manual sync button offers no feedback; testers cannot tell if a request is running or when the last sync succeeded.

## Decision Log

- (2025-02-15) Keep match durations hard-coded for now but broaden to common regulation and youth presets; defer dynamic schedule-driven durations until aggregate schedules expose that metadata.
- (2025-02-15) Retain the existing substitution confirmation screen but ensure both jersey numbers populate before proceeding, regardless of order preference.
- (2025-02-15) Show aggregate-powered team names wherever kickoff/team flows reference sides; fall back to abbreviations only when data is truly unavailable.
- (2025-02-15) Replace the bare "Sync from iPhone" button with a stateful control and expose a lightweight "Last synced" summary on the idle screen.

## Outcomes & Retrospective

- Duration menu once again offers regulation and youth presets, preventing mismatched 45-minute defaults reported by testers.
- Substitution capture now respects both order preferences, eliminating the nil jersey regression.
- Team-focused surfaces (team detail grid, goal picker) render synced club names, improving parity with iPhone previews.
- Home and settings sync affordances display live state, with progress feedback and concise copy suited for beta builds.

## Context and Orientation

- `RefZoneWatchOS/Core/Components/MatchStart/MatchSettingsListView.swift` owns the duration picker data; expanding its options is fast but must remain localized via `SettingPickerView`.
- `RefZoneWatchOS/Features/Events/Views/SubstitutionFlow.swift` drives jersey capture and writes to `MatchViewModel`. Logic is currently asymmetric based on the substitution preference setting.
- Kickoff and goal flows in `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift` and `RefZoneWatchOS/Features/Events/Views/GoalTypeSelectionView.swift` lean on hard-coded abbreviations.
- Sync touchpoints live in `RefZoneWatchOS/App/MatchRootView.swift` and `RefZoneWatchOS/Features/Settings/Views/SettingsScreen.swift`; these require thoughtful UX tweaks without undermining power-user diagnostics.

## Plan of Work

1. **Restore core match durations**: Add regulation (90) plus common youth presets to the duration picker, keeping defaults sensible and localization-friendly.
2. **Stabilize substitution flow**: Respect the "player on first" preference by capturing jersey numbers in the correct order and only recording once both values exist.
3. **Show real team naming**: Replace placeholder "HOM"/"AWA" labels in kickoff and goal flows with names from `MatchViewModel` while maintaining fallbacks and accessibility.
4. **Polish sync UX**: Add loading/disabled feedback to the manual sync button, surface last-sync context on the idle screen, and tone down Settings diagnostics for testers.

## Concrete Steps

Each step is tracked in `.agent/tasks/watch_beta_polish/`.

## Progress

- [x] (2025-02-15 18:05 UTC) TASK_01_watch_beta_polish.md — Duration picker restores regulation options
- [x] (2025-02-15 18:27 UTC) TASK_02_watch_beta_polish.md — Substitution flow order handling fixed
- [x] (2025-02-15 18:52 UTC) TASK_03_watch_beta_polish.md — Kickoff & goal flows show real team names
- [x] (2025-02-15 19:20 UTC) TASK_04_watch_beta_polish.md — Sync button feedback & tester-friendly status

## Testing Approach

- Manual watchOS simulator smoke testing recommended for substitution path permutations and sync states (reachable vs unreachable).
- Future coverage: add unit assertions for duration presets and substitution recorder once the new flows settle.
- UI snapshot updates pending once watch-specific test harness is restored.

## Constraints & Considerations

- Avoid blocking the user with the extended duration list; ensure the picker scroll remains manageable even as options grow.
- The substitution fix must not regress voice prompts or accessibility in the existing flow.
- Team name changes should honor Reduced Motion and Dynamic Type, avoiding cramped layouts on 41mm devices.
- Sync polish should preserve internal diagnostics, ideally behind a secondary disclosure so engineers can still troubleshoot.

## Next Steps

1. Capture simulator screenshots for release notes once QA confirms flows.
2. Coordinate with iOS team to ensure sync status copy aligns across platforms.
