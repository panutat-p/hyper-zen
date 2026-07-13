# Issue: Apple Developer ID required for trusted releases

## Summary

HyperZen releases distributed via GitHub Actions, DMG, and Homebrew are **ad-hoc signed** because no **Apple Developer Program** membership ($99/year) or CI signing secrets are configured. On macOS 15+, this blocks reliable Accessibility grants and Gatekeeper trust for end users.

**Project owner does not currently have an Apple Developer ID.**

## Current release signing

### CI (`/.github/workflows/release.yml`)

- Tag push `v*.*.*` triggers build
- `Scripts/bundle-app.sh release` runs with:
  ```yaml
  env:
    CODESIGN_IDENTITY: ${{ secrets.APPLE_SIGNING_IDENTITY }}
  ```
- If secret is unset, `bundle-app.sh` defaults to ad-hoc:
  ```bash
  SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
  ```

### Installed app state (example: v0.0.5)

```
Signature=adhoc
TeamIdentifier=not set
Gatekeeper: rejected
```

### Not implemented yet

- Apple **notarization** (`notarytool` / `stapler`)
- Hardened runtime entitlements review
- Stapled ticket on DMG or `.app`

## What ad-hoc signing is

**Ad-hoc** (`codesign --sign -`) is a local, anonymous signature. It proves the app bundle has a consistent on-disk layout (CodeDirectory sealed) but is **not** tied to any Apple-registered developer identity.

| Property | Ad-hoc (`--sign -`) | Developer ID | Apple Development (free Apple ID) |
|----------|---------------------|--------------|-----------------------------------|
| Cost | Free | $99/year program | Free |
| `TeamIdentifier` | `not set` | Real team ID | Personal team ID |
| `Authority` chain | None (`Signature=adhoc`) | `Developer ID Application: …` | `Apple Development: …` |
| Distributable (DMG, Homebrew) | Yes, but untrusted | Yes | No (personal device/dev only) |
| Gatekeeper (`spctl`) | `rejected` | `accepted` (when notarized + stapled) | Varies; not for public release |
| TCC grant keyed to | **CDHash** (per build) | Team ID + signing identity | Dev cert; local use |
| Grant survives rebuild/upgrade | **No** | **Yes** (same cert pipeline) | N/A for distribution |

HyperZen uses ad-hoc whenever `CODESIGN_IDENTITY` / `APPLE_SIGNING_IDENTITY` is unset — which is the case for all published releases to date (v0.0.1–v0.0.5).

### How HyperZen becomes ad-hoc

Every path through `Scripts/bundle-app.sh` ends with:

```bash
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"   # "-" means ad-hoc
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
```

| Build path | Command | Signing |
|------------|---------|---------|
| GitHub Release | `Scripts/bundle-app.sh release` on tag push | Ad-hoc (no `APPLE_SIGNING_IDENTITY` secret) |
| Homebrew cask | Downloads DMG from GitHub Release | Same ad-hoc binary |
| Local app build | `task dev` / `task build` | Ad-hoc |
| Xcode debug | `HyperZen.xcodeproj` (if used) | Usually “Sign to Run Locally” / Personal Team — **different** from brew |

`--deep` re-signs nested code; errors are swallowed (`2>/dev/null || true`), so a failed real signing attempt could still fall through — today the default is intentionally ad-hoc.

### CDHash — why every version looks like a “new app” to macOS

**CDHash** (Code Directory Hash) is a SHA-256 fingerprint of the signed executable content. TCC stores grants like:

```
subject=com.hyperzen.HyperZen
cdhash H"45341f6ea19074e5b3bf5e7564ae63e70d9694e6"
```

Observed on v0.0.5 (`/Applications/HyperZen.app`):

```
CodeDirectory flags=0x2(adhoc)
CDHash=45341f6ea19074e5b3bf5e7564ae63e70d9694e6
Signature=adhoc
```

Any of these changes the CDHash:

- New git tag / release (recompiled binary)
- Different optimization (`debug` vs `release`)
- Any source change affecting the Mach-O
- Re-signing with ad-hoc on a different machine

So **0.0.2 → 0.0.5** is not an “upgrade” to TCC — it is a **different binary identity**. Settings may still show one “HyperZen” row from an older grant; runtime checks the **current** CDHash and returns denied (`authValue=0`).

Developer ID breaks this cycle: grants anchor to the **signing identity**, so rebuilds with the same Developer ID certificate keep working across versions (users reset once after first signed install).

### What ad-hoc does and does not provide

**Does:**

- Seals `Info.plist`, resources, and executable into a `CodeDirectory`
- Allows the app to run when the user bypasses or ignores Gatekeeper (e.g. Homebrew drag to `/Applications`, prior open)
- Satisfies basic `codesign --verify` structural checks

**Does not:**

- Prove publisher identity to macOS or the user
- Pass Gatekeeper assessment (`spctl -a -vv` → `rejected`)
- Persist Accessibility (or other TCC) grants reliably on macOS 15+
- Prevent quarantine (`com.apple.quarantine` xattr on downloaded DMGs — separate from signing, but compounds “untrusted app” UX)
- Provide notarization malware scan / Apple ticket

### Ad-hoc and Accessibility — two failure modes

1. **Cannot grant at all** — User toggles ON in Settings; macOS validates signature before save; ad-hoc fails validation; toggle flips **OFF** immediately. See `.spec/issue_accessibility.md`.

2. **Stale grant after upgrade** — Toggle stays ON from an **older** CDHash; new version’s binary does not match; app runs but `AXIsProcessTrusted()` is false. Looks like an upgrade bug; root cause is still ad-hoc. See `.spec/issue_conflict.md` (upgrade flow).

