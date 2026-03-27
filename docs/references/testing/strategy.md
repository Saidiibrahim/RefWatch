# Testing Strategy

## Priorities
- WatchOS timer reliability is the top priority; cover `TimerManager`, `TimerFace` models, and penalty logic.
- Match lifecycle haptics are part of timer reliability; cover `PendingPeriodBoundaryDecision` sequencing, semantic cue requests, repeated watch scheduling, explicit acknowledgment, and cancellation after transition/reset/backgrounding.
- The iOS assistant now needs direct coverage for multimodal payloads, streamed text handling, and attachment lifecycle.
- Shared services should have unit tests validating persistence and data transformations.
- UI tests focus on end-to-end match flow, critical settings interactions, and the iOS assistant image-send flow.

## Test Targets
- `RefWatch Watch AppTests`: unit tests for ViewModels/services.
- `RefWatch Watch AppUITests`: end-to-end flows on watch simulator.
- `RefWatchiOSTests`: assistant service and assistant view-model tests.
- `RefWatchiOSUITests`: iOS assistant flow tests, including Photos picker/image send coverage where automation permits.

## Naming Convention
Use `test<Action>_when<Context>_does<Outcome>()` for clarity.

## Commands
```bash
swift test --package-path RefWatchCore --filter MatchViewModel_EventsAndStoppageTests
swift test --package-path RefWatchCore --filter TimerManagerTests
```

```bash
xcodebuild test -project RefWatch.xcodeproj \
  -scheme "RefWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

## Mocks & Utilities
- Provide protocol-based mocks for services (`MatchHistoryService`, `AssistantProviding`, `OpenAIAssistantService`).
- Add fixture builders for match configuration and history entries.
- Prefer protocol-based lifecycle haptics spies in `RefWatchCore` tests and fake scheduler/driver seams in watch adapter tests instead of asserting raw platform haptic playback.
- When natural period-boundary sequencing changes, prefer assertions on state order (`PendingPeriodBoundaryDecision` -> lifecycle cue request -> explicit `periodEnd` commit) and restore state over wall-clock timing.
- For assistant tests, add fixture builders for text-only, text-plus-image, and image-only turns so payload expectations stay readable.

## Reporting
- Capture failing snapshots or simulator videos for UI test regressions.
- Share flaky test reports in team channel; quarantine with clear ownership.
- Separate simulator/build evidence from physical-watch tactile proof when lifecycle haptics change, and call out foreground-only interruption behavior explicitly in release notes or QA notes.
- For natural period-boundary smoothing, include explicit proof that restore reopens the decision surface without replaying the repeating alert and that physical-watch cue feel remains calmer than the old `play cue` + `pauseMatch()` coupling.
- For assistant image support, capture an iPhone 15 Pro Max simulator or device run that shows the selected image, the streamed response, and the absence of any bundled OpenAI key.
