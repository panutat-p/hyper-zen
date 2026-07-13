import AppKit
import Testing
@testable import HyperzenCore

@Suite("Menu Popup Placement")
struct MenuPopupPlacementTests {
    private let visibleFrame = NSRect(x: 0, y: 32, width: 1_000, height: 700)
    private let menuSize = NSSize(width: 240, height: 280)

    @Test("An edge click opens the menu inside the visible frame")
    func edgeClickRaisesMenu() {
        let point = MenuPopupPlacement.point(
            cursor: NSPoint(x: 500, y: 12),
            menuSize: menuSize,
            visibleFrame: visibleFrame
        )

        #expect(point == NSPoint(x: 500, y: 312))
    }

    @Test("The menu is clamped horizontally to the active screen")
    func clampsHorizontalPosition() {
        let point = MenuPopupPlacement.point(
            cursor: NSPoint(x: 980, y: 500),
            menuSize: menuSize,
            visibleFrame: visibleFrame
        )

        #expect(point == NSPoint(x: 760, y: 500))
    }

    @Test("The menu never anchors above the visible screen")
    func clampsVerticalPosition() {
        let point = MenuPopupPlacement.point(
            cursor: NSPoint(x: 400, y: 900),
            menuSize: menuSize,
            visibleFrame: visibleFrame
        )

        #expect(point == NSPoint(x: 400, y: 732))
    }
}
