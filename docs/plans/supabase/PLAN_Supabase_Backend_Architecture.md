# PLAN — Supabase Backend End‑State Architecture

This document describes the target architecture for using Supabase as the backend for RefWatch, and how it integrates with the iOS and watchOS apps, native Supabase auth, StoreKit 2 (purchases), SwiftData/CloudKit (local and iCloud sync), and WatchConnectivity.

> **Status Update (Mar 2025):** Clerk has been removed from the mobile stack. Supabase GoTrue now issues the JWTs used across repositories and functions. Any Clerk references below reflect the original rollout plan and remain for archival purposes.

## Goals
- Establish a Supabase foundation that keeps entitlements server‑sourced, with enough schema flexibility to introduce tiered plans later (only the free tier is active today).
- Offline‑first UX on both iOS and watchOS; graceful degradation when offline.
- Clear separation of roles: iOS owns identity and purchase flows; watchOS stays lightweight and network‑independent.
- Optional server ingestion for analytics/sharing without disrupting local ownership of data.
- Privacy by default: upload minimal summaries unless user opts in to richer analytics.

## Current Implementation Snapshot
- `SupabaseEnvironment` now guards configuration loading and normalizes URL/keys before constructing the SDK client.
- `SupabaseClientProvider` centralizes client creation, injects the publishable key, and wires in auth callbacks.
- `SupabaseAuthController` now owns session management and exposes tokens directly via Supabase GoTrue, eliminating the bridge to Clerk.
- `SupabaseHelloWorldService` and its XCTest validate that an authorized client can read from the `todos` table, proving round‑trip connectivity.
- Settings surface this diagnostic, giving us a live health check while we roll out the real schema.
- Broader table design now lives in `PLAN_Supabase_Database_Schema.md`; use that roadmap when adding new migrations.
- Edge-function implementation guidance sits in `edge_functions/README.md`; functions are deployed directly in Supabase when ready.

## Stack Overview
- watchOS App (offline‑first)
  - Core officiating: timers, events, local persistence (JSON today; SwiftData later).
  - No direct Clerk/StoreKit usage. Receives an “entitlements snapshot” from iPhone and gates features locally.
  - Sends completed match snapshots to iPhone via WatchConnectivity.

- iOS App (identity, purchases, persistence, sync)
  - Identity: Clerk SDK; exposes `AuthenticationProviding` (`ownerId = clerk_user_id`) and adds a lightweight `TokenProviding` helper that can supply a fresh third-party session token via `session.getToken()` when networking with Supabase.
  - Purchases: StoreKit 2 for subscriptions; sends signed transactions to backend for validation.
  - Persistence: SwiftData `CompletedMatchRecord` (primary), optional CloudKit Private DB for same-user cross-device sync.
  - Sync: WatchConnectivity receiver; tags incoming snapshots with `ownerId`, persists, and notifies UI.
  - Network: Calls Supabase Edge Functions with third-party session tokens (via `SupabaseTokenProvider`) for entitlements, IAP verification, and optional analytics ingestion.
  - AI (Responses): Calls `/ai/*` endpoints to create/list threads and stream responses using the Responses API; messages persist in Postgres (`ai_threads`, `ai_messages`).
  - Entitlements distribution: Pushes a compact entitlements snapshot to watch via `WCSession` whenever it changes.

- Supabase Backend (source of truth for entitlements)
  - Postgres with RLS; Edge Functions (Deno) that verify third-party Clerk session tokens and interact with App Store Server API.
  - Tables for `users`, `entitlements`, optional `matches_summary` and `share_links`.
  - Webhooks for App Store Server Notifications (renewals, revocations) and optional Clerk events.
  - Mirrors plan to Clerk `publicMetadata` for quick client reflection (optional nicety).

## Identity & Entitlements
- Identity Source: Clerk on iOS; device holds a Clerk session and exposes `currentUserId` via `AuthenticationProviding`.
- Token Transport: `SupabaseTokenProvider` calls the third‑party session manager (`try await Clerk.shared.session?.getToken()?.jwt`) and injects the bearer token into Supabase requests. No Supabase Auth sessions are created on-device.
- Entitlements Source of Truth: Supabase `user_entitlements` table (name pending final schema).
  - iOS completes StoreKit purchase → sends transaction JWS + Clerk session token to `/iap/verify`.
  - Edge Function verifies with App Store Server API → upserts the entitlement row → returns `EntitlementsSnapshot` (current tier, feature flags, expiresAt) even though only the free tier is active today.
  - Edge endpoints validate the Clerk session token using Clerk's backend helpers/JWKS, ensuring we never accept an unsigned or expired third‑party token.
  - Supabase secrets store the Clerk verification keys and allowed origins so token checks run locally in the function environment.
  - Entitlement tiers should be modeled explicitly (`subscription_tier` enum + optional `expires_at`) so future paid plans only require configuration changes.
  - iOS caches the snapshot with TTL and pushes it to the watch.

