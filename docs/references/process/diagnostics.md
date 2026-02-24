# Diagnostics Runbook

Use this guide when a build, test, or runtime issue needs structured triage.

## Before You Start
- [ ] Capture the git SHA and branch.
- [ ] Note Xcode + macOS versions (`xcodebuild -version`, `sw_vers`).
- [ ] List connected devices and simulators (`xcrun simctl list devices available`).
- [ ] Record SwiftLint/SwiftFormat versions if linting is involved.

## Quick Triage (Local)
- [ ] Re-run the failing step locally with the same scheme and destination.
- [ ] Confirm the linter config files are present: `.swiftlint.yml` and `.swiftformat`.
- [ ] Clean DerivedData if the failure is non-deterministic:
  - `rm -rf ~/Library/Developer/Xcode/DerivedData`
- [ ] Reset simulators if UI or runtime failures persist:
  - `xcrun simctl erase all`

## CI-Specific Checks
- [ ] Compare the CI Xcode version with local Xcode.
- [ ] Verify the CI simulator selection logs match the platform you expect.
- [ ] Confirm lint steps run before build/test in `.github/workflows/ci.yml`.

## Common Failure Patterns

### SwiftLint / SwiftFormat
- [ ] Verify binaries are installed and on PATH.
- [ ] Run directly:
  - `swiftlint --config .swiftlint.yml`
  - `swiftformat --lint . --config .swiftformat`

### Build or Test Failures
- [ ] Re-run with a local result bundle to capture details:
  - `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatchiOS" -destination "<dest>" -resultBundlePath /tmp/RefWatch.xcresult`
- [ ] Inspect the result bundle:
  - `xcrun xccov view --report --only-targets /tmp/RefWatch.xcresult`
  - `xcrun xcresulttool get --path /tmp/RefWatch.xcresult --format json > /tmp/xcresult.json`

### Simulator Pairing (watchOS)
- [ ] Ensure a watchOS simulator exists and is available.
- [ ] If watchOS tests fail to boot, try:
  - `xcrun simctl shutdown all`
  - `xcrun simctl boot "<watch-udid>"`

### Runtime/Sync Issues (iOS ↔ watchOS)
- [ ] Confirm WatchConnectivity is enabled in entitlements.
- [ ] Verify the watch and iPhone simulators are paired.
- [ ] Check console logs for `WCSession` activation errors.

## What to Share in a Bug Report
- [ ] Git SHA + branch
- [ ] Xcode + macOS versions
- [ ] Failing command(s) and destination(s)
- [ ] Relevant excerpts from the xcresult or simulator logs
- [ ] Steps to reproduce and expected vs actual behavior

## Security Note
Never include API keys, access tokens, or personal data in shared logs or screenshots.
