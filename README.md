# RefWatch

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-watchOS%20%7C%20iOS-blue.svg)](https://developer.apple.com/watchos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)

<table align="center">
  <tr>
    <td><img src="docs/images/screenshots/iphone/iphone-1.png" alt="iPhone App" height="400"></td>
    <td><img src="docs/images/screenshots/watch/watch-1.png" alt="Watch App" height="400"></td>
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

## Quick Start

## Post-clone setup

- Run `./scripts/setup.sh` to generate `RefWatchiOS/Config/Config.xcconfig` with your Team ID, bundle prefix, app group, and URL scheme (local-only, gitignored).
- Optional: copy `RefWatchiOS/Config/Secrets.example.xcconfig` to `RefWatchiOS/Config/Secrets.xcconfig` and add API keys.
- Optional: add `RefWatchiOS/GoogleService-Info.plist` for Firebase/Google Sign-In.

### Prerequisites

- **Xcode 15.4+** (Swift 5.9)
- **Apple Developer Account** (for device deployment)
- **watchOS 11.0+** target device or simulator
- **iOS 17.0+** for companion app (optional)

Optional services:
- Supabase account for cloud sync
- OpenAI API key for AI assistant features
- Firebase project for analytics

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

3. **Configure App Group entitlements**

   After running setup.sh, you must manually update the App Group in the entitlements files to match your App Group ID:

   - `RefWatch Watch App.entitlements`
   - `RefWatchWidgetsExtension.entitlements`

   Replace `group.refwatch.shared` with your App Group ID (e.g., `group.yourcompany.refwatch`).

   You'll also need to create the App Group in the Apple Developer portal:
   1. Go to [Identifiers](https://developer.apple.com/account/resources/identifiers)
   2. Click '+' and select 'App Groups'
   3. Enter your App Group ID

4. **Configure API keys** (required for cloud features)
   ```bash
   cp RefWatchiOS/Config/Secrets.example.xcconfig RefWatchiOS/Config/Secrets.xcconfig
   ```
   Edit `Secrets.xcconfig` with your API keys if using cloud features.

5. **Firebase/Google Sign-In setup** (optional)
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Download `GoogleService-Info.plist` and place it in `RefWatchiOS/`
   - Copy the `REVERSED_CLIENT_ID` value from `GoogleService-Info.plist` to `GID_REVERSED_CLIENT_ID` in your `Secrets.xcconfig`

6. **Build and run**
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

See [Architecture Overview](docs/architecture/overview.md) for detailed documentation.

## Documentation

- [Installation & Tooling](docs/getting-started/installation.md)
- [Running the App](docs/getting-started/running.md)
- [Architecture Overview](docs/architecture/overview.md)
- [Testing Strategy](docs/testing/strategy.md)
- [Contributing Guide](docs/process/contributing.md)

## Contributing

We welcome contributions! Please see our [Contributing Guide](docs/process/contributing.md) for details on:

- Branch naming conventions
- Development workflow
- Code review process
- Testing requirements

Before contributing, please read our [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

For security vulnerabilities, please see our [Security Policy](SECURITY.md) for responsible disclosure guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

