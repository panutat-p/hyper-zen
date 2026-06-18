import ApplicationServices
import XCTest
@testable import HyperzenCore

final class AccessibilityGuardTests: XCTestCase {
    func testIsTrustedMatchesAXIsProcessTrusted() {
        XCTAssertEqual(AccessibilityGuard.isTrusted, AXIsProcessTrusted())
    }

    func testMissingAccessAlertContent() {
        let alert = AccessibilityGuard.makeMissingAccessAlert()

        XCTAssertEqual(alert.alertStyle, .critical)
        XCTAssertEqual(alert.messageText, AccessibilityGuard.alertTitle)
        XCTAssertEqual(alert.informativeText, AccessibilityGuard.alertMessage)
        XCTAssertEqual(alert.buttons.map(\.title), [
            AccessibilityGuard.openSettingsButtonTitle,
            AccessibilityGuard.quitButtonTitle,
        ])
    }

    func testAlertMessageExplainsAccessibilityRequirement() {
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("HyperZen"))
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("Accessibility"))
        XCTAssertTrue(AccessibilityGuard.alertMessage.contains("System Settings"))
    }

    func testAccessibilitySettingsURLIsValid() {
        XCTAssertNotNil(URL(string: AccessibilityGuard.accessibilitySettingsURLString))
    }

    func testEnforceReturnsTrueWhenProcessIsTrusted() throws {
        guard AccessibilityGuard.isTrusted else {
            throw XCTSkip("Test runner does not have Accessibility permission")
        }

        XCTAssertTrue(AccessibilityGuard.enforce())
    }
}
