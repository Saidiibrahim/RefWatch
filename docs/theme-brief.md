# RefZone Theme Brief & Audit

## Product context
- **Primary surfaces**: watchOS companion (RefZone Watch App) with complementary iOS app for setup, history, and configuration.
- **Primary moments**: in-match timer management, quick incident logging, post-match review, and configuration before kickoff.
- **Users**: grassroots to semi-professional referees who need legibility, low friction, and quick recovery from mistakes while on the pitch.

## Experience goals
1. **High focus** – reduce cognitive load with strong hierarchy, clear status colors, and predictable motion/haptics.
2. **At-a-glance legibility** – typography that reads at arm’s length in sunlight and during motion.
3. **Trustworthy urgency cues** – distinct states for normal time, stoppages, cards, and penalties.
4. **Platform-native feel** – respect watchOS/iOS conventions while sharing a coherent brand language.
5. **Accessibility first** – AA contrast minimums, scalable type (Dynamic Type on iOS, content size categories on watchOS), and non-color affordances for critical actions.

## Constraints & opportunities
- watchOS faces must balance data density with glanceability; animation should stay subtle to conserve battery.
- The timer face and quick actions are the primary anchors for theme adoption; they need semantic styling hooks.
- iOS already hosts a rudimentary `AppTheme` struct (`RefZoneiOS/Core/DesignSystem/Theme.swift`); we should evolve it into a shared token set to avoid diverging palettes.

## Color audit (Feb 2025)
_Current theme relies on system colors and ad-hoc `Color.*` values. Below highlights repeated usage to migrate into semantic tokens._

| Usage | Current value | Surface | Reference |
| --- | --- | --- | --- |
| Match start hero gradient | `Color.blue`, `Color.green` | watchOS Start match | `RefZoneWatchOS/Features/Match/Views/StartMatchScreen.swift`
| Kickoff selection | `Color.green`, `Color.gray` | watchOS kickoff | `RefZoneWatchOS/Features/Match/Views/MatchKickOffView.swift`
| Quick action tint | `.blue`, `.gray` | watchOS home | `RefZoneWatchOS/App/MatchRootView.swift`
| Penalty shootout states | `Color.green`, `Color.orange`, `Color.red`, `Color.gray`, `Color.white.opacity` | watchOS penalties | `RefZoneWatchOS/Features/Events/Views/PenaltyShootoutView.swift`
| Full-time screen | `Color.black`, `Color.green`, `Color.gray.opacity` | watchOS timer | `RefZoneWatchOS/Features/Timer/Views/FullTimeView.swift`
| Timer faces | hard-coded greens/oranges | watchOS timer component | `RefZoneWatchOS/Core/Components/TimerFaces/*`
| Neutral backgrounds | `Color.gray.opacity`, `Color.white.opacity`, `Color.black` | misc cards | multiple files noted above
| iOS palette | `Color.green`, `.yellow`, `.red`, `.orange`, `.blue` | iOS design system | `RefZoneiOS/Core/DesignSystem/Theme.swift`

**Observations**
- Most match-critical states use pure system greens/reds/yellows; they lack defined dark-mode/contrast variants.
- Neutral backgrounds mix white/black/gray with varying opacities, which will render inconsistently against watch complications and in different display modes.
- No persistent tokens for divider strokes, overlays, or gradients; each view creates its own values.

## Typography audit (Feb 2025)

| Context | Font usage | Reference |
| --- | --- | --- |
| MatchRootView hero | `.title2.semibold`, `.system(size: 18, weight: .semibold)`, `.headline`, `.footnote` | `RefZoneWatchOS/App/MatchRootView.swift`
| Timer faces | `.system(size: 48/36/20, weight: .bold/medium, design: .rounded)` | `RefZoneWatchOS/Core/Components/TimerFaces/StandardTimerFace.swift`
| Score displays | `.system(size: 14/24, weight: .medium/.bold)` | `RefZoneWatchOS/Core/Components/ScoreDisplayView.swift`
| Penalty flows | `.system(size: 13-18, weight: .semibold/.bold)` | `RefZoneWatchOS/Features/Events/Views/PenaltyShootoutView.swift`
| Numeric keypad | `.system(size: 15-18, weight: .medium)` | `RefZoneWatchOS/Core/Components/Input/NumericKeypad.swift`
| iOS timer + headings | `.system(size: 44-18, weight: .bold/.medium, design: .rounded)` | `RefZoneiOS/Core/DesignSystem/Theme.swift`

**Observations**
- Timer typography already leans on rounded bold digits, aligned with quick readability. These should be formalized as `theme.typography.timerMain`, etc.
- Body copy varies between `.body`, `.headline`, and explicit font sizes; we should standardize on semantic roles (headline, label, meta) to ease scaling.
- No documented approach for dynamic type scaling—should adopt `FontMetrics` on watchOS where sensible and ensure iOS uses `.scaledFont` wrappers.

## Theming principles to adopt
1. **Semantic tokens first** – replace raw colors/fonts with descriptive tokens (`matchPositive`, `stateWarning`, `labelSecondary`).
2. **Platform modifiers** – shared tokens in `Shared/DesignSystem/Theme`, with additional adapters for watch-specific treatments (vibrancy, corner radii) or iOS-specific spacing.
3. **State-driven variants** – design theme APIs to respond to match state (`MatchPhase`, `CardType`) so views stay declarative.
4. **Preview coverage** – ensure each major feature view has previews cycling through base/high-contrast themes.

## Next implementation steps
- Codify shared tokens and Theme protocol (see implementation tasks in repo).
- Gradually refactor watchOS views (starting with `MatchRootView`) to consume theme tokens.
- Mirror the approach in iOS once shared scaffolding is stable.
