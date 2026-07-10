#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/idle-probe"

swiftc \
  -o "$OUT" \
  "$DIR/main.swift" \
  -framework CoreGraphics \
  -framework ApplicationServices

echo "Built: $OUT"
echo
echo "One-shot test (mouse-move + scroll + keyboard):  $OUT"
echo "Watch mode — nudge every 30s, keep Teams green:  $OUT watch"
echo "Watch mode — custom interval (e.g. 15s):         $OUT watch 15"
echo
echo "Methodology:"
echo "  POSITIVE direction: run from a terminal WITH Accessibility (e.g. Cursor) -> expect RESET ✅"
echo "  NEGATIVE direction: run from a terminal WITHOUT Accessibility (stock Terminal.app) -> expect NO reset ❌"
echo "  AXIsProcessTrusted() is printed in the header so you always know which case you are in."
