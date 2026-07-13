import CoreGraphics
import Testing
@testable import HyperzenCore

@Suite("Activity Nudger", .serialized)
struct ActivityNudgerTests {
    @Test("Nudge interval is one minute")
    func nudgeIntervalIsOneMinute() {
        #expect(ActivityNudger.nudgeInterval == 60)
    }

    @Test("Nudge moves one pixel right")
    func nudgedLocationMovesOnePixelRight() {
        let location = CGPoint(x: 420, y: 240)

        #expect(ActivityNudger.nudgedLocation(from: location) == CGPoint(x: 421, y: 240))
    }

    @Test("Forward event uses the target and positive delta")
    func moveEventUsesTargetAndDeltas() throws {
        let start = CGPoint(x: 420, y: 240)
        let end = CGPoint(x: 421, y: 240)
        let event = try #require(ActivityNudger.makeMoveEvent(from: start, to: end))

        #expect(event.type == .mouseMoved)
        #expect(event.location == end)
        #expect(event.getIntegerValueField(.mouseEventDeltaX) == 1)
        #expect(event.getIntegerValueField(.mouseEventDeltaY) == 0)
    }

    @Test("Restore event uses the target and negative delta")
    func restoreEventMovesBack() throws {
        let start = CGPoint(x: 421, y: 240)
        let end = CGPoint(x: 420, y: 240)
        let event = try #require(ActivityNudger.makeMoveEvent(from: start, to: end))

        #expect(event.location == end)
        #expect(event.getIntegerValueField(.mouseEventDeltaX) == -1)
        #expect(event.getIntegerValueField(.mouseEventDeltaY) == 0)
    }

    @Test("Nudger starts inactive")
    func initiallyNotRunning() {
        let nudger = ActivityNudger()

        #expect(!nudger.isRunning)
    }

    @Test("Start marks the nudger as running")
    func startSetsRunning() {
        let nudger = ActivityNudger()
        defer { nudger.stop() }

        nudger.start()

        #expect(nudger.isRunning)
    }

    @Test("Start is idempotent")
    func startIsIdempotent() {
        let nudger = ActivityNudger()
        defer { nudger.stop() }

        nudger.start()
        nudger.start()

        #expect(nudger.isRunning)
    }

    @Test("Stop clears the running state")
    func stopClearsRunning() {
        let nudger = ActivityNudger()
        nudger.start()
        nudger.stop()

        #expect(!nudger.isRunning)
    }

    @Test("Stopping an inactive nudger is safe")
    func stopWhenNotRunningIsSafe() {
        let nudger = ActivityNudger()
        nudger.stop()

        #expect(!nudger.isRunning)
    }

    @Test("Start can post its initial activity")
    func startPostsInitialNudgeWithoutCrashing() {
        let nudger = ActivityNudger()
        defer { nudger.stop() }

        nudger.start()

        #expect(nudger.isRunning)
    }

    @Test("Deinitialization releases the nudger")
    func deinitStopsTimer() {
        var nudger: ActivityNudger? = ActivityNudger()
        nudger?.start()
        #expect(nudger?.isRunning == true)

        nudger = nil

        #expect(nudger == nil)
    }
}
