---
name: tcc
description: Inspect macOS TCC (Transparency, Consent, and Control) and Accessibility permission state for HyperZen. Use when the user reports permission issues, toggle flips off in Settings, keep-awake or activity nudges fail, or asks to verify/debug Accessibility grants after install, upgrade, or brew reinstall.
---

# macOS TCC inspection (HyperZen)

Read-only diagnostics first. **Never run `tccutil reset` unless the user explicitly asks** — it revokes grants.

## HyperZen identifiers

| Item | Value |
|------|-------|
| Bundle ID (release) | `com.hyperzen.HyperZen` |
| Bundle ID (Xcode dev) | `com.hyperzen.Hyperzen` |
| Install path | `/Applications/HyperZen.app` |
| TCC service | `kTCCServiceAccessibility` |
| Settings deep link | `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility` |

Activity nudges (`CGEvent.post`) require Accessibility. `IOPMAssertion` keep-awake does not.

## Inspection checklist

Run in parallel where possible:

```bash
# Install & process
brew info --cask hyperzen 2>&1 | head -12
pgrep -lf HyperZen || echo "(not running)"
mdfind "kMDItemCFBundleIdentifier == 'com.hyperzen.HyperZen'" 2>/dev/null

# App identity
APP="/Applications/HyperZen.app"
plutil -p "$APP/Contents/Info.plist" | rg 'CFBundleIdentifier|CFBundleShortVersion'
codesign -dv "$APP" 2>&1 | rg 'Identifier=|CDHash=|Signature='
spctl -a -vv "$APP" 2>&1
shasum -a 256 "$APP/Contents/MacOS/HyperZen"
xattr -lr "$APP" 2>&1 | rg -i quarantine || echo "(no quarantine)"

# Caskroom layout
ls -la /opt/homebrew/Caskroom/hyperzen/*/HyperZen.app 2>/dev/null
```

`TCC.db` is usually not readable from Terminal without Full Disk Access — use `tccd` logs instead.

## TCC logs (authoritative)

```bash
PID=$(pgrep HyperZen)
/usr/bin/log show --last 30m \
  --predicate 'subsystem == "com.apple.TCC" AND eventMessage CONTAINS "com.hyperzen.HyperZen"' \
  2>&1 | rg 'AUTHREQ_RESULT|binary_path=|subject=' | tail -25
```

**`authValue` meaning:**

| Value | Meaning |
|-------|---------|
| `0` | Denied |
| `2` | Allowed |

Confirm path is `/Applications/HyperZen.app/Contents/MacOS/HyperZen`, not a DMG mount or dev build.

## Keep-awake verification

```bash
PID=$(pgrep HyperZen)
/usr/bin/log show --last 15m --predicate "eventMessage CONTAINS \"HyperZen.$PID\"" 2>&1 \
  | rg 'PreventUserIdle|Created|Released' | tail -10
```

`Created PreventUserIdleDisplaySleep "Hyperzen Keep Awake"` without a matching `Released` → assertion active.

## Common failure modes

| Symptom | Likely cause |
|---------|----------------|
| Settings toggle flips OFF after closing | Ad-hoc signature (`Signature=adhoc`); grant tied to CDHash, validation fails on save |
| Toggle ON but nudges fail | Stale grant for old binary after upgrade |
| Multiple "HyperZen" entries | DMG demo + brew + dev build (`com.hyperzen.Hyperzen` vs `HyperZen`) |
| `brew uninstall` fails on Caskroom path | Duplicate app bundles (Applications + Caskroom both real copies) → `brew uninstall --cask --force hyperzen` |
| App quits on launch (v0.0.3) | `AccessibilityGuard.enforce()` — fixed in v0.0.4+ (warn, gate keep-awake) |
| `Gatekeeper: rejected` | Expected for ad-hoc releases; fix is Developer ID signing + notarization |

Release builds use `codesign --sign -` unless `CODESIGN_IDENTITY` / `APPLE_SIGNING_IDENTITY` is set in CI.

## User recovery steps

Only suggest when inspection confirms a grant problem:

1. Quit HyperZen (menu bar → Quit)
2. `tccutil reset Accessibility com.hyperzen.HyperZen` (and `com.hyperzen.Hyperzen` if dev builds existed)
3. Remove all HyperZen rows in **System Settings → Privacy & Security → Accessibility**
4. Reinstall single copy: `brew upgrade --cask hyperzen` or drag from DMG to `/Applications` only
5. Launch HyperZen first (triggers system prompt), then enable in Settings
6. Quit and relaunch after granting

Do not run apps from mounted DMG volumes or `.build/` while testing permissions.

## Report template

```markdown
## TCC inspection

| Check | Result |
|-------|--------|
| Installed version | |
| Running from | |
| Duplicate copies | |
| Signature | adhoc / Developer ID |
| Gatekeeper | accepted / rejected |
| TCC authValue | 0 denied / 2 allowed |
| Keep-awake assertion | active / inactive |

**Verdict:** [granted / denied / stale grant / signing issue]

**Next step:** [specific action]
```

## Safety rules

- Do not run `tccutil reset` during routine inspection
- Do not launch apps from DMG mount paths when diagnosing grants
- Compare installed binary SHA256 to the release notes SHA256 (DMG hash, not Mach-O hash)
- After upgrades, expect grants to invalidate when CDHash changes (adhoc builds)
