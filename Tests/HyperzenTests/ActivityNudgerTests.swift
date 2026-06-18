import CoreGraphics
import XCTest
@testable import HyperzenCore

final class ActivityNudgerTests: XCTestCase {
    func testNudgeIntervalIsFiveMinutes() {
        XCTAssertEqual(ActivityNudger.nudgeInterval, 300)
    }

    func testMakeNudgeEventIsMouseMovedAtGivenLocation() {
        let location = CGPoint(x: 420, y: 240)
        let event = ActivityNudger.makeNudgeEvent(at: location)

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, .mouseMoved)
        XCTAssertEqual(event?.location, location)
    }

    func testMakeNudgeEventAtOrigin() {
        let event = ActivityNudger.makeNudgeEvent(at: .zero)

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, .mouseMoved)
        XCTAssertEqual(event?.location, .zero)
    }

    func testInitiallyNotRunning() {
        let nudger = ActivityNudger()
        XCTAssertFalse(nudger.isRunning)
    }

    func testStartSetsRunning() {
        let nudger = ActivityNudger()
        nudger.start()
        XCTAssertTrue(nudger.isRunning)
        nudger.stop()
    }

    func testStartIsIdempotent() {
        let nudger = ActivityNudger()
        nudger.start()
        nudger.start()
        XCTAssertTrue(nudger.isRunning)
        nudger.stop()
    }

    func testStopClearsRunning() {
        let nudger = ActivityNudger()
        nudger.start()
        nudger.stop()
        XCTAssertFalse(nudger.isRunning)
    }

    func testStopWhenNotRunningIsSafe() {
        let nudger = ActivityNudger()
        nudger.stop()
        XCTAssertFalse(nudger.isRunning)
    }

    func testStartPostsInitialNudgeWithoutCrashing() {
        let nudger = ActivityNudger()
        nudger.start()
        XCTAssertTrue(nudger.isRunning)
        nudger.stop()
    }

    func testDeinitStopsTimer() {
        var nudger: ActivityNudger? = ActivityNudger()
        nudger?.start()
        XCTAssertTrue(nudger?.isRunning == true)
        nudger = nil
    }
}
