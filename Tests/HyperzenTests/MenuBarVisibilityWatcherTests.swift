import Foundation
import Testing
@testable import HyperzenCore

@Suite("Menu Bar Visibility")
struct MenuBarVisibilityWatcherTests {
    @Test("Visible item without a window is blocked")
    func blockedWhenVisibleItemHasNoWindow() {
        let snapshot = StatusItemVisibilitySnapshot(
            isVisible: true,
            hasButton: true,
            hasWindow: false,
            hasScreen: false,
            isOnCurrentScreen: false,
            buttonWidth: 0
        )

        #expect(MenuBarVisibilityWatcher.isBlockedSnapshot(snapshot))
    }

    @Test("Item hidden by the app is not blocked")
    func notBlockedWhenHiddenByApp() {
        let snapshot = StatusItemVisibilitySnapshot(
            isVisible: false,
            hasButton: true,
            hasWindow: false,
            hasScreen: false,
            isOnCurrentScreen: false,
            buttonWidth: 0
        )

        #expect(!MenuBarVisibilityWatcher.isBlockedSnapshot(snapshot))
    }

    @Test("Materialized item is not blocked")
    func notBlockedWhenMaterialized() {
        let snapshot = StatusItemVisibilitySnapshot(
            isVisible: true,
            hasButton: true,
            hasWindow: true,
            hasScreen: true,
            isOnCurrentScreen: true,
            buttonWidth: 22
        )

        #expect(!MenuBarVisibilityWatcher.isBlockedSnapshot(snapshot))
    }

    @Test("Startup recovery only runs soon after launch")
    func startupRecoveryOnlySoonAfterLaunch() {
        let blocked = StatusItemVisibilitySnapshot(
            isVisible: true,
            hasButton: true,
            hasWindow: false,
            hasScreen: false,
            isOnCurrentScreen: false,
            buttonWidth: 0
        )
        let launchedAt = Date()

        #expect(
            MenuBarVisibilityWatcher.shouldAttemptStartupRecovery(
                appLaunchedAt: launchedAt,
                now: launchedAt.addingTimeInterval(3),
                snapshots: [blocked]
            )
        )
        #expect(
            !MenuBarVisibilityWatcher.shouldAttemptStartupRecovery(
                appLaunchedAt: launchedAt,
                now: launchedAt.addingTimeInterval(30),
                snapshots: [blocked]
            )
        )
    }

    @Test("Guidance repeats only after the configured interval")
    func guidanceShownOnceUnlessRepeatIntervalElapsed() throws {
        let suiteName = "MenuBarVisibilityWatcherTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(MenuBarVisibilityWatcher.shouldShowGuidance(defaults: defaults, now: now))

        MenuBarVisibilityWatcher.markGuidanceShown(defaults: defaults, now: now)
        #expect(!MenuBarVisibilityWatcher.shouldShowGuidance(defaults: defaults, now: now))

        let later = now.addingTimeInterval(MenuBarVisibilityWatcher.guidanceRepeatInterval + 1)
        #expect(MenuBarVisibilityWatcher.shouldShowGuidance(defaults: defaults, now: later))
    }
}