### Entitlements Snapshot (client-side cache, also sent to watch)
Minimal, signed or unsigned depending on needs. For now `plan` is always `free`, but the shape should already accommodate upgrades:
```json
{
  "plan": "free",
  "features": [],
  "issuedAt": "2025-09-08T10:00:00Z",
  "expiresAt": "2026-09-08T10:00:00Z",
  "ttlSeconds": 604800
}
```
Notes:
- Cache in `UserDefaults` (App Group if needed), honor `ttlSeconds` with a short grace period offline.
- The watch only ever sees this snapshot; it never talks to Clerk or Supabase.
- Consider attaching a lightweight signature (`HMAC(snapshot, sharedKey)` or checksum) so the watch can reject tampered payloads. Key material can live inside the phone app; the watch only validates the MAC.
- Define downgrade rules: if `expiresAt` + grace is exceeded, watch reverts to Free entitlements until a fresh snapshot arrives.

## Data & Persistence
- iOS (primary local store): SwiftData `CompletedMatchRecord` with `ownerId` tagging (already implemented).
- Cloud sync (optional): SwiftData + CloudKit Private DB for same‑user, Apple‑ID–scoped sync.
- watchOS: local JSON today; planned migration to SwiftData when ready.
- Backend ingestion (optional): periodically upload match summaries keyed by `ownerId` for trends/sharing.
  - Prefer summary rows in Postgres (`jsonb` fields for flexible metrics). Store full payloads in Supabase Storage only with explicit opt‑in.

## Platform Responsibilities
- watchOS
  - Runs all officiating flows offline.
  - Applies entitlements from iOS snapshot to gate features (e.g., Advanced Timers) only when the snapshot signature/TTL checks pass.
  - Exports completed matches to iOS via WatchConnectivity (foreground or background transfer).

- iOS
  - Configures Clerk; exposes `ClerkAuth` via `AuthenticationProviding`.
  - Fetches a fresh Clerk session token on each Supabase call (or caches per minute via `session.getToken()`), attaches it as `Authorization`.
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

> **Note:** This high-level sketch is kept for entitlements context. The full
> schema roadmap (teams, scheduled matches, analytics, etc.) is detailed in
> `PLAN_Supabase_Database_Schema.md` and should drive upcoming migrations.

Enable Row Level Security (RLS); functions verify Clerk JWT and set `request.user_id` based on `clerk_user_id` mapping.

Lifecycle guardrails:
- `users` upsert runs whenever `/entitlements` or `/iap/verify` sees a new `clerk_user_id`; missing rows are created on the fly with metadata from Clerk.
- Enforce a unique constraint on `clerk_user_id` and surface 409s if two accounts race to use the same identifier.
- `entitlements` writes always include `user_id` from the `users` mapping so RLS stays effective; deletes or Clerk webhooks clean up the pair.

### Clerk JWT verification strategy
- All edge functions run with `verify_jwt = false` in `config.toml`; they manually authenticate incoming requests using Clerk session JWTs.
- Use `@clerk/backend`’s `verifyToken` (or a `jose` JWKS verifier) to avoid hitting Clerk on every call and to enforce the latest claim validation guidance.
- Reject any request that fails token verification before touching Postgres or the App Store Server API.
- Map `claims.sub` to `clerk_user_id` → `users.id`; if mapping is missing, create the row and resume with the same transaction for consistency.

### Edge Functions (Deno)
- `GET /entitlements`
  - Verify Clerk JWT via Clerk JWKS.
  - Resolve `clerk_user_id` → `users.id` → return current entitlements snapshot.

- `POST /iap/verify`
  - Input: StoreKit transaction JWS + Clerk JWT.
  - Validate with App Store Server API (environment aware).
    - Keep sandbox vs production endpoints keyed by app build config; store private key + issuer ID + bundle ID as Supabase secrets.
    - Use `originalTransactionId` to enforce idempotency and log App Store outages; retry with backoff when Apple is down.
  - Upsert `entitlements` (plan/status/expires_at), return snapshot.
  - Optionally call Clerk Admin API to set `publicMetadata.plan` and `expiresAt`.
  - Emit structured telemetry (duration, Apple error codes) so the client can surface retry guidance when validation is delayed.
- Keep implementation notes in `edge_functions/README.md`; source code lives in
  the Supabase project once we are ready to deploy.

- `POST /matches/ingest` (optional)
  - Input: compact match summary (or storage path to full payload).
  - Idempotent by match `id` to avoid duplicates.

- `GET /ai/threads`
  - Verify Clerk JWT → list threads by owner.
  - Paginated results ordered by `last_activity_at desc`.

- `POST /ai/threads`
  - Create a thread (optional title/instructions/model/temperature/metadata).
  - Return created thread.

- `GET /ai/threads/:id/messages`
  - Owner check → return messages ordered by `created_at asc`.

