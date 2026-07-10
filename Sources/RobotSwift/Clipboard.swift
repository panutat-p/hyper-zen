import AppKit
import Foundation

public enum RobotClipboard {
    public static func read() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    public static func write(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw RobotError.operationFailed("Could not write to the clipboard")
        }
    }
}
