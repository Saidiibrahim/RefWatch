# AGENTS.md — docs folder

This file guides coding agents working within the `docs/` directory. It complements the root `AGENTS.md` and applies to the entire `docs/` subtree (including `docs/decisions/`).

## Scope
- Applies to: `docs/**`
- Purpose: Organize planning and architecture docs so agents can locate, create, and update them consistently without impacting app builds.
- Build impact: Files in `docs/` are not part of any Xcode target and do not affect builds or tests.

## Structure
- Planning docs: `docs/PLAN_*.md` (feature plans, roadmaps, distribution, migrations, backends).
- Architecture decisions: `docs/decisions/ADR-*.md` (Architecture Decision Records).
- Additional docs live alongside these as needed. Prefer concise, single-purpose files.

## Conventions
- Filenames
  - Plans: `PLAN_<Topic>_<Qualifier>.md` (use `PascalCase` words joined by underscores). Examples: `PLAN_TimerFaces_Roadmap.md`, `PLAN_TestFlight_Distribution.md`.
  - ADRs: `ADR-<NNNN>-<slug>.md` under `docs/decisions/` (kebab-case slug).
- Content style
  - Use clear headings; keep sections focused and scannable.
  - Prefer relative links. From outside `docs/`, use `docs/<file>.md` paths. Within `docs/`, relative links are fine.
  - Include actionable checklists where helpful; avoid duplicating code-level details that belong in source comments.
- Ownership notes
  - Plans should reflect the current intent of the product/feature.
  - ADRs capture decisions with context, alternatives, and consequences; they rarely change after acceptance—add new ADRs instead of rewriting history.

## Tasks agents can do here
- Create or update plan docs (`PLAN_*.md`) for new or evolving features.
- Write ADRs under `docs/decisions/` when a durable architectural decision is made.
- Update cross-references when files move or are renamed.
- Maintain an up-to-date index of plan docs (see below).

## Cross-reference updates
- When moving or renaming any `PLAN_*.md`, search and update references:
  - Search: `rg -n "\\bPLAN_.*\\.md\\b"` from repo root.
  - Fix links found in Markdown, comments, or other docs. Use `docs/<file>.md` when linking from outside `docs/`.

## Current plan documents
- [PLAN_Frameworks_Integration_Roadmap.md](PLAN_Frameworks_Integration_Roadmap.md)
- [PLAN_iOS_Target_Roadmap.md](PLAN_iOS_Target_Roadmap.md)
- [PLAN_MatchLifecycle_Roadmap.md](PLAN_MatchLifecycle_Roadmap.md)
- [PLAN_Supabase_Backend_Architecture.md](PLAN_Supabase_Backend_Architecture.md)
- [PLAN_TestFlight_Distribution.md](PLAN_TestFlight_Distribution.md)
- [PLAN_TimerFaces_Roadmap.md](PLAN_TimerFaces_Roadmap.md)
- [PLAN_watchOS_LiveActivities_Roadmap.md](PLAN_watchOS_LiveActivities_Roadmap.md)
- [PLAN_watchOS_SwiftData_Migration.md](PLAN_watchOS_SwiftData_Migration.md)

## ADRs present
- See `docs/decisions/`. Example:
  - ADR-0001 — WidgetKit-first for watchOS, optional ActivityKit on iOS (`docs/decisions/ADR-0001-widgetkit-first-watchos.md`).

## Contribution workflow for docs
- For a new plan: add a `PLAN_*.md` file, add it to the index above, and reference it from relevant ADRs or README sections when appropriate.
- For an ADR: create `docs/decisions/ADR-xxxx-<slug>.md` with Status, Context, Options, Decision, Rationale, Consequences, and Rollback.
- Keep docs in sync with code: when major flows change, update the corresponding plan/ADR or create a new ADR.

## Do and don’t
- Do keep plans practical and tied to current milestones.
- Do use relative links and update them when files move.
- Don’t place secrets, credentials, or target-specific configs here.
- Don’t duplicate code-level decisions that are already captured in ADRs—link instead.

---
This directory-level AGENTS.md follows the open AGENTS.md format and narrows guidance to documentation tasks so agents can operate predictably in `docs/`.
