## Plan: Migrate RefWatch to iOS Container With Embedded watchOS App (Option 2)

Status: Draft plan to restructure project for the classic iOS + embedded watchOS distribution model used by TestFlight and App Store.

### Context & Goal
- Current setup is watch-first with a standalone watchOS app (`RefZone` watch container + `RefZone Watch App`) and a separate iOS app (`RefZoneiOS`).
- Goal is to ship via a single iOS binary that embeds the watchOS app, so TestFlight/Testers install the iOS app and the paired Apple Watch installs the watch app automatically.

### Target End State (High Level)
- iOS app becomes the container app: `RefWatch` (bundle ID: `com.IbrahimSaidi.RefWatch`).
- watchOS app is embedded: `RefZone Watch App` (bundle ID: `com.IbrahimSaidi.RefWatch.watchkitapp`).
- Xcode scheme "RefWatch" archives an iOS `.xcarchive` that contains the watch app.
- TestFlight distribution happens from the iOS app record; watch app rides inside automatically.

### Prerequisites
- Xcode 16.x.
- Active Apple Developer Program membership.
- Ability to create/manage App IDs and provisioning profiles for both iOS and watchOS.

### Step-by-Step Migration

1) Prepare Identifiers and App Store Connect
- Reserve (or confirm) iOS App ID: `com.IbrahimSaidi.RefWatch`.
- Reserve watchOS App ID: `com.IbrahimSaidi.RefWatch.watchkitapp`.
- In App Store Connect, create an iOS app record using `com.IbrahimSaidi.RefWatch` (this will be the TestFlight host). Leave the old watch-only record untouched for now.

2) Rename and Align iOS Target
- In Xcode, rename target `RefZoneiOS` → `RefZone` (optional but recommended for clarity).
- Update iOS target bundle identifier to `com.IbrahimSaidi.RefWatch`.
- Ensure Signing & Capabilities is set to your team with "Automatically manage signing" enabled.

3) Embed the Watch App Into the iOS Target
- Select iOS target `RefWatch` → General → Frameworks, Libraries, and Embedded Content.
- Add `RefZone Watch App.app` and set to "Embed & Sign".
- Xcode should create an "Embed Watch Content" build phase on the iOS target. Verify the watch app appears there.

4) Remove Standalone Watch Container Target (After Successful Dry Run)
- The existing standalone watch container target currently named `RefWatch` (product type `watchapp2-container`) becomes redundant once the watch app is embedded in iOS.
- After embedding works locally, delete that container target from the project to avoid confusion.

5) Bundle IDs & Plists
- Watch app target bundle ID should be `com.IbrahimSaidi.RefWatch.watchkitapp`.
- In the watch app Info.plist, ensure `WKCompanionAppBundleIdentifier` matches the iOS bundle ID `com.IbrahimSaidi.RefWatch` (Xcode often manages this automatically; verify).
- The iOS app Info.plist does not typically require manual watch keys when using modern templates, but verify that the archive shows the watch app embedded.

6) Schemes & Build Order
- Make sure the iOS scheme (now `RefWatch`) builds the watch app as a dependency (this happens automatically when embedded).
- Archive using the iOS scheme; the resulting archive should contain both the iOS app and the watch app in the Organizer.

7) Signing & Provisioning
- iOS target: iOS Development/Distribution profiles for `com.IbrahimSaidi.RefWatch`.
- Watch target: watchOS Development/Distribution profiles for `com.IbrahimSaidi.RefWatch.watchkitapp`.
- Keep both on the same Apple Development team; prefer "Automatically manage signing" unless you need explicit profiles.

8) CI/CD and Local Build Commands
```bash
# Clean archive for iOS container (must use iOS scheme)
xcodebuild -project RefZone.xcodeproj \
  -scheme "RefWatch" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/RefWatch_iOS.xcarchive archive

# Export for App Store/TestFlight (requires an export options plist)
xcodebuild -exportArchive \
  -archivePath build/RefWatch_iOS.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

ExportOptions.plist (example, supply your own signing method and team ID):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>uploadBitcode</key><false/>
  <key>compileBitcode</key><false/>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>stripSwiftSymbols</key><true/>
  <key>teamID</key><string>6NV7X5BLU7</string>
</dict>
</plist>
```

9) App Store Connect Upload & TestFlight
- Use Xcode Organizer → Distribute App on the iOS archive. Validation should show the embedded watch app.
- Once processing completes in App Store Connect, enable TestFlight for the iOS app; the watch app will be available to paired watches automatically.

10) Data/Settings Migration Considerations
- Keychain access groups and app group identifiers may change if bundle IDs change; audit any persistent storage or shared containers.
- If you previously shipped a standalone watch app, plan for a transition period where both are available; communicate migration to existing users.

11) Risk & Mitigations
- Project restructuring risk (medium/high): perform changes on a dedicated branch (e.g., `option2/ios-watch-bundle`).
- Signing complexity: prefer automatic signing; verify provisioning for both platforms before archiving.
- Bundle ID changes: verify push/notifications, background modes, and Health/Workout entitlements on both targets.

12) Rollback Strategy
- Keep the original project targets and the old watch-only App Store Connect record intact on a separate branch/tag.
- If archiving or TestFlight validation fails, revert to the watch-only distribution path immediately.

13) Verification Checklist (Local, then TestFlight)
- Local run with iPhone selected installs both iOS and watchOS apps to paired hardware.
- Archive contains `RefWatch.app` and an embedded `RefZone Watch App.app`.
- TestFlight install on iPhone results in watchOS app auto-installing on paired watch.
- End-to-end smoke tests pass: open watch app → start/pause/resume timer → lifecycle flows.

### Timeline (Rough)
- Day 1: App IDs, signing, and initial embedding.
- Day 2: Archive, validation, and internal TestFlight build.
- Day 3–4: QA on multiple devices/watchOS versions; fix issues.

### Notes
- This plan intentionally leaves the watch-only path available so we can compare UX and decide which distribution to keep long term.
