# hyper-zen

Native macOS automation built with Apple frameworks directly in Swift.

- CoreGraphics for mouse, keyboard, scrolling, and display geometry.
- AppKit for clipboard, process, window, activation, and alerts.
- Swift Package Manager for a library target (`HyperZen`) and a CLI (`hyper-zen`).

## Build

```sh
swift build
```

## Try it

```sh
swift run hyper-zen permissions --prompt
swift run hyper-zen status-icon
swift run hyper-zen pos
swift run hyper-zen move 300 300
swift run hyper-zen click left
swift run hyper-zen key a cmd
swift run hyper-zen type "hello from Swift"
swift run hyper-zen copy "clipboard text"
swift run hyper-zen paste
swift run hyper-zen windows
```

macOS will require Accessibility permission for input automation. This package does not request Screen/System Recording permission.

`status-icon` keeps the terminal process alive, shows a small menu bar icon, holds macOS idle system/display sleep assertions, and declares user activity every 60 seconds while it is running. It also briefly moves the pointer by one pixel and returns it so presence-aware apps such as Microsoft Teams receive an input event. Accessibility permission is required for that input nudge. Quit it from the menu bar item or press Control-C in the terminal.

## Start At Login

```sh
scripts/install-startup.sh
```

This builds the release binary and installs a user LaunchAgent at `~/Library/LaunchAgents/com.panutat.hyper-zen.status-icon.plist`.

To remove it:

```sh
scripts/uninstall-startup.sh
```

## Library example

```swift
import HyperZen

HyperZen.move(x: 300, y: 300)
HyperZen.click()
try HyperZen.keyTap("v", modifiers: ["cmd"])
try HyperZen.writeClipboard("Hello")

let size = HyperZen.screenSize()
print(size.width, size.height)
```

## Scope

This is intentionally macOS-native and omits screenshot and pixel-capture features that would require Screen/System Recording permission.
