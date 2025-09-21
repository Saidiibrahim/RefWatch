# PLAN — Supabase Backend End‑State Architecture

This document describes the target architecture for using Supabase as the backend for RefWatch, and how it integrates with the iOS and watchOS apps, Clerk (auth), StoreKit 2 (purchases), SwiftData/CloudKit (local and iCloud sync), and WatchConnectivity.

## Goals
- Canonical, server‑side entitlements validated against Apple’s App Store Server API.
- Offline‑first UX on both iOS and watchOS; graceful degradation when offline.
- Clear separation of roles: iOS owns identity and purchase flows; watchOS stays lightweight and network‑independent.
- Optional server ingestion for analytics/sharing without disrupting local ownership of data.
- Privacy by default: upload minimal summaries unless user opts in to richer analytics.

## Stack Overview
- watchOS App (offline‑first)
  - Core officiating: timers, events, local persistence (JSON today; SwiftData later).
  - No direct Clerk/StoreKit usage. Receives an “entitlements snapshot” from iPhone and gates features locally.
  - Sends completed match snapshots to iPhone via WatchConnectivity.

- iOS App (identity, purchases, persistence, sync)
  - Identity: Clerk SDK; exposes `AuthenticationProviding` (`ownerId = clerk_user_id`).
  - Purchases: StoreKit 2 for subscriptions; sends signed transactions to backend for validation.
  - Persistence: SwiftData `CompletedMatchRecord` (primary), optional CloudKit Private DB for same‑user cross‑device sync.
  - Sync: WatchConnectivity receiver; tags incoming snapshots with `ownerId`, persists, and notifies UI.
  - Network: Calls Supabase Edge Functions with Clerk JWT for entitlements, IAP verification, and (optional) analytics ingestion.
  - Entitlements distribution: Pushes a compact entitlements snapshot to watch via `WCSession` whenever it changes.

- Supabase Backend (source of truth for entitlements)
  - Postgres with RLS; Edge Functions (Deno) that verify Clerk JWTs and interact with App Store Server API.
  - Tables for `users`, `entitlements`, optional `matches_summary` and `share_links`.
  - Webhooks for App Store Server Notifications (renewals, revocations) and optional Clerk events.
  - Mirrors plan to Clerk `publicMetadata` for quick client reflection (optional nicety).

## Identity & Entitlements
- Identity Source: Clerk on iOS; device holds a Clerk session and exposes `currentUserId` via `AuthenticationProviding`.
- Entitlements Source of Truth: Supabase `entitlements` table.
  - iOS completes StoreKit purchase → sends transaction JWS + Clerk JWT to `/iap/verify`.
  - Edge Function verifies with App Store Server API → upserts `entitlements` row → returns `EntitlementsSnapshot` (plan, features, expiresAt).
  - Edge Function may update Clerk `publicMetadata.plan` to reflect plan quickly in the UI.
  - iOS caches the snapshot with TTL and pushes it to the watch.

### Entitlements Snapshot (client‑side cache, also sent to watch)
Minimal, signed or unsigned depending on needs:
```json
{
  "plan": "pro",
  "features": ["advancedTimers", "richAnalytics"],
  "issuedAt": "2025-09-08T10:00:00Z",
  "expiresAt": "2026-09-08T10:00:00Z",
  "ttlSeconds": 604800
}
```
Notes:
- Cache in `UserDefaults` (App Group if needed), honor `ttlSeconds` with a short grace period offline.
- The watch only ever sees this snapshot; it never talks to Clerk or Supabase.

## Data & Persistence
- iOS (primary local store): SwiftData `CompletedMatchRecord` with `ownerId` tagging (already implemented).
- Cloud sync (optional): SwiftData + CloudKit Private DB for same‑user, Apple‑ID–scoped sync.
- watchOS: local JSON today; planned migration to SwiftData when ready.
- Backend ingestion (optional): periodically upload match summaries keyed by `ownerId` for trends/sharing.
  - Prefer summary rows in Postgres (`jsonb` fields for flexible metrics). Store full payloads in Supabase Storage only with explicit opt‑in.

## Platform Responsibilities
- watchOS
  - Runs all officiating flows offline.
  - Applies entitlements from iOS snapshot to gate features (e.g., Advanced Timers).
  - Exports completed matches to iOS via WatchConnectivity (foreground or background transfer).

- iOS
  - Configures Clerk; exposes `ClerkAuth` via `AuthenticationProviding`.
  - Manages StoreKit purchase UI, sends transactions to backend for verification.
  - Persists snapshots to SwiftData; tags with `ownerId` on save/import.
  - Receives and merges watch snapshots; posts `.matchHistoryDidChange` for UI.
  - Retrieves entitlements from Supabase; caches and pushes snapshot to watch.

