#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/Design/AppIcon-preview.png"
GENERATOR="$ROOT/Scripts/generate_icon_preview.swift"

mkdir -p "$ROOT/.build" "$ROOT/Design"

swiftc -o "$ROOT/.build/generate_icon_preview" \
  "$GENERATOR" \
  "$ROOT/Hyperzen/IconRenderer.swift" \
  -framework AppKit \
  -target "$(uname -m)-apple-macos13.0"

(cd "$ROOT" && "$ROOT/.build/generate_icon_preview")

echo "$OUTPUT"
