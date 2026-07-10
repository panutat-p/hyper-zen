#!/bin/sh
set -eu

LABEL="com.panutat.hyper-zen.status-icon"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

echo "Removed $LABEL"
