#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="HyperZen"
APP_DIR="$ROOT/.build/$APP_NAME.app"
OUTPUT_DIR="${1:-$ROOT}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  echo "Run 'task release' or 'task build:cli-release' first." >&2
  exit 1
fi

DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
STAGING="$ROOT/.build/dmg-staging"

mkdir -p "$OUTPUT_DIR"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING"

echo "$DMG_PATH"