Both are fixed by the same remedy: **Developer ID signed + notarized releases**, not reinstall alone.

### Inspecting ad-hoc on an installed app

```bash
APP="/Applications/HyperZen.app"

# Signing summary
codesign -dv "$APP" 2>&1 | rg 'Identifier=|Format=|CDHash=|Signature=|TeamIdentifier=|flags='

# Gatekeeper
spctl -a -vv "$APP" 2>&1
# expected today: rejected (the string is used as a boolean)

# Structural verify (can still pass for ad-hoc)
codesign --verify --deep --strict "$APP" 2>&1 && echo "structure OK"

# Quarantine from download (independent of ad-hoc)
xattr -lr "$APP" 2>&1 | rg quarantine || echo "(no quarantine)"

# TCC requests for current binary
/usr/bin/log show --last 30m \
  --predicate 'subsystem == "com.apple.TCC" AND eventMessage CONTAINS "com.hyperzen.HyperZen"' \
  2>&1 | rg 'cdhash|AUTHREQ_RESULT|authValue' | tail -10
```

Example Gatekeeper output:

```
/Applications/HyperZen.app: rejected
```

### Ad-hoc vs “just unsigned”

An app with **no** `codesign` at all is worse: macOS may refuse to run it entirely. HyperZen **is** signed — ad-hoc is the weakest valid signature tier. That is enough to ship a `.app` bundle but not enough for privacy consent databases to trust it long-term.

### Why CI does not “accidentally” get real signing

`release.yml` passes `secrets.APPLE_SIGNING_IDENTITY` into `CODESIGN_IDENTITY`. If the secret is missing or empty, bash expands to empty and `bundle-app.sh` falls back to `-`. No certificate is present on `macos-latest` runners without importing a `.p12` from secrets — which is not configured.

## User-visible impact

| Area | Ad-hoc release | Developer ID + notarized |
|------|----------------|---------------------------|
| Accessibility toggle persists | Unreliable on macOS 15+ | Reliable |
| Gatekeeper on first open | Rejected / quarantine | Accepted when stapled |
| TCC grant survives app upgrade | No (CDHash changes every build) | Yes (same Team ID + signing pipeline) |
| Homebrew install trust | Depends on user overrides | Standard trusted distribution |
| Corporate MDM / strict policies | May block entirely | Usually allowed |

## Why ad-hoc is insufficient

macOS 15+ ties privacy permissions (including Accessibility) to **code signature identity**, not display name. Ad-hoc signatures:

- Change **CDHash** on every build → upgrades invalidate grants (see [CDHash](#cdhash--why-every-version-looks-like-a-new-app-to-macos))
- Fail Gatekeeper assessment (`spctl -a -vv` → `rejected`)
- Cause Settings UI to **reject** saving Accessibility grants (toggle flips OFF)
- Offer no `TeamIdentifier` for enterprise allow-lists or MDM “trusted developer” rules

This is platform policy, not a HyperZen bug. Clean uninstall, `tccutil reset`, and reinstall **do not** change the signature tier — the new install is ad-hoc again.

## Options without paid Developer ID

| Option | Scope | Accessibility |
|--------|-------|----------------|
| Homebrew / DMG ad-hoc build | All users | Unreliable |
| Local Xcode + free Apple ID (“Personal Team”) | Developer’s Mac only | May work for personal dev; not distributable |
| `caffeinate -dims` | CLI workaround | N/A |
| HyperZen “basic keep-awake” without `CGEvent` nudges | Product change | Not needed (IOPMAssertion only) |

Free Apple ID does **not** replace Developer ID for public Homebrew releases.

## Path to proper releases (when budget allows)

### 1. Enroll in Apple Developer Program

- https://developer.apple.com/programs/
- Create **Developer ID Application** certificate in Certificates, Identifiers & Profiles

### 2. Store GitHub secrets (`panutat-p/hyper-zen`)

| Secret | Purpose |
|--------|---------|
| `APPLE_SIGNING_IDENTITY` | e.g. `Developer ID Application: Name (TEAMID)` |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | Team identifier |

### 3. Extend `Scripts/bundle-app.sh` / `release.yml`

- Sign with Developer ID (not ad-hoc)
- Enable hardened runtime if required
- Submit to notary service
- Staple notarization ticket to `.app` and DMG
- Verify: `spctl -a -vv /Applications/HyperZen.app` → `accepted`

### 4. Release verification checklist

```bash
codesign -dv --verbose=4 /Applications/HyperZen.app 2>&1 | rg 'Authority=|TeamIdentifier=|Signature='
spctl -a -vv /Applications/HyperZen.app
xattr -lr /Applications/HyperZen.app | rg quarantine || true
```

After first signed release, users should reset Accessibility once, then grants should persist across future signed upgrades.

## Product / docs actions (no Developer ID)

- Document in README: Accessibility may not work on ad-hoc builds; link to `.spec/issue_accessibility.md`
- Consider **optional keep-awake without Accessibility** (display/system assertions only) for unsigned users
- Keep `APPLE_SIGNING_IDENTITY` placeholder comment in `release.yml` until secrets exist
- README release section: note signing status in release notes

## Cost / decision record

| Item | Cost | Status |
|------|------|--------|
| Apple Developer Program | $99 USD / year | Not enrolled |
| Signed + notarized HyperZen | Blocked on above | Future work |

## References

- `.github/workflows/release.yml` — `APPLE_SIGNING_IDENTITY` hook (unused)
- `Scripts/bundle-app.sh` — codesign step
- `.spec/issue_accessibility.md` — user-facing Accessibility symptoms
- `.cursor/skills/homebrew/SKILL.md` — tap release pipeline
