import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sleepPreventer = SleepPreventer()
    private let activityNudger = ActivityNudger()
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var hasAccessibility = false

    private var animationSource: DispatchSourceTimer?
    private var currentFrame = 0
    private var screensAsleep = false

    // ~2.5 FPS — slow gait, still light on CPU.
    private let animationInterval: TimeInterval = 0.4

    private lazy var runFrames: [NSImage] = (0..<IconRenderer.statusFrameCount)
        .map { IconRenderer.makeStatusFrame(frame: $0) }
    private lazy var idleFrame: NSImage = IconRenderer.makeStatusIdleIcon()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        observeScreenSleep()

        hasAccessibility = AccessibilityGuard.isTrusted
        if hasAccessibility {
            enableKeepAwakeByDefault()
            updateUI()
        } else {
            updateUI()
            requestAccessibilityForKeepAwake()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        recheckAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopAnimation()
        activityNudger.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        sleepPreventer.disable()
    }

    @objc private func recheckAccessibility() {
        let wasGranted = hasAccessibility
        hasAccessibility = AccessibilityGuard.isTrusted

        if !hasAccessibility && sleepPreventer.isEnabled {
            try? setKeepAwakeEnabled(false)
            updateUI()
            return
        }

        guard hasAccessibility != wasGranted else { return }
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
        stopAnimation()
        activityNudger.stop()
    }

    @objc private func screensDidWake() {
        screensAsleep = false
        updateUI()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = idleFrame

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Enable Keep Awake",
            action: #selector(toggleKeepAwake(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        self.toggleMenuItem = toggleItem

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Hyperzen",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func enableKeepAwakeByDefault() {
        do {
            try setKeepAwakeEnabled(true)
        } catch {
            showErrorAlert(message: error.localizedDescription)
        }
    }

    @objc private func toggleKeepAwake(_ sender: NSMenuItem) {
        let turningOn = !sleepPreventer.isEnabled

        if turningOn {
            requestAccessibilityForKeepAwake { [weak self] granted in
                guard let self, granted else { return }
                do {
                    try self.setKeepAwakeEnabled(true)
                    self.updateUI()
                } catch {
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
            return
        }

        do {
            try setKeepAwakeEnabled(false)
            updateUI()
        } catch {
            showErrorAlert(message: error.localizedDescription)
        }
    }

    /// Defers the permission flow so the warning modal is shown reliably after
    /// launch and after the status-item menu closes.
    private func requestAccessibilityForKeepAwake(
        completion: ((Bool) -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            self.hasAccessibility = AccessibilityGuard.requireAccessForKeepAwake()
            self.updateUI()
            completion?(self.hasAccessibility)
        }
    }

    private func setKeepAwakeEnabled(_ enabled: Bool) throws {
        if enabled {
            try sleepPreventer.enable()
            if !screensAsleep && hasAccessibility {
                activityNudger.start()
            }
        } else {
            sleepPreventer.disable()
            activityNudger.stop()
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    private func startAnimation() {
        guard animationSource == nil, !screensAsleep else { return }

        let source = DispatchSource.makeTimerSource(flags: [], queue: .main)
        // 50% leeway lets the OS coalesce wakeups with other timers.
        let leeway = DispatchTimeInterval.milliseconds(Int(animationInterval * 1000 * 0.5))
        source.schedule(deadline: .now() + animationInterval, repeating: animationInterval, leeway: leeway)
        source.setEventHandler { [weak self] in
            self?.advanceFrame()
        }
        source.resume()
        animationSource = source
    }

    private func stopAnimation() {
        animationSource?.cancel()
        animationSource = nil
        currentFrame = 0
    }

    private func advanceFrame() {
        currentFrame = (currentFrame + 1) % runFrames.count
        statusItem?.button?.image = runFrames[currentFrame]
    }

    private func updateUI() {
        let isEnabled = sleepPreventer.isEnabled
        toggleMenuItem?.title = isEnabled ? "Disable Keep Awake" : "Enable Keep Awake"

        if isEnabled && !screensAsleep {
            if hasAccessibility && !activityNudger.isRunning {
                activityNudger.start()
            }
            startAnimation()
            statusItem?.button?.image = runFrames[currentFrame]
        } else {
            stopAnimation()
            statusItem?.button?.image = isEnabled ? runFrames[0] : idleFrame
        }
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Could Not Enable Keep Awake"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
