import CoreGraphics
import Foundation

final class ActivityNudger {
    static let nudgeInterval: TimeInterval = 300

    private var timer: Timer?

    var isRunning: Bool {
        timer != nil
    }

    func start() {
        guard timer == nil else { return }

        nudge()

        let timer = Timer(timeInterval: Self.nudgeInterval, repeats: true) { [weak self] _ in
            self?.nudge()
        }
        timer.tolerance = Self.nudgeInterval * 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }

    /// Builds the zero-distance mouse-move event used to reset the HID idle timer.
    static func makeNudgeEvent(at location: CGPoint) -> CGEvent? {
        let source = CGEventSource(stateID: .hidSystemState)
        return CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: location,
            mouseButton: .left
        )
    }

    private func nudge() {
        let location = CGEvent(source: nil)?.location ?? .zero
        guard let move = Self.makeNudgeEvent(at: location) else {
            return
        }

        move.post(tap: .cghidEventTap)
    }
}
