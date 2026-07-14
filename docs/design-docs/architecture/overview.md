# Architecture Overview

RefWatch is split into a primary watchOS experience with an optional iOS companion. Shared match logic lives in the core/watch stack, while the iOS companion owns the assistant and other phone-first surfaces.

## Backend Boundary

The active target backend architecture is Clerk + Cloudflare Workers/Hono + PlanetScale Postgres:

1. The iOS app signs in with Clerk and obtains a Clerk session token.
2. iOS sends the token to `api/` as `Authorization: Bearer <clerk-session-token>`.
3. Clerk middleware verifies the session and resolves the Clerk subject to an internal `app_users.id`.
4. The Worker derives `owner_id` from that internal identity for every user-scoped query and mutation.
5. The Worker reaches PlanetScale Postgres through Cloudflare Hyperdrive and calls OpenAI with server-side credentials.

SwiftUI never connects directly to PlanetScale. PlanetScale credentials, Clerk secret/JWT material, the Clerk webhook signing secret, and the OpenAI key must never enter the iOS bundle. `AuthState.currentUserId` may contain a Clerk subject string and must not be parsed as a UUID; local owner metadata uses the separately resolved internal app-user ID.

The architecture is in migration, not production cutover. As of 2026-07-14, the Worker workspace and active iOS composition/repositories route through Clerk and the backend API—including authenticated reference-catalog reads—and the app builds without Supabase configuration. The Supabase SDK/package dependency is removed. Staging Worker/Hyperdrive readiness and disposable 5/54 catalog readback passed; production deployment/data import/catalog apply-readback, full iOS test acceptance, and legacy Supabase-named repository/type/source-path cleanup remain incomplete. Supabase source and migration files are legacy evidence until cutover validation and rollback gates close.

## Layering
- **App Layer**: SwiftUI entry points and root views per platform.
- **Features**: MVVM-oriented folders for each domain area (Match, Timer, Events, etc.).
- **Core**: Cross-feature services, managers, protocols, and platform adapters (timer coordination, haptics, storage).
- **Assets**: Shared visual resources and previews.

## Cross-Target Sharing
- Watch target owns domain models and services; iOS reuses them via target membership.
- Platform adapters implement protocols (e.g., `HapticsProviding`) to avoid conditional imports in shared code.
- Shared timer/lifecycle code must stay free of direct WatchKit/UIKit haptic playback; shared layers emit semantic cues and platform adapters own playback policy.
- Assistant transport is iOS-only and routes through a server proxy rather than a watch-shared runtime service.
- Authentication and backend clients remain behind vendor-neutral protocol seams so Clerk/Hono details do not spread through feature code.
- SwiftData stays the offline-first local store; remote synchronization is additive and retryable.

## Key Workflows
- Match timer flow orchestrates period transitions, penalties, and haptics.
- Match history persists state for quick access on watch and optional sync to iOS.
- Assistant and match-sheet parsing are iOS-only and call authenticated Hono routes; the Worker streams or returns OpenAI responses without exposing the OpenAI key.
- watchOS match timing, haptics, and lifecycle logic do not depend on Clerk, PlanetScale, or Worker availability.

See `docs/design-docs/architecture/ios.md`, `docs/design-docs/architecture/watchos.md`, and `docs/references/backend-migration-cutover.md` for more detail.
