---
name: gh-pr
description: Use GitHub CLI (gh) to create a PR, review an existing PR, or add/update details on a PR for hyperzen. Use when the user asks to open a PR, create a pull request, review a PR, update PR description, add reviewers, or any gh pr workflow.
disable-model-invocation: true
---

# GitHub CLI PR Workflow

## Create a PR

### PR Title

Use a **plain English sentence** that describes the change for a human reader.

- Good: `Pause menu bar animation while display is asleep`
- Good: `Fix sleep assertion not released on quit`
- Bad: `feat: pause animation`
- Bad: `fix(hyperzen): sleep assertion`

Do **not** use conventional commit prefixes (`feat:`, `fix:`, `chore:`, etc.) or scoped commit formats (`fix(scope): ...`) in PR titles.

### PR Body

Pick the template that matches the change. Do **not** include a Test Plan section.

#### Bug fix

1. **Problem** — What is broken? Where does it show up in the app?
2. **Root Cause** — Why it happens (IOPMAssertion lifecycle, menu bar state, timer scheduling, etc.)
3. **Solution** — What was changed and why that fixes it
4. **Code changes** — Table of every file touched (see below)

#### New feature

1. **Overview** — What the feature does and why it is needed
2. **Implementation** — How it was built: key files, approach, and notable design choices
3. **Code changes** — Table of every file touched (see below)

Optional: add a diagram (mermaid) when the change involves power-management flow, timer scheduling, or build pipeline steps.

#### Code changes (required)

Every PR body must end with a **Code changes** section: a markdown table listing **every file** in the PR diff.

Use `git diff <base>...HEAD --stat` (or `gh pr diff [number] --stat`) to enumerate files. Group rows by area (App, Assets, Tests, Build, Project, Docs, Tooling, etc.). One row per file or logical path (e.g. `Hyperzen/Assets.xcassets/AppIcon.appiconset/*`).

| Area | File | Change |
|------|------|--------|
| App | `Hyperzen/SleepPreventer.swift` | Short description of what changed |
| Build | `Scripts/generate-icons.sh` | Short description of what changed |

- **Area** — coarse category for scanning (App, Assets, Tests, Build, Project, Docs, Tooling)
- **File** — path relative to repo root, in backticks
- **Change** — one-line summary (added, removed, renamed, or what behavior changed)

For large/binary-only paths (icon PNGs), one grouped row is fine. Do not omit files from the diff.

### Create PR

1. Create PR with title and body (bug fix example):

   `gh pr create --title "Fix sleep assertion not released on quit" --body "$(cat <<'EOF'
   ## Problem

   After quitting Hyperzen from the menu bar, the Mac may stay awake because IOPMAssertions are not released on shutdown.

   ## Root Cause

   - `SleepPreventer` enabled assertions on launch but had no teardown hook when the app terminated
   - `applicationWillTerminate` was not calling `disable()`

   ## Solution

   - Register `applicationWillTerminate` in `AppDelegate`
   - Call `SleepPreventer.disable()` to release both system and display assertions

   ## Code changes

   | Area | File | Change |
   |------|------|--------|
   | App | `Hyperzen/AppDelegate.swift` | Call `SleepPreventer.disable()` in `applicationWillTerminate` |
   | App | `Hyperzen/SleepPreventer.swift` | Ensure `disable()` releases system and display assertions |
   EOF
   )"`

   New feature example:

   `gh pr create --title "Pause menu bar animation while display is asleep" --body "$(cat <<'EOF'
   ## Overview

   The menu bar icon keeps animating after the display sleeps, which is distracting and wastes CPU.

   ## Implementation

   - Observe `NSWorkspace.screensDidSleepNotification` in `AppDelegate`
   - Pause `IconRenderer` animation on sleep and resume on wake
   - Gate resume on keep-awake being enabled so idle state stays static

   ## Code changes

   | Area | File | Change |
   |------|------|--------|
   | App | `Hyperzen/AppDelegate.swift` | Observe screen sleep/wake; pause and resume icon animation |
   | App | `Hyperzen/IconRenderer.swift` | Add pause/resume hooks for menu bar frame cycling |
   EOF
   )"`

2. Add reviewers or assignees (optional): `gh pr create --title "..." --body "..." --reviewer handle1,handle2 --assignee "@me"`

3. Draft PR (not ready for review): `gh pr create --draft --title "..." --body "..."`

4. Autofill title and body from commit messages (only when appropriate): `gh pr create --fill`

   After `--fill`, **edit the title and body** to match the conventions above. Commit messages often use conventional prefixes; PR titles and bodies should not.

## View / Review a PR

- View PR in terminal: `gh pr view [number]`
- Open PR in browser: `gh pr view [number] --web`
- List open PRs: `gh pr list`
- View PR diff: `gh pr diff [number]`
- View PR checks / CI status: `gh pr checks [number]`
- Watch checks until they finish: `gh pr checks [number] --watch`

## Add or Update PR Details

- Set title: `gh pr edit [number] --title "new title"`
- Replace body: `gh pr edit [number] --body "new body text"`
- Add reviewers: `gh pr edit [number] --add-reviewer handle1,handle2`
- Remove reviewers: `gh pr edit [number] --remove-reviewer handle1`
- Add labels: `gh pr edit [number] --add-label "bug,enhancement"`
- Remove labels: `gh pr edit [number] --remove-label "needs-triage"`
- Mark ready for review (un-draft): `gh pr ready [number]`
- Convert back to draft: `gh pr ready [number] --undo`

## Merge a PR

- Merge commit: `gh pr merge [number] --merge`
- Squash merge: `gh pr merge [number] --squash`
- Rebase merge: `gh pr merge [number] --rebase`
- Auto-merge when checks pass: `gh pr merge [number] --auto --squash`
- Delete branch after merge: `gh pr merge [number] --squash --delete-branch`

## Tips

- If not authenticated, run `gh auth login` before proceeding.
- Omit `[number]` to target the PR for the current branch.
- Use `--web` on any command to open that PR in the browser.
- `gh pr view --json title,body,reviews,reviewRequests` for structured data.
- When updating an existing PR with `gh pr edit --body`, keep the same template sections (bug fix: Problem, Root Cause, Solution, Code changes; new feature: Overview, Implementation, Code changes).
- Regenerate the **Code changes** table when new commits are pushed to the PR branch.
