#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/Resources/AppIcon/keydock-generated-source.png"
ICONSET="$ROOT/dist/store/KeyDock-Generated.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  RETINA=$((SIZE * 2))
  sips -z "$RETINA" "$RETINA" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/KeyDock-Generated.icns"
printf 'Generated Resources/KeyDock-Generated.icns\n'
