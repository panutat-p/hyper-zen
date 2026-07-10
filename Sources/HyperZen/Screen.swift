import AppKit
import CoreGraphics
import Foundation

public enum HyperZenScreen {
    public static func displayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else {
            return []
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return displays
    }

    public static func mainDisplayID() -> CGDirectDisplayID {
        CGMainDisplayID()
    }

    public static func mainDisplayIndex() -> Int {
        displayIDs().firstIndex(of: mainDisplayID()) ?? 0
    }

    public static func displayCount() -> Int {
        displayIDs().count
    }

    public static func displayRect(_ index: Int = 0) throws -> HyperZenRect {
        let displays = displayIDs()
        guard displays.indices.contains(index) else {
            throw HyperZenError.notFound("Display index \(index) was not found")
        }
        return HyperZenRect(CGDisplayBounds(displays[index]))
    }

    public static func screenSize() -> HyperZenSize {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        return HyperZenSize(width: Int(bounds.width), height: Int(bounds.height))
    }

    public static func scale(displayIndex: Int = 0) -> Double {
        guard displayIDs().indices.contains(displayIndex) else {
            return Double(NSScreen.main?.backingScaleFactor ?? 1.0)
        }
        let displayID = displayIDs()[displayIndex]
        for screen in NSScreen.screens {
            if let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               screenID.uint32Value == displayID {
                return Double(screen.backingScaleFactor)
            }
        }
        return 1.0
    }
}
