# Plan: Archive and Distribute to TestFlight (iOS + watchOS Companion)

Goal: produce a TestFlight build of the iOS app that includes and installs the bundled watchOS companion app for testers.

## Outcomes
- iOS build archived and uploaded from Xcode Organizer.
- TestFlight “Ready to Test” with an internal testers group assigned a build.
- Watch app auto‑installs for testers with a paired Apple Watch (or is installable from the Watch app’s “Available Apps”).

## Prerequisites
- Apple Developer Program account with App Store Connect access.
- Xcode 15+ signed in to the same team; Automatic signing enabled for both targets.
- Project setup:
  - iOS target contains the “Embed Watch Content” build phase that references the watch app.
  - watch target has `WKCompanionAppBundleIdentifier` pointing to iOS bundle id (companion configuration).
  - Schemes are shared (Product → Scheme → Manage Schemes… → Shared).
  - On device: iPhone + paired Apple Watch with Developer Mode enabled (for local installs).

## Project Sanity Checklist (once per project)
- iOS target (custom Info.plist):
  - `CFBundleIconName = AppIcon`.
  - `UISupportedInterfaceOrientations` set for iPhone; `UISupportedInterfaceOrientations~ipad` set if targeting iPad. If iPhone‑only, set device family to iPhone to skip iPad requirements.
  - AppIcon asset contains required sizes (iPhone: 120, 180; iPad: 152, 167; Marketing: 1024).
- watch target:
  - Uses Automatic signing and its own AppIcon asset is filled.
  - `WKCompanionAppBundleIdentifier` = iOS bundle id; `WKWatchOnly = NO` (for companion delivery).
  - `SKIP_INSTALL = YES` (typical for the watch app product that is embedded).
- Code/Previews:
  - Wrap SwiftUI preview code that references `#if DEBUG`-only helpers (e.g., `AppRouter.preview()`) with `#if DEBUG` to avoid Release/Archive errors.

## Archive (Xcode)
1) Select scheme: `RefZoneiOS` → destination `Any iOS Device (arm64)`.
2) Product → Archive.
3) If errors occur:
   - Missing icons/orientations: add to Info.plist/AppIcon as above.
   - “Type 'X' has no member 'preview'”: wrap previews in `#if DEBUG`.
   - “Embed & Sign” not visible for watch app: expected. Use “Embed Without Signing”; watch is signed by its own target and embedded via “Embed Watch Content”.

## Upload to TestFlight (Organizer)
1) Open Xcode → Window → Organizer → Archives → select latest `RefZoneiOS` archive.
2) Click “Distribute App” → App Store Connect → Upload.
3) Answer export compliance (usually “uses standard encryption” if networking is present) and continue.
4) Wait for processing (5–30 min). Status becomes “Ready to Test”.

## App Store Connect: Enable Testing
Internal Testing (immediate):
1) TestFlight tab → Create Group (e.g., “Internal”).
2) Add App Store Connect users to the group.
3) Add Build → select the uploaded build → Save.
4) Testers open TestFlight on iPhone → Install.

External Testing (optional):
1) Create external group.
2) Provide Test Information + Export Compliance.
3) Submit for Beta App Review. After approval, invite testers by email or enable a Public Link.

## Apple Watch Installation Behavior
- Watch companion installs with the iOS app if the iPhone Watch app has “Automatic App Install” enabled.
- Otherwise: iPhone Watch app → My Watch → Available Apps → Install “RefZone”.
- Ensure the tester’s watchOS version meets the project’s deployment target.

## Troubleshooting
- WCSession says counterpart not installed: first install the iOS TestFlight build, then confirm the watch app is installed (auto or via Watch app → Available Apps).
- Missing icon/orientation errors on upload: add `CFBundleIconName=AppIcon` and orientations to the iOS Info.plist; fill AppIcon slots.
- “Embed & Sign” not available for watch app: expected for watch; ensure watch target signs itself and iOS target has “Embed Watch Content”.
- Duplicate iOS container target: remove/rename; ensure only the intended iOS target uses the release bundle id.

## Versioning Tips
- Bump build numbers between uploads (`CURRENT_PROJECT_VERSION`).
- Keep `MARKETING_VERSION` in sync with release notes.

## Optional: Watch‑Only Distribution (not used here)
- For a standalone watch app, set `WKWatchOnly = YES` and remove `WKCompanionAppBundleIdentifier` on the watch target; archive and upload the watch target directly. This removes iPhone companion behavior and changes how testers install the app.

---
Owner: iOS platform
Last updated: 2025‑09‑12
