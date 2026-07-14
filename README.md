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

> Migration status (2026-07-14): the active iOS composition builds and routes cloud-backed features, including reference-catalog reads, through Clerk and `BackendAPIClient`. Staging Worker/Hyperdrive readiness and disposable 5/54 catalog readback passed. Production provider deployment, Supabase data/account import, production application/readback of the bundled PlanetScale reference-catalog seed, full iOS test acceptance, and Supabase compatibility cleanup are not complete. Legacy Supabase-named repositories/types may remain compiled until the active exec plan closes; the Supabase SDK package is removed. See [Backend migration and cutover](docs/references/backend-migration-cutover.md).

## Quick Start

## Post-clone setup

- Run `./scripts/setup.sh` to generate `RefWatchiOS/Config/Config.xcconfig` with your Team ID, bundle prefix, app group, and URL scheme (local-only, gitignored).
- Optional: copy `RefWatchiOS/Config/Secrets.example.xcconfig` to `RefWatchiOS/Config/Secrets.xcconfig` and add local app-facing values.
- Configure the public Clerk key and Worker base URL in `Secrets.xcconfig` when exercising the migrating cloud path.

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

4. **Configure local app secrets** (required for cloud features)
   ```bash
   cp RefWatchiOS/Config/Secrets.example.xcconfig RefWatchiOS/Config/Secrets.xcconfig
   ```
   Edit `Secrets.xcconfig` with your local app-facing values if using cloud features.

   **Environment Variables Reference:**

   | Variable | Service | Description |
   |----------|---------|-------------|
   | `BACKEND_API_BASE_URL` | Cloudflare | Deployed Worker origin, with no trailing slash |
   | `CLERK_PUBLISHABLE_KEY` | Clerk | Public native-app key; safe to embed |
   | `CLERK_FRONTEND_API_HOST` | Clerk | Frontend API host used by the associated-domain capability |

   Never add `CLERK_SECRET_KEY`, `CLERK_JWT_KEY`, `CLERK_WEBHOOK_SIGNING_SECRET`, `DATABASE_URL`, PlanetScale credentials, or `OPENAI_API_KEY` to iOS configuration.

5. **Configure and run the Worker API**
   ```bash
   cd api
   npm install
   cp .dev.vars.example .dev.vars
   npm run typecheck
   npm test
   npm run dev
   ```
   For deployment, provision Clerk, PlanetScale Postgres, and Cloudflare Hyperdrive first, configure the `HYPERDRIVE` binding, and store the following with `wrangler secret put`: `CLERK_SECRET_KEY`, `CLERK_PUBLISHABLE_KEY`, `CLERK_JWT_KEY`, `CLERK_WEBHOOK_SIGNING_SECRET`, and `OPENAI_API_KEY`. Use `DATABASE_URL` only for local runtime fallback; use a separate migration-role `DATABASE_URL` with Drizzle tooling.

6. **Clerk native-app setup**
   - Create or select the RefWatch Clerk application and enable the desired sign-in methods.
   - Add the iOS bundle identifier/native application in Clerk.
   - Put only the publishable key and Frontend API host in `Secrets.xcconfig`.
   - Configure `webcredentials:<CLERK_FRONTEND_API_HOST>` in the iOS associated-domains capability.
   - Create a Clerk webhook for the deployed `/webhooks/clerk` endpoint and keep its signing secret in Worker secrets.

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
