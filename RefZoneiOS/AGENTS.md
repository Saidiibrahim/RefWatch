# AGENTS.md

## Scope
Instructions for the iOS app. Applies to everything under `RefZoneiOS/`.

## Build & Test
- Build: `xcodebuild -project RefZone.xcodeproj -scheme RefZoneiOS -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Test (unit+UI if present): `xcodebuild test -project RefZone.xcodeproj -scheme RefZoneiOS -destination 'platform=iOS Simulator,name=iPhone 15'`
- Run locally: select the scheme, pick an iPhone simulator, `⌘R`.
- Ensure the scheme is Shared.

## Structure & Conventions
- SwiftUI + MVVM, 2‑space indent. One primary type per file.
- App entry under `App/` with `AppRouter` for navigation.
- Core code in `Core/` (DesignSystem/Theme, Platform adapters, Persistence, Diagnostics).
- Features in `Features/` with `FeatureName/{Models,ViewModels,Views}`.
- Use domain/services shared from the watch target via target membership; avoid watch‑only imports.

## Platform Adapters
- Prefer `RefZoneiOS/Core/Platform` adapters (e.g., `IOSHaptics`, `ConnectivityClient`, AI assistant) accessed via protocols. Inject into view models/services.

## Config & Secrets
- See `RefZoneiOS/Config/` for `.xcconfig` usage. Never commit real secrets; use `Secrets.example.xcconfig` for placeholders.

## Testing Focus
- Unit tests emphasize iOS‑specific services/adapters and feature view models. UI tests focus on main tab flows.

## Don’ts
- Don’t import `WatchKit` or watch‑only code in iOS sources. Use `#if os(iOS)` and adapters.

