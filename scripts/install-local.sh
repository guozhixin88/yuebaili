#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="月白历"
APP_SRC="$ROOT/build/$APP_NAME.app"
APP_DEST="$HOME/Applications/$APP_NAME.app"
AGENT="$HOME/Library/LaunchAgents/local.yuebaili.plist"

"$ROOT/scripts/build.sh"

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.yuebaili</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-gj</string>
        <string>$APP_DEST</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/yuebaili.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/yuebaili.err</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
killall Yuebaili 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT"
open -gj "$APP_DEST"

echo "Installed $APP_DEST"

