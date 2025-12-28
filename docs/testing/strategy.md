# Testing Strategy

## Priorities
- WatchOS timer reliability is the top priority; cover TimerManager, TimerFace models, and penalty logic.
- Shared services should have unit tests validating persistence and data transformations.
- UI tests focus on end-to-end match flow and critical settings interactions.

## Test Targets
- `RefWatch Watch AppTests`: unit tests for ViewModels/services.
- `RefWatch Watch AppUITests`: end-to-end flows on watch simulator.
- Future iOS tests can live under new targets mirroring watch coverage.

## Naming Convention
Use `test<Action>_when<Context>_does<Outcome>()` for clarity.

## Commands
```bash
xcodebuild test -project RefWatch.xcodeproj \
  -scheme "RefWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

## Mocks & Utilities
- Provide protocol-based mocks for services (`MatchHistoryService`, `OpenAIAssistantService`).
- Add fixture builders for match configuration and history entries.

## Reporting
- Capture failing snapshots or simulator videos for UI test regressions.
- Share flaky test reports in team channel; quarantine with clear ownership.
