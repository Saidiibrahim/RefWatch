---
task_id: 01
plan_id: PLAN_match-lifecycle-haptics
plan_file: ./PLAN_match-lifecycle-haptics.md
title: Implement semantic match lifecycle haptics and synchronized validation/docs
phase: Implementation
---

- [x] Add `MatchLifecycleHapticsProviding`, semantic lifecycle cue cases, and a noop implementation in `RefWatchCore`.
- [x] Inject lifecycle haptics into `TimerManager` and `MatchViewModel`.
- [x] Persist halftime-expiry cue dedupe in `TimerManager.PersistenceState`.
- [x] Replace shared `TimerManager` direct watch playback with lifecycle cue requests.
- [x] Add watchOS repeated-sequence adapter (`3 x 0.4s`) with centralized cancellation and fakeable scheduler seam.
- [x] Add iOS lifecycle adapter with conservative one-shot boundary playback and no halftime-expiry playback.
- [x] Repair the stale natural-boundary test and add semantic lifecycle haptics coverage in core tests.
- [x] Add watch adapter tests for repeated scheduling and cancellation.
- [x] Remove the unsafe injected-`MatchViewModel` `MatchRootView` seam so watch-owned lifecycle/runtime/persistence wiring is always applied.
- [x] Add focused watch restore coverage proving a persisted `didRequestHalftimeDurationCue` does not replay on relaunch.
- [x] Update architecture, product, testing, process, release, and launch docs to match the new ownership split.
- [x] Sync active exec-plan evidence with the closure-batch reruns and remaining baseline simulator/core blockers.
