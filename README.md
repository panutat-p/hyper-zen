# HyperZen

A lightweight macOS menu bar app that keeps your Mac awake. HyperZen lives in the status bar, prevents system and display sleep, and nudges the HID idle timer so long-running tasks are not interrupted by power management.

## Features

- **Menu bar only** — no Dock icon; runs quietly in the background.
- **Keep awake by default** — enabled on launch; toggle from the menu bar icon.
- **System + display assertions** — uses `IOPMAssertion` to block both idle system sleep and display sleep (similar to Amphetamine's default behavior).
- **Activity nudges** — posts a zero-distance mouse-move event every 5 minutes to reset the HID idle timer.
- **Animated status icon** — a running monkey when keep-awake is active; static icon when disabled.
- **Screen-aware** — pauses animation and nudges while the display is asleep; resumes when screens wake.

## Install

### Homebrew (recommended)

```bash
brew tap panutat-p/tap
brew install --cask hyperzen
```

To upgrade later:

```bash
brew upgrade --cask hyperzen
```

To uninstall:

```bash
brew uninstall --cask hyperzen
```

### Manual

1. Download `HyperZen.dmg` from the [latest release](https://github.com/panutat-p/hyper-zen/releases/latest)
2. Open the DMG and drag **HyperZen.app** to **Applications**
3. Launch HyperZen from Applications or Spotlight

> If macOS shows a Gatekeeper warning, run:
> ```bash
> xattr -cr /Applications/HyperZen.app
> ```

## Requirements

- macOS 13.0 (Ventura) or later
- [Task](https://taskfile.dev/) (recommended for local builds)
- **Optional:** Xcode (for `xcodebuild` builds and unit tests)

The app can be built with `swiftc` alone — Xcode is not required to compile or run HyperZen.

## Quick start

```bash
# Build and launch
task dev
```

The built app is at `.build/HyperZen.app`.

## Build commands

| Command | Description |
|---------|-------------|
| `task build` | Build Debug (Xcode if available, otherwise `swiftc`) |
| `task dev` | Build Debug and open the app |
| `task release` | Build Release and create `HyperZen.dmg` in the project root |
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

## Usage

1. Launch HyperZen — a monkey icon appears in the menu bar.
2. Keep awake is **on** by default; the icon animates while active.
3. Click the icon and choose **Disable Keep Awake** to turn it off, or **Quit HyperZen** to exit.

## Release pipeline

Releases are fully automated via GitHub Actions. Pushing a version tag triggers the entire pipeline — building, packaging, publishing, and updating the Homebrew formula — without any manual steps.

### How to release

```bash
git tag v1.2.0
git push origin v1.2.0
```

### What happens automatically

```
git push origin v1.2.0
        │
        ▼
release.yml (this repo) — runs on macos-latest
  1. Build HyperZen.app     Scripts/bundle-app.sh release
  2. Package HyperZen.dmg   Scripts/create-dmg.sh
  3. Compute SHA256          shasum -a 256 HyperZen.dmg
  4. Publish GitHub Release  HyperZen.dmg attached, SHA256 in release notes
  5. Dispatch to tap         POST /repos/panutat-p/homebrew-tap/dispatches
        │
        │  payload: { cask, version, sha256 }
        ▼
update-tap.yml (panutat-p/homebrew-tap)
  6. Patch Casks/hyperzen.rb  version + sha256 replaced via sed
  7. Commit and push          "chore: bump hyperzen to v1.2.0"
```

After step 7, `brew upgrade --cask hyperzen` will pull the new version for all users.

### Workflow file

`.github/workflows/release.yml` — triggered on `v*.*.*` tag push.

| Step | Tool | Notes |
|------|------|-------|
| Build app | `Scripts/bundle-app.sh release` | Compiles with `swiftc -O`, bundles `Info.plist` and icon |
| Create DMG | `Scripts/create-dmg.sh` | Adds Applications symlink, compresses with UDZO |
| Compute SHA256 | `shasum -a 256` | Written to `GITHUB_OUTPUT` for downstream steps |
| GitHub Release | `softprops/action-gh-release@v2` | Creates release, attaches DMG, sets release notes |
| Tap dispatch | `peter-evans/repository-dispatch@v3` | Fires `update-cask` event on `panutat-p/homebrew-tap` |

### Secrets

| Secret | Repo | Purpose |
|--------|------|---------|
| `TAP_GITHUB_TOKEN` | `hyper-zen` | Classic PAT with `repo` scope — authorises the `repository_dispatch` call to `homebrew-tap` |
| `GITHUB_TOKEN` | `homebrew-tap` | Auto-injected by GitHub Actions — used by `update-tap.yml` to push the formula bump |

### Homebrew tap

The shared tap repo is [panutat-p/homebrew-tap](https://github.com/panutat-p/homebrew-tap).

```
homebrew-tap/
  Casks/
    hyperzen.rb      ← patched automatically on each release
    json-young.rb
  .github/workflows/
    update-tap.yml   ← receives dispatch, patches formula, pushes bump
```

The tap is shared across all panutat-p macOS apps. Adding a new app only requires:
1. Adding a new `.rb` file to `Casks/` in the tap repo
2. Adding `release.yml` to the app repo with the correct `cask` name in the dispatch payload

## Project structure

```
Hyperzen/           App source (menu bar UI, sleep prevention, icon rendering)
Tests/              Unit tests (HyperzenCore)
Scripts/            bundle-app.sh, generate-icons.sh, create-dmg.sh
Design/             Generated icon previews (task icon; gitignored PNG)
.github/workflows/  release.yml — automated build, release, and tap update
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
