import Testing
@testable import HyperZen

@Test func versionIsPresent() {
    #expect(!HyperZen.getVersion().isEmpty)
}

@Test func screenSizeIsPositive() {
    let size = HyperZen.screenSize()
    #expect(size.width > 0)
    #expect(size.height > 0)
}

@Test func keyboardKnowsCommonKeys() {
    #expect(HyperZenKeyboard.keyCode(for: "a") != nil)
    #expect(HyperZenKeyboard.keyCode(for: "enter") != nil)
    #expect(HyperZenKeyboard.keyCode(for: "f12") != nil)
}
