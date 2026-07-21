# RefWatch

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-watchOS%20%7C%20iOS-blue.svg)](https://developer.apple.com/watchos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-26.2-147EFB.svg?logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![Cloudflare Workers](https://img.shields.io/badge/Cloudflare-Workers-F38020.svg?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/workers/)
[![Clerk](https://img.shields.io/badge/Clerk-Authentication-6C47FF.svg)](https://clerk.com/docs)
[![PlanetScale](https://img.shields.io/badge/PlanetScale-Postgres-000000.svg?logo=planetscale&logoColor=white)](https://planetscale.com/docs/postgres)
[![OpenAI](https://img.shields.io/badge/OpenAI-Responses_API-412991.svg?logo=openai&logoColor=white)](https://platform.openai.com/docs/api-reference/responses)

<table align="center">
  <tr>
    <td><img src="docs/images/screenshots/iphone/iphone-3.png" alt="iPhone App" height="400"></td>
    <td><img src="docs/images/screenshots/watch/refzone-watch.png" alt="Watch App" height="400"></td>
  </tr>
</table>

A watchOS-first app designed for football/soccer referees to manage matches efficiently. The Apple Watch app is production-ready for on-pitch use, while the companion iOS app provides match library management, live mirroring, and post-match review.

## Table of Contents

- [RefWatch](#refwatch)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
    - [Match Timer Management](#match-timer-management)
    - [Match Events Recording](#match-events-recording)
    - [Match Configuration](#match-configuration)
    - [Match Library (iOS)](#match-library-ios)
  - [Tech Stack](#tech-stack)
  - [Quick Start](#quick-start)
  - [Post-clone setup](#post-clone-setup)
    - [Prerequisites](#prerequisites)
    - [Setup](#setup)
  - [Architecture](#architecture)
  - [Documentation](#documentation)
  - [Contributing](#contributing)
  - [Security](#security)
  - [License](#license)

## Features

### Match Timer Management
- Start/pause/resume match timing with haptic feedback
- Automatic period tracking with configurable durations
- Half-time countdown
- Extra time and stoppage time support
- Penalty shootout mode

### Match Events Recording
- Goals (with goal type: open play, penalty, own goal)
- Yellow and red cards with reason tracking
- Substitutions
- Team-specific event attribution

### Match Configuration
- Customizable match duration (e.g., 45, 40, 35 min halves)
- Adjustable number of periods
- Half-time length settings
- Extra time and penalties options
- Save match templates for quick setup

### Match Library (iOS)
- Team management
- Competition/league organization
- Venue tracking
- Match history with full event logs

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| UI Framework | SwiftUI | Declarative UI for watchOS and iOS |
| Local Storage | SwiftData | On-device persistence |
| Backend API | [Cloudflare Workers](https://developers.cloudflare.com/workers/) + Hono | Authenticated sync and server-side integrations |
| Cloud Database | [PlanetScale Postgres](https://planetscale.com/docs/postgres) via Hyperdrive | Match sync, team library, user data |
| Authentication | [Clerk](https://clerk.com/docs) | Native iOS sign-in and session tokens |
| AI Assistant | [OpenAI Responses API](https://platform.openai.com) | Match analysis and referee assistance |

The watch-first match runtime and local SwiftData stores remain offline-first. When cloud sync is enabled, iOS obtains a Clerk session token and calls the Worker with `Authorization: Bearer <clerk-session-token>`. Only the Worker can access PlanetScale or OpenAI.

> Greenfield launch status (authorized 2026-07-20): the active iOS composition
> builds and routes cloud-backed features, including reference-catalog reads,
> through Clerk and `BackendAPIClient`. The exact production Clerk instance is
> `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, its domain is `refwatch.ibby.ai`, and its
> issuer/Frontend API is `https://clerk.refwatch.ibby.ai`. The historical
> Supabase inventory (43 Auth identities, 42 profiles, 1,106 application rows,
> including `testing@refwatch.com`) is disposable and will not be imported or
> mapped. Production must start from zero app users, zero legacy mappings, and
> zero user-owned rows while preserving the exact deterministic global reference
> seed reviewed from repository sources. Migration `0016` and a separate
> least-privilege read/write-data role/Hyperdrive pair are now prepared with
> exact schema/clean-seed/inactive-ledger readbacks and both mutation modes
> disabled; both mandatory preparation reviewers returned `NO FINDINGS`.
> Distinct disabled/accepted Worker candidates plus guard/LKG deployment and
> later acceptance remain open. The active v2 packet carries exact,
> digest-checked sanitized A/B `wrangler versions view --json` receipts and
> recomputes their equal code/stable-binding lineage against the approved
> production binding and secret-name allowlist. Its non-disclosing
> `worker.secret_lineage` binds stdin installation of only newly required/
> changed secrets (at least webhook signing and cutover acceptance) to final
> source version S, which preserves unchanged existing bindings, then records
> operator-confirmed sequential S→A→B uploads bounded by provider history.
> Sanitized A/B readbacks expose exactly the six allowed secret names/types.
> S is bounded by its exact ID/time, the required-name operator confirmation,
> documented Wrangler preservation, and provider version history; zero
> intervening versions/secret mutations/upload overrides and
> `secret_values_recorded=false` are required. This is not a cryptographic
> parent-link or secret-value equality claim, and the deferred ledger key is
> neither recovered nor rotated. The provider sequence must
> publicly route A=100%/B=0% and prove exact-version health/readiness, auth rejection,
> retryable API/webhook denial, and zero mutations. B must be reachable for bounded
> automation only through a Cloudflare version override protected by an
> exact Cloudflare Access `service_auth` policy on
> `api.refwatch.ibby.ai/api/*` with one service token and zero bypass, plus the
> server-side `CUTOVER_ACCEPTANCE_TOKEN` header gate; the token is never an iOS
> or evidence value. Guard G and last-known-good L are each temporarily
> deployed at 100%; canonical provider readbacks/timestamps bracket each probe
> inside the rollback window, complete by validation time, use the same initial
> route with unique receipts, and require G-after < L-before before final A
> proof. The bounded webhook lifecycle records `manual_signed_harness`, exact
> override/token header names and presence, plus valid/invalid signature
> outcomes; it is not Clerk-provider delivery. Passing automation promotes B to 100% with no
> competing version while `/api/*` Access stays active. Clerk must then deliver
> the exact three-event lifecycle directly to promoted B without an override or
> cutover token, including retry/delete-wins and zero-count cleanup. Only after
> that proof may a provider-bound Access-removal receipt and deployment history
> precede physical devices exercising B. Production acceptance follows
> device/release evidence and ends with an
> inactive-ledger/zero-consumer readback.
> Current beta.3 preparation proof is 108/108 focused, 268/268 unit, 23/23
> database, and 19/19 mounted-route tests; typecheck, Node syntax, Wrangler
> types, production dry-run, mutation coverage, focused iOS cursor tests, and
> unsigned Release/Debug builds pass. Migration `0017` adds a Clerk profile
> event-time watermark locally and remains unapplied in production; `.projects`
> remains excluded wholesale from source control.
> Ledger escrow, recovery, and activation
> are deferred; launch evidence requires zero preparing, open, or
> capture-enforced epochs and zero Queue, cron, or D1 consumers, not absence of
> provisioned ledger resources. The full provider cutover is authorized but is
> not represented here as completed. Initial rollback may stop traffic/writes,
> route to a write-disabled Worker, restore Worker/client versions,
> reset/reseed PlanetScale, recreate test identities, and rerun the launch.
> Secrets remain server-side/non-disclosing, and commits or publishing require a
> separate request. See [Backend migration and
> cutover](docs/references/backend-migration-cutover.md).

## Quick Start

## Post-clone setup

- Run `./scripts/setup.sh` to generate `RefWatchiOS/Config/Config.xcconfig` with your Team ID, bundle prefix, app group, and URL scheme (local-only, gitignored).
- Production cloud configuration is authorized, but this quick start is not the
  operator procedure. Populate `RefWatchiOS/Config/Secrets.xcconfig` only after
  the authoritative Apple identifiers, native registration, and release
  configuration destination are resolved and recorded. Follow the cutover
  runbook.

### Prerequisites

- **Xcode 16+** minimum for the iOS 18/watchOS 11 SDKs; the badge above records the newer repository-validated toolchain
- **Apple Developer Account** (for device deployment)
- **watchOS 11.0+** target device or simulator
- **iOS 17.0+** for companion app (optional)

**Cloud services for the target backend:**
- [Clerk](https://dashboard.clerk.com) — native authentication
- [Cloudflare Workers](https://dash.cloudflare.com) — Hono API and OpenAI proxy
- [PlanetScale Postgres](https://app.planetscale.com) — cloud persistence
- [OpenAI](https://platform.openai.com) — server-side assistant and match-sheet parsing

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/RefWatch.git
   cd RefWatch
   ```

2. **Run the setup script**
   ```bash
   chmod +x scripts/setup.sh
   ./scripts/setup.sh
   ```
   This will prompt you for:
   - Apple Development Team ID
   - Bundle identifier prefix
   - App Group identifier
   - URL scheme

   **Recommended:** Install git hooks to prevent committing secrets:
   ```bash
   ./scripts/install-git-hooks.sh
   ```

3. **Configure App Group entitlements**

   After running setup.sh, you must manually update the App Group in the entitlements files to match your App Group ID:

   - `RefWatch Watch App.entitlements`
   - `RefWatchWidgetsExtension.entitlements`

   Replace `group.refwatch.shared` with your App Group ID (e.g., `group.yourcompany.refwatch`).

   You'll also need to create the App Group in the Apple Developer portal:
   1. Go to [Identifiers](https://developer.apple.com/account/resources/identifiers)
   2. Click '+' and select 'App Groups'
   3. Enter your App Group ID

4. **Configure local app-facing cloud values**

   For production, execute this only through the reviewed operator procedure
   after authoritatively resolving the signed Bundle ID, Apple App ID Prefix,
   native redirect URL, and release configuration destination:

   ```bash
   cp RefWatchiOS/Config/Secrets.example.xcconfig RefWatchiOS/Config/Secrets.xcconfig
   ```
   Add only the approved public app-facing values. Do not infer a Bundle ID,
   App ID Prefix, redirect URL, host, or key from this README.

   **Environment Variables Reference:**

   | Variable | Service | Description |
   |----------|---------|-------------|
   | `BACKEND_API_BASE_URL` | Cloudflare | Deployed Worker origin, with no trailing slash |
   | `CLERK_PUBLISHABLE_KEY` | Clerk | Public native-app key; safe to embed |
   | `CLERK_FRONTEND_API_HOST` | Clerk | Frontend API host used by the associated-domain capability |

   Never add `CLERK_SECRET_KEY`, `CLERK_JWT_KEY`,
   `CLERK_WEBHOOK_SIGNING_SECRET`, `CUTOVER_ACCEPTANCE_TOKEN`, `DATABASE_URL`,
   PlanetScale credentials, or `OPENAI_API_KEY` to iOS configuration.

5. **Configure and run the Worker API**
   ```bash
   cd api
   npm install
   cp .dev.vars.example .dev.vars
   npm run typecheck
   npm test
   npm run dev
   ```
   Do not recreate known-good domain/DNS/key infrastructure or run a production
   deploy from this quick start. Production schema/reset/seed, secrets, webhook,
   routing, and write steps are authorized but must use the ordered,
   non-echoing procedures and sanitized evidence in the cutover runbook. Use
   `DATABASE_URL` only for local runtime fallback; use a separate
   migration-capable credential with Drizzle tooling.

6. **Clerk native-app and webhook setup** (do not execute from this quick start)

   - First obtain the authoritative Apple App ID Prefix, signed Bundle ID, and
     reviewed native redirect URL; do not infer them from project expressions.
   - Register the native app, configure production sign-in/OAuth methods, and
     install only the verified public host/key in the ordered native/OAuth
     phases.
   - Create the lifecycle webhook only after its exact reachable Worker endpoint,
     event allowlist, non-echoing secret path, and write-disabled probe are
     verified. Follow
     `docs/references/backend-migration-cutover.md` for the staged procedure.

7. **Build and run**
   ```bash
   # Build watchOS app
   xcodebuild -project RefWatch.xcodeproj \
     -scheme "RefWatch Watch App" \
     -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
     build

   # Build iOS companion app
   xcodebuild -project RefWatch.xcodeproj \
     -scheme "RefWatchiOS" \
     -destination 'platform=iOS Simulator,name=iPhone 15' \
     build
   ```

## Architecture

RefWatch follows a feature-first MVVM architecture with clear separation between platforms:

```
RefWatch/
├── api/                 # Cloudflare Worker/Hono API and Drizzle schema
├── RefWatchWatchOS/     # watchOS app (production-first)
│   ├── App/             # App entry point, navigation
│   ├── Core/            # Shared services, components
│   └── Features/        # Feature modules (Timer, Events, etc.)
├── RefWatchiOS/         # iOS companion app
│   ├── App/             # App entry, tabs, routing
│   ├── Core/            # Platform services, persistence
│   └── Features/        # Feature modules
├── RefWatchWidgets/     # watchOS complications
└── docs/                # Documentation
```

See [Architecture Overview](docs/design-docs/architecture/overview.md) for detailed documentation.

## Documentation

- [Installation & Tooling](docs/references/getting-started/installation.md)
- [Running the App](docs/references/getting-started/running.md)
- [Architecture Overview](docs/design-docs/architecture/overview.md)
- [Backend migration and cutover](docs/references/backend-migration-cutover.md)
- [Testing Strategy](docs/references/testing/strategy.md)
- [Contributing Guide](docs/references/process/contributing.md)

## Contributing

We welcome contributions! Please see our [Contributing Guide](docs/references/process/contributing.md) for details on:

- Branch naming conventions
- Development workflow
- Code review process
- Testing requirements

Before contributing, please read our [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

For security architecture and the current migration risk register, see [docs/SECURITY.md](docs/SECURITY.md). For responsible disclosure, see [SECURITY.md](SECURITY.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
