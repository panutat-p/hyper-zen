import ApplicationServices
import Testing
@testable import HyperzenCore

@Suite("Accessibility Guard")
struct AccessibilityGuardTests {
    @Test("Trust state matches macOS")
    func trustStateMatchesMacOS() {
        #expect(AccessibilityGuard.isTrusted == AXIsProcessTrusted())
    }

    @Test("Missing-access alert explains the available actions")
    @MainActor
    func missingAccessAlertContent() {
        let alert = AccessibilityGuard.makeMissingAccessAlert()

        #expect(alert.alertStyle == .warning)
        #expect(alert.messageText == AccessibilityGuard.alertTitle)
        #expect(alert.informativeText == AccessibilityGuard.alertMessage)
        #expect(alert.buttons.map(\.title) == [
            AccessibilityGuard.openSettingsButtonTitle,
            AccessibilityGuard.dismissButtonTitle,
        ])
    }

    @Test("Permission copy explains On needs Accessibility for the input nudge")
    func permissionCopyExplainsOnNudge() {
        #expect(AccessibilityGuard.alertMessage.contains("HyperZen"))
        #expect(AccessibilityGuard.alertMessage.contains("Accessibility"))
        #expect(AccessibilityGuard.alertMessage.contains("Power assertions"))
        #expect(AccessibilityGuard.alertMessage.contains("input nudge"))
        #expect(AccessibilityGuard.alertMessage.contains("/Applications/HyperZen.app"))
    }

    @Test("Accessibility URL targets modern System Settings")
    func accessibilitySettingsURLTargetsModernSystemSettings() {
        #expect(
            AccessibilityGuard.accessibilitySettingsURLString.contains("PrivacySecurity.extension")
        )
        #expect(URL(string: AccessibilityGuard.accessibilitySettingsURLString) != nil)
    }

    @Test("Activity requirement matches the current trust state")
    func activityRequirementMatchesTrustState() {
        let expected = AXIsProcessTrusted()
        let actual = AccessibilityGuard.requireAccessForActivity(presentWarning: false)

        #expect(actual == expected)
    }

    @Test("Repeated permission checks remain stable")
    func repeatedPermissionChecksRemainStable() {
        let expected = AccessibilityGuard.isTrusted

        #expect(AccessibilityGuard.requireAccessForActivity(presentWarning: false) == expected)
        #expect(AccessibilityGuard.requireAccessForActivity(presentWarning: false) == expected)
        #expect(AccessibilityGuard.isTrusted == expected)
    }
}
