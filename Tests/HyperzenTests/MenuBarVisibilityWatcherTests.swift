import XCTest
@testable import HyperzenCore

final class MenuBarVisibilityWatcherTests: XCTestCase {
    func testBlockedWhenVisibleItemHasNoWindow() {
        let snapshot = StatusItemVisibilitySnapshot(
            isVisible: true,
            hasButton: true,
            hasWindow: false,
            hasScreen: false,
            isOnCurrentScreen: false,
            buttonWidth: 0
        )

        XCTAssertTrue(MenuBarVisibilityWatcher.isBlockedSnapshot(snapshot))
    }

    func testNotBlockedWhenHiddenByApp() {
        let snapshot = StatusItemVisibilitySnapshot(
            isVisible: false,
            hasButton: true,
            hasWindow: false,
            hasScreen: false,
            isOnCurrentScreen: false,
            buttonWidth: 0
        )

        XCTAssertFalse(MenuBarVisibilityWatcher.isBlockedSnapshot(snapshot))
    }

    func testNotBlockedWhenMaterialized() {
        let snapshot = StatusItemVisibilitySnapshot(
            isVisible: true,
            hasButton: true,
            hasWindow: true,
            hasScreen: true,
            isOnCurrentScreen: true,
            buttonWidth: 22
        )

        XCTAssertFalse(MenuBarVisibilityWatcher.isBlockedSnapshot(snapshot))
    }

    func testStartupRecoveryOnlySoonAfterLaunch() {
        let blocked = StatusItemVisibilitySnapshot(
            isVisible: true,
            hasButton: true,
            hasWindow: false,
            hasScreen: false,
            isOnCurrentScreen: false,
            buttonWidth: 0
        )
        let launchedAt = Date()

        XCTAssertTrue(
            MenuBarVisibilityWatcher.shouldAttemptStartupRecovery(
                appLaunchedAt: launchedAt,
                now: launchedAt.addingTimeInterval(3),
                snapshots: [blocked]
            )
        )
        XCTAssertFalse(
            MenuBarVisibilityWatcher.shouldAttemptStartupRecovery(
                appLaunchedAt: launchedAt,
                now: launchedAt.addingTimeInterval(30),
                snapshots: [blocked]
            )
        )
    }

    func testGuidanceShownOnceUnlessRepeatIntervalElapsed() {
        let defaults = UserDefaults(suiteName: "MenuBarVisibilityWatcherTests")!
        defaults.removePersistentDomain(forName: "MenuBarVisibilityWatcherTests")

        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(MenuBarVisibilityWatcher.shouldShowGuidance(defaults: defaults, now: now))

        MenuBarVisibilityWatcher.markGuidanceShown(defaults: defaults, now: now)
        XCTAssertFalse(MenuBarVisibilityWatcher.shouldShowGuidance(defaults: defaults, now: now))

        let later = now.addingTimeInterval(MenuBarVisibilityWatcher.guidanceRepeatInterval + 1)
        XCTAssertTrue(MenuBarVisibilityWatcher.shouldShowGuidance(defaults: defaults, now: later))
    }
}
