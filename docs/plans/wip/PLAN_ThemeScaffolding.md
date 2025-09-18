# Plan: Theme Scaffolding Rollout

## Completed
- Implemented shared theming scaffolding and wired the watch entry screen into it.
  - `docs/theme-brief.md:1` captures the product brief plus current color/typography audits so future contributors can align on intent before coding changes.
  - `RefWatchCore/Sources/RefWatchCore/DesignSystem/Theme/Theme.swift:3` together with `ColorTokens.swift:3`, `TypographyTokens.swift:3`, `SpacingTokens.swift:3`, and `ComponentStyles.swift:3` introduces a reusable token-based theme (including environment support via `AnyTheme`) that both targets can import.
  - `RefZoneWatchOS/App/MatchRootView.swift:11` now injects `@Environment(\.theme)` and routes hero + quick actions through semantic colors, typography, spacing, and component metrics; helper views such as `StartMatchHeroCard` and `QuickActionLabel` pull from the new tokens to eliminate hard-coded styling.

## Reference material
- `docs/watchos-theme-alignment-plan.md` – design blueprint aligning the rollout with watchOS HIG guidance, palette mapping, and phased roadmap.
- `docs/theme-brief.md` – background brief and audit results that motivated the shared theming work.

## Roadmap
_Phases mirror the design plan; update checkboxes as work completes._

### Phase 1 – Finalize tokens & component metrics *(in progress)*
- [x] Add Football SA-derived palette constants in `ColorTokens` and document contrast ratios.
- [x] Extend `TypographyTokens` with `timerPrimary`, `timerSecondary`, `cardHeadline`, and `cardMeta` roles using scaled fonts.
- [x] Expose `ComponentStyles.cardCornerRadius`, `cardShadow`, `listVerticalSpacing`, and ensure spacing tokens cover the navigation card layout blueprint.
- [x] Capture previews demonstrating the new tokens in isolation (no surface rewrites yet).

### Phase 2 – Theme core match surfaces *(no layout change)*
- [x] Refactor `TimerView`, `TimerFaceFactory`, `StandardTimerFace`, and penalty flows to adopt palette/typography tokens while keeping full-bleed interactions.
- [x] Audit overlays, progress indicators, and alerts to confirm state colors read correctly under motion and ambient lighting. *(2025-09-18: Selection + substitution flows, numeric keypad, and action sheets now fully tokenized; alert tints standardized to accent palette.)*
- [ ] Run visual QA on 41mm + 45mm simulators; log issues in this plan for follow-up. *(Blocked in sandbox: `xcodebuild` cannot access CoreSimulator services—see command log from 2025-09-18 15:31 for details. Re-run locally to capture screenshots once outside sandbox.)*

### Phase 3 – Card layout for navigation & configuration
- [ ] Convert entry, match options, match history, and settings screens to the card-based list pattern using shared spacing + component tokens. *(Entry, history, and settings updated; match options reverted to original layout pending new design direction.)*
- [ ] Verify tap targets meet ≥44pt and spacing tokens produce consistent rhythm across these screens. *(Need follow-up once match options path is finalised.)*
- [ ] Capture before/after screenshots and store annotated comparisons in `/docs/decisions`. *(Follow-up once QA run is unblocked.)*

### Phase 4 – iOS adoption & high-contrast theme
- [x] Replace the iOS-specific `AppTheme` implementation with the shared theme API; adapt spacing/typography via platform conditionals.
- [x] Introduce a `HighContrastTheme` variant toggleable via Settings; validate contrast targets.
- [x] Add regression tests (snapshot or UI) confirming theme selection persistence and visual differences.

## Risks & follow-ups
- watchOS sandbox build issues (clang cache) still block local `swift build`; rerun outside sandbox to verify once palette code lands.
- Brand assets may update with precise hex values; keep palette definitions centralized to minimize churn.
- Ensure match-critical surfaces remain performant when color updates occur (watch out for expensive gradients or animations tied to theme changes).
- Confirm the Pro Stoppage face typography scaling on 41mm hardware—`scaleEffect` keeps tokens aligned, but extreme content sizes may need bespoke sizing.
