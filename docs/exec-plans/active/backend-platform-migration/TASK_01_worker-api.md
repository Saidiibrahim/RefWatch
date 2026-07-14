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
- [ ] Add ownership, idempotency, contract, webhook, AI, event-reference, reference-catalog, cutover-validator, and rollback tests. Forty-seven tests across nine files pass, including query-aware event predicates, legacy match-sheet normalization/warnings and streaming bounds, strict 39-table/source-Auth-ID/identity-collision/disposition/relation validation, emergency write gating including auth-side provisioning suppression, and rollback-packet validation. A separate real-Postgres suite passes 3/3 for match-route concurrency/idempotency and focused tenant isolation; broader route-family and authenticated deployed coverage remain.
- [ ] Run API typecheck/tests, Wrangler types, and deploy dry-run. On 2026-07-14, typecheck, 47 tests across 9 files, staging dry-run/deploy, real Hyperdrive readiness, the complete six-migration disposable PlanetScale apply/readback, parser parity, emergency write-gate coverage, and rollback-packet validation passed. Production Hyperdrive/Worker deployment, authenticated staging CRUD/idempotency/AI/webhook coverage, final bundle/import, production environment, external mutation ledger/probe, guard-version upload/readback, and production apply remain.
