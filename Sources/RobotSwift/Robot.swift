import Foundation

public enum Robot {
    public static let version = "0.1.0"

    public static func sleep(seconds: Int) {
        Thread.sleep(forTimeInterval: TimeInterval(seconds))
    }

    public static func milliSleep(_ milliseconds: Int) {
        Thread.sleep(forTimeInterval: TimeInterval(milliseconds) / 1000.0)
    }

    public static func getVersion() -> String {
        version
    }

    public static func location() -> RobotPoint {
        RobotMouse.location()
    }

    public static func move(x: Int, y: Int) {
        RobotMouse.move(x: x, y: y)
    }

    public static func click(_ button: MouseButton = .left, doubleClick: Bool = false) {
        RobotMouse.click(button, doubleClick: doubleClick)
    }

    public static func keyTap(_ key: String, modifiers: [String] = []) throws {
        try RobotKeyboard.keyTap(key, modifiers: modifiers)
    }

    public static func typeText(_ text: String, delay: TimeInterval = 0) {
        RobotKeyboard.typeText(text, delay: delay)
    }

    public static func readClipboard() -> String {
        RobotClipboard.read()
    }

    public static func writeClipboard(_ text: String) throws {
        try RobotClipboard.write(text)
    }

    public static func screenSize() -> RobotSize {
        RobotScreen.screenSize()
    }
}
