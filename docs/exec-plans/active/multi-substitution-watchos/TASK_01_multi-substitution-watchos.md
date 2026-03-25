---
task_id: 01
plan_id: PLAN_multi-substitution-watchos
plan_file: ./PLAN_multi-substitution-watchos.md
title: Propagate team IDs and roster lookup inputs through iPhone/watch sync
phase: Foundation
---

- [x] Extend scheduled-match persistence and aggregate snapshot payloads to carry `homeTeamId` and `awayTeamId`.
- [x] Hydrate watch aggregate schedule records and `MatchLibrarySchedule` with those team IDs.
- [x] Update watch-side saved match mapping so selected matches carry team IDs for roster resolution.
- [x] Preserve chosen team IDs when creating or editing scheduled matches on iPhone.
- [x] Add persistence/sync tests covering team ID retention through iPhone and watch library snapshots.
