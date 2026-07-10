# Apple Accessibility Permission Issue

## Summary

The `robot-swift` menu could show:

```text
Accessibility: Required for Teams presence
```

even when a foreground permission check printed:

```text
accessibility=true
```

The results came from different security contexts. A command launched from an authorized terminal can report trusted, while the same executable running independently as a LaunchAgent can still be denied synthetic-input access.

## LaunchAgent

The installed LaunchAgent is:

```text
~/Library/LaunchAgents/com.panutat.robot-swift.status-icon.plist
```

It launches:

```text
/Users/Panutat/app/robot-swift/.build/release/robot-swift status-icon
```

The LaunchAgent process must have its own valid Accessibility authorization. Granting access only to Terminal, Codex, or another parent application is not sufficient for the independently launched background process.

## Ad-Hoc Signing Root Cause

The Swift release executable is linker-signed with an ad-hoc identity:

```text
Signature: ad-hoc
TeamIdentifier: not set
```

Its designated requirement is based on its code hash. Running another release build changes the executable and its code hash. An Accessibility permission previously granted to the older build can therefore remain visible in System Settings while no longer matching the current executable.

This commonly produces the following sequence:

1. Build `robot-swift`.
2. Add it to Accessibility and enable it.
3. Rebuild `robot-swift`.
4. The new LaunchAgent process is denied even though an enabled `robot-swift` entry remains visible.

Until the executable is signed with a stable code-signing certificate, Accessibility permission may need to be granted again after every rebuild.

## Granting Permission

Open the Accessibility settings:

```sh
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

Reveal the current executable in Finder:

```sh
open -R ~/app/robot-swift/.build/release/robot-swift
```

Then:

1. Remove the stale `robot-swift` entry from the Accessibility list if one exists.
2. Click `+`, or drag the revealed executable into the list.
3. Add this exact file:

   ```text
   /Users/Panutat/app/robot-swift/.build/release/robot-swift
   ```

4. Enable its toggle.
5. Restart the LaunchAgent with `task robot-swift`.

macOS intentionally requires the grant to be confirmed in System Settings. There is no supported command that grants Accessibility permission.

## `tccutil` Limitation

This command does not work:

```sh
tccutil reset Accessibility robot-swift
```

It fails because `robot-swift` is a standalone executable, not a registered application bundle with a bundle identifier:

```text
tccutil: No such bundle identifier "robot-swift"
```

The following command resets Accessibility permission for every application and is therefore not recommended for routine recovery:

```sh
tccutil reset Accessibility
```

There is no supported `tccutil` command to remove only one path-based executable entry. Remove the stale entry manually in System Settings.

## Menu Status

The menu initially evaluated Accessibility only when the helper started, which could leave a stale label after permission changed. It now checks the permission again whenever the menu opens.

The possible labels are:

```text
Accessibility: Allowed
Accessibility: Required for Teams presence
```

The LaunchAgent's live result is more relevant than a foreground invocation of:

```sh
.build/release/robot-swift permissions
```

## Functional Verification

The most reliable verification is to observe whether the LaunchAgent's synthetic input reaches the cursor:

```text
+1 pixel
-1 pixel after 50 milliseconds
```

In the completed test:

- Without LaunchAgent Accessibility authorization: no cursor change was observed.
- After adding the current executable and restarting: `dx=1`, followed by `dx=-1`, was observed.

This functional test confirms the permission needed by Teams input activity, rather than relying only on a foreground trust query.

## Permanent Improvement

For permissions that survive rebuilds, distribute the helper as a consistently signed macOS application or executable using a stable code-signing certificate and identifier. No valid code-signing identity was installed on the Mac during this investigation, so the current workflow remains:

1. Build the release executable.
2. Grant Accessibility permission to that exact build.
3. Avoid rebuilding afterward unless permission will be granted again.
