import AppKit
import Foundation

struct StatusItemVisibilitySnapshot: Equatable {
    let isVisible: Bool
    let hasButton: Bool
    let hasWindow: Bool
    let hasScreen: Bool
    let isOnCurrentScreen: Bool
    let buttonWidth: CGFloat
}

/// Detects when macOS creates a status item but refuses to show it in the menu bar.
///
/// On recent macOS versions, third-party menu bar icons can be blocked in
/// System Settings → Menu Bar → Allow in the Menu Bar. The app keeps running,
/// but the icon never appears and AppKit reports no error.
enum MenuBarVisibilityWatcher {
    static let guidanceShownKey = "hasShownMenuBarVisibilityGuidance"
    static let guidanceLastShownAtKey = "menuBarVisibilityGuidanceLastShownAt"
    static let guidanceRepeatInterval: TimeInterval = 24 * 60 * 60
    static let startupFreshnessInterval: TimeInterval = 10
    static let startupCheckDelay: TimeInterval = 2
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.MenuBarSettings")!

    static let alertTitle = "HyperZen Menu Bar Icon Isn't Available"
    static let alertMessage = """
    HyperZen is running, but macOS may be hiding its menu bar icon.

    You can still use HyperZen: click its Dock icon to open the controls.

    Open System Settings → Menu Bar, find HyperZen under Allow in the Menu Bar, \
    and turn it on. The icon should appear immediately.
    """
    static let openSettingsButtonTitle = "Open Menu Bar Settings"
    static let dismissButtonTitle = "OK"

    @MainActor
    static func visibilitySnapshot(_ item: NSStatusItem) -> StatusItemVisibilitySnapshot {
        let screen = item.button?.window?.screen
        return StatusItemVisibilitySnapshot(
            isVisible: item.isVisible,
            hasButton: item.button != nil,
            hasWindow: item.button?.window != nil,
            hasScreen: screen != nil,
            isOnCurrentScreen: screen.map(isCurrentScreen) ?? false,
            buttonWidth: item.button?.frame.size.width ?? 0
        )
    }

    static func isBlockedSnapshot(_ snapshot: StatusItemVisibilitySnapshot) -> Bool {
        guard snapshot.isVisible else { return false }
        guard snapshot.hasButton else { return true }
        return !snapshot.hasWindow
            || !snapshot.hasScreen
            || !snapshot.isOnCurrentScreen
            || snapshot.buttonWidth <= 0
    }

    static func shouldAttemptStartupRecovery(
        appLaunchedAt: Date,
        now: Date = Date(),
        snapshots: [StatusItemVisibilitySnapshot]
    ) -> Bool {
        guard now.timeIntervalSince(appLaunchedAt) <= startupFreshnessInterval else { return false }
        return snapshots.contains { snapshot in
            snapshot.isVisible && isBlockedSnapshot(snapshot)
        }
    }

    static func shouldShowGuidance(defaults: UserDefaults, now: Date = Date()) -> Bool {
        guard defaults.bool(forKey: guidanceShownKey) else { return true }
        let lastShownAt = defaults.double(forKey: guidanceLastShownAtKey)
        guard lastShownAt > 0 else { return false }
        return now.timeIntervalSince1970 - lastShownAt >= guidanceRepeatInterval
    }

    static func markGuidanceShown(defaults: UserDefaults, now: Date = Date()) {
        defaults.set(true, forKey: guidanceShownKey)
        defaults.set(now.timeIntervalSince1970, forKey: guidanceLastShownAtKey)
    }

    @MainActor
    static func presentGuidance(
        defaults: UserDefaults,
        now: Date = Date(),
        openURL: (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        markGuidanceShown(defaults: defaults, now: now)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = alertTitle
        alert.informativeText = alertMessage
        alert.addButton(withTitle: openSettingsButtonTitle)
        alert.addButton(withTitle: dismissButtonTitle)

        if alert.runModal() == .alertFirstButtonReturn {
            openURL(settingsURL)
        }
    }

    @MainActor
    static func scheduleStartupCheck(
        appLaunchedAt: Date,
        statusItem: @escaping () -> NSStatusItem?,
        recreateStatusItem: @escaping () -> Void,
        defaults: UserDefaults = .standard
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + startupCheckDelay) {
            guard let item = statusItem() else { return }

            var snapshots = [visibilitySnapshot(item)]
            guard shouldAttemptStartupRecovery(appLaunchedAt: appLaunchedAt, snapshots: snapshots) else {
                return
            }

            recreateStatusItem()
            if let recreated = statusItem() {
                snapshots = [visibilitySnapshot(recreated)]
            }

            guard shouldAttemptStartupRecovery(appLaunchedAt: appLaunchedAt, snapshots: snapshots),
                  shouldShowGuidance(defaults: defaults)
            else {
                return
            }

            presentGuidance(defaults: defaults)
        }
    }

    @MainActor
    private static func isCurrentScreen(_ screen: NSScreen) -> Bool {
        let number = screenNumber(screen)
        return NSScreen.screens.contains { candidate in
            if let number, let candidateNumber = screenNumber(candidate) {
                return candidateNumber == number
            }
            return candidate === screen
        }
    }

    private static func screenNumber(_ screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }
}
