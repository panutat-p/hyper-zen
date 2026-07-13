import AppKit
import ApplicationServices

/// Verifies that HyperZen has been granted macOS Accessibility (TCC) access.
/// Keep-awake power assertions work without this permission; only Teams
/// activity needs it because that feature posts synthetic HID events.
enum AccessibilityGuard {
    static let alertTitle = "Accessibility Permission Required"
    static let openSettingsButtonTitle = "Open System Settings"
    static let dismissButtonTitle = "OK"
    static let accessibilitySettingsURLString =
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"

    static let alertMessage = """
    HyperZen can keep your Mac awake without Accessibility access. Accessibility \
    is only required for Keep Teams Active.

    Open System Settings ▸ Privacy & Security ▸ Accessibility, enable \
    HyperZen, then return to the app. Teams activity will start automatically.

    If HyperZen is already listed, remove it with − and add \
    /Applications/HyperZen.app again. App updates can invalidate an existing \
    approval.
    """

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the standard macOS prompt that offers to open Accessibility settings.
    static func requestSystemPrompt() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Re-checks permission for Teams activity. When still denied, presents
    /// `showAccessRequiredWarning()` before returning `false` unless
    /// `presentWarning` is `false` (used by unit tests).
    @discardableResult
    static func requireAccessForTeamsActivity(presentWarning: Bool = true) -> Bool {
        if isTrusted { return true }

        requestSystemPrompt()
        if isTrusted { return true }

        if presentWarning {
            showAccessRequiredWarning()
        }
        return false
    }

    static func makeMissingAccessAlert() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = alertTitle
        alert.informativeText = alertMessage
        alert.addButton(withTitle: openSettingsButtonTitle)
        alert.addButton(withTitle: dismissButtonTitle)
        return alert
    }

    static func showAccessRequiredWarning() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = makeMissingAccessAlert()
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: accessibilitySettingsURLString) {
            NSWorkspace.shared.open(url)
        }
    }
}
