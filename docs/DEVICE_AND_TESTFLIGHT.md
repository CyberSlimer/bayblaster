# Playing on an iPhone, and shipping to TestFlight

Everything below is scripted in `Tools/ship.sh`. Signing is automatic with team **5X895J3VYD**
(the Apple ID signed into Xcode > Settings > Accounts, ryan.j.probst@icloud.com). Bundle id is
`com.cyberslimer.bayblaster`, version 1.0.0, build 1.

## Play on your iPhone (2 minutes)

1. Plug the phone in with a cable, unlock it, tap **Trust** if asked.
2. From the repo root:

   ```bash
   Tools/ship.sh device
   ```

   It builds Debug, installs, and launches. The first time, iOS may refuse to open it:
   **Settings > General > VPN & Device Management > Apple Development: Ryan Probst > Trust.**
3. Wireless later: Xcode > Window > Devices and Simulators > tick *Connect via network* once.

No App Store Connect setup is needed for this — it's plain developer signing.

## Push to TestFlight

### One-time: create the app record (you, in a browser — ~2 minutes)

`xcodebuild` can upload but cannot create the App Store Connect record. Do this once:

1. Register the bundle id: https://developer.apple.com/account/resources/identifiers/list
   → **+** → App IDs → App → Description `Bay Blaster`, Bundle ID **Explicit**
   `com.cyberslimer.bayblaster` → Continue → Register. (No capabilities needed.)
2. Create the app: https://appstoreconnect.apple.com/apps → **+ New App**
   - Platforms: iOS · Name: **Bay Blaster** (if taken, e.g. "Bay Blaster: Marlow's Launch")
   - Primary language: English (U.S.) · Bundle ID: `com.cyberslimer.bayblaster`
   - SKU: `bayblaster` · User access: Full Access

### Every build

```bash
Tools/ship.sh testflight
```

Archives Release, exports with `ExportOptions.plist` (`destination: upload`,
`manageAppVersionAndBuildNumber: true` so the build number auto-increments), and uploads.
Processing takes 5–15 minutes, then it appears under **TestFlight** in App Store Connect.

Then, in App Store Connect > TestFlight:
- **Internal testing**: add yourself (and up to 100 App Store Connect users) to a group — no
  review needed, install via the TestFlight app on the phone.
- **External testing** (public link / up to 10,000 testers) needs a short Beta App Review.
  Export compliance: the app uses no encryption → answer "No" (or add
  `ITSAppUsesNonExemptEncryption = NO` to Info.plist to skip the question).

## If something fails

- `error: exportArchive Error Downloading App Information` / `missingApp` → the app record
  doesn't exist for this bundle id yet (step above).
- `No signing certificate` → Xcode > Settings > Accounts > select the Apple ID > Manage
  Certificates > + Apple Distribution. `-allowProvisioningUpdates` normally does this itself.
- Logs: the failing command prints an `.xcdistributionlogs` path under `/var/folders/…/T/`.
- App icon: `Tools/make_icon.swift` renders the placeholder 1024×1024 opaque PNG in
  `Assets.xcassets/AppIcon.appiconset`. Replace the PNG with real art, same size, no alpha.
