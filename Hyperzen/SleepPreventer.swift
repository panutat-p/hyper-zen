import Foundation
import IOKit.pwr_mgt

enum SleepPreventerError: LocalizedError {
    case assertionFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .assertionFailed(let code):
            return "macOS rejected the sleep prevention request (error \(code))."
        }
    }
}

final class SleepPreventer {
    // Holds both a system-idle-sleep and a display-idle-sleep assertion.
    // The display assertion keeps the whole machine awake (matching Amphetamine's
    // default) so the Mac doesn't drift to sleep once the screen would dim off.
    private var systemAssertionID: IOPMAssertionID?
    private var displayAssertionID: IOPMAssertionID?

    var isEnabled: Bool {
        systemAssertionID != nil
    }

    func enable() throws {
        guard systemAssertionID == nil else { return }

        let systemID = try createAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep)
        do {
            displayAssertionID = try createAssertion(type: kIOPMAssertionTypePreventUserIdleDisplaySleep)
        } catch {
            // If the display assertion fails, fall back to system-only rather than aborting.
            displayAssertionID = nil
        }

        systemAssertionID = systemID
    }

    private func createAssertion(type: String) throws -> IOPMAssertionID {
        var newAssertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Hyperzen Keep Awake" as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            throw SleepPreventerError.assertionFailed(result)
        }

        return newAssertionID
    }

    func disable() {
        if let systemAssertionID {
            IOPMAssertionRelease(systemAssertionID)
            self.systemAssertionID = nil
        }
        if let displayAssertionID {
            IOPMAssertionRelease(displayAssertionID)
            self.displayAssertionID = nil
        }
    }

    func toggle() throws {
        if isEnabled {
            disable()
        } else {
            try enable()
        }
    }

    deinit {
        disable()
    }
}
