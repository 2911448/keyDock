#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
MODE="${1:-preview}"
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  elif [[ "$MODE" == preview && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  else
    printf 'Set DEVELOPER_DIR to a complete, Apple-accepted Xcode installation.\n' >&2
    exit 1
  fi
fi
mkdir -p dist/store
python3 scripts/store/generate-project.py
case "$MODE" in
  preview)
    APP="$ROOT/dist/store-preview/KeyDock Store Preview.app"
    if pgrep -f '^.*/dist/store-preview/KeyDock Store Preview.app/Contents/MacOS/KeyDock$' >/dev/null; then
      printf 'Quit KeyDock Store Preview before updating its signature.\n' >&2; exit 1
    fi
    IDENTITY="${KEYDOCK_SIGNING_IDENTITY:-}"
    if [[ -z "$IDENTITY" ]]; then
      IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ {print $2; exit}')"
    fi
    [[ -n "$IDENTITY" ]] || { printf 'Apple Development signing identity required.\n' >&2; exit 1; }
    xcodebuild -project KeyDock.xcodeproj -scheme KeyDock -configuration Release -destination 'generic/platform=macOS' \
      -archivePath dist/store/KeyDock-unsigned.xcarchive CODE_SIGNING_ALLOWED=NO archive
    mkdir -p "$(dirname "$APP")"
    ditto dist/store/KeyDock-unsigned.xcarchive/Products/Applications/KeyDock.app "$APP"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.keydock.app.storepreview' "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName KeyDock Store Preview' "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName KeyDock Store Preview' "$APP/Contents/Info.plist"
    codesign --force --sign "$IDENTITY" --options runtime --timestamp=none --entitlements Resources/KeyDock.entitlements "$APP"
    codesign --verify --strict "$APP"
    python3 scripts/store/verify-bundle.py "$APP"
    printf '\nSandbox preview (not an upload package): %s\n' "$APP"
    ;;
  archive)
    : "${KEYDOCK_TEAM_ID:?Set KEYDOCK_TEAM_ID to your developer team ID}"
    xcodebuild -version
    xcodebuild -project KeyDock.xcodeproj -scheme KeyDock -configuration Release -destination 'generic/platform=macOS' \
      -archivePath dist/store/KeyDock.xcarchive -allowProvisioningUpdates "DEVELOPMENT_TEAM=$KEYDOCK_TEAM_ID" archive
    python3 scripts/store/verify-bundle.py dist/store/KeyDock.xcarchive/Products/Applications/KeyDock.app
    ;;
  export)
    : "${KEYDOCK_TEAM_ID:?Set KEYDOCK_TEAM_ID to your developer team ID}"
    python3 - <<'PY'
import os, plistlib
from pathlib import Path
options=dict(method='app-store-connect',destination='export',teamID=os.environ['KEYDOCK_TEAM_ID'],signingStyle='automatic',manageAppVersionAndBuildNumber=False,uploadSymbols=True)
Path('dist/store/ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
    xcodebuild -exportArchive -archivePath dist/store/KeyDock.xcarchive -exportPath dist/store/export \
      -exportOptionsPlist dist/store/ExportOptions.plist -allowProvisioningUpdates
    ;;
  *) printf 'Usage: scripts/store/build.sh preview|archive|export\n' >&2; exit 1 ;;
esac
