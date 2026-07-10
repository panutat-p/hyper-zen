# robot-swift

Native macOS Swift rewrite of the useful RobotGo surface area for this app. It uses Apple frameworks directly instead of Go plus C shims:

- CoreGraphics for mouse, keyboard, scrolling, and display geometry.
- AppKit for clipboard, process, window, activation, and alerts.
- Swift Package Manager for a library target (`RobotSwift`) and a CLI (`robot-swift`).

## Build

```sh
swift build
```

## Try it

```sh
swift run robot-swift permissions --prompt
swift run robot-swift status-icon
swift run robot-swift pos
swift run robot-swift move 300 300
swift run robot-swift click left
swift run robot-swift key a cmd
swift run robot-swift type "hello from Swift"
swift run robot-swift copy "clipboard text"
swift run robot-swift paste
swift run robot-swift windows
```

macOS will require Accessibility permission for input automation. This package does not request Screen/System Recording permission.

`status-icon` keeps the terminal process alive, shows a small menu bar icon, holds macOS idle system/display sleep assertions, and declares user activity every 60 seconds while it is running. It also briefly moves the pointer by one pixel and returns it, mirroring the RobotGo helper so presence-aware apps such as Microsoft Teams receive an input event. Accessibility permission is required for that input nudge. Quit it from the menu bar item or press Control-C in the terminal.

## Start At Login

```sh
scripts/install-startup.sh
```

This builds the release binary and installs a user LaunchAgent at `~/Library/LaunchAgents/com.panutat.robot-swift.status-icon.plist`.

To remove it:

```sh
scripts/uninstall-startup.sh
```

## Library example

```swift
import RobotSwift

Robot.move(x: 300, y: 300)
Robot.click()
try Robot.keyTap("v", modifiers: ["cmd"])
try Robot.writeClipboard("Hello")

let size = Robot.screenSize()
print(size.width, size.height)
```

## Scope

This is intentionally macOS-native. The original RobotGo project supports Windows and Linux through C/X11/Win32 backends; this rewrite replaces that portability layer with direct Apple APIs and omits screenshot/pixel-capture features that would require Screen/System Recording permission.
