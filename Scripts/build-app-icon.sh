#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_SRC="$ROOT/Hyperzen/Assets.xcassets/AppIcon.appiconset"
ICONSET="$ROOT/.build/AppIcon.iconset"
OUTPUT="$ROOT/.build/AppIcon.icns"
GENERATOR="$ROOT/Scripts/generate_app_icons.swift"

mkdir -p "$ROOT/.build"

swiftc -o "$ROOT/.build/generate_app_icons" \
  "$GENERATOR" \
  "$ROOT/Hyperzen/IconRenderer.swift" \
  -framework AppKit \
  -target "$(uname -m)-apple-macos13.0"

(cd "$ROOT" && "$ROOT/.build/generate_app_icons")

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp "$ICON_SRC"/icon_*.png "$ICONSET/"

iconutil -c icns "$ICONSET" -o "$OUTPUT"
rm -rf "$ICONSET"

echo "$OUTPUT"
