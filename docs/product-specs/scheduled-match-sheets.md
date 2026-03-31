# Scheduled Match Sheets

## Objective
Let referees save upcoming matches on iPhone whether or not they have match sheets, while letting watchOS use saved side-specific participant lists whenever they exist.

## Product Rules
- Library teams remain reusable source rosters only.
- No library team owns a permanent match sheet.
- Each scheduled fixture may own:
  - `homeMatchSheet`
  - `awayMatchSheet`
- Match sheets are optional on both sides.
- `Save` in the upcoming-match editor remains available as long as the basic fixture fields are valid.
- A saved manual or imported sheet is final for that side until the referee edits or replaces it later.
- iPhone does not expose `Draft`, `Ready`, `Official`, or `Watch Ready` labels in the upcoming editor or match-sheet editor.
- iPhone may offer Teams library/catalog autofill for the home/away name fields through the app’s existing team-selection flow. Picker selection updates only the visible schedule name string and does not bind `TeamRecord`, mint team IDs, or rewrite stored sheet provenance.
- iPhone may still persist explicit empty home/away sheet shells for compatibility, but that is an internal storage detail and not user-facing product language.
- Existing `sourceTeamId` / `sourceTeamName` remain preserved provenance for older or imported sheets, but iPhone editing does not silently reseed them from the library.
- Later edits to the library must not silently rewrite saved schedule sheets.

## Match Sheet Structure
- Each sheet stores:
  - optional preserved source-team linkage and denormalized source-team name
  - internal status: `draft` or `ready`
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

## Internal Status Rules
- `draft` and `ready` remain internal persistence/sync states only.
- A side is promoted to `ready` when the upcoming match is saved and that side:
  - has at least one starter
  - has the required denormalized display fields on every included entry
  - has stable explicit ordering
- A side that does not meet those rules is persisted as `draft`.
- Eleven starters is a UX target and summary aid, not a save blocker.
- Staff and other members are optional.

## iPhone Scheduling UX
- The upcoming-match editor shows separate `Home Match Sheet` and `Away Match Sheet` sections.
- Home and away fixture names are free-text schedule fields, with optional Teams library/catalog autofill for the visible name only.
- That autofill uses the same saved-team plus reference-catalog browsing flow as Settings > Library > Teams. Selecting one updates only the chosen text field; it does not bind a library team to the schedule, reseed entries, or rewrite stored provenance/IDs.
- The schedule editor is the source of truth for editing official match sheets.
- Each side exposes explicit actions:
  - `Add Manually` or `Edit`
  - `Import Screenshots` or `Replace from Screenshots`
  - `Remove Sheet` when that side already has entries
- The upcoming editor shows per-side participant counts only when a side has entries:
  - starters
  - substitutes
  - staff
  - other members
- When a side is empty, the upcoming editor shows optional guidance instead of a readiness state.
- `MatchSheetEditorView` manages:
  - starters
  - substitutes
  - staff
  - other members
- `MatchSheetEditorView` keeps internal `draft` / `ready` preparation out of the visible iPhone UI. Standard editing shows participant sections only, while import review shows parser warnings plus editable entries before the parent upcoming match is saved.
- Import review stays focused on parser warnings plus editable entries, and `Use Import` only updates the selected side in memory until the parent upcoming match is saved.
- Existing saved schedules must have a stable pre-kickoff edit route on iPhone.
- Editing match sheets after kickoff is out of scope for v1.

### Screenshot Import
- Import is per side and supports multiple screenshots in one submission so a complete sheet can be reconstructed from several captures.
- The app parses screenshots into starters, substitutes, staff, and other members, then presents a transient review surface before anything is persisted.
- `Use Import` updates only the selected side inside the upcoming-match editor.
- The parent upcoming-match `Save` action is the persistence boundary.
- Importing screenshots for a side replaces that side’s current entries; there is no merge flow.
- The import parser surfaces warnings for unreadable text, ambiguous identity, duplicate entries, unsupported roles, or team-name mismatches so the referee can correct the imported side before saving.
- Raw screenshots and parser output stay transient in the import flow; only the normalized schedule-owned match sheet is persisted.

## Watch Consumption Rules
- Watch uses saved sheets per side, not all-or-nothing across the fixture.
- When the requested side has a persisted `ready` sheet, watch uses that side’s saved participants.
- When the requested side has no usable saved sheet, watch falls back for that side only.
- If neither side has any saved sheet model at all, legacy library-roster lookup may still be used only in flows that already had that backward-compatibility behavior before schedule-owned sheets existed.
- Newly saved schedules authored under this feature are not treated as legacy, even if one or both sides remain empty.

### Watch Event Entry
- Player numbers are the primary identity for referees and should remain visible in selection rows whenever a side list exists.
  - Example: `#10 Lionel Messi`
- Goals are player-only:
  - if the side has a usable saved sheet, goal selection uses saved player names for that side
  - otherwise the flow falls back to manual player-number entry for that side
- Cards are side-specific:
  - player cards use saved starters/substitutes for that side when that side has a usable saved player list, otherwise manual/numeric entry
  - team-official cards use saved staff/other members for that side when available, preserve stored free-text role labels when they do not map cleanly to the generic picker roles, and keep generic official-role fallback available when the saved list is partial or missing the needed person
- Substitutions stay strict when the side has a usable saved sheet:
  - `player(s) off` comes from the current on-field set derived from starters plus saved substitution history
  - `player(s) on` comes from unused substitutes
  - if a saved side has no eligible candidates for a spoke, watch shows an unavailable state instead of silently falling through to numeric/manual entry
- When a side does not have a usable saved sheet, substitution entry falls back to manual numeric entry for that side.

## Live Match Freeze
- When a scheduled match starts, the live match/session context freezes whichever home/away match sheets are present onto the live match.
- Once a scheduled fixture is attached, team identity for kickoff comes from the schedule.
  - Match setup must preserve the scheduled home/away team identity.
  - If a referee needs different teams, they must return to the schedule editor and change the schedule before kickoff.
- During play, restore, and relaunch, participant choices resolve from frozen live-match sheets and substitution history whenever the live match carries schedule-owned sheets.
- Legacy true no-sheet schedules remain allowed to use the backward-compatible library-roster lookup path.

## Validation Focus
- Existing schedules with no sheets still load.
- Upcoming matches can be saved with no sheets at all.
- One-side-only sheets survive relaunch and sync.
- Complete saved sides are promoted to `ready` on save and are consumable on watch.
- Incomplete or missing sides fall back safely without blocking the whole fixture.
- Player selection rows on watch keep shirt numbers visible whenever a side list exists.
