import ApplicationServices
import XCTest
@testable import HyperzenCore

final class AccessibilityGuardTests: XCTestCase {
    func testIsTrustedMatchesAXIsProcessTrusted() {
        XCTAssertEqual(AccessibilityGuard.isTrusted, AXIsProcessTrusted())
    }

    func testMissingAccessAlertContent() {
        let alert = AccessibilityGuard.makeMissingAccessAlert()

        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertEqual(alert.messageText, AccessibilityGuard.alertTitle)
        XCTAssertEqual(alert.informativeText, AccessibilityGuard.alertMessage)
        XCTAssertEqual(alert.buttons.map(\.title), [
            AccessibilityGuard.openSettingsButtonTitle,
            AccessibilityGuard.dismissButtonTitle,
        ])
    }

    func testAlertMessageExplainsKeepAwakeRequiresAccessibility() {
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("HyperZen"))
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("Accessibility"))
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("keep-awake"))
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("Enable Keep Awake"))
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("/Applications/HyperZen.app"))
    }

    func testAccessibilitySettingsURLTargetsModernSystemSettings() {
        XCTAssertTrue(
            AccessibilityGuard.accessibilitySettingsURLString.contains("PrivacySecurity.extension")
        )
        XCTAssertNotNil(URL(string: AccessibilityGuard.accessibilitySettingsURLString))
    }

    func testRequestSystemPromptDoesNotCrash() {
        AccessibilityGuard.requestSystemPrompt()
    }

    func testRequireAccessForKeepAwakeReturnsTrueWhenProcessIsTrusted() throws {
        guard AccessibilityGuard.isTrusted else {
            throw XCTSkip("Test runner does not have Accessibility permission")
        }

        XCTAssertTrue(AccessibilityGuard.requireAccessForKeepAwake(presentWarning: false))
        XCTAssertTrue(AccessibilityGuard.requireAccessForKeepAwake())
    }

    func testRequireAccessForKeepAwakeReturnsFalseWhenProcessIsUntrusted() throws {
        guard !AccessibilityGuard.isTrusted else {
            throw XCTSkip("Test runner has Accessibility permission")
        }

        XCTAssertFalse(AccessibilityGuard.requireAccessForKeepAwake(presentWarning: false))
    }

    func testRequireAccessForKeepAwakeShortCircuitsWhenAlreadyTrusted() throws {
        guard AccessibilityGuard.isTrusted else {
            throw XCTSkip("Test runner does not have Accessibility permission")
        }

        XCTAssertTrue(AccessibilityGuard.isTrusted)
        XCTAssertTrue(AccessibilityGuard.requireAccessForKeepAwake(presentWarning: false))
        XCTAssertTrue(AccessibilityGuard.isTrusted)
    }
}
