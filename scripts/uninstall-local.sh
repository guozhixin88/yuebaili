#!/usr/bin/env bash
set -euo pipefail

APP_DEST="$HOME/Applications/月白历.app"
AGENT="$HOME/Library/LaunchAgents/local.yuebaili.plist"

launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
killall Yuebaili 2>/dev/null || true
rm -f "$AGENT"
rm -rf "$APP_DEST"

echo "Uninstalled 月白历"

