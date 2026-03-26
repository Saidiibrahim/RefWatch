---
task_id: 02
plan_id: PLAN_multi-substitution-watchos-speed-polish
plan_file: ./PLAN_multi-substitution-watchos-speed-polish.md
title: Implement watch UI and tests for the speed polish
phase: watchOS UI
---

- [x] Remove the top substitutions summary card from the watch hub.
- [x] Change hub subtitles to number-only comma-separated summaries, with `?` for missing shirt numbers.
- [x] Keep player names inside roster/sheet selection rows while removing the redundant `Selected X` subtitle chrome.
- [x] Remove the manual-entry selected-numbers card and keep manual correction keypad-first.
- [x] Add empty-backspace support so manual entry pops the most recently committed number when the buffer is empty.
- [x] Keep `Confirm Subs` for single-pair substitutions only and bypass it for multi-pair batches.
- [x] Add focused watch-side tests for summaries, duplicate rejection, backspace undo, and confirmation gating.
- [x] Allow navigation-row subtitles to wrap to two lines so the hub can still display longer multi-number summaries on compact watch layouts.
