import AppKit

enum MenuBarIndicatorState: CaseIterable, Equatable {
    case active
    case disabled
    case blocked

    init(teamsActivityRequested: Bool, hasAccessibility: Bool) {
        if !teamsActivityRequested {
            self = .disabled
        } else if hasAccessibility {
            self = .active
        } else {
            self = .blocked
        }
    }

    var symbolName: String {
        switch self {
        case .active: "play.fill"
        case .disabled: "pause.fill"
        case .blocked: "stop.fill"
        }
    }

    var label: String {
        switch self {
        case .active: "Active"
        case .disabled: "Disabled"
        case .blocked: "Blocked"
        }
    }

    var tintColor: NSColor {
        switch self {
        case .active: .systemGreen
        case .disabled: .systemGray
        case .blocked: .systemRed
        }
    }

    func makeImage() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        return NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "HyperZen \(label)"
        )?.withSymbolConfiguration(configuration)
    }
}

struct MenuPopupPlacement {
    /// Returns the screen point for a menu whose first item is positioned at the point.
    ///
    /// A Dock click occurs below the screen's visible frame. Raising the point by the
    /// menu height keeps the menu above the Dock instead of relying on AppKit to
    /// recover from an off-screen presentation.
    static func point(
        cursor: NSPoint,
        menuSize: NSSize,
        visibleFrame: NSRect
    ) -> NSPoint {
        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - menuSize.width)
        let x = min(max(cursor.x, visibleFrame.minX), maximumX)
        let y = min(
            max(cursor.y, visibleFrame.minY + menuSize.height),
            visibleFrame.maxY
        )
        return NSPoint(x: x, y: y)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sleepPreventer = SleepPreventer()
    private let activityNudger = ActivityNudger()
    private let teamsActivityEnabledKey = "teamsActivityEnabled"

    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var keepAwakeMenuItem: NSMenuItem?
    private var teamsActivityMenuItem: NSMenuItem?
    private var powerStatusMenuItem: NSMenuItem?
    private var teamsStatusMenuItem: NSMenuItem?
    private var accessibilityStatusMenuItem: NSMenuItem?

    private var hasAccessibility = false
    private var teamsActivityRequested = true
    private var screensAsleep = false
    private let appLaunchedAt = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = IconRenderer.makeAppIcon(size: 512)
        teamsActivityRequested = UserDefaults.standard.object(forKey: teamsActivityEnabledKey) as? Bool ?? true

        setupStatusItem()
        scheduleMenuBarVisibilityCheck()
        observeScreenSleep()

        hasAccessibility = AccessibilityGuard.isTrusted
        enableKeepAwakeByDefault()
        reconcileTeamsActivity()
        updateUI()

        if teamsActivityRequested && !hasAccessibility {
            DispatchQueue.main.async {
                AccessibilityGuard.requestSystemPrompt()
            }
        }

