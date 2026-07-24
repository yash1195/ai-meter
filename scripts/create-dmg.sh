#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_PATH="${1:-$PROJECT_DIR/dist/AI Meter.app}"
OUTPUT_PATH="${2:-$PROJECT_DIR/dist/AI-Meter.dmg}"
VOLUME_NAME="AI Meter"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-meter-dmg.XXXXXX")"
MOUNT_DIR="/Volumes/$VOLUME_NAME"
READ_WRITE_DMG="$WORK_DIR/AI-Meter-rw.dmg"
BACKGROUND_IMAGE="$WORK_DIR/background.png"
DEVICE=""

cleanup() {
  if [[ -n "$DEVICE" ]]; then
    hdiutil detach "$DEVICE" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

if [[ -e "$MOUNT_DIR" ]]; then
  echo "A volume named $VOLUME_NAME is already mounted. Eject it and try again." >&2
  exit 1
fi

swift "$PROJECT_DIR/scripts/generate-dmg-background.swift" "$BACKGROUND_IMAGE"

hdiutil create \
  -quiet \
  -size 48m \
  -fs HFS+ \
  -volname "$VOLUME_NAME" \
  "$READ_WRITE_DMG"

DEVICE="$(
  hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    "$READ_WRITE_DMG" |
    awk '/Apple_HFS/ {print $1}'
)"

ditto "$APP_PATH" "$MOUNT_DIR/AI Meter.app"
ln -s /Applications "$MOUNT_DIR/Applications"
mkdir "$MOUNT_DIR/.background"
cp "$BACKGROUND_IMAGE" "$MOUNT_DIR/.background/background.png"
chflags hidden "$MOUNT_DIR/.background"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set bounds of container window to {120, 120, 760, 540}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set text size of theViewOptions to 13
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "AI Meter.app" of container window to {180, 220}
    set position of item "Applications" of container window to {460, 220}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet
DEVICE=""

hdiutil convert \
  "$READ_WRITE_DMG" \
  -quiet \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "$OUTPUT_PATH"

echo "$OUTPUT_PATH"
