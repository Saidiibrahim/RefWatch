# Release Checklist

## Pre-Release Validation
- [ ] Confirm watchOS and iOS builds succeed on latest Xcode GM.
- [ ] Run unit and UI tests for watch target.
- [ ] Verify timer flows (start, pause, halftime, resume) on device or simulator.
- [ ] Smoke test Assistant and Authentication features.

## Documentation
- [ ] Update DocC articles/tutorials if APIs changed.
- [ ] Refresh `docs/features/` guides for new user-visible behavior.
- [ ] Ensure `docs/glossary.md` reflects any terminology updates.

## Assets & Localization
- [ ] Check watch/iOS asset changes are included and sized correctly.
- [ ] Confirm any localized strings have fallbacks.

## Versioning
- [ ] Bump marketing and build versions in both targets.
- [ ] Tag release branch following semantic versioning (`vX.Y.Z`).

## Post-Release
- [ ] Announce release notes in team channels.
- [ ] Monitor analytics and crash reporting for regressions.
