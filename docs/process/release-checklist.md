# Release Checklist

Use this checklist for both watchOS and iOS releases. Keep the working tree clean and ensure CI is green before cutting a release.

## Pre-Release Validation
- [ ] Confirm CI is green on the release branch.
- [ ] Verify watchOS and iOS builds succeed on the target Xcode version.
- [ ] Run unit and UI tests for iOS and watchOS (simulator or device).
- [ ] Smoke test core flows: match start/pause/halftime/resume/end.
- [ ] Smoke test account/assistant flows (login, sync, mirror, post-match review).

## Versioning & Changelog
- [ ] Update `CHANGELOG.md` with user-facing highlights.
- [ ] Bump marketing and build versions in both targets.
- [ ] Confirm bundle identifiers and entitlements are correct for the release channel.

## Documentation
- [ ] Update DocC articles/tutorials if APIs changed.
- [ ] Refresh `docs/features/` guides for new user-visible behavior.
- [ ] Ensure `docs/glossary.md` reflects any terminology updates.

## Assets & Localization
- [ ] Check watch/iOS asset changes are included and sized correctly.
- [ ] Confirm any localized strings have fallbacks.
- [ ] Verify screenshots and app previews match current UI.

## Build & Archive
- [ ] Archive iOS (with watchOS companion) in Xcode Organizer.
- [ ] Validate archive for App Store distribution.
- [ ] Export TestFlight build and run a quick device install check.

## Release & Tagging
- [ ] Tag the release commit following semantic versioning (`vX.Y.Z`).
- [ ] Push the tag and create release notes from the changelog.
- [ ] Upload to TestFlight / App Store and confirm processing status.

## Post-Release
- [ ] Announce release notes in team channels.
- [ ] Monitor analytics, crash reporting, and review feedback for regressions.
