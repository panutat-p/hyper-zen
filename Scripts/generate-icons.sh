#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GENERATOR="$ROOT/Scripts/generate_icons.swift"
BINARY="$ROOT/.build/generate_icons"
TARGET="$(uname -m)-apple-macos13.0"

usage() {
  echo "Usage: $0 preview [output.png]" >&2
  echo "       $0 icns [output.icns]" >&2
  exit 1
}

MODE="${1:-}"
[[ -n "$MODE" ]] || usage

mkdir -p "$ROOT/.build"

swiftc -o "$BINARY" \
  "$GENERATOR" \
  "$ROOT/Hyperzen/IconRenderer.swift" \
  -framework AppKit \
  -target "$TARGET"

case "$MODE" in
  preview)
    OUTPUT="${2:-$ROOT/Design/AppIcon-preview.png}"
    mkdir -p "$(dirname "$OUTPUT")"
    (cd "$ROOT" && "$BINARY" preview "$OUTPUT")
    echo "$OUTPUT"
    ;;
  icns)
    OUTPUT="${2:-$ROOT/.build/AppIcon.icns}"
    ICONSET="$ROOT/.build/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    (cd "$ROOT" && "$BINARY" iconset "$ICONSET")
    iconutil -c icns "$ICONSET" -o "$OUTPUT"
    rm -rf "$ICONSET"
    echo "$OUTPUT"
    ;;
  *)
    usage
    ;;
esac
