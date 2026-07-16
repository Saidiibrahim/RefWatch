---
task_id: 01
plan_id: PLAN_backend-platform-migration
plan_file: ./PLAN_backend-platform-migration.md
title: Build the authenticated Worker API and PlanetScale Postgres schema
phase: Phase 1 - Backend
---

- [x] Create the Hono/Workers workspace, Drizzle Postgres schema/migration, and initial Vitest harness.
- [x] Add Clerk bearer middleware, internal app-user resolution, `/api/me`, and signed Clerk webhook handling.
- [x] Port match ingest/read/delete, schedule, assessment, and library routes with server-derived ownership; apply the API review fixes for assessment/reference ownership, JSONB serialization, idempotency, and deletion sync.
- [x] Port authenticated, season-bounded reference-catalog reads plus the portable idempotent 2026 seed (5 competitions, 54 teams).
- [x] Port assistant streaming and match-sheet parsing with server-side OpenAI access. Routes and OpenAI bounds exist; the legacy portable match-sheet prompt, strict schema, refusal/incomplete handling, field normalization, dropped-row warnings, deduplication, and ordering contract now have Worker tests. Authenticated deployed calls remain part of release acceptance.
- [x] Add focused ownership, idempotency, contract, webhook, AI, event-reference, reference-catalog, encrypted cutover-validator, candidate-snapshot, onboarding, rollback, mutation-group ordering, envelope-bound, key-rotation, and mutation-ledger tests. Seventy-eight tests across fourteen files pass. Real-Postgres suites pass 19/19 across three files, including oversized insert/update transactional rollback, match-route isolation/idempotency, receipt/registry activation, identity serialization, transactional capture/freeze, effective trigger installation, immutable events, fenced delivery, retained-key recovery, retry, and quarantine.
- [ ] Complete broader route-family and Clerk-authenticated deployed coverage, including the production health/auth/tenant-isolation/CRUD/idempotency/AI/match-sheet/webhook matrix.
- [x] Run API typecheck/78 tests, Wrangler types/dry-run, production PlanetScale apply/readback, exact 5/54 seed verification, read-only runtime-role/local config readiness, Hyperdrive control-plane readback, write-gate coverage, production Queue/DLQ/D1/local-key provisioning, and secure production Clerk/OpenAI secret installation. Production Worker `e966d6df-b5ff-4288-832c-c8d91e00ce48` is unrouted, write-disabled, has preview URLs disabled, and has no cron/Queue consumers. Its Clerk issuer and regenerated publishable-key pins match verified owned domain `refwatch.ibby.ai`. Localhost production-config probes against the exact role returned health/readiness 200 and API/webhook write denial 503.
- [ ] Complete organizational key escrow/recovery, separately approved functional production ledger activation/probe, authenticated deployed route coverage, final bundle/import, webhook signing-secret custody, guard-version upload/readback, and later approved traffic/write cutover.