- `POST /ai/threads/:id/messages`
  - Append a user message; optionally kick off Responses streaming.

- `POST /ai/threads/:id/responses`
  - Call OpenAI Responses API; stream events to client and persist an assistant message with multi‑part `content_parts` and usage. Update `ai_usage_daily` and `ai_threads.last_activity_at`.

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
   - Edge fetch includes `Authorization: Bearer <ClerkSessionToken>`; fetch a fresh token if the cached one is older than ~60s to mirror Clerk guidance.

2) Purchase (iOS)
   - Complete StoreKit purchase → Send transaction JWS + Clerk session token to `/iap/verify` → Backend validates and updates DB → Returns snapshot → Cache + push to watch → Update UI.
   - Ensure outgoing call refreshes the Clerk token immediately post-purchase so revoked sessions cannot reuse stale tokens.

3) Complete Match (watch → iOS)
   - Watch exports snapshot → iOS tags `ownerId` and saves SwiftData → (Optional) enqueue summary upload to `/matches/ingest`.

4) Sign‑In/Out (iOS)
   - Sign‑in sets `ownerId` for future saves; optionally backfill existing SwiftData rows missing `ownerId`.
   - Sign‑out keeps local data; entitlements revert to Free after TTL/grace.

## Offline, Caching, Resilience
- Everything functions offline: watch officiating, iOS history, and gating via cached snapshot.
- Entitlements: TTL with grace (e.g., 3–7 days) to avoid punishing subscribers without connectivity. Even with a single tier today, keep the refresh flow identical so paid tiers can drop in later.
- Watch fallbacks: if no valid snapshot is present, gate any paid-only features automatically (future) and surface a subtle prompt to reconnect for refreshed entitlements.
- Idempotency: Use match UUIDs for ingestion; guard duplicate uploads.
- CloudKit: optional, for Apple‑ID sync of SwiftData; independent of Supabase.

## Security & Privacy
- Client→Backend: `Authorization: Bearer <ClerkSessionToken>` obtained by `SupabaseTokenProvider`; verify in functions via Clerk JWKS.
- Edge functions reject unauthenticated calls before touching Postgres/App Store APIs; no public PostgREST routes expose entitlement tables.
- Never ship Supabase service role keys in the app; keep secrets server-side.
- RLS: restrict rows by `user_id`; map `clerk_user_id` to `users.id` per request.
- PII minimization: upload summaries by default; full payload uploads only with explicit user consent.
- Optional hardening: DeviceCheck/App Attest checks before honoring remote entitlements.

## Environments & DevOps
- Separate Supabase projects for dev/stage/prod; Xcode schemes select the Functions base URL.
- Observability: Supabase logs/metrics; Sentry for client crashes; OSLog for connectivity/debug.
- Schema migrations: versioned SQL; CI applies migrations to dev and runs integration checks.
- Secrets management: store `CLERK_SECRET_KEY`, `CLERK_JWT_KEY`, App Store private keys, and environment-specific origins as Supabase secrets; never embed them in configs checked into git.

## Incremental Adoption Plan
1) App Foundation (in progress)
   - Harden `SupabaseClientProvider` diagnostics (already landed) and surface Settings‑level status (done).
   - Add lightweight Observability (`OSLog`, metrics) around Supabase calls to catch token/URL issues early.
2) Database & Auth Bootstrap (next)
   - Create `users` table keyed by Clerk `user_id` with columns for `subscription_tier` (enum: `free`, `pro_future`) and optional `tier_expires_at`.
   - Create `user_entitlements` (or merge into `users`) storing the cached entitlements payload plus audit timestamps.
   - Add Row Level Security policies mapping Clerk `sub` → `users.id` once verification is wired.
3) Read APIs & Edge Functions
   - Ship `GET /entitlements` Edge Function that verifies Clerk session tokens and returns the canonical snapshot (even if it only returns the free tier for now).
   - Introduce `/diagnostics/ping` that the Settings check can call instead of the public `todos` table once the schema is in place.
   - Add Assistant: `GET/POST /assistant/threads`, `GET/POST /assistant/threads/:id/messages`, `POST /assistant/threads/:id/stream` with OpenAI first.
4) Purchase Flow Prep
   - Scaffold `/iap/verify` endpoint (stub App Store calls) so the client path is ready when StoreKit integration starts.
   - Store verification results in `iap_transactions` with foreign keys to `users`.
5) Optional Analytics Foundation
   - Define `match_summaries` table with `owner_id`, `period_count`, `total_penalties`, etc. Keep ingestion opt‑in and minimized.
6) Sync Enhancements (later)
   - Enable CloudKit Private DB for SwiftData once entitlements + purchases stabilize.

---

This plan preserves the current offline‑first experience, adds clean entitlements with server‑side truth, and keeps watchOS simple by consuming a compact, time‑bounded snapshot from iOS.
