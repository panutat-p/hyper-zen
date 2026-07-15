import AppKit
import Testing
@testable import HyperzenCore

@Suite("Menu Bar Indicator State")
struct MenuBarIndicatorStateTests {
    @Test("On/Off state maps to active, disabled, and blocked indicators", arguments: [
        (isOn: true, allowed: true, expected: MenuBarIndicatorState.active),
        (isOn: false, allowed: true, expected: MenuBarIndicatorState.disabled),
        (isOn: false, allowed: false, expected: MenuBarIndicatorState.disabled),
        (isOn: true, allowed: false, expected: MenuBarIndicatorState.blocked),
    ])
    func stateMapping(testCase: (isOn: Bool, allowed: Bool, expected: MenuBarIndicatorState)) {
        let actual = MenuBarIndicatorState(
            isOn: testCase.isOn,
            hasAccessibility: testCase.allowed
        )

        #expect(actual == testCase.expected)
    }

    @Test("Playback symbols and labels identify every static state")
    func playbackSymbols() {
        #expect(MenuBarIndicatorState.active.symbolName == "play.fill")
        #expect(MenuBarIndicatorState.active.label == "On")
        #expect(MenuBarIndicatorState.disabled.symbolName == "pause.fill")
        #expect(MenuBarIndicatorState.disabled.label == "Off")
        #expect(MenuBarIndicatorState.blocked.symbolName == "stop.fill")
        #expect(MenuBarIndicatorState.blocked.label == "Blocked")
    }

    @Test("Every state resolves to a built-in static SF Symbol")
    func builtInSymbolsExist() throws {
        for state in MenuBarIndicatorState.allCases {
            let image = try #require(state.makeImage())
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
            #expect(image.isTemplate == false)
        }
    }
}
