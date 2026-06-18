---
name: homebrew
description: Deploy macOS apps to Homebrew Cask via the panutat-p/homebrew-tap shared tap. Use when publishing a new app release, adding a new app to the tap, updating a cask formula, or asking about the Homebrew release pipeline.
disable-model-invocation: true
---

# Homebrew Deployment

## Overview

All panutat-p macOS apps are distributed through a single shared tap:
**[panutat-p/homebrew-tap](https://github.com/panutat-p/homebrew-tap)**

Users install apps with:
```bash
brew tap panutat-p/tap
brew install --cask <app-name>
```

## Registered apps

| Cask | App repo | DMG name | macOS min |
|------|----------|----------|-----------|
| `hyperzen` | `panutat-p/hyper-zen` | `Hyperzen.dmg` | 13 (Ventura) |
| `json-young` | `panutat-p/json-young` | `JSON_Young.dmg` | 14 (Sonoma) |

## Release pipeline

Triggered by pushing a version tag (`v*.*.*`) from any app repo:

```
git push origin v1.2.0
        │
        ▼
release.yml (app repo)
  1. Scripts/bundle-app.sh release  → .build/App.app
  2. Scripts/create-dmg.sh          → App.dmg
  3. shasum -a 256 App.dmg          → SHA256
  4. Create GitHub Release + upload DMG
  5. repository_dispatch → homebrew-tap
        │  payload: {cask, version, sha256}
        ▼
update-tap.yml (homebrew-tap)
  6. sed-patch version + sha256 in Casks/<cask>.rb
  7. git commit + push
```

## How to do a release

```bash
git tag v1.2.0
git push origin v1.2.0
```

That's it. The rest is fully automated.

## Adding a new app to the tap

### 1. Add the cask formula to homebrew-tap

Clone `panutat-p/homebrew-tap` and create `Casks/<cask-name>.rb`:

```ruby
cask "<cask-name>" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/panutat-p/<repo>/releases/download/v#{version}/<App>.dmg"
  name "<Display Name>"
  desc "<One-line description>"
  homepage "https://github.com/panutat-p/<repo>"

  depends_on macos: ">= :<codename>"   # e.g. :ventura, :sonoma

  app "<App>.app"

  zap trash: [
    "~/Library/Preferences/com.<bundle-id>.plist",
    "~/Library/Application Support/<App>",
    "~/Library/Caches/com.<bundle-id>",
  ]
end
```

Commit directly to `main` in `homebrew-tap` — no PR needed for new formula additions.

### 2. Add release.yml to the app repo

Copy `.github/workflows/release.yml` from `hyper-zen` and change:
- The `cask` field in the `repository_dispatch` payload
- The DMG filename in the `Create DMG` step if different

Key section to customize:
```yaml
- name: Trigger tap update
  uses: peter-evans/repository-dispatch@v3
  with:
    token: ${{ secrets.TAP_GITHUB_TOKEN }}
    repository: panutat-p/homebrew-tap
    event-type: update-cask
    client-payload: |
      {
        "cask": "<cask-name>",
        "version": "${{ steps.version.outputs.VERSION }}",
        "sha256": "${{ steps.sha256.outputs.SHA256 }}"
      }
```

### 3. Add TAP_GITHUB_TOKEN secret to the app repo

GitHub → app repo → Settings → Secrets → `TAP_GITHUB_TOKEN`

The token needs `Contents: write` permission on `panutat-p/homebrew-tap`.
One token can be reused across all app repos.

## Updating a formula manually

When you need to update a cask without a full release (e.g. fix a description):

```bash
cd homebrew-tap
# edit Casks/<cask>.rb
git add Casks/<cask>.rb
git commit -m "chore: fix <cask> description"
git push
```

## Verifying a formula locally

```bash
brew tap panutat-p/tap
brew install --cask <cask-name>
brew audit --cask <cask-name>
brew uninstall --cask <cask-name>
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `update-tap.yml` fails with "Cask file not found" | Cask name in payload doesn't match filename | Check `cask` field matches `Casks/<cask>.rb` exactly |
| `repository_dispatch` step fails | `TAP_GITHUB_TOKEN` missing or expired | Re-generate token; re-add secret to app repo |
| `brew install` downloads wrong version | Formula not updated yet | Check if `update-tap.yml` run succeeded in homebrew-tap Actions |
| Gatekeeper blocks the app | App not notarized | Sign with Developer ID and notarize before packaging DMG |
