import Testing
@testable import RobotSwift

@Test func versionIsPresent() {
    #expect(!Robot.getVersion().isEmpty)
}

@Test func screenSizeIsPositive() {
    let size = Robot.screenSize()
    #expect(size.width > 0)
    #expect(size.height > 0)
}

@Test func keyboardKnowsCommonKeys() {
    #expect(RobotKeyboard.keyCode(for: "a") != nil)
    #expect(RobotKeyboard.keyCode(for: "enter") != nil)
    #expect(RobotKeyboard.keyCode(for: "f12") != nil)
}
