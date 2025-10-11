# Running RefZone Locally

## Watch App (Primary)
1. In Xcode, select the `RefZone Watch App` scheme.
2. Choose `Apple Watch Series 9 (45mm)` or your preferred simulator.
3. Build & run (`⌘R`).
4. For CLI builds:
   ```bash
   xcodebuild -project RefZone.xcodeproj \
     -scheme "RefZone Watch App" \
     -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
   ```

## iOS Companion App
1. Switch to the `RefZoneiOS` scheme.
2. Select an `iPhone 15` simulator.
3. Build & run (`⌘R`).
4. CLI build command:
   ```bash
   xcodebuild -project RefZone.xcodeproj \
     -scheme RefZoneiOS \
     -destination 'platform=iOS Simulator,name=iPhone 15' build
   ```

## Testing
- Primary focus: watchOS unit/UI tests.
- Run all tests from Xcode or via:
  ```bash
  xcodebuild test -project RefZone.xcodeproj \
    -scheme "RefZone Watch App" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
  ```

## Troubleshooting
- If the watch app fails to install, make sure the paired iPhone simulator is running.
- For signing issues, ensure personal team provisioning profiles are selected under Targets → Signing & Capabilities.
