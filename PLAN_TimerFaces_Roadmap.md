# Timer Faces Roadmap (watchOS)

Status: Working plan for introducing swappable timer faces to the watchOS app.

## Context & Goals
- Abstract the central match timer UI into swappable "faces" without changing timing logic.
- Keep `TimerManager` and `MatchViewModel` as the single source of truth for timing and lifecycle.
- `TimerView` remains the host for period label, score chrome, actions sheet, and lifecycle routing.
- Default face is visually identical to current UX ("Standard").

## Current Status
- PR1 (Architecture + Standard face) is MERGED to main (v0.5.1).
  - Branch: `feature/watchos-timer-faces`
  - PR: https://github.com/Saidiibrahim/RefWatch/pull/20

## PR Breakdown

### PR1 — Timer Faces Architecture (MERGED)
- Branch: `feature/watchos-timer-faces`
- Commits: 5 (landed in branch)
- Scope:
  - Contracts: `TimerFaceModel` (read‑only state + minimal actions).
  - Styles: `TimerFaceStyle` with default `.standard`.
  - Factory: `TimerFaceFactory` producing a SwiftUI view for a style.
  - Face: `StandardTimerFace` reproduces the previous inline UI.
  - Host wiring: `TimerView` renders face via factory; persists selection using `@AppStorage("timer_face_style")`.
  - Tests: model conformance + factory sanity; Docs updated in `AGENTS.md`.
- Acceptance:
  - Standard face renders and behaves exactly like before.
  - Long‑press actions + lifecycle routing still handled by the host.
  - Tests compile and pass.
- Risk: Low (UI extraction only).

### PR2 — Settings Toggle For Timer Face
- Branch: `feature/watchos-timer-face-settings`
- Base: `main`
- Commits: ~4
- Scope:
  - Add `TimerSettingsView` under `RefZoneWatchOS/Features/Settings/Views/` with a Picker over `TimerFaceStyle.allCases`.
  - Add a row in Settings root: "Timer Face" → navigates to picker.
  - Bind to `@AppStorage("timer_face_style")`; default `.standard`.
- Acceptance:
  - Choice persists and reflects in `TimerView` when returning to match screen.
  - No changes to behavior or routing otherwise.
- Tests:
  - Unit: AppStorage default + round‑trip set/get for face style.
- Risk: Low (isolated to Settings).

### PR3 — Pro Stoppage Face (ADVANCED)
- Branch: `feature/watchos-timer-face-pro`
- Base: `main` (after PR1 merges) or stack on PR2 if preferred
- Commits: ~4–6
- Scope:
  - Add `ProStoppageFace` to `Core/Components/TimerFaces/`.
    - Prominent per‑period target label (e.g., 45:00) for context.
    - Display "Elapsed" and "Stoppage" rows using existing `formattedStoppageTime`.
    - Subtle visual indicator for stoppage (orange accent) when active.
    - Tap toggles pause/resume like Standard.
  - Extend `TimerFaceStyle` and factory mapping with `.proStoppage`.
- Acceptance:
  - Switching faces changes visuals only; logic untouched.
  - Stoppage renders consistently with Standard face.
- Tests:
  - Factory returns a view for `.proStoppage`.
- Risk: Medium (enum growth). Ensure factory `switch` exhaustiveness.

### PR4 — Haptics Unification For Faces
- Branch: `feature/watchos-timer-face-haptics`
- Base: `main`
- Commits: ~3–4
- Scope:
  - Route face haptics via `HapticsProviding` instead of direct WatchKit calls.
  - Option A: Provide haptics through Environment to faces.
  - Option B: Host injects haptics into faces via init.
  - Extend `HapticsProviding` with simple cases: `.tap`, `.pause`, `.resume`, `.notify`.
- Acceptance:
  - No behavior change; faces compile without WatchKit imports.
- Tests:
  - Use a mock haptics provider in unit tests to verify calls (best‑effort).
- Risk: Low.

### PR5 — Tests & Docs Polish
- Branch: `feature/watchos-timer-face-tests-docs`
- Base: `main`
- Commits: ~2–3
- Scope:
  - Tests: host renders the expected face for a given AppStorage value.
  - Docs: Add a short guide "Authoring a Timer Face" with steps + code snippets.
- Acceptance:
  - Tests pass on watch target.
  - Docs explain adding a new face in ≤10 minutes.
- Risk: Low.

## Sequencing & Stacking
- PR1 merged: develop PR2 off `main`.
  - Create branch: `git checkout -b feature/watchos-timer-face-settings`
  - Push and open PR with base set to `main`.

## Acceptance Criteria (Global)
- Default face is Standard with zero behavior change.
- Users can switch faces in Settings; selection persists and reflects in the timer host.
- Advanced face surfaces stoppage clearly without altering timing logic.
- Faces remain view‑only (no navigation/lifecycle); host centralizes routing and action sheets.
- Haptics unified via provider (post‑PR4), keeping faces platform‑agnostic.

## Risks & Mitigations
- Enum growth/coverage: centralize mapping in factory; add tests for all cases.
- Settings routing regressions: isolate changes to the Settings feature; keep host untouched.
- Platform imports: remove direct WatchKit usage from faces in PR4.

## Rollback Strategy
- Each PR is additive and can be reverted independently.
- Standard remains the default face; if a new face causes issues, remove its enum case + factory mapping.

## Decisions on Prior Open Questions
- Quick access toggle: Defer. Settings toggle is sufficient for now.
- Cross‑device sync: Yes. Add a dedicated PR to sync face selection via connectivity.

### PR6 — Sync Face Selection Across Devices (Connectivity)
- Branch: `feature/timer-face-connectivity-sync`
- Base: `main`
- Commits: ~3–5
- Scope:
  - Use existing connectivity adapter (`ConnectivitySyncProviding`) to sync a small payload with the selected `TimerFaceStyle`.
  - Watch side: on change of `@AppStorage("timer_face_style")`, send `{"timer_face_style": "standard|proStoppage|..."}`.
  - iOS side: receive payload and persist in iOS AppStorage/UserDefaults (app group optional later), notify UI if Settings screen is visible.
  - On app launch, each side can optionally send its current value to reconcile.
- Acceptance:
  - Changing face on watch updates iOS preference shortly after (and vice versa if desired).
  - No crashes offline; updates queue or are dropped gracefully.
- Tests:
  - Use existing connectivity test scaffolding to assert send/receive round‑trip for a simple key/value change.
- Risk:
  - Low/Medium. Ensure schema versioning or namespacing (e.g., `prefs.timer_face_style`) to avoid clashing with other messages.
