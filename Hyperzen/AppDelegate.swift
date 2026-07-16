import AppKit

enum MenuBarIndicatorState: CaseIterable, Equatable {
    case active
    case disabled
    case blocked

    init(isOn: Bool, hasAccessibility: Bool) {
        if !isOn {
            self = .disabled
        } else if hasAccessibility {
            self = .active
        } else {
            self = .blocked
        }
    }

    var symbolName: String {
        switch self {
        case .active: "eye.fill"
        case .disabled: "eye.slash.fill"
        case .blocked: "xmark"
        }
    }

    var label: String {
        switch self {
        case .active: "On"
        case .disabled: "Off"
        case .blocked: "Blocked"
        }
    }

    var tintColor: NSColor {
        switch self {
        case .active: .systemGreen
        case .disabled: .white
        case .blocked: .systemRed
        }
    }

    func makeImage() -> NSImage? {
        let sizeConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let colorConfiguration = NSImage.SymbolConfiguration(paletteColors: [tintColor])
        let configuration = sizeConfiguration.applying(colorConfiguration)
        guard let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "HyperZen \(label)"
        )?.withSymbolConfiguration(configuration) else {
            return nil
        }
        // Menu bar treats template SF Symbols as monochrome; bake color in instead.
        image.isTemplate = false
        return image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sleepPreventer = SleepPreventer()
    private let activityNudger = ActivityNudger()
    private let isOnKey = "hyperZenIsOn"

    private var statusItem: NSStatusItem?
    private var onOffMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private var accessibilityStatusMenuItem: NSMenuItem?

    private var hasAccessibility = false
    private var isOn = true
    private var screensAsleep = false
    private let appLaunchedAt = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = IconRenderer.makeAppIcon(size: 512)
        isOn = UserDefaults.standard.object(forKey: isOnKey) as? Bool ?? true

        setupStatusItem()
        scheduleMenuBarVisibilityCheck()
        observeScreenSleep()

        hasAccessibility = AccessibilityGuard.isTrusted
        applyOnOffState()
        updateUI()

        if isOn && !hasAccessibility {
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
        reconcileActivityNudger()
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
        reconcileActivityNudger()
        updateUI()
    }

    @objc private func screensDidWake() {
        screensAsleep = false
        reconcileActivityNudger()
        updateUI()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "HyperZen"
        item.isVisible = true
        let indicator = MenuBarIndicatorState(
            isOn: isOn,
            hasAccessibility: hasAccessibility
        )
        item.button?.image = indicator.makeImage()
        item.button?.toolTip = "HyperZen"

        let menu = NSMenu()
        menu.delegate = self

        let onOffItem = NSMenuItem(
            title: "On",
            action: #selector(toggleOnOff(_:)),
            keyEquivalent: ""
        )
        onOffItem.target = self
        menu.addItem(onOffItem)
        onOffMenuItem = onOffItem

        menu.addItem(.separator())
        statusMenuItem = addDisabledItem("Status: Off", to: menu)
        accessibilityStatusMenuItem = addDisabledItem("Accessibility: Checking…", to: menu)

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

    @objc private func toggleOnOff(_ sender: Any?) {
        setOn(!isOn)
    }

    private func setOn(_ enabled: Bool) {
        isOn = enabled
        UserDefaults.standard.set(isOn, forKey: isOnKey)
        hasAccessibility = AccessibilityGuard.isTrusted
        applyOnOffState()
        updateUI()

        if isOn && !hasAccessibility {
            DispatchQueue.main.async {
                self.hasAccessibility = AccessibilityGuard.requireAccessForActivity(presentWarning: true)
                self.reconcileActivityNudger()
                self.updateUI()
            }
        }
    }

    private func applyOnOffState() {
        do {
            if isOn {
                try sleepPreventer.enable()
            } else {
                sleepPreventer.disable()
            }
        } catch {
            showErrorAlert(message: error.localizedDescription)
        }
        reconcileActivityNudger()
    }

    private func reconcileActivityNudger() {
        let shouldRun = isOn && hasAccessibility && !screensAsleep
        if shouldRun {
            activityNudger.start()
        } else {
            activityNudger.stop()
        }
    }

    @objc private func showDropdown(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        recheckAccessibility()

        // Open from the menu-bar icon (same as a status-item click), not at the cursor.
        // Launcher / Spotlight reopen must not float a menu under the pointer.
        guard let button = statusItem?.button else { return }
        button.performClick(nil)
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        AccessibilityGuard.openAccessibilitySettings()
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private var statusText: String {
        if !isOn {
            return "Off"
        }
        if !hasAccessibility {
            return "On — needs Accessibility for input"
        }
        if screensAsleep {
            return "On — paused while display sleeps"
        }
        let power = sleepPreventer.isEnabled ? "awake" : "assertions unavailable"
        let nudge = activityNudger.isRunning ? "nudging" : "idle"
        return "On — \(power), \(nudge)"
    }

    private func updateUI() {
        onOffMenuItem?.title = isOn ? "On" : "Off"
        onOffMenuItem?.state = isOn ? .on : .off

        let accessibilityText = hasAccessibility ? "Allowed" : "Not Allowed"
        statusMenuItem?.title = "Status: \(statusText)"
        accessibilityStatusMenuItem?.title = "Accessibility: \(accessibilityText)"

        let indicator = MenuBarIndicatorState(
            isOn: isOn,
            hasAccessibility: hasAccessibility
        )
        statusItem?.button?.image = indicator.makeImage()
        statusItem?.button?.toolTip = "HyperZen — \(indicator.label)"
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Could Not Update On/Off"
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
