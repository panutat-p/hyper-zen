# Issue: Local dev build vs Homebrew HyperZen conflicts

## Summary

Multiple HyperZen app bundles on disk (Homebrew install, CLI/Xcode dev build, DMG demo, Caskroom copy) share similar names but differ in **path**, **bundle ID**, and **CDHash**. macOS TCC and the user’s mental model treat them as one app (“HyperZen”), which causes permission confusion, duplicate Settings rows, and “it worked yesterday” reports after upgrades.

## Identifiers

| Install source | Typical path | Bundle ID | Executable name |
|--------------|--------------|-----------|-----------------|
| Homebrew / release | `/Applications/HyperZen.app` | `com.hyperzen.HyperZen` | `HyperZen` |
| Xcode debug | `.build/DerivedData/.../Debug/Hyperzen.app` | `com.hyperzen.Hyperzen` | `Hyperzen` |
| CLI `task dev` | `.build/HyperZen.app` | `com.hyperzen.HyperZen` | `HyperZen` |
| DMG (not installed) | `/Volumes/HyperZen/HyperZen.app` | `com.hyperzen.HyperZen` | `HyperZen` |
| Caskroom | `/opt/homebrew/Caskroom/hyperzen/<ver>/HyperZen.app` | `com.hyperzen.HyperZen` | `HyperZen` |

Note the **capital Z** in release bundle ID vs **lowercase z** in Xcode dev (`Hyperzen` vs `HyperZen`).

## Symptoms

| Symptom | Likely cause |
|---------|----------------|
| Accessibility ON in Settings but app still denied | Grant tied to old CDHash or different path |
| Multiple “HyperZen” rows in Accessibility | DMG + Applications + dev build each prompted separately |
| `brew uninstall` fails on Caskroom path | Duplicate real copies (Applications + Caskroom both exist) → use `brew uninstall --cask --force hyperzen` |
| Permission works for dev, not for brew (or vice versa) | Different bundle IDs or signatures |
| Menu bar icon missing while “app runs” | Wrong binary running, or macOS Menu Bar allow-list (see v0.0.5 `MenuBarVisibilityWatcher`) |
| Inspector sees one install; user sees another behavior | Stale process from `.build/` or duplicate `mdfind` hits |

## Common failure flows

### DMG demo then Homebrew

1. User opens `HyperZen.dmg` and launches from `/Volumes/...` without installing
2. macOS prompts for Accessibility; user grants for **that path**
3. User later `brew install --cask hyperzen` → `/Applications/HyperZen.app`
4. New binary, new CDHash → grant does not transfer

### Dev + release side by side

1. Developer runs `task dev` → `.build/HyperZen.app` (adhoc, same bundle ID as release)
2. Homebrew copy also at `/Applications/HyperZen.app`
3. TCC may show one row; only one CDHash is authorized
4. Launching the “other” copy appears broken

### Upgrade without clean TCC

1. User on 0.0.2 grant, upgrades to 0.0.5 via brew
2. Settings still shows HyperZen enabled
3. New ad-hoc CDHash → `authValue=0` at runtime

## Inspection checklist

```bash
# All copies on disk
mdfind "kMDItemCFBundleIdentifier == 'com.hyperzen.HyperZen'"
mdfind "kMDItemCFBundleIdentifier == 'com.hyperzen.Hyperzen'"

# What is running
pgrep -lf HyperZen

# Brew layout
brew info --cask hyperzen
ls -la /opt/homebrew/Caskroom/hyperzen/*/HyperZen.app 2>/dev/null
ls -la /Applications/HyperZen.app

# Dev artifacts (repo)
ls -la .build/HyperZen.app 2>/dev/null
ls -la .build/DerivedData/Build/Products/Debug/Hyperzen.app 2>/dev/null

# Compare signatures
for app in /Applications/HyperZen.app .build/HyperZen.app; do
  [[ -d "$app" ]] && echo "=== $app ===" && codesign -dv "$app" 2>&1 | rg 'CDHash=|Identifier='
done
```

## Recovery (single canonical install)

1. Quit all HyperZen processes: `killall HyperZen`
2. Remove dev/demo copies from testing path (do not run from `.build/` or DMG while validating brew install)
3. `brew uninstall --cask --force hyperzen` if uninstall errors
4. Reset TCC for **both** bundle IDs (user must request reset):
   - `tccutil reset Accessibility com.hyperzen.HyperZen`
   - `tccutil reset Accessibility com.hyperzen.Hyperzen`
5. Remove all HyperZen rows in Accessibility
6. `brew install --cask hyperzen`
7. Launch only `/Applications/HyperZen.app`

## Developer guidelines

- When debugging TCC for **release**, use only `/Applications/HyperZen.app` — not `task dev` output
- `task accessibility:reset` resets both bundle IDs; warn before running
- After local `task dev`, expect a separate TCC entry if bundle ID or path differs
- Document in README: install to Applications; do not run from DMG mount
- Consider single-instance guard or startup log line with `Bundle.main.bundlePath` for support

## Build / task matrix

| Command | Output | Use for TCC testing? |
|---------|--------|----------------------|
| `brew install --cask hyperzen` | `/Applications/HyperZen.app` | Yes (matches users) |
| `task dev` | `.build/HyperZen.app` | No (conflicts with brew) |
| `task release` | `.build/HyperZen.app` + DMG | Only after install to Applications |

## Related issues

- `.spec/issue_accessibility.md` — why grants fail even with a single install (adhoc signing)
- `.spec/issue_apple.md` — stable grants require Developer ID across releases
