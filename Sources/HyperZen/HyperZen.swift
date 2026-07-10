import Foundation

public enum HyperZen {
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

    public static func location() -> HyperZenPoint {
        HyperZenMouse.location()
    }

    public static func move(x: Int, y: Int) {
        HyperZenMouse.move(x: x, y: y)
    }

    public static func click(_ button: MouseButton = .left, doubleClick: Bool = false) {
        HyperZenMouse.click(button, doubleClick: doubleClick)
    }

    public static func keyTap(_ key: String, modifiers: [String] = []) throws {
        try HyperZenKeyboard.keyTap(key, modifiers: modifiers)
    }

    public static func typeText(_ text: String, delay: TimeInterval = 0) {
        HyperZenKeyboard.typeText(text, delay: delay)
    }

    public static func readClipboard() -> String {
        HyperZenClipboard.read()
    }

    public static func writeClipboard(_ text: String) throws {
        try HyperZenClipboard.write(text)
    }

    public static func screenSize() -> HyperZenSize {
        HyperZenScreen.screenSize()
    }
}
