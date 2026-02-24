# Match Setup Feature Guide

## Objective
Collect match parameters (teams, period length, stoppage settings) before launching the timer experience.

## Components
- `MatchSetupView`: SwiftUI flow guiding the referee through configuration steps.
- `MatchSetupViewModel`: owns form state, validation, and default values.
- Shared Models: team definitions and rule presets reused by watch and iOS.

## Flow
1. User opens Match Setup from the watch home or iOS matches tab.
2. Select teams, set period duration, choose timer face.
3. Review summary screen; confirm to transition to `MatchRootView`.
4. ViewModel passes configuration into `TimerManager` and related services.

## Validation Rules
- Ensure both teams selected (or substitute placeholders).
- Period duration must be positive; warn when outside recommended range.
- Optional toggles for halftime duration, stoppage, or overtime.

## Extensibility
- Additional rule presets can be added via the shared models.
- Integrate with Supabase for syncing default teams or rule sets between devices.

## Testing
- Cover form validation and default values in unit tests.
- UI tests should ensure the confirmation routes correctly into match flow.
