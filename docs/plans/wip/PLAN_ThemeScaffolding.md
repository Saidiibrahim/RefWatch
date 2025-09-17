# Plan: Theme Scaffolding Rollout

## Completed
- Implemented shared theming scaffolding and wired the watch entry screen into it.
  - `docs/theme-brief.md:1` captures the product brief plus current color/typography audits so future contributors can align on intent before coding changes.
  - `RefWatchCore/Sources/RefWatchCore/DesignSystem/Theme/Theme.swift:3` together with `ColorTokens.swift:3`, `TypographyTokens.swift:3`, `SpacingTokens.swift:3`, and `ComponentStyles.swift:3` introduces a reusable token-based theme (including environment support via `AnyTheme`) that both targets can import.
  - `RefZoneWatchOS/App/ContentView.swift:11` now injects `@Environment(\.theme)` and routes hero + quick actions through semantic colors, typography, spacing, and component metrics; helper views such as `StartMatchHeroCard` and `QuickActionLabel` pull from the new tokens to eliminate hard-coded styling.

## Reference material
- `docs/watchos-theme-alignment-plan.md` – design blueprint aligning the rollout with watchOS HIG guidance, palette mapping, and phased roadmap.
- `docs/theme-brief.md` – background brief and audit results that motivated the shared theming work.

## Roadmap
_Phases mirror the design plan; update checkboxes as work completes._

### Phase 1 – Finalize tokens & component metrics *(in progress)*
- [ ] Add Football SA-derived palette constants in `ColorTokens` and document contrast ratios.
- [ ] Extend `TypographyTokens` with `timerPrimary`, `timerSecondary`, `cardHeadline`, and `cardMeta` roles using scaled fonts.
- [ ] Expose `ComponentStyles.cardCornerRadius`, `cardShadow`, `listVerticalSpacing`, and ensure spacing tokens cover the navigation card layout blueprint.
- [ ] Capture previews demonstrating the new tokens in isolation (no surface rewrites yet).

### Phase 2 – Theme core match surfaces *(no layout change)*
- [ ] Refactor `TimerView`, `TimerFaceFactory`, `StandardTimerFace`, and penalty flows to adopt palette/typography tokens while keeping full-bleed interactions.
- [ ] Audit overlays, progress indicators, and alerts to confirm state colors read correctly under motion and ambient lighting.
- [ ] Run visual QA on 41mm + 45mm simulators; log issues in this plan for follow-up.

### Phase 3 – Card layout for navigation & configuration
- [ ] Convert entry, match options, match history, and settings screens to the card-based list pattern using shared spacing + component tokens.
- [ ] Verify tap targets meet ≥44pt and spacing tokens produce consistent rhythm across these screens.
- [ ] Capture before/after screenshots and store annotated comparisons in `/docs/decisions`.

### Phase 4 – iOS adoption & high-contrast theme
- [ ] Replace the iOS-specific `AppTheme` implementation with the shared theme API; adapt spacing/typography via platform conditionals.
- [ ] Introduce a `HighContrastTheme` variant toggleable via Settings; validate contrast targets.
- [ ] Add regression tests (snapshot or UI) confirming theme selection persistence and visual differences.

## Risks & follow-ups
- watchOS sandbox build issues (clang cache) still block local `swift build`; rerun outside sandbox to verify once palette code lands.
- Brand assets may update with precise hex values; keep palette definitions centralized to minimize churn.
- Ensure match-critical surfaces remain performant when color updates occur (watch out for expensive gradients or animations tied to theme changes).

