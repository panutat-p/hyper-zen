# Issue: Monkey Icon Hidden Behind MacBook Notch

## Problem

On MacBook Pro M3 (and other notched models), the HyperZen monkey icon can be shifted left and obscured by the notch in the center of the menu bar, making it unreachable.

macOS places third-party `NSStatusItem` icons right-to-left, after the focused app's left-side menus. When the bar is crowded, icons are pushed toward the center and can land under the notch.

## Root Cause

- `NSStatusItem` placement is fully managed by the system — there is no public API to set an absolute X position.
- On notched MacBooks, the safe zone to the right of the notch is limited. Crowded menu bars push icons into the notch area.
- The app already sets `item.autosaveName = "HyperZen"` which persists position across relaunches, but does not bias the initial position.

## Resolution

HyperZen remains a regular macOS application with a Dock icon. Its controls live in one shared dropdown:

- Click the **menu-bar icon** for the normal status-item dropdown.
- Click the **Dock icon** to open the same dropdown near the pointer.
- When the pointer is on the Dock, HyperZen positions the menu above the Dock and clamps it to the active screen's visible frame.

This is the supported recovery path when the status item is hidden behind the notch or crowded out of reach. It does not depend on trying to control AppKit's system-owned menu-bar layout.

The user can still hold **⌘ Cmd** and drag a visible menu-bar icon; its `autosaveName` preserves that placement across relaunches.

## What Won't Work

- Setting an absolute frame/position on the status item button — the menu bar window is system-owned.
- Guaranteeing icon placement to the right of the notch in all crowded scenarios.
- Writing the undocumented `NSStatusItem Preferred Position` defaults key.

## Affected Hardware

- MacBook Pro M3 (and any MacBook with a notch: M1 Pro/Max/Ultra, M2, M3, M4 families)

## References

- `Hyperzen/AppDelegate.swift` — creates the shared status menu and presents it from Dock reopen events
- `Hyperzen/MenuBarVisibilityWatcher.swift` — detects when macOS blocks the icon and presents recovery guidance
