# AGENTS.md

## Scope
Unit tests for the watch app. Applies to `RefZoneWatchOSTests/`.

## Run
- `xcodebuild test -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`

## Guidance
- Focus on ViewModels and services; mock adapters via protocols.
- Naming: `test<Action>_when<Context>_does<Outcome>()`.
- Keep tests deterministic; avoid timers/sleeps—inject clocks where needed.

