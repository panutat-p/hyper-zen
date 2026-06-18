# Hyperzen

A lightweight macOS menu bar app that keeps your Mac awake. Hyperzen lives in the status bar, prevents system and display sleep, and nudges the HID idle timer so long-running tasks are not interrupted by power management.

## Features

- **Menu bar only** — no Dock icon; runs quietly in the background.
- **Keep awake by default** — enabled on launch; toggle from the menu bar icon.
- **System + display assertions** — uses `IOPMAssertion` to block both idle system sleep and display sleep (similar to Amphetamine’s default behavior).
- **Activity nudges** — posts a zero-distance mouse-move event every 5 minutes to reset the HID idle timer.
- **Animated status icon** — a running monkey when keep-awake is active; static icon when disabled.
- **Screen-aware** — pauses animation and nudges while the display is asleep; resumes when screens wake.

## Requirements

- macOS 13.0 or later
- [Task](https://taskfile.dev/) (recommended for builds)
- **Optional:** Xcode (for `xcodebuild` builds and unit tests)

The app can be built with `swiftc` alone — Xcode is not required to compile or run Hyperzen.

## Quick start

```bash
# Build and launch
task dev
```

The built app is at `.build/Hyperzen.app`.

## Build commands

| Command | Description |
|---------|-------------|
| `task build` | Build Debug (Xcode if available, otherwise `swiftc`) |
| `task dev` | Build Debug and open the app |
| `task release` | Build Release and create `Hyperzen.dmg` in the project root |
| `task build:cli` | Build Debug with `swiftc` (no Xcode) |
| `task build:cli-release` | Build Release with `swiftc` (no Xcode) |
| `task test` | Run unit tests via Swift Package Manager |
| `task icon` | Generate a 1024px app icon preview and open it |
| `task unquarantine` | Remove Gatekeeper quarantine flags from the built app and DMG |

### Xcode

Open `Hyperzen.xcodeproj` and build the **Hyperzen** scheme, or use:

```bash
xcodebuild -project Hyperzen.xcodeproj -scheme Hyperzen -configuration Debug build
```

### Swift Package Manager

Core logic is exposed as the `HyperzenCore` target for testing:

```bash
swift test
```

> Unit tests require XCTest. If `swift test` fails, install Xcode and select it:
>
> ```bash
> sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
> ```

## Distribution

```bash
task release
```

This produces `Hyperzen.dmg` with the app and an **Applications** shortcut. If macOS blocks the download, run:

```bash
task unquarantine
```

## Usage

1. Launch Hyperzen — a monkey icon appears in the menu bar.
2. Keep awake is **on** by default; the icon animates while active.
3. Click the icon and choose **Disable Keep Awake** to turn it off, or **Quit Hyperzen** to exit.

## Project structure

```
Hyperzen/           App source (menu bar UI, sleep prevention, icon rendering)
Tests/              Unit tests (HyperzenCore)
Scripts/            bundle-app.sh, generate-icons.sh, create-dmg.sh
Design/             Generated icon previews (`task icon`; gitignored PNG)
taskfile.yaml       Task definitions for build and release
Package.swift       Swift package manifest (HyperzenCore + tests)
```

**App icon** — `IconRenderer.swift` is the source of truth for the monkey mascot. Xcode builds use the committed PNGs in `Hyperzen/Assets.xcassets/AppIcon.appiconset/`. CLI builds (`task build:cli`) render icons at build time into `.build/AppIcon.icns` without modifying the asset catalog.

## How it works

**Sleep prevention** — `SleepPreventer` creates two IOKit power assertions: one for user-idle system sleep and one for display sleep. Assertions are released when keep-awake is disabled or the app quits.

**Activity nudges** — `ActivityNudger` fires every 300 seconds, posting a `mouseMoved` event at the current cursor position. The move has zero distance but resets the HID idle timer.

**Menu bar icon** — `IconRenderer` draws the monkey mascot programmatically; `AppDelegate` cycles through animation frames at ~2.5 FPS while keep-awake is active and the screen is on.

## License

Not specified.
