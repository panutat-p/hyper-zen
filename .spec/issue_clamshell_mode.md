# Clamshell Mode Lock Issue

## Summary

`hyper-zen status-icon` worked as expected with the laptop lid open, but closing the lid while connected to power and HDMI could leave the Mac awake while showing the lock screen on the external display.

Observed cases:

- Case 1: lid open, program running: no sleep, no lock.
- Case 2: power connected, HDMI monitor connected, lid closed: no sleep, but lock screen can appear.

## Diagnosis

The recent Case 2 behavior looked like a display/session lock transition, not a full system sleep. The power log did not show a matching `Entering Sleep` and `Wake` pair around the observed event. It did show loginwindow activity and display/power assertion changes.

The original `status-icon` implementation only posted a synthetic mouse-moved event every 5 minutes. It did not hold macOS power assertions, so macOS had no explicit instruction from `hyper-zen` to keep idle system sleep or idle display sleep blocked.

## Fix

`status-icon` now uses IOKit power management APIs:

- Holds `PreventUserIdleSystemSleep` while running.
- Holds `PreventUserIdleDisplaySleep` while running.
- Calls `IOPMAssertionDeclareUserActivity` every 60 seconds.
- Keeps the old synthetic mouse movement only as a fallback if the user-activity declaration fails.
- Re-checks assertions after wake and screen-configuration changes.
- Releases assertions on quit.

This is a code-only fix. It does not change system security settings.

## Remaining macOS Limitation

Apple documents that `PreventUserIdleDisplaySleep` prevents idle display sleep, but a portable Mac display may still sleep for other reasons such as closing the lid. If macOS is configured to require a password after the display turns off or the screen saver starts, lid-close clamshell transitions may still show the lock screen even though the system did not sleep.

If Case 2 still locks after this fix, check:

- System Settings > Lock Screen
- "Require password after screen saver begins or display is turned off"

That setting is intentionally not changed by this project.

## Verification

With `status-icon` running, `pmset -g assertions` should list `hyper-zen` as owning:

- `PreventUserIdleSystemSleep`
- `PreventUserIdleDisplaySleep`

Manual scenarios:

- Lid open: confirm no regression from the previous working behavior.
- Power + HDMI + lid closed: confirm the system stays awake and external-display clamshell mode remains available. If the lock screen appears, inspect the power log to distinguish lock/display behavior from real sleep.