## Supabase Backend Details
### Tables (sketch)
- `users`: `id uuid pk`, `clerk_user_id text unique`, `created_at timestamptz`
- `entitlements`: `id uuid pk`, `user_id uuid fk`, `plan text`, `status text`, `expires_at timestamptz`, `updated_at timestamptz`
- `matches_summary` (optional): `id uuid pk`, `user_id uuid fk`, `completed_at timestamptz`, `home text`, `away text`, `scores jsonb`, `metrics jsonb`, `payload_hash text`, `created_at timestamptz`
- `share_links` (optional): `id uuid pk`, `resource_id uuid`, `token text`, `expires_at timestamptz`, `created_at timestamptz`

Enable Row Level Security (RLS); functions verify Clerk JWT and set `request.user_id` based on `clerk_user_id` mapping.

### Edge Functions (Deno)
- `GET /entitlements`
  - Verify Clerk JWT via Clerk JWKS.
  - Resolve `clerk_user_id` → `users.id` → return current entitlements snapshot.

- `POST /iap/verify`
  - Input: StoreKit transaction JWS + Clerk JWT.
  - Validate with App Store Server API (environment aware).
  - Upsert `entitlements` (plan/status/expires_at), return snapshot.
  - Optionally call Clerk Admin API to set `publicMetadata.plan` and `expiresAt`.

- `POST /matches/ingest` (optional)
  - Input: compact match summary (or storage path to full payload).
  - Idempotent by match `id` to avoid duplicates.

### Webhooks
- App Store Server Notifications v2 → updates `entitlements` on renew/cancel/refund.
- Optional Clerk webhooks (user created/deleted) → keep `users` in sync.

## Feature Gating in App Code
- Single seam: `EntitlementsProviding { var plan: Plan; func has(_ feature: Entitlement) -> Bool }`.
- iOS: `CompositeEntitlementsProvider` resolves from StoreKit (local) and remote snapshot (Supabase); caches results.
- watchOS: `SnapshotEntitlementsProvider` using only the pushed snapshot.
- Gate at feature boundaries (view/VM entry points), not deep in helpers.

## Core Flows
1) App Launch (iOS)
   - Configure Clerk → Build SwiftData container → Load cached entitlements → Fetch `/entitlements` in background → Push snapshot to watch if changed.

2) Purchase (iOS)
   - Complete StoreKit purchase → Send transaction JWS + Clerk JWT to `/iap/verify` → Backend validates and updates DB → Returns snapshot → Cache + push to watch → Update UI.

3) Complete Match (watch → iOS)
   - Watch exports snapshot → iOS tags `ownerId` and saves SwiftData → (Optional) enqueue summary upload to `/matches/ingest`.

4) Sign‑In/Out (iOS)
   - Sign‑in sets `ownerId` for future saves; optionally backfill existing SwiftData rows missing `ownerId`.
   - Sign‑out keeps local data; entitlements revert to Free after TTL/grace.

## Offline, Caching, Resilience
- Everything functions offline: watch officiating, iOS history, and gating via cached snapshot.
- Entitlements: TTL with grace (e.g., 3–7 days) to avoid punishing subscribers without connectivity.
- Idempotency: Use match UUIDs for ingestion; guard duplicate uploads.
- CloudKit: optional, for Apple‑ID sync of SwiftData; independent of Supabase.

## Security & Privacy
- Client→Backend: `Authorization: Bearer <ClerkJWT>`; verify in functions via Clerk JWKS.
- Never ship Supabase service role keys in the app; keep secrets server‑side.
- RLS: restrict rows by `user_id`; map `clerk_user_id` to `users.id` per request.
- PII minimization: upload summaries by default; full payload uploads only with explicit user consent.
- Optional hardening: DeviceCheck/App Attest checks before honoring remote entitlements.

## Environments & DevOps
- Separate Supabase projects for dev/stage/prod; Xcode schemes select the Functions base URL.
- Observability: Supabase logs/metrics; Sentry for client crashes; OSLog for connectivity/debug.
- Schema migrations: versioned SQL; CI applies migrations to dev and runs integration checks.

## Incremental Adoption Plan
1) App: Add `EntitlementsProviding` and gate one “Pro” feature (e.g., Advanced Timers). Cache snapshot; push to watch.
2) Backend: Implement `GET /entitlements` with Clerk JWT verification; add `users`/`entitlements` tables.
3) Purchases: Implement `POST /iap/verify` (App Store Server API) and App Store Server Notifications; mirror plan to Clerk `publicMetadata`.
4) Optional: `POST /matches/ingest` for analytics; add basic trends dashboard later.
5) Optional: Enable CloudKit Private DB for SwiftData to sync personal history across the user’s devices.

---

This plan preserves the current offline‑first experience, adds clean entitlements with server‑side truth, and keeps watchOS simple by consuming a compact, time‑bounded snapshot from iOS.

