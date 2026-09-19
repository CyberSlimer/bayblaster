#!/bin/bash
# Bay Blaster build helpers.
#
#   Tools/ship.sh device      build Debug, install + launch on the plugged-in iPhone
#   Tools/ship.sh testflight  archive Release, upload to App Store Connect (TestFlight)
#
# Both use Xcode's automatic signing with the team in the project (5X895J3VYD) and the
# Apple ID signed into Xcode > Settings > Accounts. Run from the repo root.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=BayBlaster.xcodeproj
SCHEME=BayBlaster
BUNDLE_ID=com.cyberslimer.bayblaster
DD=build/DerivedData
ARCHIVE=build/BayBlaster.xcarchive

case "${1:-}" in
  device)
    DEVICE_ID=$(xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null \
      | python3 -c 'import json,sys; ds=[d for d in json.load(sys.stdin)["result"]["devices"] if d["connectionProperties"]["pairingState"]=="paired"]; print(ds[0]["identifier"] if ds else "")')
    if [ -z "$DEVICE_ID" ]; then
      echo "No paired iPhone found. Plug it in, unlock it, tap Trust, then retry." >&2
      xcrun devicectl list devices >&2
      exit 1
    fi
    echo "▶ building for device $DEVICE_ID"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
      -destination "id=$DEVICE_ID" -derivedDataPath "$DD" -allowProvisioningUpdates build \
      | grep -E "error|warning: |BUILD" || true
    APP="$DD/Build/Products/Debug-iphoneos/BayBlaster.app"
    echo "▶ installing"
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
    echo "▶ launching"
    xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
    echo "Done. If iOS says 'Untrusted Developer', go to Settings > General > VPN & Device Management and trust the certificate."
    ;;

  testflight)
    echo "▶ archiving Release"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
      -destination 'generic/platform=iOS' -derivedDataPath "$DD" -archivePath "$ARCHIVE" \
      -allowProvisioningUpdates archive | grep -E "error|warning: |ARCHIVE" || true
    echo "▶ exporting + uploading to App Store Connect"
    xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist \
      -exportPath build/export -allowProvisioningUpdates | grep -E "error|Upload|EXPORT|Uploaded|succeeded" || true
    echo "Done. The build shows up in App Store Connect > TestFlight after processing (5–15 min)."
    ;;

  *)
    echo "usage: $0 device|testflight" >&2
    exit 2
    ;;
esac
