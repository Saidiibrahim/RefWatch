# Contributing Guide

## Before You Start
- Read our [Code of Conduct](../../CODE_OF_CONDUCT.md).
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

## First-Time Contributors
New to the project? Here's how to get started:
1. Look for issues labeled [`good first issue`](https://github.com/Saidiibrahim/RefWatch/labels/good%20first%20issue).
2. Comment on the issue to let maintainers know you're working on it.
3. Fork the repo and create a branch following the naming conventions above.
4. Submit a PR using the [pull request template](../../.github/PULL_REQUEST_TEMPLATE.md).

## Reporting Issues
Use the issue templates when reporting bugs or requesting features:
- [Bug Report](../../.github/ISSUE_TEMPLATE/bug_report.md)
- [Feature Request](../../.github/ISSUE_TEMPLATE/feature_request.md)

## Questions & Support
- Open a GitHub Discussion or tag maintainers in the issue with blockers or architecture questions.
