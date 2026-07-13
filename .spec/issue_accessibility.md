# Issue: Accessibility permission cannot be granted

## Summary

On macOS 15+, users install HyperZen from Homebrew, open **System Settings → Privacy & Security → Accessibility**, turn HyperZen **ON**, and the toggle immediately flips back **OFF** when Settings is closed or revisited.

The app may still launch and show menu bar UI (if allowed under **Menu Bar** settings), but **keep-awake mode with activity nudges stays disabled** because `CGEvent.post` requires Accessibility.

## Symptoms

| Symptom | Notes |
|---------|-------|
| Toggle flips OFF after enabling | Most common report on Homebrew / DMG installs |
| HyperZen listed in Accessibility but grant ineffective | Often a stale row for an older binary (different CDHash) |
| Keep-awake menu item does nothing useful | `AccessibilityGuard` gates full keep-awake on `AXIsProcessTrusted()` |
| App runs without crashing | Expected since v0.0.4+ (warn instead of quit) |
| `authValue=0` in TCC logs | Denied at runtime even if Settings UI looks enabled |

## Root cause

macOS TCC (Transparency, Consent, and Control) binds **Accessibility** to a specific **binary identity**, not just the app name:

- Bundle ID (`com.hyperzen.HyperZen`)
- **Code signature / CDHash** (changes on every ad-hoc build)
- Sometimes the path where approval was first granted (e.g. DMG mount vs `/Applications`)

Current CI and Homebrew releases are **ad-hoc signed** (`codesign --sign -`):

```
Signature=adhoc
TeamIdentifier=not set
Gatekeeper: rejected
```

When the user toggles ON, macOS validates the signature before persisting the grant. Validation fails for ad-hoc / Gatekeeper-rejected apps on macOS 15+, so the toggle reverts to OFF. **No error is shown to the user or the app.**

### What requires Accessibility

| Feature | Needs Accessibility? |
|---------|------------------------|
| `ActivityNudger` (`CGEvent.post`) | Yes |
| `IOPMAssertion` keep-awake (`SleepPreventer`) | No |
| Menu bar status item | No |
| Showing permission warning modal | No |

HyperZen intentionally disables full keep-awake until Accessibility is granted so users are not left in a half-working state (assertions on, nudges silently failing).

## Reproduction (verified)

1. Install `hyperzen` 0.0.5 via Homebrew → `/Applications/HyperZen.app`
2. Confirm signing: `codesign -dv /Applications/HyperZen.app 2>&1 | rg Signature` → `adhoc`
3. Open Accessibility settings, enable HyperZen → toggle flips OFF
4. TCC logs show requests for `com.hyperzen.HyperZen` with current CDHash but no persistent allow

## Recovery steps (user)

Only help when inspection confirms a grant problem. **Do not run `tccutil reset` during routine debugging** unless the user asks.

1. Quit HyperZen (menu bar → Quit HyperZen)
2. `tccutil reset Accessibility com.hyperzen.HyperZen` (and `com.hyperzen.Hyperzen` if dev builds existed)
3. Remove **all** HyperZen rows in Accessibility (use **−**)
4. Reinstall a single copy: `brew reinstall --cask hyperzen`
5. Clear quarantine if present: `xattr -cr /Applications/HyperZen.app`
6. Launch HyperZen from `/Applications/HyperZen.app` only (not DMG, not `.build/`)
7. Add via **+** → select `/Applications/HyperZen.app` → enable → quit and relaunch

**Limitation:** Clean uninstall / reinstall / reset does **not** fix the toggle-flip if the binary remains ad-hoc signed.

## Diagnostics

```bash
APP="/Applications/HyperZen.app"
codesign -dv "$APP" 2>&1 | rg 'Identifier=|CDHash=|Signature=|TeamIdentifier'
spctl -a -vv "$APP" 2>&1
pgrep -lf HyperZen
/usr/bin/log show --last 30m \
  --predicate 'subsystem == "com.apple.TCC" AND eventMessage CONTAINS "com.hyperzen.HyperZen"' \
  2>&1 | rg 'AUTHREQ_RESULT|authValue|cdhash|binary_path' | tail -20
```

| `authValue` | Meaning |
|-------------|---------|
| `0` | Denied |
| `2` | Allowed |

## Related app behavior (v0.0.4+)

- `AccessibilityGuard.requireAccessForKeepAwake()` — system prompt + warning modal; does **not** terminate
- Keep-awake forced **off** when permission missing
- Re-check on app activation and when user toggles keep-awake ON

## Tasks

| Task | Purpose |
|------|---------|
| `task accessibility` | Open Accessibility settings |
| `task accessibility:reset` | Reset TCC for release + dev bundle IDs |

## Permanent fix

See `.spec/issue_apple.md` — **Developer ID signing + notarization** in the release pipeline (`APPLE_SIGNING_IDENTITY` GitHub secret). Ad-hoc releases cannot reliably persist Accessibility on macOS 15+.

## References

- `Hyperzen/AccessibilityGuard.swift`
- `Hyperzen/ActivityNudger.swift`
- `.cursor/skills/tcc/SKILL.md`
- PR #4, #5 — accessibility guard and warn-don’t-quit behavior
