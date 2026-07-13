# Homebrew: Formula vs Cask

## Current distribution

HyperZen ships as a **Homebrew Cask** via `panutat-p/tap`.

```
brew tap panutat-p/tap
brew install --cask hyperzen
```

The cask installs a pre-built `HyperZen.app` bundle into `/Applications`.

---

## Can HyperZen become a Brew Formula?

Yes — if the app is rewritten as a CLI tool. A formula installs a compiled binary into `/opt/homebrew/bin` instead of a `.app` into `/Applications`.

### What changes

| | Brew Cask (`--cask`) | Brew Formula |
|---|---|---|
| Installs | `.app` bundle → `/Applications` | Binary → `/opt/homebrew/bin` |
| Distribution | Pre-built DMG/zip | Source compiled at install time (or pre-built bottle) |
| Suitable for | GUI apps | CLI tools / daemons |
| Bundle ID / TCC | Yes — macOS tracks permissions by bundle ID | No bundle ID — TCC attributed to Terminal/parent process |

---

## Implementation path

`HyperzenCore` in `Package.swift` already separates the logic (`SleepPreventer`, `ActivityNudger`) from the UI. A new executable target could be added:

```swift
// Package.swift
.executableTarget(
    name: "hyperzen",
    dependencies: ["HyperzenCore"]
)
```

A minimal CLI interface:

```bash
hyperzen start           # enable keep-awake + nudging (foreground)
hyperzen stop            # disable
hyperzen status          # show current state
hyperzen start --daemon  # install launchd plist and run in background
```

The brew formula would compile with `swift build -c release` and install the binary.

---

## Hard problem: Accessibility (TCC) permission

This is the main blocker for the CLI approach.

- As a `.app`, macOS grants Accessibility to the specific **bundle ID** — the permission dialog points directly at HyperZen.
- As a CLI binary, macOS grants Accessibility to the **Terminal.app** (or iTerm2, zsh, etc.) that launched the process — not to the binary itself.
- There is no reliable way to prompt the user for Accessibility from a raw CLI binary the way a `.app` can.
- If run via launchd without a terminal parent that has Accessibility, `CGEvent` nudges will silently fail.

`IOPMAssertion` (sleep prevention via IOKit) is **not affected** — it works from any process without special permissions.

---

## Feature impact summary

| Feature | CLI / Formula | Notes |
|---|---|---|
| Sleep prevention (`IOPMAssertion`) | ✅ Works | No permission required |
| HID idle timer nudging (`CGEvent`) | ⚠️ Conditional | Works only if calling terminal has Accessibility |
| Menu bar UI / visual indicator | ❌ Gone | No `.app`, no status bar icon |
| Background running | Needs launchd plist | `hyperzen start --daemon` would manage this |
| Brew formula distribution | ✅ Feasible | `swift build` in formula recipe |

---

## Recommendation

- If **HID nudging** (Teams/Slack "Away" fix) is a required feature → keep Cask to preserve clean TCC flow.
- If **sleep prevention only** is sufficient → CLI formula is a clean, simpler distribution.
- A hybrid approach is also possible: ship both a `.app` cask and a `hyperzen` CLI formula that only handles `IOPMAssertion`.
