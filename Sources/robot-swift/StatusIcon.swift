import AppKit
import CoreGraphics
import Foundation
import IOKit.pwr_mgt
import RobotSwift

@MainActor
private var statusIconDelegate: StatusIconAppDelegate?

@MainActor
final class StatusIconAppDelegate: NSObject, NSApplicationDelegate {
    private let activityInterval: TimeInterval = 60
    private let powerAssertions = PowerAssertionController()
    private var statusItem: NSStatusItem?
    private var accessibilityStatusItem: NSMenuItem?
    private var activityTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        powerAssertions.start()
        startUserActivity()
        observePowerRelatedNotifications()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: "robot-swift is running") {
                let sizeConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                let colorConfiguration = NSImage.SymbolConfiguration(paletteColors: [.systemYellow, .systemOrange])
                let symbolConfiguration = sizeConfiguration.applying(colorConfiguration)
                let colorImage = image.withSymbolConfiguration(symbolConfiguration) ?? image
                colorImage.isTemplate = false
                button.image = colorImage
            } else {
                button.title = "R"
            }
            button.toolTip = "robot-swift is running in Terminal"
        }

        let menu = NSMenu()
        addDisabledItem("robot-swift is running", to: menu)
        addDisabledItem("PID \(ProcessInfo.processInfo.processIdentifier)", to: menu)
        addDisabledItem("Power Assertions: \(powerAssertions.statusText)", to: menu)
        addDisabledItem("Input nudge: Every \(Int(activityInterval)) seconds", to: menu)
        let accessibilityItem = addDisabledItem(accessibilityStatusText, to: menu)
        accessibilityStatusItem = accessibilityItem
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        menu.delegate = self
        statusItem = item
    }

    func applicationWillTerminate(_ notification: Notification) {
        activityTimer?.invalidate()
        activityTimer = nil
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        notificationObservers.removeAll()
        powerAssertions.stop()
    }

    private func startUserActivity() {
        declareUserActivity()
        activityTimer = Timer.scheduledTimer(withTimeInterval: activityInterval, repeats: true) { _ in
            Task { @MainActor in
                declareUserActivity()
            }
        }
    }

    private func observePowerRelatedNotifications() {
        notificationObservers = [
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    Task { @MainActor in
                        self?.handlePowerRelatedNotification()
                    }
                }
            ),
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    Task { @MainActor in
                        self?.handlePowerRelatedNotification()
                    }
                }
            )
        ]
    }

    private func handlePowerRelatedNotification() {
        powerAssertions.ensureActive()
        declareUserActivity()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private var accessibilityStatusText: String {
        "Accessibility: \(RobotPermissions.isAccessibilityTrusted ? "Allowed" : "Required for Teams presence")"
    }

    @discardableResult
    private func addDisabledItem(_ title: String, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        return item
    }
}

extension StatusIconAppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        accessibilityStatusItem?.title = accessibilityStatusText
    }
}

@MainActor
private final class PowerAssertionController {
    private var systemSleepAssertionID = IOPMAssertionID(0)
    private var displaySleepAssertionID = IOPMAssertionID(0)

    var statusText: String {
        systemSleepAssertionID != 0 && displaySleepAssertionID != 0 ? "Enabled" : "Unavailable"
    }

    func start() {
        ensureActive()
    }

    func ensureActive() {
        if systemSleepAssertionID == 0 {
            systemSleepAssertionID = createAssertion(
                type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                name: "robot-swift status-icon keep system awake"
            )
        }

        if displaySleepAssertionID == 0 {
            displaySleepAssertionID = createAssertion(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                name: "robot-swift status-icon keep display awake"
            )
        }
    }

    func stop() {
        releaseAssertion(&systemSleepAssertionID)
        releaseAssertion(&displaySleepAssertionID)
    }

    private func createAssertion(type: CFString, name: String) -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &assertionID
        )

        if result != kIOReturnSuccess {
            return 0
        }

        return assertionID
    }

    private func releaseAssertion(_ assertionID: inout IOPMAssertionID) {
        guard assertionID != 0 else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}

@MainActor
private var userActivityAssertionID = IOPMAssertionID(0)

@MainActor
private func declareUserActivity() {
    let result = IOPMAssertionDeclareUserActivity(
        "robot-swift status-icon user activity" as CFString,
        kIOPMUserActiveLocal,
        &userActivityAssertionID
    )

    // The power assertion keeps macOS awake, but collaboration apps such as
    // Microsoft Teams determine presence from input events.  Always send a
    // tiny move-and-return event, not merely when the IOKit call fails.
    postSyntheticActivity()

    if result != kIOReturnSuccess {
        NSLog("robot-swift could not declare IOKit user activity (result: %d)", result)
    }
}

private func postSyntheticActivity() {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let current = CGEvent(source: source)?.location else {
        return
    }

    let nudged = CGPoint(x: current.x + 1, y: current.y)
    postMouseMove(to: nudged, from: current, source: source)

    // Match the RobotGo helper's short move-and-return behavior while avoiding
    // moving the pointer back over a real user movement made in the meantime.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        guard let restoreSource = CGEventSource(stateID: .hidSystemState),
              let location = CGEvent(source: restoreSource)?.location,
              location == nudged else {
            return
        }
        postMouseMove(to: current, from: nudged, source: restoreSource)
    }
}

private func postMouseMove(to point: CGPoint, from previousPoint: CGPoint, source: CGEventSource) {
    guard let event = CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        return
    }

    event.setIntegerValueField(.mouseEventDeltaX, value: Int64(point.x - previousPoint.x))
    event.setIntegerValueField(.mouseEventDeltaY, value: Int64(point.y - previousPoint.y))
    event.post(tap: .cghidEventTap)
}

@MainActor
func runStatusIcon() {
    let app = NSApplication.shared
    let delegate = StatusIconAppDelegate()
    statusIconDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.accessory)

    print("robot-swift status icon is running with macOS power assertions and an input nudge every 60 seconds. Use the menu bar Quit item or press Control-C in the terminal.")
    app.run()
}
