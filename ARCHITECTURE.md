# Architecture

RefWatch is a watch-first product with an iOS companion app, sharing core domain logic and services.

## System Shape

- The Swift watchOS app owns in-match execution, continuity, and local recovery without depending on cloud availability.
- The Swift/SwiftUI iOS companion owns planning, analysis, and cloud-backed features. It uses SwiftData as its offline-first local store and synchronizes through backend repository adapters.
- Protected application traffic crosses an authenticated HTTP boundary to the Cloudflare Worker under `api/`. The iOS client sends a Clerk session token; watchOS does not connect directly to the Worker or cloud database.
- Hono owns Worker routing, middleware, request handling, and HTTP responses; route-local schemas validate request payloads.
- Drizzle ORM owns the typed PlanetScale Postgres schema and application data queries inside the Worker. Drizzle Kit generates and applies the SQL migrations under `api/src/db/migrations`.
- Deployed Worker runtime reaches PlanetScale Postgres through Cloudflare Hyperdrive. Local/direct runtime may fall back to `DATABASE_URL`; migration commands require a separate migration-role `DATABASE_URL`.

The deployed application-data path is:

```text
iOS Swift client -> Hono Worker API -> Drizzle ORM -> pg client -> Hyperdrive -> PlanetScale Postgres
```

## Security and Ownership Boundary

Swift clients are untrusted API clients. They may hold public app configuration and short-lived Clerk session tokens, but never database credentials, Clerk server or webhook secrets, or OpenAI credentials. For protected `/api/*` routes, the Worker verifies the Clerk session, resolves the Clerk subject to the internal `app_users.id`, and derives the authoritative `owner_id` server-side. Client-supplied ownership values are not trusted. Health routes and the signed Clerk webhook are separate public Worker surfaces.

## Migration Status

Clerk + Cloudflare Workers/Hono + Drizzle + PlanetScale Postgres is the active target architecture, not a completed production cutover. Staging Worker/Hyperdrive connectivity and disposable PlanetScale migration rehearsal have passed. Production deployment, identity and data migration/reconciliation, authenticated end-to-end proof, compatibility cleanup, and physical-device acceptance remain gated by the active backend migration plan and cutover runbook.

## Where To Read
- Canonical architecture index: `docs/design-docs/index.md`
- Core architectural beliefs: `docs/design-docs/core-beliefs.md`
- System breakdown: `docs/design-docs/architecture/overview.md`
- Platform details: `docs/design-docs/architecture/watchos.md` and `docs/design-docs/architecture/ios.md`
- Shared services: `docs/design-docs/architecture/shared-services.md`
- Backend implementation and operations: `api/README.md`
- Active backend migration state: `docs/exec-plans/active/backend-platform-migration/PLAN_backend-platform-migration.md`
- Migration and production cutover gates: `docs/references/backend-migration-cutover.md`
- Source and target database evidence: `docs/generated/db-schema.md`

## Working Rule
All architecture changes must update the relevant design doc and, when non-trivial, be tracked in an active exec plan under `docs/exec-plans/active`.
