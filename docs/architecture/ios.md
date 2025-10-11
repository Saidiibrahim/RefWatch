# iOS Architecture

## Entry Points
- `RefZoneiOSApp` bootstraps the iOS experience.
- `MainTabView` provides navigation across Matches, Live, Library, Trends, and Settings.
- `AppRouter` coordinates deep links and onboarding routes.

## Platform Core
- `DesignSystem/Theme` centralizes typography, colors, and reusable components.
- `Platform` adapters implement watch-shared protocols, e.g.:
  - `IOSHaptics` for tactile feedback.
  - `ConnectivityClient` (placeholder) for syncing with watch.
  - `SupabaseAuthController` for authentication flows.

## Feature Modules
- `Matches`: watch match history, continue sessions, and manage saved data.
- `Live`: planned for real-time monitoring or scoreboard.
- `Library`: references to training material, rules, or external content.
- `Trends`: analytics and performance insights.
- `Settings`: account management and device preferences.

## Shared Code Consumption
- Most domain models originate in watch feature modules and are shared via target membership.
- Services like `MatchHistoryService` are reused directly on iOS when platform adapters satisfy the dependencies.

## Testing Notes
- Unit tests should exercise shared services inside the iOS context where behavior diverges (e.g., networking).
- Snapshot/UI tests can validate tab navigation once the UI test target is configured.
