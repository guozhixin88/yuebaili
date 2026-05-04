#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="月白历"
VERSION="1.0.0"
DIST_DIR="$ROOT/dist"
STAGE_DIR="$DIST_DIR/stage"
DMG="$DIST_DIR/Yuebaili-$VERSION.dmg"

"$ROOT/scripts/build.sh"

rm -rf "$STAGE_DIR" "$DMG"
mkdir -p "$STAGE_DIR"
cp -R "$ROOT/build/$APP_NAME.app" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG"

hdiutil verify "$DMG"
echo "Packaged $DMG"
