# Release Checklist

Use this checklist for both watchOS and iOS releases. Keep the working tree clean and ensure CI is green before cutting a release.

## Pre-Release Validation
- [ ] Confirm CI is green on the release branch.
- [ ] Verify watchOS and iOS builds succeed on the target Xcode version.
- [ ] Run unit and UI tests for iOS and watchOS (simulator or device).
- [ ] Smoke test core flows: match start/pause/halftime/resume/end.
- [ ] Smoke test lifecycle haptics: natural period boundary cue, halftime-expiry cue, repeating alert until acknowledgment, and no duplicate/late pulses after manual transition, abandonment, reset, finalize, interruption, or backgrounding.
- [ ] Smoke test account/assistant flows (login, image attach, streamed reply, post-match review).

## Versioning & Changelog
- [ ] Update `CHANGELOG.md` with user-facing highlights.
- [ ] Bump marketing and build versions in both targets.
- [ ] Confirm bundle identifiers and entitlements are correct for the release channel.

## Documentation
- [ ] Update DocC articles/tutorials if APIs changed.
- [ ] Refresh `docs/features/` guides for new user-visible behavior.
- [ ] Ensure `docs/glossary.md` reflects any terminology updates.
- [ ] Update the assistant spec/reference/architecture docs whenever the assistant transport, model tier, or attachment flow changes.

## Assets & Localization
- [ ] Check watch/iOS asset changes are included and sized correctly.
- [ ] Confirm any localized strings have fallbacks.
- [ ] Verify screenshots and shared release visuals match current UI.

## Build Verification
- [ ] Produce a release-candidate iOS build with the watchOS companion app.
- [ ] Inspect the built watch bundle `Info.plist` and confirm `WKBackgroundModes` contains only `workout-processing`; confirm no watch audio/media usage strings remain unless a separately approved feature requires them.
- [ ] Inspect the iOS app bundle and confirm no `OPENAI_API_KEY` value is embedded in the shipped app Info.plist or build settings.
- [ ] Validate the assistant server proxy path with a real image question on iPhone 15 Pro Max and confirm the response streams back from the backend proxy.
- [ ] Install the release-candidate build on target hardware and run a quick sanity check.
- [ ] Validate lifecycle haptic feel on Apple Watch Series 9 (45mm); simulator/build evidence alone is not sufficient for tactile sign-off.
- [ ] Confirm repeating lifecycle alerts stop and stay dismissed when RefWatch becomes inactive, backgrounds, or relaunches.

## Release & Tagging
- [ ] Tag the release commit following semantic versioning (`vX.Y.Z`).
- [ ] Push the tag and create release notes from the changelog.

## Post-Release
- [ ] Announce release notes in team channels.
- [ ] Monitor analytics, crash reporting, and review feedback for regressions.
