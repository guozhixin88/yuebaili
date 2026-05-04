#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT/build/AppIcon.iconset"

mkdir -p "$ROOT/build"
swiftc "$ROOT/Tools/IconMaker.swift" -o "$ROOT/build/icon-maker" -framework AppKit
"$ROOT/build/icon-maker" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"

echo "Regenerated $ROOT/Resources/AppIcon.icns"
