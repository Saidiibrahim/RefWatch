# Running RefWatch Locally

## Watch App (Primary)
1. In Xcode, select the `RefWatch Watch App` scheme.
2. Choose `Apple Watch Series 9 (45mm)` or your preferred simulator.
3. Build & run (`⌘R`).
4. For CLI builds:
   ```bash
   xcodebuild -project RefWatch.xcodeproj \
     -scheme "RefWatch Watch App" \
     -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
   ```

## iOS Companion App
1. Switch to the `RefWatchiOS` scheme.
2. Select an `iPhone 15` simulator.
3. Build & run (`⌘R`).
4. CLI build command:
   ```bash
   xcodebuild -project RefWatch.xcodeproj \
     -scheme RefWatchiOS \
     -destination 'platform=iOS Simulator,name=iPhone 15' build
   ```

## Testing
- Primary focus: watchOS unit/UI tests.
- Run all tests from Xcode or via:
  ```bash
  xcodebuild test -project RefWatch.xcodeproj \
    -scheme "RefWatch Watch App" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
  ```
- For iOS coverage locally:
  ```bash
  ./scripts/test-ios-coverage.sh
  ```

## Troubleshooting
- If the watch app fails to install, make sure the paired iPhone simulator is running.
- For signing issues, ensure personal team provisioning profiles are selected under Targets → Signing & Capabilities.