        DispatchQueue.main.async {
            self.showDropdown(nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        recheckAccessibility()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showDropdown(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        activityNudger.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        sleepPreventer.disable()
    }

    @objc private func recheckAccessibility() {
        hasAccessibility = AccessibilityGuard.isTrusted
        reconcileTeamsActivity()
        updateUI()
    }

    private func observeScreenSleep() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(screensDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func screensDidSleep() {
        screensAsleep = true
        reconcileTeamsActivity()
        updateUI()
    }

    @objc private func screensDidWake() {
        screensAsleep = false
        reconcileTeamsActivity()
        updateUI()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "HyperZen"
        item.isVisible = true
        let indicator = MenuBarIndicatorState(
            teamsActivityRequested: teamsActivityRequested,
            hasAccessibility: hasAccessibility
        )
        item.button?.image = indicator.makeImage()
        item.button?.contentTintColor = indicator.tintColor
        item.button?.toolTip = "HyperZen"

        let menu = NSMenu()
        menu.delegate = self

        let keepAwakeItem = NSMenuItem(
            title: "Keep Mac Awake",
            action: #selector(toggleKeepAwake(_:)),
            keyEquivalent: ""
        )
        keepAwakeItem.target = self
        menu.addItem(keepAwakeItem)
        keepAwakeMenuItem = keepAwakeItem

        let teamsItem = NSMenuItem(
            title: "Keep Teams Active",
            action: #selector(toggleTeamsActivity(_:)),
            keyEquivalent: ""
        )
        teamsItem.target = self
        menu.addItem(teamsItem)
        teamsActivityMenuItem = teamsItem

        menu.addItem(.separator())
        powerStatusMenuItem = addDisabledItem("Power Assertions: Disabled", to: menu)
        teamsStatusMenuItem = addDisabledItem("Teams Activity: Disabled", to: menu)
        accessibilityStatusMenuItem = addDisabledItem("Accessibility: Checking…", to: menu)
        addDisabledItem("Input nudge: Every 60 seconds", to: menu)

        let settingsItem = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit HyperZen",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
        statusMenu = menu
    }

    @discardableResult
    private func addDisabledItem(_ title: String, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        return item
    }

    private func scheduleMenuBarVisibilityCheck() {
        Task { @MainActor in
            MenuBarVisibilityWatcher.scheduleStartupCheck(
                appLaunchedAt: appLaunchedAt,
                statusItem: { [weak self] in self?.statusItem },
                recreateStatusItem: { [weak self] in self?.recreateStatusItem() }
            )
        }
    }

    private func recreateStatusItem() {
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
            statusItem = nil
        }
        setupStatusItem()
        updateUI()
    }

    private func enableKeepAwakeByDefault() {
        do {
            try setKeepAwakeEnabled(true)
        } catch {
            showErrorAlert(message: error.localizedDescription)
        }
    }

    @objc private func toggleKeepAwake(_ sender: Any?) {
        do {
            try setKeepAwakeEnabled(!sleepPreventer.isEnabled)
            updateUI()
        } catch {
            showErrorAlert(message: error.localizedDescription)
        }
    }

    private func setKeepAwakeEnabled(_ enabled: Bool) throws {
        if enabled {
            try sleepPreventer.enable()
        } else {
            sleepPreventer.disable()
        }
    }

    @objc private func toggleTeamsActivity(_ sender: Any?) {
        teamsActivityRequested.toggle()
        UserDefaults.standard.set(teamsActivityRequested, forKey: teamsActivityEnabledKey)
        hasAccessibility = AccessibilityGuard.isTrusted
        reconcileTeamsActivity()
        updateUI()

        if teamsActivityRequested && !hasAccessibility {
            DispatchQueue.main.async {
                self.hasAccessibility = AccessibilityGuard.requireAccessForTeamsActivity()
                self.reconcileTeamsActivity()
                self.updateUI()
            }
        }
    }

    private func reconcileTeamsActivity() {
        let shouldRun = teamsActivityRequested && hasAccessibility && !screensAsleep
        if shouldRun {
            activityNudger.start()
        } else {
            activityNudger.stop()
        }
    }

    @objc private func showDropdown(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        recheckAccessibility()

        guard let statusMenu else { return }
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main else {
            statusMenu.popUp(positioning: nil, at: cursor, in: nil)
            return
        }

        let point = MenuPopupPlacement.point(
            cursor: cursor,
            menuSize: statusMenu.size,
            visibleFrame: screen.visibleFrame
        )
        statusMenu.popUp(positioning: nil, at: point, in: nil)
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        AccessibilityGuard.openAccessibilitySettings()
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private var teamsStatusText: String {
        if !teamsActivityRequested {
            return "Disabled"
        }
        if !hasAccessibility {
            return "Needs Accessibility"
        }
        if screensAsleep {
            return "Paused while display sleeps"
        }
        return activityNudger.isRunning ? "Active" : "Inactive"
    }

    private func updateUI() {
        let keepAwakeEnabled = sleepPreventer.isEnabled

        keepAwakeMenuItem?.state = keepAwakeEnabled ? .on : .off
        teamsActivityMenuItem?.state = teamsActivityRequested ? .on : .off

        let powerText = keepAwakeEnabled ? "Enabled" : "Disabled"
        let teamsText = teamsStatusText
        let accessibilityText = hasAccessibility ? "Allowed" : "Not Allowed"

        powerStatusMenuItem?.title = "Power Assertions: \(powerText)"
        teamsStatusMenuItem?.title = "Teams Activity: \(teamsText)"
        accessibilityStatusMenuItem?.title = "Accessibility: \(accessibilityText)"

        let indicator = MenuBarIndicatorState(
            teamsActivityRequested: teamsActivityRequested,
            hasAccessibility: hasAccessibility
        )
        statusItem?.button?.image = indicator.makeImage()
        statusItem?.button?.contentTintColor = indicator.tintColor
        statusItem?.button?.toolTip = "HyperZen — \(indicator.label) — Power: \(powerText), Teams: \(teamsText)"
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Could Not Update Keep Awake"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        recheckAccessibility()
    }
}
