#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! swift -e 'import XCTest' 2>/dev/null; then
  echo "Error: XCTest is not available in the active developer directory." >&2
  echo "Install Xcode, then select it with:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

swift test "$@"
