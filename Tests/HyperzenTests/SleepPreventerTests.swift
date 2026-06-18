import XCTest
@testable import HyperzenCore

final class SleepPreventerTests: XCTestCase {
    func testInitiallyDisabled() {
        let preventer = SleepPreventer()
        XCTAssertFalse(preventer.isEnabled)
    }

    func testEnableSetsEnabled() throws {
        let preventer = SleepPreventer()
        try preventer.enable()
        XCTAssertTrue(preventer.isEnabled)
        preventer.disable()
    }

    func testEnableIsIdempotent() throws {
        let preventer = SleepPreventer()
        try preventer.enable()
        try preventer.enable()
        XCTAssertTrue(preventer.isEnabled)
        preventer.disable()
    }

    func testDisableClearsEnabled() throws {
        let preventer = SleepPreventer()
        try preventer.enable()
        preventer.disable()
        XCTAssertFalse(preventer.isEnabled)
    }

    func testDisableWhenAlreadyDisabledIsSafe() {
        let preventer = SleepPreventer()
        preventer.disable()
        XCTAssertFalse(preventer.isEnabled)
    }

    func testToggleEnablesAndDisables() throws {
        let preventer = SleepPreventer()
        try preventer.toggle()
        XCTAssertTrue(preventer.isEnabled)
        try preventer.toggle()
        XCTAssertFalse(preventer.isEnabled)
    }
}
