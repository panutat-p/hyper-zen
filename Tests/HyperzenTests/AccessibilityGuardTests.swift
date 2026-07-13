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

    @Test("Permission copy separates Teams activity from keep-awake")
    func permissionCopySeparatesFeatures() {
        #expect(AccessibilityGuard.alertMessage.contains("HyperZen"))
        #expect(AccessibilityGuard.alertMessage.contains("Accessibility"))
        #expect(AccessibilityGuard.alertMessage.contains("keep your Mac awake without"))
        #expect(AccessibilityGuard.alertMessage.contains("Keep Teams Active"))
        #expect(AccessibilityGuard.alertMessage.contains("/Applications/HyperZen.app"))
    }

    @Test("Accessibility URL targets modern System Settings")
    func accessibilitySettingsURLTargetsModernSystemSettings() {
        #expect(
            AccessibilityGuard.accessibilitySettingsURLString.contains("PrivacySecurity.extension")
        )
        #expect(URL(string: AccessibilityGuard.accessibilitySettingsURLString) != nil)
    }

    @Test("Teams activity requirement matches the current trust state")
    func teamsActivityRequirementMatchesTrustState() {
        let expected = AXIsProcessTrusted()
        let actual = AccessibilityGuard.requireAccessForTeamsActivity(presentWarning: false)

        #expect(actual == expected)
    }

    @Test("Repeated permission checks remain stable")
    func repeatedPermissionChecksRemainStable() {
        let expected = AccessibilityGuard.isTrusted

        #expect(AccessibilityGuard.requireAccessForTeamsActivity(presentWarning: false) == expected)
        #expect(AccessibilityGuard.requireAccessForTeamsActivity(presentWarning: false) == expected)
        #expect(AccessibilityGuard.isTrusted == expected)
    }
}
