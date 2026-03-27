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
- `AssistantProviding`: wraps the iOS assistant transport so feature views can consume it without coupling to the server proxy.

## Dependency Injection
- Services are instantiated in feature ViewModels; rely on protocols for testing.
- Keep shared services platform-agnostic. Inject adapters for platform differences (e.g., haptics, connectivity). The assistant transport is iOS-only and should not be treated as a watch-shared runtime service.
- `TimerManager` and `MatchViewModel` emit semantic lifecycle cues through `MatchLifecycleHapticsProviding`; repeated-sequence playback and cancellation stay in platform adapters, not in shared services or views.
- Shared core owns the explicit `PendingPeriodBoundaryDecision` state for natural period expiry. `MatchViewModel` transitions into that state before requesting `.periodBoundaryReached`, while the watch layer remains responsible only for foreground alert playback and acknowledgment UI.

## Persistence & Sync
- Short-term storage stays local on watch for responsiveness.
- Unfinished-match persistence stores lifecycle decision state needed to restore referee-controlled continuation after a natural period boundary, but it does not persist foreground repeating-alert playback for automatic replay.
- Planned enhancements include Supabase-backed sync triggered via connectivity adapters.

## Testing Strategy
- Provide protocol-based mocks per service.
- Focus on deterministic timer behaviors, `PendingPeriodBoundaryDecision` sequencing, lifecycle haptic dedupe/cancellation, restore behavior, and penalty edge cases.
