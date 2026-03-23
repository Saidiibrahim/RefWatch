# Shared Services & Protocols

## Service Catalog
- `MatchHistoryService`: persists match data and exposes retrieval APIs.
- `TimerManager`: orchestrates timers, period transitions, and break logic.
- `PenaltyManager`: normalizes penalty tracking and associated alerts.
- `MatchPersistence`: file system or cloud-backed storage helpers.

## Protocol Conventions
- `HapticsProviding`: watch/iOS adapters implement this to send context-specific haptics.
- `MatchLifecycleHapticsProviding`: shared match flow uses this for lifecycle cues such as natural period boundary and halftime expiry.
- `ConnectivityProviding`: abstract layer for future watch ↔︎ iPhone sync.
- `AIResponseProviding`: wraps AI assistant calls so features can consume them without platform coupling.

## Dependency Injection
- Services are instantiated in feature ViewModels; rely on protocols for testing.
- Keep shared services platform-agnostic. Inject adapters for platform differences (e.g., haptics, connectivity).
- `TimerManager` and `MatchViewModel` emit semantic lifecycle cues through `MatchLifecycleHapticsProviding`; repeated-sequence playback and cancellation stay in platform adapters, not in shared services or views.

## Persistence & Sync
- Short-term storage stays local on watch for responsiveness.
- Planned enhancements include Supabase-backed sync triggered via connectivity adapters.

## Testing Strategy
- Provide protocol-based mocks per service.
- Focus on deterministic timer behaviors, lifecycle haptic dedupe/cancellation, and penalty edge cases.
