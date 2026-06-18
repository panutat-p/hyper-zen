#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
APP_DIR="$ROOT/.build/HyperZen.app"
BUILD_DIR="$ROOT/.build"
BINARY="$BUILD_DIR/HyperZen"
ARCH="$(uname -m)"
TARGET="$ARCH-apple-macos13.0"

SWIFT_FLAGS=(
  -o "$BINARY"
  "$ROOT/Hyperzen/main.swift"
  "$ROOT/Hyperzen/AppDelegate.swift"
  "$ROOT/Hyperzen/SleepPreventer.swift"
  "$ROOT/Hyperzen/IconRenderer.swift"
  "$ROOT/Hyperzen/ActivityNudger.swift"
  "$ROOT/Hyperzen/AccessibilityGuard.swift"
  -framework AppKit
  -framework IOKit
  -framework CoreGraphics
  -framework ApplicationServices
  -target "$TARGET"
)

if [[ "$CONFIG" == "release" ]]; then
  SWIFT_FLAGS+=(-O)
fi

mkdir -p "$BUILD_DIR"
swiftc "${SWIFT_FLAGS[@]}"

chmod +x "$ROOT/Scripts/generate-icons.sh"
"$ROOT/Scripts/generate-icons.sh" icns

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/HyperZen"
chmod +x "$APP_DIR/Contents/MacOS/HyperZen"
cp "$BUILD_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>HyperZen</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.hyperzen.HyperZen</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>HyperZen</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" 2>/dev/null || true
fi

xattr -cr "$APP_DIR" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "$APP_DIR"
