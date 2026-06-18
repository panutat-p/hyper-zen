import AppKit
import ApplicationServices

/// Verifies that HyperZen has been granted macOS Accessibility (TCC) access.
///
/// HyperZen posts synthetic HID events via `CGEvent` to reset the idle timer,
/// which macOS only permits for apps trusted in
/// System Settings ▸ Privacy & Security ▸ Accessibility. Without that grant the
/// nudges silently fail, so the app refuses to run in a half-working state.
enum AccessibilityGuard {
    static let alertTitle = "Accessibility Permission Required"
    static let openSettingsButtonTitle = "Open System Settings"
    static let quitButtonTitle = "Quit"
    static let accessibilitySettingsURLString =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    static let alertMessage = """
    HyperZen needs Accessibility access to keep your Mac awake by simulating \
    user activity.

    Open System Settings ▸ Privacy & Security ▸ Accessibility, enable \
    HyperZen, then launch it again.
    """

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Returns `true` when Accessibility is granted. Otherwise presents a
    /// blocking error modal and terminates the app, returning `false`.
    @discardableResult
    static func enforce() -> Bool {
        if isTrusted { return true }

        presentMissingAccessAlert()
        NSApp.terminate(nil)
        return false
    }

    static func makeMissingAccessAlert() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = alertTitle
        alert.informativeText = alertMessage
        alert.addButton(withTitle: openSettingsButtonTitle)
        alert.addButton(withTitle: quitButtonTitle)
        return alert
    }

    private static func presentMissingAccessAlert() {
        // A menu bar (LSUIElement) app is not active by default, so the modal
        // would otherwise open behind other windows.
        NSApp.activate(ignoringOtherApps: true)

        let alert = makeMissingAccessAlert()

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private static func openAccessibilitySettings() {
        if let url = URL(string: accessibilitySettingsURLString) {
            NSWorkspace.shared.open(url)
        }
    }
}
