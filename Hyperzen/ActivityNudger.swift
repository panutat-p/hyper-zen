import CoreGraphics
import Foundation
import IOKit.pwr_mgt

final class ActivityNudger {
    static let nudgeInterval: TimeInterval = 60
    static let restoreDelay: TimeInterval = 0.05

    private var timer: Timer?
    private var restoreWorkItem: DispatchWorkItem?
    private var userActivityAssertionID = IOPMAssertionID(0)

    var isRunning: Bool {
        timer != nil
    }

    func start() {
        guard timer == nil else { return }

        nudge()

        let timer = Timer(timeInterval: Self.nudgeInterval, repeats: true) { [weak self] _ in
            self?.nudge()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        restoreWorkItem?.cancel()
        restoreWorkItem = nil

        if userActivityAssertionID != 0 {
            IOPMAssertionRelease(userActivityAssertionID)
            userActivityAssertionID = 0
        }
    }

    deinit {
        stop()
    }

    static func nudgedLocation(from location: CGPoint) -> CGPoint {
        CGPoint(x: location.x + 1, y: location.y)
    }

    /// Builds a real mouse movement with matching HID delta fields. Teams and
    /// similar collaboration apps can ignore zero-distance mouse events.
    static func makeMoveEvent(
        from previousLocation: CGPoint,
        to location: CGPoint,
        source: CGEventSource? = CGEventSource(stateID: .hidSystemState)
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: location,
            mouseButton: .left
        ) else {
            return nil
        }

        event.setIntegerValueField(
            .mouseEventDeltaX,
            value: Int64((location.x - previousLocation.x).rounded())
        )
        event.setIntegerValueField(
            .mouseEventDeltaY,
            value: Int64((location.y - previousLocation.y).rounded())
        )
        return event
    }

    private func nudge() {
        declareUserActivity()

        guard let source = CGEventSource(stateID: .hidSystemState),
              let currentLocation = CGEvent(source: source)?.location
        else {
            return
        }

        let nudgedLocation = Self.nudgedLocation(from: currentLocation)
        Self.makeMoveEvent(
            from: currentLocation,
            to: nudgedLocation,
            source: source
        )?.post(tap: .cghidEventTap)

        restoreWorkItem?.cancel()
        let restore = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isRunning,
                  let restoreSource = CGEventSource(stateID: .hidSystemState),
                  let observedLocation = CGEvent(source: restoreSource)?.location,
                  observedLocation == nudgedLocation
            else {
                return
            }

            Self.makeMoveEvent(
                from: nudgedLocation,
                to: currentLocation,
                source: restoreSource
            )?.post(tap: .cghidEventTap)
            self.restoreWorkItem = nil
        }
        restoreWorkItem = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay, execute: restore)
    }

    private func declareUserActivity() {
        let result = IOPMAssertionDeclareUserActivity(
            "HyperZen Teams activity" as CFString,
            kIOPMUserActiveLocal,
            &userActivityAssertionID
        )

        if result != kIOReturnSuccess {
            NSLog("HyperZen could not declare user activity (result: %d)", result)
        }
    }
}
