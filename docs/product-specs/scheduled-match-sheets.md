# Scheduled Match Sheets

## Objective
Let referees prepare official home and away match sheets per scheduled fixture on iPhone, then make watchOS live-match player selection consume those frozen schedule-owned sheets.

## Product Rules
- Library teams remain reusable source rosters only.
- No library team owns a permanent match sheet.
- Each scheduled fixture may own:
  - `homeMatchSheet`
  - `awayMatchSheet`
- Newly saved schedules under this feature always persist explicit home/away match-sheet objects, even when both are empty drafts.
- A scheduled match sheet can be seeded from the selected library team when available, but becomes a schedule-owned frozen snapshot once saved.
- Team selection alone does not silently populate official participants.
  - iPhone persists explicit draft match-sheet shells for new schedules.
  - `Create Match Sheet`, `Add Players`, and `Add Staff` are the actions that seed or mutate the schedule-owned sheet.
- Later edits to the library team must not silently rewrite saved schedule sheets.

## Match Sheet Structure
- Each sheet stores:
  - source team linkage and denormalized source team name
  - status: `draft` or `ready`
  - starters
  - substitutes
  - coaching staff
  - other members
  - updated timestamp
- Player entries keep source linkage plus denormalized values:
  - display name
  - shirt number
  - position
  - notes
  - sort order
- Staff/member entries keep source linkage plus denormalized values:
  - display name
  - role label
  - notes
  - sort order
- Ad hoc entries are allowed. When an entry is ad hoc, source IDs may be absent but denormalized display fields remain required.

## Readiness Rules
- A sheet may be saved in `draft` with incomplete data.
- A sheet is `ready` when:
  - it has at least one starter
  - every included entry has the required denormalized display fields
  - list order is explicit and stable
- Eleven starters is a UX target and summary aid, not a hard save blocker.
- Staff and other members are optional.
- A scheduled match is watch-ready only when both home and away sheets are `ready`.

## iPhone Scheduling UX
- The upcoming-match editor shows separate `Home Match Sheet` and `Away Match Sheet` sections.
- The schedule editor is the source of truth for editing official match sheets.
  - `Add Players` and `Add Staff` always mutate the schedule-owned sheet.
  - Any library mutation path is a separate secondary action such as `Edit Source Team`.
- Each section exposes explicit actions:
  - `Create Match Sheet`
  - `Edit Match Sheet`
  - `Add Players`
  - `Add Staff`
- `Edit Match Sheet` is the detailed editor for all categories.
  - Players are managed inside `starters` and `substitutes`.
  - Staff and other members share the same non-player editor with an explicit category toggle.
  - `other members` are added from `Edit Match Sheet`; they are not a separate library-owned flow.
- The editor shows inline status/count summaries:
  - starters
  - substitutes
  - staff
  - other members
  - `Draft` or `Ready`
- Existing saved schedules must have a stable edit route on iPhone.
  - Tapping a schedule row may continue to launch match setup/start.
  - A dedicated schedule-edit action must reopen the schedule editor for pre-kickoff fixture changes, including match-sheet authoring.
- If the selected library team has no players or staff, iPhone must warn clearly and route users into sheet editing and/or library editing rather than pretending the side is ready.
- Editing match sheets after kickoff is out of scope for v1.

### Screenshot Import
- Each side also exposes `Import from Screenshots` for referees who have the match sheet split across multiple Photos images.
- Import is per side and supports multiple screenshots in one submission so a complete sheet can be reconstructed from several captures.
- The app parses the screenshots into starters, substitutes, coaching staff, and medical staff when those roles are visible, then presents a transient review draft before anything is applied to the schedule.
- `Apply Import` replaces the entire selected side with the normalized draft, and the imported sheet remains `draft` after apply and save so referees can continue editing it like any other schedule-owned sheet.
- The import parser should surface warnings for unreadable text, ambiguous identity, duplicate entries, unsupported roles, or team-name mismatches so the referee can correct the draft before saving.
- Raw screenshots and parser output stay transient in the import flow; only the normalized schedule-owned match sheet is persisted.

## Watch Consumption Rules
- Watch substitution/player selection uses scheduled match sheets first when both sides are `ready`.
- If a schedule contains match-sheet data but either side is not `ready`, watch must use manual/numeric entry and must not silently mix live library rosters into the official participant path.
- Legacy schedules created before match-sheet support, where both sheet fields are absent, may continue using the existing library-roster lookup as a backward-compatibility fallback.
- Newly saved schedules are not considered legacy because they persist explicit draft home/away match-sheet shells from the start.
- When a ready frozen sheet has no eligible candidates for a substitution spoke, watch shows an unavailable/blocked state for that spoke instead of falling through to numeric/manual entry.

## Live Match Freeze
- When a scheduled match starts, the live match/session context freezes the chosen home and away match sheets onto the live match.
- Once a scheduled fixture is attached, team identity for kickoff comes from the schedule.
  - Match setup must lock or preserve the scheduled home/away team identity.
  - If a referee needs different teams, they must return to the schedule editor and change the schedule before kickoff.
- During play, restore, and relaunch, participant choices resolve from frozen live-match sheets and substitution history whenever the live match carries schedule-owned sheets.
- Legacy no-sheet schedules remain allowed to use the backward-compatible library-roster lookup path.

## Validation Focus
- Existing schedules with no sheets still load.
- Draft sheets survive relaunch and sync.
- Ready sheets sync to watch.
- Watch substitution/player selection prefers frozen scheduled sheets when watch-ready.
- Incomplete sheets fall back safely to numeric/manual entry.
