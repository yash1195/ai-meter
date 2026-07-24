#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/AI Meter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$PROJECT_DIR/.build/apple/Products/Release/AIUsageMonitor" "$MACOS_DIR/AIUsageMonitor"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

echo "$APP_DIR"
