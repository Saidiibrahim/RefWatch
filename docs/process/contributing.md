# Contributing Guide

## Before You Start
- Install prerequisites listed in [Installation & Tooling](../getting-started/installation.md).
- Ensure you can build both watchOS and iOS targets locally.
- Review the [Architecture Overview](../architecture/overview.md) for folder conventions.

## Branch & Commit Expectations
- Branch naming: `feature/<short-description>`, `fix/<issue-id>`, or `docs/<topic>`.
- Commits: single-purpose, present tense (e.g., `Improve timer pause logic`).
- For UI changes, include screenshots or GIFs in the pull request.

## Development Workflow
1. Sync `main`.
2. Implement changes, keeping MVVM and folder boundaries intact.
3. Update or add tests when behavior changes.
4. Update DocC comments or `docs/` guides if features/components shift.
5. Run the relevant `xcodebuild` commands (build + tests).
6. Submit PR referencing related issues; include validation steps.

## Code Review Checklist
- Architectural alignment with watch/iOS split.
- Services remain protocol-driven; no platform-specific imports in shared code.
- Tests cover new or changed logic.
- Documentation updated (DocC + `docs/`).
- Schemes remain shared for CI.

## Slack & Questions
- Tag maintainers in the #refzone channel with blockers or architecture questions.
