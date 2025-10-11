# Architecture Overview

RefZone is split into a primary watchOS experience with an optional iOS companion. Shared logic lives in the watch target to simplify synchronization and reuse.

## Layering
- **App Layer**: SwiftUI entry points and root views per platform.
- **Features**: MVVM-oriented folders for each domain area (Match, Timer, Events, etc.).
- **Core**: Cross-feature services, managers, protocols, and platform adapters (timer coordination, haptics, storage).
- **Assets**: Shared visual resources and previews.

## Cross-Target Sharing
- Watch target owns domain models and services; iOS reuses them via target membership.
- Platform adapters implement protocols (e.g., `HapticsProviding`) to avoid conditional imports in shared code.

## Key Workflows
- Match timer flow orchestrates period transitions, penalties, and haptics.
- Match history persists state for quick access on watch and optional sync to iOS.
- Assistant tab surfaces AI-assisted workflows backed by Supabase functions.

See platform-specific deep dives for more detail.
