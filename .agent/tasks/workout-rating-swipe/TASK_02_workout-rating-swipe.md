---
task_id: 02
plan_id: PLAN_workout-rating-swipe
plan_file: ../../plans/workout-rating-swipe/PLAN_workout-rating-swipe.md
title: Design rating state and persistence flow
phase: Phase 2 - Architecture
---

### Objective
Define how the 0-10 difficulty score is stored, synced, and resurfaced across watch, iOS, and backend layers.

### Steps
- prototype `WorkoutSessionRatingState` ownership and lifecycle within `WorkoutSessionHostView`, including five-minute gating and saved-state transitions.
- specify persistence contract (local model, Supabase payload, migration requirements) plus how previously saved ratings repopulate for mid-session adjustments.
- outline auto-save trigger logic, crown focus handling to avoid TabView swipes, and lightweight confirmation feedback (haptic + fleeting label).

### Deliverable
Documented state diagram or notes appended to the ExecPlan covering gating, persistence, confirmation feedback, and acceptance criteria for auto-save behavior.
