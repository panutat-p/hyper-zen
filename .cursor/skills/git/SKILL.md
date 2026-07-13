---
name: git
description: Git workflow for hyperzen (Hyperzen macOS menu bar app) — use git switch, check branch with git status, avoid pushing to main, and use conventional branch names and commit messages. Use when creating branches, committing, pushing, or any git operation in this repo.
---

# Git workflow (hyperzen)

## Project context

- **Repo**: `hyperzen` — a macOS menu bar app that prevents sleep, built with Swift, AppKit, and Swift Package Manager.
- **App name**: Hyperzen (`.app` bundle under `.build/Hyperzen.app` or Xcode derived data).
- **Layout**:
  - `Hyperzen/` — app source (menu bar UI, sleep prevention, icon rendering)
  - `Tests/HyperzenTests/` — unit tests for `HyperzenCore`
  - `Scripts/` — build, icon generation, and DMG packaging
  - `Design/` — app icon SVG and generated previews
  - `Hyperzen.xcodeproj/` — Xcode project (optional; `swiftc` build also supported)
- **Common commands**: `task dev`, `task build`, `task test`, `task release`, `swift test`

## Rules

- Prefer **`git switch`** over `git checkout` (branches, new branches, restore files).
- **Always run `git status`** before branch-changing or push operations to confirm the current branch and staged files.
- **Do not push to `main` directly.** Work on a feature branch, push that branch, and open a PR.
- Use **conventional branch names** and **conventional commit messages**.
- **Only commit when asked.** Do not create commits proactively unless the user explicitly requests it.

## Branch names

Use lowercase, hyphenated suffixes:

| Prefix      | When                                                |
| ----------- | --------------------------------------------------- |
| `feat/`     | New feature or user-facing behavior                 |
| `fix/`      | Bug fix                                             |
| `refactor/` | Code change without behavior change                 |
| `chore/`    | Tooling, deps, config, version bumps                |
| `test/`     | Tests only                                          |
| `docs/`     | Documentation only                                  |
| `style/`    | Formatting, whitespace, lint-only (no logic change) |
| `perf/`     | Performance improvement                             |
| `build/`    | Build system, bundler, or deploy config             |
| `revert/`   | Revert a previous change                            |

Examples:

- `feat/menu-bar-toggle-shortcut`
- `fix/sleep-assertion-not-released-on-quit`
- `refactor/extract-icon-renderer`
- `chore/update-dmg-packaging-script`

Create and switch:

- `git status`
- `git switch -c feat/short-description`

Switch to an existing branch:

- `git status`
- `git switch feat/short-description`

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

`<type>: <short summary>` with an optional body explaining why, not just what.

Common types: `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `style`, `perf`, `build`, `revert`.

Examples:

- `feat: pause animation while display is asleep`
- `fix: release IOPMAssertion on app quit`
- `refactor: move activity nudge logic into ActivityNudger`
- `test: add SleepPreventer assertion lifecycle tests`
- `chore: update bundle script for release builds`
- `build: bump minimum macOS target in Package.swift`
- `docs: document task release workflow in README`

Commit:

`git status`

`git add <relevant-files>`

`git commit -m "$(cat <<'EOF'
feat: short summary here

Optional body.
EOF
)"`

## Push

- Confirm not on `main`: `git status`
- `git push -u origin HEAD`

If currently on `main`, create and switch to a branch first — never push commits directly to `main`.

## Pre-commit checks

Before committing Swift changes, run tests when the change affects logic:

- `swift test`
- `task test`

For menu bar UI or bundling changes, verify the app launches:

- `task dev`

## Quick checklist

- [ ] `git status` — correct branch, only intended files staged
- [ ] Branch name uses conventional prefix (`feat/`, `fix/`, `refactor/`, …)
- [ ] Commit message uses conventional type (`feat:`, `refactor:`, …)
- [ ] Push targets a feature branch, not `main`
- [ ] `swift test` passes when logic changed

## Related skills

- PR creation and review: [github/SKILL.md](../github/SKILL.md) — PR **titles** use plain English, not conventional commit prefixes.
