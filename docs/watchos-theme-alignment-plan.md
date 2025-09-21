# watchOS Theme Alignment Plan

## Purpose
Provide an actionable blueprint for finishing the RefZone theming work while aligning the watch experience with Apple's Human Interface Guidelines (HIG). The plan complements `docs/theme-brief.md` and the WIP plan at `docs/plans/wip/PLAN_ThemeScaffolding.md` by translating the shared tokens into concrete UI patterns, palette decisions, and rollout tasks.

## Design principles to uphold
- **Glanceable hierarchy** – Each screen must surface the primary action or state change within one eye fixation. Use bold typography, large numeric displays, and obvious accent colors for match status.
- **Context-driven layouts** – Apply the card-based list treatment to navigation and configuration flows (entry, match history, settings, options). Preserve purpose-built full-bleed layouts for match-critical surfaces (timer faces, penalties, in-progress match actions) while refreshing them with theme tokens.
- **High-contrast accessibility** – Ensure WCAG AA contrast (prefer AAA for key text). Provide a future high-contrast theme variant that increases contrast ratios and reduces gradients.
- **Brand-coherent urgency** – Map match states and alerts to the Football South Australia palette while maintaining semantic naming within `ColorPalette`.
- **Platform consistency** – Reuse shared tokens for both watchOS and iOS while allowing per-platform layout tuning via `ComponentStyles` and spacing tokens.

## Palette translation (Football South Australia)
The table maps the brand inspiration to semantic tokens. Hex values are approximations based on the provided logo; exact values can be tuned once brand assets are sourced. All colors are sRGB.

| Token | Hex | Usage | Notes |
| --- | --- | --- | --- |
| `accentPrimary` | `#0F2C63` | Primary nav surfaces, headings, primary text in dark mode | Deep navy; pair with white text for ≥7:1 contrast. |
| `accentSecondary` | `#40A3D3` | Secondary highlights, card backgrounds, segmented controls | Light blue/teal derived from ball curve. |
| `matchCritical` | `#E4002B` | Dismissive/destructive actions (red card, stop match) | Ensure blur/vibrancy variants retain clarity on watch faces. |
| `matchWarning` | `#F76B35` | Caution states (yellow card, added time) | Slightly softened red to remain distinguishable beside `matchCritical`. |
| `matchPositive` | `#1FB36A` | Positive actions (start match, confirm) | Keeps accessibility while differentiating from brand red. |
| `matchNeutral` | `#F2C744` | Neutral states (pending kickoff, paused) | Works with dark backgrounds; provide dark-mode tweak if needed. |
| `accentMuted` | `#7A1E3A` | Secondary buttons, chips, inactive states | Burgundy shade from logo gradient. |
| `backgroundPrimary` | `#030711` | Base background for watch surfaces | Nearly-black navy; supports glow-less visuals outdoors. |
| `backgroundSecondary` | `#10172A` | Cards, grouped backgrounds | Adds subtle elevation separation when combined with blur. |
| `backgroundElevated` | `#1B2338` | Modals, sheets, active tiles | Provide 8–12pt corner radius to mirror watch cards. |
| `surfaceOverlay` | `rgba(255,255,255,0.08)` | Overlay for pressed/disabled states | Keep alpha consistent across themes. |
| `textPrimary` | `#FFFFFF` | Primary text on dark surfaces | Ensure `.opacity(0.88)` for secondary copy when needed. |
| `textSecondary` | `rgba(255,255,255,0.72)` | Labels, metadata | Maintain readability in bright conditions. |
| `textInverted` | `#0B1326` | Text on light tiles (e.g., teal chips) | Provides 8:1 contrast vs light backgrounds. |
| `outlineMuted` | `rgba(255,255,255,0.12)` | Dividers, keyline strokes | Increase to `0.2` in high-contrast variant. |

### Palette rollout notes
1. Introduce a `FootballSAThemePalette` constant implementing the above mapping inside `ColorTokens`. Provide computed colors using `Color(red:green:blue:)` for clarity.
2. Document HIG-compliant contrast ratios per token (see Acceptance Criteria below).
3. Prepare a `HighContrastThemePalette` variant: tweak `backgroundSecondary`, `surfaceOverlay`, and text opacities to meet AAA.

