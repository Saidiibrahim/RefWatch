# PLAN: watchOS Layout Compliance

## Objective
Ensure all watchOS surfaces render within safe areas across hardware sizes, eliminating clipped content observed in TestFlight builds.

## Key Problem Areas
- **Team & Kickoff Panels** (`RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift`, `RefZoneWatchOS/Features/Match/Views/MatchKickOffView.swift`): Twin rows of 60 pt event buttons plus fixed-height `CompactTeamBox` instances and 44 pt confirmation controls sit inside non-scroll `VStack`s. On 40/41 mm watches, the nav bar and rounded corners hide the bottom row. `CompactTeamBox` enforces a 65 pt height and 24 pt font, preventing graceful shrinkage.
- **Penalty Surfaces** (`RefZoneWatchOS/Features/Events/Views/PenaltyShootoutView.swift`, `RefZoneWatchOS/Features/Events/Views/PenaltyFirstKickerView.swift`): 110 pt team panels and full-width buttons use static `VStack` layouts. Physical devices introduce larger bottom safe-area insets, leaving decisive buttons partially off-screen.
- **Timer & Full-Time Screens** (`RefZoneWatchOS/Features/Timer/Views/TimerView.swift`, `RefZoneWatchOS/Features/Timer/Views/FullTimeView.swift`): Generous top/bottom padding and fixed-size score cards constrain the central timer face. When stoppage time appears, the face overruns the available vertical space on smaller cases; the bottom `safeAreaInset` control can slip beneath the dock.
- **Shared Components** (`RefZoneWatchOS/Core/Components/EventButtonView.swift`, `ActionGridItem`, `CompactTeamBox`, penalty panels): Hard-coded frames (60–110 pt) and fixed font sizes lack scaling. Shadows/outlines enlarge effective bounds, exceeding carousel list limits on small hardware.
- **Workout Media Host** (`RefZoneWatchOS/Features/Workout/Views/WorkoutSessionHostView.swift`): A 120 pt artwork tile and 22 pt typography push transport controls below the safe area when artwork is present, an issue not reproduced on 45 mm simulators.

## Why Device Builds Clip
- **Hardware Size Mix**: Internal testing relied on 45 mm simulators; many TestFlight users wear 40/41 mm watches, reducing vertical safe space by ~56 pt.
- **Physical Safe-Area Insets**: Real watches reserve extra pixels for status chrome, rounded corners, and the dock indicator, so static padding (e.g., `.safeAreaInset` with `padding(.bottom, theme.spacing.xl)`) forces content off-screen.
- **Dynamic Type Behavior**: Release builds respect user text-size overrides. Views pinned to `.font(.system(size: ...))` cannot shrink dynamically, resulting in truncation rather than reflow.

## Mitigation Recommendations
1. **Adopt Adaptive Containers**: Wrap dense surfaces in `ScrollView`/`List` or apply `ViewThatFits` to collapse secondary rows when space is tight. Use `GeometryReader` strictly for measuring available height (e.g., in timer faces) and drive layout with that measurement instead of fixed numbers.
2. **Parameterize Component Sizing**: Replace explicit `frame(height:)` calls in shared components with theme-driven minimum heights and apply `.minimumScaleFactor`/`layoutPriority` to textual elements. Centralize sizing tokens so the team can adjust across the app in one change.
3. **Normalize Safe-Area Handling**: Keep bottom actions inside `safeAreaInset` but remove redundant padding and introduce flexible `Spacer(minLength: 0)` segments above. Validate tap targets with `button.contentShape` to maintain usability on tight layouts.
4. **Respect Dynamic Type**: Favor theme typography tokens (already mapped to watch text styles) or `Font.watch` variants. Where fixed fonts are unavoidable, pair with `.lineLimit(1)` and `.minimumScaleFactor(0.6)` to allow compression instead of clipping.
5. **Broaden Preview/Test Coverage**: Add `.previewDevice("Apple Watch Series 9 (41mm)")` and `.previewDevice("Apple Watch Ultra 2 (49mm)")` variants for each dense view. Exercise UITests on the smallest simulator prior to TestFlight submission.
6. **Introduce Layout Assertions**: Extend `RefZoneWatchOSUITests` to verify key controls are hittable after navigation transitions and integrate lightweight visual snapshots to catch occlusion regressions automatically.

## Verification Workflow
- **Build & Test**: Run `xcodebuild -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (41mm)' test` after layout adjustments to ensure the smallest simulator passes.
- **Snapshot Baseline**: Capture reference screenshots for `TimerView`, `TeamDetailsView`, `PenaltyShootoutView`, and `WorkoutSessionHostView` at 41 mm and 45 mm to detect regressions.
- **Device Smoke Tests**: During beta cycles, prioritize smoke tests on physical 41 mm hardware or request tester watch-size metadata; attach Xcode’s live view debugger to confirm safe-area compliance.

## Status & Next Steps
- Report authored; awaiting prioritization for implementation. Recommend scheduling a spike to refactor shared components (CompactTeamBox/EventButtonView) before tackling individual screens.
