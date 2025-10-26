# ExecPlan: watch_ui_polish

## Purpose / Big Picture
Polish the watchOS experience before beta by eliminating unfinished actions and clarifying the team setup screens. The work should (1) prevent users from tapping a "Choose colours" row that only shows a placeholder alert, and (2) surface real team names plus contextual guidance in the team detail views so referees instantly know which side they are editing.

## Suprises & Discoveries
- Observation: _None yet_
- Evidence: _None yet_

## Decision Log
- Decision: _None yet_
- Rationale: _N/A_
- Date/Author: _N/A_

## Outcomes & Retrospective
_Pending completion of the plan._

## Context and Orientation
The watch app uses SwiftUI with feature-first organization.
- `RefZoneWatchOS/Features/Timer/Views/MatchOptionsView.swift` presents match management actions via a carousel list in a `NavigationStack`. The "Choose colours" `ActionButton` currently triggers an alert explaining the feature is coming soon.
- `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift` renders the home/away event grids. It shows hard-coded headers (`"HOM"`/`"AWA"`) regardless of the match configuration and lacks descriptive copy to orient the referee.
- `ActionButton` is a reusable component (see `RefZoneWatchOS/Core/Components/ActionButton.swift`, already themed) used for options rows.
- `MatchViewModel` exposes `homeTeamDisplayName`/`awayTeamDisplayName`, which are used elsewhere (e.g., timer score display) and can replace the static abbreviations.

## Plan of Work
1. **Match options cleanup**: In `MatchOptionsView`, conditionally hide or visually downgrade the "Choose colours" entry until colours are supported. Replace the tap with explanatory secondary text so the list reads intentional for beta users.
2. **Team header improvements**: In `TeamDetailsView`, display the configured team name with safe truncation and add a short subtitle (e.g., "Manage home events") so each tab communicates its purpose. Ensure large and compact layouts remain balanced.
3. Update previews if needed to reflect new copy and verify layout on 41mm and Ultra devices.

## Concrete Steps
- See tasks under `.agent/tasks/watch_ui_polish/`.

## Progress
[ ] (TASK_01_watch_ui_polish.md) Remove or gate the "Choose colours" action from MatchOptionsView.
[ ] (TASK_02_watch_ui_polish.md) Replace "HOM/AWA" headers with contextual team info in TeamDetailsView.

## Testing Approach
Targeted SwiftUI preview inspection for the affected views (`MatchOptionsView`, `TeamDetailsView`). If time permits, run the watchOS scheme to confirm layout alignment, but focus on visual verification via previews or simulator snapshots.

## Constraints & Considerations
- Avoid exposing unfinished features to testers.
- Maintain existing theming by reusing the `theme` environment values and respecting `watchLayoutScale` sizing.
- Ensure accessibility labels remain accurate when header text changes.