## Typography & spacing guidance
- **Timer surfaces** – Use `TypographyTokens.timerPrimary` (`systemRounded`, weight `.bold`, size 52, `FontMetrics` tied to `.title`) for the main match clock, with `timerSecondary` at size 24 for period and stoppage indicators.
- **Card/navigation flows** – Headline: `.system(size: 22, weight: .semibold)`. Metadata: `.system(size: 15, weight: .medium)`. Ensure all fonts use `.monospacedDigit()` when representing time.
- **Interactive elements** – Maintain ≥12pt vertical padding and 16pt lateral padding around tappable content. Spacing tokens should include: `stackXS = 4`, `stackSM = 8`, `stackMD = 12`, `stackLG = 16`, `stackXL = 24` (values already in `SpacingTokens`; document usage).
- **Dynamic type** – Adopt `.scaledFont` wrappers on iOS and `FontMetrics` on watchOS to respect `WKInterfaceDevice.current().preferredContentSizeCategory` equivalents.

## Layout blueprints
Apply different treatments depending on the user flow.

1. **Navigation & configuration (card surfaces)**
   - Target screens: app entry, match options, match history, settings.
   - Use vertically scrolling lists with card-style rows filling most of the width (`listRowInsets(.zero)` with custom `cardStyle()` modifier).
   - Leading cards (e.g., Start/Resume tile) use `accentPrimary` backgrounds with 20pt radius. Secondary cards adopt `backgroundElevated` with subtle outlines.
   - Primary action per screen; keep secondary affordances within the card using iconography tinted with `accentSecondary`.

2. **Match-critical surfaces (full-bleed layouts)**
   - Timer faces, running match controls, and penalty flows retain their purpose-built layouts for glanceability and rapid interaction.
   - Apply the new theme tokens for colors, typography, and spacing without forcing a card container. Use overlays from the palette to signal states (paused, warning, critical).
   - Ensure background treatments remain minimal to avoid distracting during match play; rely on typography weight and color contrast for hierarchy.

3. **Supporting modules (hybrid)**
   - For components like numeric keypads or segmented controls that already have bespoke layouts, introduce token colors and spacing but skip card wrappers unless the view sits within a navigation list.

## Implementation roadmap
_Phase numbering aligns with development milestones; update `PLAN_ThemeScaffolding.md` as work completes._

### Phase 1 – Finalize token definitions (Design + Dev pairing)
- Add the Football SA palette constants and document them in code comments.
- Extend `TypographyTokens` with explicit timer, card headline, and meta roles; update previews to capture new fonts.
- Provide `ComponentStyles` additions: `cardCornerRadius`, `cardShadow`, `listVerticalSpacing` derived from layout blueprint.

### Phase 2 – Theme core match surfaces (no layout change)
- Refactor `TimerView`, `TimerFaceFactory`, `StandardTimerFace`, and penalty flows to consume the new palette and typography while keeping their existing full-bleed formats.
- Audit match-specific overlays, progress rings, and alerts to ensure they communicate state using the updated tokens.
- Validate on 41mm and 45mm simulators to confirm legibility and contrast when in motion.

### Phase 3 – Roll out card layout to navigation/config screens
- Convert entrypoint, match options, match history, and settings views to the card-based list pattern with consistent spacing.
- Ensure tap targets meet ≥44pt and enforce `ComponentStyles.cardCornerRadius` and `listVerticalSpacing` tokens across these screens.
- Capture before/after screenshots for documentation in `docs/decisions`.

### Phase 4 – Share theme with iOS & add high-contrast variant
- Replace `RefZoneiOS/Core/DesignSystem/AppTheme` usages with the shared theme objects; adapt spacing to align with iOS HIG (larger paddings, adapt typography scale).
- Supply a `HighContrastTheme` toggled via Settings, increasing `textSecondary` opacity and `outlineMuted` thickness.
- Create UI tests validating theme switching.

## Acceptance criteria & checkpoints
- ✅ Palette values defined in code and validated for ≥4.5:1 contrast (key text at ≥7:1) using Figma/Sketch or web tools; record ratios in `docs/theme-brief.md` once confirmed.
- ✅ Match-critical screens use theme tokens exclusively while preserving glanceable layouts (no regressions in tap targets or animation timing).
- ✅ Navigation/config flows showcase the card-based pattern with consistent spacing and alignment tokens.
- ✅ Preview gallery demonstrating base and high-contrast themes for top-level watch surfaces.
- ✅ Documented migration guide for iOS theme adoption.

## Deliverables for design & dev partnership
- Updated Figma (or design source) with palette swatches, card-layout components, and match-surface theme examples.
- Annotated screenshots for each Phase 2 and Phase 3 surface stored in `/docs/decisions` when ready.
- Engineering checklist referencing this plan embedded in `PLAN_ThemeScaffolding.md`.

## Open questions
- Should we support watchOS Accessibility sizes (Extra Large) by switching to paged layouts instead of long lists? Investigate during Phase 2.
- Does the brand require gradients beyond flat colors (e.g., hero tile)? If yes, define gradient tokens alongside flat colors.
- Confirm whether the high-contrast theme ships as part of MVP or moves to backlog; update roadmap accordingly.

