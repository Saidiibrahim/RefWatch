# Apple Test Receipts — 2026-07-14

This artifact preserves the compact `xcresulttool` summaries for the final iOS
reruns after Xcode evicted the earlier DerivedData result bundles. The large
transient `.xcresult` directories are not repository artifacts.

## iOS Unit Target

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'platform=iOS Simulator,id=A14D4100-CCC5-4B05-AD82-39BA48742E49' \
  -parallel-testing-enabled NO -only-testing:RefWatchiOSTests \
  -resultBundlePath /tmp/refwatch-ios-unit-20260714.xcresult test
```

`xcodebuild` exited 0. The compact `xcresulttool get test-results summary`
readback was:

```json
{
  "device": {
    "deviceId": "A14D4100-CCC5-4B05-AD82-39BA48742E49",
    "modelName": "iPhone 15 Pro Max",
    "osBuildNumber": "21A342",
    "osVersion": "17.0.1",
    "platform": "iOS Simulator"
  },
  "expectedFailures": 0,
  "failedTests": 0,
  "passedTests": 89,
  "result": "Passed",
  "skippedTests": 0,
  "totalTestCount": 89
}
```

The console output separately accounted for 71 XCTest cases and 18 Swift
Testing cases.

## iOS UI Target

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS \
  -destination 'platform=iOS Simulator,id=BA142766-1871-4873-80C4-5DE6BB7987CA' \
  -parallel-testing-enabled NO -only-testing:RefWatchiOSUITests \
  -resultBundlePath /tmp/refwatch-ios-ui-20260714.xcresult test -quiet
```

`xcodebuild` exited 0. The compact `xcresulttool get test-results summary`
readback was:

```json
{
  "device": {
    "deviceId": "BA142766-1871-4873-80C4-5DE6BB7987CA",
    "modelName": "iPhone 15 Pro Max",
    "osBuildNumber": "22F77",
    "osVersion": "18.5",
    "platform": "iOS Simulator"
  },
  "expectedFailures": 0,
  "failedTests": 0,
  "passedTests": 19,
  "result": "Passed",
  "skippedTests": 2,
  "totalTestCount": 21
}
```

The two skips remain the bounded unavailable attachment-picker/fallback and
theme-selection product surfaces described in `2026-07-14-verification.md`.
