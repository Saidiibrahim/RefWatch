---
task_id: 03
plan_id: PLAN_workout-rating-swipe
plan_file: ../../plans/workout-rating-swipe/PLAN_workout-rating-swipe.md
title: Implement rating UI, integration, and tests
phase: Phase 3 - Implementation
---

### Objective
Ship the minimalist rating dial, wire it into the session host, and validate with automated tests.

### Steps
- replace `WorkoutSessionMediaPage` with `WorkoutSessionRatingPage` and remove unused media code.
- build the crown-driven dial UI and auto-save acknowledgement animation.
- extend data models, add tests, and run watchOS simulator smoke checks.

### Deliverable
Merged code implementing the new swipe-right experience with passing tests and updated release notes.
