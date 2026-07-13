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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sleepPreventer = SleepPreventer()
    private let activityNudger = ActivityNudger()
    private let teamsActivityEnabledKey = "teamsActivityEnabled"

    private var statusItem: NSStatusItem?
    private var keepAwakeMenuItem: NSMenuItem?
    private var teamsActivityMenuItem: NSMenuItem?
    private var powerStatusMenuItem: NSMenuItem?
    private var teamsStatusMenuItem: NSMenuItem?
    private var accessibilityStatusMenuItem: NSMenuItem?

    private var mainWindow: NSWindow?
    private var keepAwakeCheckbox: NSButton?
    private var teamsActivityCheckbox: NSButton?
    private var powerStatusLabel: NSTextField?
    private var teamsStatusLabel: NSTextField?
    private var accessibilityStatusLabel: NSTextField?

    private var hasAccessibility = false
    private var teamsActivityRequested = true
    private var screensAsleep = false
    private let appLaunchedAt = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = IconRenderer.makeAppIcon(size: 512)
        teamsActivityRequested = UserDefaults.standard.object(forKey: teamsActivityEnabledKey) as? Bool ?? true

        setupStatusItem()
        setupMainWindow()
        scheduleMenuBarVisibilityCheck()
        observeScreenSleep()

        hasAccessibility = AccessibilityGuard.isTrusted
        enableKeepAwakeByDefault()
        reconcileTeamsActivity()
        updateUI()
        showMainWindow(nil)

        if teamsActivityRequested && !hasAccessibility {
            DispatchQueue.main.async {
                AccessibilityGuard.requestSystemPrompt()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        recheckAccessibility()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow(nil)
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

        let showItem = NSMenuItem(
            title: "Show HyperZen",
            action: #selector(showMainWindow(_:)),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())

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
    }

    private func setupMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HyperZen"
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("HyperZenMainWindow")
        window.center()

        let contentView = NSView()
        window.contentView = contentView

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 18
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 26),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
        ])

        let iconView = NSImageView(image: IconRenderer.makeAppIcon(size: 72))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),
        ])

        let titleLabel = makeLabel("HyperZen", font: .systemFont(ofSize: 28, weight: .semibold))
        let subtitleLabel = makeLabel(
            "Keep your Mac awake and your collaboration presence active.",
            color: .secondaryLabelColor
        )
        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 5

        let headerStack = NSStackView(views: [iconView, titleStack])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 18
        rootStack.addArrangedSubview(headerStack)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: rootStack.widthAnchor).isActive = true

        let keepAwakeButton = NSButton(
            checkboxWithTitle: "Keep Mac Awake",
            target: self,
            action: #selector(toggleKeepAwake(_:))
        )
        keepAwakeButton.font = .systemFont(ofSize: 16, weight: .medium)
        keepAwakeCheckbox = keepAwakeButton
        let keepAwakeStack = makeFeatureStack(
            control: keepAwakeButton,
            help: "Prevents idle system sleep and display sleep.\nWorks without Accessibility permission."
        )
        rootStack.addArrangedSubview(keepAwakeStack)
        keepAwakeStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor).isActive = true

        let teamsButton = NSButton(
            checkboxWithTitle: "Keep Teams Active",
            target: self,
            action: #selector(toggleTeamsActivity(_:))
        )
        teamsButton.font = .systemFont(ofSize: 16, weight: .medium)
        teamsActivityCheckbox = teamsButton
        let teamsStack = makeFeatureStack(
            control: teamsButton,
            help: "Declares activity and performs a one-pixel move-and-return every 60 seconds.\nRequires Accessibility."
        )
        rootStack.addArrangedSubview(teamsStack)
        teamsStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor).isActive = true

        let statusTitle = makeLabel("Live Status", font: .systemFont(ofSize: 15, weight: .semibold))
        rootStack.addArrangedSubview(statusTitle)

        let powerValue = makeLabel("Disabled", color: .secondaryLabelColor)
        let teamsValue = makeLabel("Disabled", color: .secondaryLabelColor)
        let accessibilityValue = makeLabel("Checking…", color: .secondaryLabelColor)
        powerStatusLabel = powerValue
        teamsStatusLabel = teamsValue
        accessibilityStatusLabel = accessibilityValue

        let statusStack = NSStackView(views: [
            makeStatusRow(title: "Power assertions", value: powerValue),
            makeStatusRow(title: "Teams activity", value: teamsValue),
            makeStatusRow(title: "Accessibility", value: accessibilityValue),
            makeStatusRow(title: "Input nudge", value: makeLabel("Every 60 seconds")),
        ])
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 8
        rootStack.addArrangedSubview(statusStack)
        statusStack.leadingAnchor.constraint(equalTo: rootStack.leadingAnchor).isActive = true

        let settingsButton = NSButton(
            title: "Open Accessibility Settings",
            target: self,
            action: #selector(openAccessibilitySettings(_:))
        )
        rootStack.addArrangedSubview(settingsButton)

        mainWindow = window
    }

    private func makeFeatureStack(control: NSButton, help: String) -> NSStackView {
        let helpLabels = help.components(separatedBy: "\n").map {
            makeLabel($0, color: .secondaryLabelColor)
        }
        let stack = NSStackView(views: [control] + helpLabels)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    private func makeStatusRow(title: String, value: NSTextField) -> NSStackView {
        let titleLabel = makeLabel(title, color: .secondaryLabelColor)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let row = NSStackView(views: [titleLabel, value])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 18
        return row
    }

    private func makeLabel(
        _ text: String,
        font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
        color: NSColor = .labelColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        return label
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

    @objc private func showMainWindow(_ sender: Any?) {
        guard let mainWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
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
        keepAwakeCheckbox?.state = keepAwakeEnabled ? .on : .off
        teamsActivityCheckbox?.state = teamsActivityRequested ? .on : .off

        let powerText = keepAwakeEnabled ? "Enabled" : "Disabled"
        let teamsText = teamsStatusText
        let accessibilityText = hasAccessibility ? "Allowed" : "Not Allowed"

        powerStatusMenuItem?.title = "Power Assertions: \(powerText)"
        teamsStatusMenuItem?.title = "Teams Activity: \(teamsText)"
        accessibilityStatusMenuItem?.title = "Accessibility: \(accessibilityText)"

        powerStatusLabel?.stringValue = powerText
        powerStatusLabel?.textColor = keepAwakeEnabled ? .systemGreen : .secondaryLabelColor
        teamsStatusLabel?.stringValue = teamsText
        teamsStatusLabel?.textColor = teamsStatusColor
        accessibilityStatusLabel?.stringValue = accessibilityText
        accessibilityStatusLabel?.textColor = hasAccessibility ? .systemGreen : .systemRed

        let indicator = MenuBarIndicatorState(
            teamsActivityRequested: teamsActivityRequested,
            hasAccessibility: hasAccessibility
        )
        statusItem?.button?.image = indicator.makeImage()
        statusItem?.button?.contentTintColor = indicator.tintColor
        statusItem?.button?.toolTip = "HyperZen — \(indicator.label) — Power: \(powerText), Teams: \(teamsText)"
    }

    private var teamsStatusColor: NSColor {
        if !teamsActivityRequested {
            return .secondaryLabelColor
        }
        if !hasAccessibility {
            return .systemRed
        }
        if screensAsleep {
            return .systemOrange
        }
        return activityNudger.isRunning ? .systemGreen : .secondaryLabelColor
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
