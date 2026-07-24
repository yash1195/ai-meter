#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
ICONSET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-meter-iconset.XXXXXX")/AppIcon.iconset"
MASTER_ICON="$PROJECT_DIR/Resources/AppIcon-1024.png"
trap 'rm -rf "${ICONSET_DIR:h}"' EXIT

mkdir -p "$ICONSET_DIR"
swift "$PROJECT_DIR/scripts/generate-app-icon.swift" "$MASTER_ICON"

for specification in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"
do
  pixels="${specification%% *}"
  filename="${specification#* }"
  sips -z "$pixels" "$pixels" "$MASTER_ICON" --out "$ICONSET_DIR/$filename" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$PROJECT_DIR/Resources/AppIcon.icns"
echo "$PROJECT_DIR/Resources/AppIcon.icns"
