---
task_id: 01
plan_id: PLAN_watch_sync_feedback
plan_file: ../../plans/watch_sync_feedback/PLAN_watch_sync_feedback.md
title: Harden WatchConnectivity availability checks and message dispatch
phase: Phase 1 - Connectivity Reliability
---

## Objective
Ensure watch-originated sync traffic honours WCSession pairing/activation state and avoids duplicate deliveries by introducing a unified send helper with error-aware fallback.

## Scope
- Extend `WCSessioning`/`WCSessionWrapper` to surface `isPaired`, `isWatchAppInstalled`, and `activationState`.
- Update `WatchConnectivitySyncClient` availability guards and `flushAggregateDeltas()` to block dispatch until the session is paired, installed, and activated.
- Implement a reusable send routine that prefers `sendMessage` with explicit error handling and falls back to `transferUserInfo` only when necessary, logging outcomes.
- Wire the helper into `sendCompletedMatch`, manual sync requests, and aggregate delta flushing.

## Deliverables
- Updated connectivity abstraction and client implementation with reachability + activation gating.
- Structured logging/notification hooks describing when fallbacks occur and why.
- Initial unit tests (or scaffolding) covering reachable/unreachable/error scenarios for the new helper.
