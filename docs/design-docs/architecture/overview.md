# Architecture Overview

RefWatch is split into a primary watchOS experience with an optional iOS companion. Shared match logic lives in the core/watch stack, while the iOS companion owns the assistant and other phone-first surfaces.

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

## Key Workflows
- Match timer flow orchestrates period transitions, penalties, and haptics.
- Match history persists state for quick access on watch and optional sync to iOS.
- Assistant tab surfaces AI-assisted workflows backed by a Supabase Edge Function proxy on iOS only.

See platform-specific deep dives for more detail.
