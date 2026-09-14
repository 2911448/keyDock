#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
CONFIGURATION="${CONFIGURATION:-release}"
if pgrep -x KeyDock >/dev/null; then
  printf '请先退出正在运行的 KeyDock，再构建更新，以免正在运行的签名失效。\n' >&2
  exit 1
fi
# Certificate-backed requirements stay stable across rebuilds; ad-hoc requirements contain a cdhash.
SIGNING_IDENTITY="${KEYDOCK_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ {print $2; exit}')"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
  printf '未找到 Apple Development 签名证书。请设置 KEYDOCK_SIGNING_IDENTITY；临时本机测试可显式设为 -，但重建后需要重新授权。\n' >&2
  exit 1
fi
xcrun swift build -c "$CONFIGURATION" --arch arm64
BIN_DIR="$(xcrun swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/KeyDock.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/KeyDock" "$APP_DIR/Contents/MacOS/KeyDock"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
if [[ ! -f "$PROJECT_DIR/dist/KeyDock.icns" || "$PROJECT_DIR/scripts/make-icon.swift" -nt "$PROJECT_DIR/dist/KeyDock.icns" ]]; then
  mkdir -p "$PROJECT_DIR/dist/KeyDock.iconset"
  xcrun swift "$PROJECT_DIR/scripts/make-icon.swift" "$PROJECT_DIR/dist/KeyDock.iconset"
  iconutil -c icns "$PROJECT_DIR/dist/KeyDock.iconset" -o "$PROJECT_DIR/dist/KeyDock.icns"
fi
cp "$PROJECT_DIR/dist/KeyDock.icns" "$APP_DIR/Contents/Resources/KeyDock.icns"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none --identifier io.keydock.app "$APP_DIR"
codesign --verify --strict "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
