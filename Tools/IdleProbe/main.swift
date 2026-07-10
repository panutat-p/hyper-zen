import ApplicationServices
import CoreGraphics
import Foundation

// idle-probe: confirms whether synthetic CGEvents reset the macOS HID idle
// timer (the value Microsoft Teams / Slack use to decide "Away") and whether
// doing so requires Accessibility (TCC) permission.
//
// Usage:
//   idle-probe            One-shot test: mouse-move, scroll, and keyboard.
//   idle-probe watch      Nudge every 30s forever; open Teams and watch status.
//   idle-probe watch 15   Same, but nudge every 15s.
//
// Methodology:
//   - Run from a Accessibility-TRUSTED process (e.g. Cursor terminal) to test
//     the POSITIVE direction (events should reset idle).
//   - Run from an UN-trusted process (e.g. stock Terminal.app with no
//     Accessibility grant) to test the NEGATIVE direction.
//   - AXIsProcessTrusted() is reported in the header so you always know which
//     case you are in.

let anyInputEventType = CGEventType(rawValue: ~0)!

func idleSeconds() -> Double {
    CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInputEventType)
}

func cursorLocation() -> CGPoint {
    CGEvent(source: nil)?.location ?? .zero
}

func postMouseMove() {
    let src = CGEventSource(stateID: .hidSystemState)
    let loc = cursorLocation()
    CGEvent(
        mouseEventSource: src,
        mouseType: .mouseMoved,
        mouseCursorPosition: loc,
        mouseButton: .left
    )?.post(tap: .cghidEventTap)
}

func postScroll() {
    let src = CGEventSource(stateID: .hidSystemState)
    // A zero-delta scroll is invisible but still counts as HID input.
    CGEvent(
        scrollWheelEvent2Source: src,
        units: .pixel,
        wheelCount: 1,
        wheel1: 0,
        wheel2: 0,
        wheel3: 0
    )?.post(tap: .cghidEventTap)
}

func postKeyboard() {
    // Left Shift (keyCode 56) is a modifier: it counts as HID input but types
    // no character, so it has no side effect on the focused app.
    let src = CGEventSource(stateID: .hidSystemState)
    let shift: CGKeyCode = 56
    CGEvent(keyboardEventSource: src, virtualKey: shift, keyDown: true)?.post(tap: .cghidEventTap)
    CGEvent(keyboardEventSource: src, virtualKey: shift, keyDown: false)?.post(tap: .cghidEventTap)
}

func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

func printHeader() {
    let trusted = AXIsProcessTrusted()
    print("== idle-probe ==")
    print("macOS HID idle timer = what Teams/Slack read to flip you to \"Away\".")
    print("AXIsProcessTrusted (Accessibility granted to this process): \(trusted ? "YES" : "NO")")
    if trusted {
        print("""
        NOTE: This process is Accessibility-TRUSTED (it inherited the grant from
              the terminal/IDE that launched it). To prove the NO-Accessibility
              case, run this binary from a Terminal that is NOT in
              System Settings > Privacy & Security > Accessibility.
        """)
    } else {
        print("NOTE: This process is NOT Accessibility-trusted — a clean test of the no-permission path.")
    }
    print("")
}

// Waits (polling) until the idle timer climbs above `threshold`, so the result
// isn't confounded by the user touching the mouse/keyboard. Returns the idle
// value reached, or nil on timeout.
func waitForIdle(above threshold: Double, timeout: Double) -> Double? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        let i = idleSeconds()
        if i >= threshold { return i }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return nil
}

func runResetTest(label: String, threshold: Double, nudge: () -> Void) {
    print("[\(label)] Keep your hands OFF the mouse & keyboard...")
    guard let before = waitForIdle(above: threshold, timeout: 30) else {
        print("[\(label)] Idle never climbed above \(fmt(threshold))s (input detected). Skipped.\n")
        return
    }
    print("[\(label)] idle reached \(fmt(before))s -> posting nudge")
    nudge()
    Thread.sleep(forTimeInterval: 0.25)
    let after = idleSeconds()
    print("[\(label)] idle after nudge: \(fmt(after))s")
    if after < before - 0.5 {
        print("[\(label)] RESULT: nudge RESET the idle timer  ✅\n")
    } else {
        print("[\(label)] RESULT: nudge did NOT reset the idle timer  ❌\n")
    }
}

func runWatch(interval: Double) {
    print("Watching: posting a mouse-move + scroll nudge every \(fmt(interval))s.")
    print("Open Microsoft Teams and confirm your status stays \"Available\".")
    print("Press Ctrl+C to stop.\n")
    while true {
        postMouseMove()
        postScroll()
        let stamp = ISO8601DateFormatter().string(from: Date())
        print("\(stamp)  nudged  | idle now: \(fmt(idleSeconds()))s | trusted: \(AXIsProcessTrusted() ? "YES" : "NO")")
        Thread.sleep(forTimeInterval: interval)
    }
}

// MARK: - Entry

let args = Array(CommandLine.arguments.dropFirst())
printHeader()

if args.first == "watch" {
    let interval = args.count > 1 ? (Double(args[1]) ?? 30) : 30
    runWatch(interval: interval)
} else {
    runResetTest(label: "mouse-move", threshold: 3.0, nudge: postMouseMove)
    runResetTest(label: "scroll", threshold: 3.0, nudge: postScroll)
    runResetTest(label: "keyboard", threshold: 3.0, nudge: postKeyboard)
    print("Done. Interpretation:")
    print(" - trusted=YES + RESET ✅  -> synthetic input DOES reset the idle timer (Teams stays active) WHEN Accessibility is granted.")
    print(" - trusted=NO  + RESET ✅  -> nudges work WITHOUT Accessibility (both problems solvable).")
    print(" - trusted=NO  + NOT reset ❌ -> Accessibility is required for nudges (confirmed on macOS 15).")
}
