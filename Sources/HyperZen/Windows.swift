import AppKit
import CoreGraphics
import Foundation

public enum HyperZenWindows {
    public static func activeApplicationPID() -> Int32? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    public static func activeApplicationName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    public static func list() -> [HyperZenWindow] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return info.compactMap { window in
            guard let id = window[kCGWindowNumber as String] as? UInt32,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                return nil
            }

            let title = window[kCGWindowName as String] as? String ?? ""
            let width = Int(bounds.width.rounded())
            let height = Int(bounds.height.rounded())
            guard width > 1, height > 1 else {
                return nil
            }

            return HyperZenWindow(
                id: id,
                ownerPID: ownerPID,
                ownerName: ownerName,
                title: title,
                bounds: HyperZenRect(bounds)
            )
        }
    }

    public static func windows(forPID pid: Int32) -> [HyperZenWindow] {
        list().filter { $0.ownerPID == pid }
    }

    public static func title(pid: Int32? = nil) -> String? {
        let targetPID = pid ?? activeApplicationPID()
        guard let targetPID else {
            return nil
        }
        return windows(forPID: targetPID).first?.title
    }

    public static func bounds(pid: Int32? = nil) -> HyperZenRect? {
        let targetPID = pid ?? activeApplicationPID()
        guard let targetPID else {
            return nil
        }
        return windows(forPID: targetPID).first?.bounds
    }

    @discardableResult
    public static func activate(pid: Int32) throws -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            throw HyperZenError.notFound("Process \(pid) was not found")
        }
        return app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    public static func alert(title: String, message: String, primaryButton: String = "OK", alternateButton: String? = nil) -> Bool {
        let buttons: String
        if let alternateButton {
            buttons = "{\"\(escapeAppleScript(primaryButton))\", \"\(escapeAppleScript(alternateButton))\"}"
        } else {
            buttons = "{\"\(escapeAppleScript(primaryButton))\"}"
        }

        let script = """
        display dialog "\(escapeAppleScript(message))" with title "\(escapeAppleScript(title))" buttons \(buttons) default button 1
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
