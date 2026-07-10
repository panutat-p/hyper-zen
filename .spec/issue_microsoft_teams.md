# Microsoft Teams Presence Issue

## Summary

`hyper-zen status-icon` kept macOS awake, but Microsoft Teams could still change the user's presence to **Away**.

The original implementation called `IOPMAssertionDeclareUserActivity` every 60 seconds. That informs macOS power management about activity, but it does not necessarily produce an input event that Teams recognizes when calculating presence.

The helper stays online because it generates an actual mouse movement: one pixel to the right, followed by a return to the original position after 50 milliseconds.

## Root Cause

Teams appears to base automatic presence on input activity rather than macOS power-management assertions alone.

The previous Swift implementation only posted a synthetic mouse event when `IOPMAssertionDeclareUserActivity` failed. Because the IOKit call normally succeeded, Teams received no mouse event and could still mark the user as Away.

## Fix

The status helper now performs both actions every 60 seconds:

- Declares user activity through IOKit.
- Posts a synthetic mouse movement from the current location to one pixel to the right.
- Waits 50 milliseconds.
- Returns the pointer to its original location.

The pointer is returned only if it is still at the nudged location. This avoids overriding a real mouse movement made by the user during the 50-millisecond interval.

The helper continues to hold these power assertions:

- `PreventUserIdleSystemSleep`
- `PreventUserIdleDisplaySleep`

## Accessibility Requirement

macOS blocks synthetic input from an unauthorized background process. The `hyper-zen` release executable must be enabled in:

```text
System Settings > Privacy & Security > Accessibility
```

The exact executable is:

```text
/Users/Panutat/app/hyper-zen/.build/release/hyper-zen
```

Without this permission, the power assertions may still keep the Mac awake, but Teams will not receive the synthetic mouse activity.

## Verification

The LaunchAgent was restarted while the cursor position was sampled every millisecond. With Accessibility permission enabled, the expected movement was observed:

```text
change dx=1 dy=0
change dx=-1 dy=0
```

Before permission was enabled, no cursor movement occurred during the same test.

This confirms that the synthetic input reaches macOS when the background helper has Accessibility permission.

## Starting and Restarting

Start or restart the installed LaunchAgent with:

```sh
task hyper-zen
```

The task runs:

```sh
launchctl kickstart -k gui/$(id -u)/com.panutat.hyper-zen.status-icon
```

`kickstart -k` terminates the existing instance and starts one replacement. It does not create duplicate helpers.

## Remaining Limitation

Microsoft Teams presence is ultimately controlled by Teams and Microsoft 365. A manually selected status, calendar state, call state, account policy, network interruption, or Teams service behavior may override local activity detection.
