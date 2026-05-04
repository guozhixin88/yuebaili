#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="月白历"
EXECUTABLE="Yuebaili"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

swiftc "$ROOT/Sources/Yuebaili/main.swift" \
  -o "$APP_DIR/Contents/MacOS/$EXECUTABLE" \
  -framework AppKit \
  -framework EventKit

chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"

