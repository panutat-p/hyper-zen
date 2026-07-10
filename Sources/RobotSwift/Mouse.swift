import CoreGraphics
import Foundation

public enum MouseButton: String, CaseIterable, Sendable {
    case left
    case right
    case center
    case middle

    var cgButton: CGMouseButton {
        switch self {
        case .left:
            .left
        case .right:
            .right
        case .center, .middle:
            .center
        }
    }

    var downEvent: CGEventType {
        switch self {
        case .left:
            .leftMouseDown
        case .right:
            .rightMouseDown
        case .center, .middle:
            .otherMouseDown
        }
    }

    var upEvent: CGEventType {
        switch self {
        case .left:
            .leftMouseUp
        case .right:
            .rightMouseUp
        case .center, .middle:
            .otherMouseUp
        }
    }

    var draggedEvent: CGEventType {
        switch self {
        case .left:
            .leftMouseDragged
        case .right:
            .rightMouseDragged
        case .center, .middle:
            .otherMouseDragged
        }
    }
}

public enum RobotMouse {
    public static var eventSource: CGEventSource? {
        CGEventSource(stateID: .hidSystemState)
    }

    public static func location() -> RobotPoint {
        let point = CGEvent(source: eventSource)?.location ?? .zero
        return RobotPoint(x: Int(point.x.rounded()), y: Int(point.y.rounded()))
    }

    public static func move(to point: RobotPoint) {
        postMouse(type: .mouseMoved, at: point.cgPoint, button: .left)
    }

    public static func move(x: Int, y: Int) {
        move(to: RobotPoint(x: x, y: y))
    }

    public static func moveRelative(dx: Int, dy: Int) {
        let current = location()
        move(x: current.x + dx, y: current.y + dy)
    }

    @discardableResult
    public static func moveSmooth(to point: RobotPoint, duration: TimeInterval = 0.35, steps: Int = 40) -> Bool {
        let start = location()
        let clampedSteps = max(1, steps)
        let sleepSeconds = max(0, duration) / Double(clampedSteps)

        for step in 1...clampedSteps {
            let progress = Double(step) / Double(clampedSteps)
            let eased = progress * progress * (3 - 2 * progress)
            let x = Double(start.x) + (Double(point.x - start.x) * eased)
            let y = Double(start.y) + (Double(point.y - start.y) * eased)
            move(x: Int(x.rounded()), y: Int(y.rounded()))
            if sleepSeconds > 0 {
                Thread.sleep(forTimeInterval: sleepSeconds)
            }
        }

        return true
    }

    public static func click(_ button: MouseButton = .left, doubleClick: Bool = false) {
        let point = location()
        let count = doubleClick ? 2 : 1

        for clickIndex in 1...count {
            postMouse(type: button.downEvent, at: point.cgPoint, button: button.cgButton, clickState: Int64(clickIndex))
            postMouse(type: button.upEvent, at: point.cgPoint, button: button.cgButton, clickState: Int64(clickIndex))
            if doubleClick && clickIndex == 1 {
                Thread.sleep(forTimeInterval: 0.08)
            }
        }
    }

    public static func moveClick(x: Int, y: Int, button: MouseButton = .left, doubleClick: Bool = false) {
        move(x: x, y: y)
        click(button, doubleClick: doubleClick)
    }

    public static func mouseDown(_ button: MouseButton = .left) {
        postMouse(type: button.downEvent, at: location().cgPoint, button: button.cgButton)
    }

    public static func mouseUp(_ button: MouseButton = .left) {
        postMouse(type: button.upEvent, at: location().cgPoint, button: button.cgButton)
    }

    public static func drag(to point: RobotPoint, button: MouseButton = .left, duration: TimeInterval = 0.2, steps: Int = 25) {
        let start = location()
        let clampedSteps = max(1, steps)
        let sleepSeconds = max(0, duration) / Double(clampedSteps)
        mouseDown(button)

        for step in 1...clampedSteps {
            let progress = Double(step) / Double(clampedSteps)
            let x = Double(start.x) + (Double(point.x - start.x) * progress)
            let y = Double(start.y) + (Double(point.y - start.y) * progress)
            postMouse(type: button.draggedEvent, at: CGPoint(x: x, y: y), button: button.cgButton)
            if sleepSeconds > 0 {
                Thread.sleep(forTimeInterval: sleepSeconds)
            }
        }

        postMouse(type: button.upEvent, at: point.cgPoint, button: button.cgButton)
    }

    public static func scroll(dx: Int = 0, dy: Int) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: eventSource,
            units: .line,
            wheelCount: 2,
            wheel1: Int32(dy),
            wheel2: Int32(dx),
            wheel3: 0
        ) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }

    private static func postMouse(type: CGEventType, at point: CGPoint, button: CGMouseButton, clickState: Int64 = 1) {
        guard let event = CGEvent(mouseEventSource: eventSource, mouseType: type, mouseCursorPosition: point, mouseButton: button) else {
            return
        }
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        event.post(tap: .cghidEventTap)
    }
}
