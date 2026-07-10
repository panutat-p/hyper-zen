# HyperZen

HyperZen is a native macOS automation toolkit written in Swift. It provides a reusable Swift library and a command-line tool for input, clipboard, display, window, and process automation.

It uses Apple frameworks directly:

- CoreGraphics for mouse, keyboard, scrolling, and display geometry
- AppKit for clipboard, processes, windows, activation, and alerts
- Swift Package Manager for the `HyperZen` library and `hyper-zen` command

## Requirements

- macOS 13 (Ventura) or later
- Swift 6.1 or later

Input automation requires Accessibility permission. HyperZen does not request Screen Recording permission and does not provide screenshot or pixel-capture features.

## Build

```sh
swift build
```

Run the command-line tool without installing it:

```sh
swift run hyper-zen help
```

## Homebrew

Install the stable `hyper-zen` formula:

```sh
brew install panutat-p/tap/hyper-zen
```

The installed executable includes its release version. For example, version
`1.2.3` installs `hyper-zen-1.2.3`:

```sh
hyper-zen-1.2.3 version
brew services start hyper-zen
```

Hyper Zen requires Accessibility permission for Teams presence. After every
upgrade, enable the newly installed executable in **System Settings > Privacy &
Security > Accessibility**, remove the previous Hyper Zen entry, then restart
the service:

```sh
brew upgrade hyper-zen
brew services restart hyper-zen
```

Homebrew prints the exact versioned path to add during installation and upgrade.

## Command-line usage

```sh
# Check or request Accessibility permission
swift run hyper-zen permissions --prompt

# Mouse and keyboard input
swift run hyper-zen pos
swift run hyper-zen move 300 300
swift run hyper-zen click left
swift run hyper-zen key a cmd
swift run hyper-zen type "hello from Swift"

# Clipboard, display, windows, and processes
swift run hyper-zen copy "clipboard text"
swift run hyper-zen paste
swift run hyper-zen displays
swift run hyper-zen windows
swift run hyper-zen processes
```

Run `swift run hyper-zen help` for the complete command list.

## Status icon

`status-icon` shows a menu-bar icon, prevents idle system and display sleep, and generates a small input nudge every 60 seconds. Its icon is green when Accessibility is allowed and red when it is not.

```sh
swift run hyper-zen status-icon
```

Quit it from the menu bar or press Control-C in the terminal.

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
