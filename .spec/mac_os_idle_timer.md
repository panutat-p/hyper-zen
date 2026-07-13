# Investigation: Keeping Microsoft Teams "Available" without nudges

## Question

> Is there a way to stop Microsoft Teams (and Slack, etc.) from flipping the
> user to **Away** *without* synthetic input nudges — so HyperZen no longer
> needs macOS **Accessibility** permission?

Motivation: HyperZen's Accessibility dependency causes two recurring problems.

| Problem | Description | Spec |
|---------|-------------|------|
| **1. Needs Accessibility** | `ActivityNudger` posts `CGEvent`s, which require Accessibility (TCC). | `.spec/issue_accessibility.md` |
| **2. Grant lost on upgrade** | Ad-hoc signing → CDHash changes every build → TCC grant invalidated each release. | `.spec/issue_apple.md`, `.spec/issue_conflict.md` |

## TL;DR — Verdict

**No.** On macOS 15.7.1 there is **no Accessibility-free way** to keep Teams
"Available". The only thing that resets the idle timer Teams reads is a real HID
event, and synthesizing one with `CGEvent.post` requires Accessibility. This was
**confirmed empirically** (see [Empirical test](#empirical-test)).

- **Problem 1** is *unavoidable* for the Teams-presence feature specifically.
- **Problem 2** is the genuinely fixable one — via Developer ID signing +
  notarization (`.spec/issue_apple.md`), not by removing nudges.

## How Teams decides you are "Away"

Teams (and Slack, Zoom presence, Prohance, etc.) determine idle purely from the
**macOS HID idle timer**:

```swift
CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: <anyInput>)
// older C name: CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState, kCGAnyInputEventType)
```

- This counter **only resets on a real HID input event** — physical (or
  successfully injected synthetic) mouse move, keypress, or scroll.
- Threshold for Away is ~**5 minutes**, baked into the client and not
  user-configurable.
- Equivalent lower-level source: `IOHIDSystem`'s `HIDIdleTime` registry property.
- The same value is also queryable via `GetLastInputInfo()` on Windows and
  `XScreenSaverQueryInfo()` / `idle-inhibit` on Linux — this is cross-platform
  presence detection behavior, not a macOS quirk.

### Why power assertions are not enough

`IOPMAssertion` (what `SleepPreventer`, `caffeinate`, Caffeine.app, Amphetamine
all use) keeps the **system/display awake** but does **not** touch the HID idle
timer. Teams ignores power assertions entirely. This is the well-known reason
"Caffeine alone doesn't keep Teams green," and why HyperZen needs the separate
`ActivityNudger`.

## Mechanism comparison

| Mechanism | Resets HID idle timer (keeps Teams green)? | Needs Accessibility? | Notes |
|-----------|:---:|:---:|-------|
| `IOPMAssertionCreateWithName` (`PreventUserIdleSystemSleep` / `…DisplaySleep`) — current `SleepPreventer` | **No** | No | Keeps Mac/display awake only |
| `IOPMAssertionDeclareUserActivity` / `caffeinate -u` | **No** | No | Wakes display, delays sleep; does **not** reset the HID counter Teams reads |
| `UpdateSystemActivity(UsrActivity)` (deprecated Carbon) | Unreliable | No | Targets screensaver idle, not the HID counter |
| Reset `HIDIdleTime` via `IOHIDParamUserClient` external method 6 | Yes | Effectively yes | Hits `mac_iokit_check_hid_control`; needs entitlements/clearance; fragile/undocumented |
| Synthetic `CGEvent` mouse-move — current `ActivityNudger` | **Yes** | **Yes (confirmed)** | Silently no-ops when process is untrusted on macOS 15 |
| Synthetic `CGEvent` scroll-wheel | **Yes** | **Yes (confirmed)** | Same gating as mouse-move on macOS 15 |
| Synthetic `CGEvent` keyboard (e.g. Left Shift, keyCode 56) | **Yes** | **Yes (confirmed)** | Zero side-effect modifier key; same Accessibility gating |

### On the "mouse-move/scroll don't need Accessibility" claim

Third-party tools (AlwaysJiggle "Zen mode", `activity-driver`,
`diabler-ie/caffeine-that-keeps-you-active-on-teams-for-mac`) claim mouse-move
and scroll-wheel `CGEvent`s reset the idle timer **without** Accessibility,
while only clicks/keystrokes require it. **This does not hold on macOS 15.7.1** —
see the test below. The API accepts the post and returns success, but the event
is never injected for an untrusted process, so the idle timer keeps climbing.
These claims are likely outdated (older macOS) or were measured from a Terminal
that already had Accessibility granted.

## Empirical test

A standalone CLI was built to settle this: `Tools/IdleProbe/`.

- `Tools/IdleProbe/main.swift` — reads the HID idle timer, waits (polling) until
  it climbs above a threshold so the result isn't confounded by stray input,
  posts a nudge, then re-reads the timer. Reports `AXIsProcessTrusted()`.
- `Tools/IdleProbe/build.sh` — compiles with `swiftc` (frameworks:
  `CoreGraphics`, `ApplicationServices`).

Build & run:

```bash
./Tools/IdleProbe/build.sh
./Tools/IdleProbe/idle-probe           # one-shot: mouse-move + scroll + keyboard
./Tools/IdleProbe/idle-probe watch     # nudge every 30s; watch Teams status live
./Tools/IdleProbe/idle-probe watch 15  # same, every 15s
```

> Key methodology point: TCC Accessibility trust is attributed to the
> **responsible/launching process**. Running the binary from Cursor's terminal
> (which *is* trusted) makes the child report `trusted=YES` and is inconclusive.
> The clean no-permission test requires launching from a process **not** in
> System Settings ▸ Privacy & Security ▸ Accessibility (e.g. stock Terminal.app).

This is a controlled A/B experiment: same machine, same binary, same code path.
The **only** variable between runs is whether the launching process holds the
Accessibility grant.

### Run 1 — launched from Cursor terminal (TRUSTED) — positive direction

```
AXIsProcessTrusted: YES
[mouse-move] idle reached 3.10s -> posting nudge
[mouse-move] idle after nudge: 0.24s
[mouse-move] RESULT: nudge RESET the idle timer  ✅

[scroll]     idle reached 3.05s -> posting nudge
[scroll]     idle after nudge: 0.25s
[scroll]     RESULT: nudge RESET the idle timer  ✅

[keyboard]   idle reached 3.04s -> posting nudge
[keyboard]   idle after nudge: 0.25s
[keyboard]   RESULT: nudge RESET the idle timer  ✅
```

Confirms the mechanism works *when trusted*: synthetic **mouse-move, scroll, and
keyboard** events all reset the idle timer to ~0.25s. This is exactly what keeps
Teams "Available". (Keyboard test uses Left Shift, keyCode 56 — a modifier that
counts as HID input but types no character, so no side effect.)

### Run 2 — launched from stock Terminal.app (NOT trusted) — negative direction

```
AXIsProcessTrusted: NO
[mouse-move] idle reached 3.09s -> posting nudge
[mouse-move] idle after nudge: 3.41s
[mouse-move] RESULT: nudge did NOT reset the idle timer  ❌

[scroll] idle reached 3.41s -> posting nudge
[scroll] idle after nudge: 3.66s
[scroll] RESULT: nudge did NOT reset the idle timer  ❌
```

Without Accessibility, **neither** mouse-move nor scroll reset the timer — it
climbed straight through both nudges. (Keyboard synthesis also requires
Accessibility, so it cannot help here either.)

### Conclusion from the A/B runs

| Synthetic event | Trusted (Accessibility ON) | Untrusted (Accessibility OFF) |
|-----------------|:--------------------------:|:-----------------------------:|
| mouse-move | reset ✅ (3.10 → 0.24s) | no reset ❌ (3.09 → 3.41s) |
| scroll | reset ✅ (3.05 → 0.25s) | no reset ❌ (3.41 → 3.66s) |
| keyboard | reset ✅ (3.04 → 0.25s) | n/a (requires Accessibility) |

**Accessibility is the sole gating factor.** The synthetic-input approach is the
*only* one that resets the idle timer, and it works **if and only if** the
process is Accessibility-trusted.

### Environment

| Item | Value |
|------|-------|
| macOS | 15.7.1 (build 24G231) |
| Hardware | Apple Silicon |
| Date | 2026-06-19 |
| Tool | `Tools/IdleProbe` (commit not yet made) |

## What requires Accessibility (and what does not)

| HyperZen feature | API | Needs Accessibility? |
|------------------|-----|----------------------|
| Keep-awake (prevent sleep) | `IOPMAssertion…` (`SleepPreventer`) | **No** |
| Menu bar status item / animation | `NSStatusItem` | No |
| Permission warning modal | `NSAlert` | No |
| **Keep Teams "Available"** (idle reset) | `CGEvent.post` (`ActivityNudger`) | **Yes (confirmed)** |

Important: **only the Teams-presence nudge needs Accessibility.** Basic
keep-awake does not. Today `AppDelegate` gates *all* keep-awake behind
`AXIsProcessTrusted()`, forcing every user to grant Accessibility even if they
only want to prevent sleep.

## Recommendations

### A. Decouple the two features (no cost, removes most pain)

Split into:

1. **Keep Awake (basic)** — `IOPMAssertion` only, no Accessibility, always
   works. Make this the default.
2. **Stay active in Teams** — optional toggle that starts `ActivityNudger`;
   only this path prompts for / requires Accessibility.

Effect: Accessibility becomes opt-in for the single feature that truly needs it.
Users who only want sleep prevention never touch TCC, sidestepping Problem 2
entirely for them.

### B. Fix Problem 2 properly — Developer ID signing + notarization

The only reliable way to make the Accessibility grant survive upgrades. Anchors
TCC to the signing identity instead of a per-build CDHash. Requires Apple
Developer Program ($99/yr) and CI secrets. Full plan in `.spec/issue_apple.md`.
No free distribution-grade alternative exists.

### C. Both (recommended)

A removes friction now; B makes the remaining Accessibility-dependent feature
durable across releases.

## Dead ends (do not revisit without new OS behavior)

- Power assertions / `caffeinate` / `DeclareUserActivity` to keep Teams green —
  do not reset the HID idle timer.
- Mouse-move or scroll `CGEvent` without Accessibility on macOS 15 — silently
  no-ops (confirmed).
- Free Apple ID "Personal Team" for distribution — works on the dev Mac only.

## References

- `Hyperzen/ActivityNudger.swift` — the `CGEvent` nudge (Accessibility-gated mechanism)
- `Hyperzen/SleepPreventer.swift` — `IOPMAssertion` keep-awake (no Accessibility)
- `Hyperzen/AccessibilityGuard.swift` — `AXIsProcessTrusted()` gate + prompt
- `Hyperzen/AppDelegate.swift` — currently gates all keep-awake on Accessibility
- `Tools/IdleProbe/` — the CLI used to confirm these results
- `.spec/issue_accessibility.md`, `.spec/issue_apple.md`, `.spec/issue_conflict.md`
- `.cursor/skills/tcc/SKILL.md`
- External: `diabler-ie/caffeine-that-keeps-you-active-on-teams-for-mac`,
  AlwaysJiggle, `activity-driver` (claims of permission-free nudges — not
  reproducible on macOS 15.7.1)
