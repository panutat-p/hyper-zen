import Testing
@testable import HyperzenCore

@Suite("Sleep Preventer", .serialized)
struct SleepPreventerTests {
    @Test("Preventer starts disabled")
    func initiallyDisabled() {
        let preventer = SleepPreventer()

        #expect(!preventer.isEnabled)
    }

    @Test("Enable activates sleep prevention")
    func enableSetsEnabled() throws {
        let preventer = SleepPreventer()
        defer { preventer.disable() }

        try preventer.enable()

        #expect(preventer.isEnabled)
    }

    @Test("Enable is idempotent")
    func enableIsIdempotent() throws {
        let preventer = SleepPreventer()
        defer { preventer.disable() }

        try preventer.enable()
        try preventer.enable()

        #expect(preventer.isEnabled)
    }

    @Test("Disable clears the enabled state")
    func disableClearsEnabled() throws {
        let preventer = SleepPreventer()
        try preventer.enable()
        preventer.disable()

        #expect(!preventer.isEnabled)
    }

    @Test("Disabling an inactive preventer is safe")
    func disableWhenAlreadyDisabledIsSafe() {
        let preventer = SleepPreventer()
        preventer.disable()

        #expect(!preventer.isEnabled)
    }

    @Test("Toggle enables and disables")
    func toggleEnablesAndDisables() throws {
        let preventer = SleepPreventer()
        defer { preventer.disable() }

        try preventer.toggle()
        #expect(preventer.isEnabled)

        try preventer.toggle()
        #expect(!preventer.isEnabled)
    }
}
