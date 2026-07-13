# Issue: Monkey Icon Hidden Behind MacBook Notch

## Problem

On MacBook Pro M3 (and other notched models), the HyperZen monkey icon can be shifted left and obscured by the notch in the center of the menu bar, making it unreachable.

macOS places third-party `NSStatusItem` icons right-to-left, after the focused app's left-side menus. When the bar is crowded, icons are pushed toward the center and can land under the notch.

## Root Cause

- `NSStatusItem` placement is fully managed by the system — there is no public API to set an absolute X position.
- On notched MacBooks, the safe zone to the right of the notch is limited. Crowded menu bars push icons into the notch area.
- The app already sets `item.autosaveName = "HyperZen"` which persists position across relaunches, but does not bias the initial position.

## Options

### Option 1: Seed preferred position to far right (recommended)

AppKit reads a hidden `UserDefaults` key before placing a status item:

```
NSStatusItem Preferred Position <autosaveName>
```

Key: `NSStatusItem Preferred Position HyperZen`

Writing a **small** value (e.g. `0` or near-`0`) biases the item to the far right (closest to Control Center / system clock), which is the safest zone on notched displays.

**Implementation:** Before creating the `NSStatusItem`, write the preferred position key only if the user has not already manually set it (i.e., respect existing Cmd+drag placement).

```swift
private func setupStatusItem() {
    let posKey = "NSStatusItem Preferred Position HyperZen"
    if UserDefaults.standard.object(forKey: posKey) == nil {
        UserDefaults.standard.set(0.0, forKey: posKey)
    }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.autosaveName = "HyperZen"
    // ...
}
```

**Caveats:**
- Undocumented/private key — could break in a future macOS version.
- Once the user manually Cmd+drags the icon, AppKit overwrites the key; the seed is ignored on subsequent launches.

### Option 2: Manual Cmd+drag (zero code, user-facing)

The user can hold **⌘ Cmd** and drag the icon along the menu bar to reposition it. Since `autosaveName` is set, the position is remembered across relaunches.

Action: Document this in the README / onboarding UI.

### Option 3: Third-party menu bar managers

Tools like **Ice** (free) or **Bartender** manage overflow icons. Not fixable in-app, but worth mentioning in support docs.

## What Won't Work

- Setting an absolute frame/position on the status item button — the menu bar window is system-owned.
- Guaranteeing icon placement to the right of the notch in all crowded scenarios.

## Affected Hardware

- MacBook Pro M3 (and any MacBook with a notch: M1 Pro/Max/Ultra, M2, M3, M4 families)

## References

- `Hyperzen/AppDelegate.swift` — `setupStatusItem()` at line 89
- `Hyperzen/MenuBarVisibilityWatcher.swift` — detects when the icon is blocked and attempts recovery
