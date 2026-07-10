import Carbon.HIToolbox
import CoreGraphics
import Foundation

public enum RobotKeyboard {
    public static let keySleep: TimeInterval = 0.01

    private static let keyCodes: [String: CGKeyCode] = [
        "a": CGKeyCode(kVK_ANSI_A), "b": CGKeyCode(kVK_ANSI_B), "c": CGKeyCode(kVK_ANSI_C),
        "d": CGKeyCode(kVK_ANSI_D), "e": CGKeyCode(kVK_ANSI_E), "f": CGKeyCode(kVK_ANSI_F),
        "g": CGKeyCode(kVK_ANSI_G), "h": CGKeyCode(kVK_ANSI_H), "i": CGKeyCode(kVK_ANSI_I),
        "j": CGKeyCode(kVK_ANSI_J), "k": CGKeyCode(kVK_ANSI_K), "l": CGKeyCode(kVK_ANSI_L),
        "m": CGKeyCode(kVK_ANSI_M), "n": CGKeyCode(kVK_ANSI_N), "o": CGKeyCode(kVK_ANSI_O),
        "p": CGKeyCode(kVK_ANSI_P), "q": CGKeyCode(kVK_ANSI_Q), "r": CGKeyCode(kVK_ANSI_R),
        "s": CGKeyCode(kVK_ANSI_S), "t": CGKeyCode(kVK_ANSI_T), "u": CGKeyCode(kVK_ANSI_U),
        "v": CGKeyCode(kVK_ANSI_V), "w": CGKeyCode(kVK_ANSI_W), "x": CGKeyCode(kVK_ANSI_X),
        "y": CGKeyCode(kVK_ANSI_Y), "z": CGKeyCode(kVK_ANSI_Z),
        "0": CGKeyCode(kVK_ANSI_0), "1": CGKeyCode(kVK_ANSI_1), "2": CGKeyCode(kVK_ANSI_2),
        "3": CGKeyCode(kVK_ANSI_3), "4": CGKeyCode(kVK_ANSI_4), "5": CGKeyCode(kVK_ANSI_5),
        "6": CGKeyCode(kVK_ANSI_6), "7": CGKeyCode(kVK_ANSI_7), "8": CGKeyCode(kVK_ANSI_8),
        "9": CGKeyCode(kVK_ANSI_9),
        "-": CGKeyCode(kVK_ANSI_Minus), "=": CGKeyCode(kVK_ANSI_Equal),
        "[": CGKeyCode(kVK_ANSI_LeftBracket), "]": CGKeyCode(kVK_ANSI_RightBracket),
        "\\": CGKeyCode(kVK_ANSI_Backslash), ";": CGKeyCode(kVK_ANSI_Semicolon),
        "'": CGKeyCode(kVK_ANSI_Quote), ",": CGKeyCode(kVK_ANSI_Comma),
        ".": CGKeyCode(kVK_ANSI_Period), "/": CGKeyCode(kVK_ANSI_Slash),
        "`": CGKeyCode(kVK_ANSI_Grave),
        "space": CGKeyCode(kVK_Space), "tab": CGKeyCode(kVK_Tab), "enter": CGKeyCode(kVK_Return),
        "return": CGKeyCode(kVK_Return), "esc": CGKeyCode(kVK_Escape), "escape": CGKeyCode(kVK_Escape),
        "delete": CGKeyCode(kVK_ForwardDelete), "backspace": CGKeyCode(kVK_Delete),
        "up": CGKeyCode(kVK_UpArrow), "down": CGKeyCode(kVK_DownArrow),
        "left": CGKeyCode(kVK_LeftArrow), "right": CGKeyCode(kVK_RightArrow),
        "home": CGKeyCode(kVK_Home), "end": CGKeyCode(kVK_End),
        "pageup": CGKeyCode(kVK_PageUp), "pagedown": CGKeyCode(kVK_PageDown),
        "f1": CGKeyCode(kVK_F1), "f2": CGKeyCode(kVK_F2), "f3": CGKeyCode(kVK_F3),
        "f4": CGKeyCode(kVK_F4), "f5": CGKeyCode(kVK_F5), "f6": CGKeyCode(kVK_F6),
        "f7": CGKeyCode(kVK_F7), "f8": CGKeyCode(kVK_F8), "f9": CGKeyCode(kVK_F9),
        "f10": CGKeyCode(kVK_F10), "f11": CGKeyCode(kVK_F11), "f12": CGKeyCode(kVK_F12),
        "f13": CGKeyCode(kVK_F13), "f14": CGKeyCode(kVK_F14), "f15": CGKeyCode(kVK_F15),
        "f16": CGKeyCode(kVK_F16), "f17": CGKeyCode(kVK_F17), "f18": CGKeyCode(kVK_F18),
        "f19": CGKeyCode(kVK_F19), "f20": CGKeyCode(kVK_F20),
        "capslock": CGKeyCode(kVK_CapsLock),
        "num0": CGKeyCode(kVK_ANSI_Keypad0), "num1": CGKeyCode(kVK_ANSI_Keypad1),
        "num2": CGKeyCode(kVK_ANSI_Keypad2), "num3": CGKeyCode(kVK_ANSI_Keypad3),
        "num4": CGKeyCode(kVK_ANSI_Keypad4), "num5": CGKeyCode(kVK_ANSI_Keypad5),
        "num6": CGKeyCode(kVK_ANSI_Keypad6), "num7": CGKeyCode(kVK_ANSI_Keypad7),
        "num8": CGKeyCode(kVK_ANSI_Keypad8), "num9": CGKeyCode(kVK_ANSI_Keypad9),
        "num.": CGKeyCode(kVK_ANSI_KeypadDecimal), "num+": CGKeyCode(kVK_ANSI_KeypadPlus),
        "num-": CGKeyCode(kVK_ANSI_KeypadMinus), "num*": CGKeyCode(kVK_ANSI_KeypadMultiply),
        "num/": CGKeyCode(kVK_ANSI_KeypadDivide), "num_enter": CGKeyCode(kVK_ANSI_KeypadEnter)
    ]

    public static func cmdCtrl() -> String {
        "cmd"
    }

    public static func keyCode(for key: String) -> CGKeyCode? {
        keyCodes[key.lowercased()]
    }

    public static func keyTap(_ key: String, modifiers: [String] = []) throws {
        try keyToggle(key, down: true, modifiers: modifiers)
        if keySleep > 0 {
            Thread.sleep(forTimeInterval: keySleep)
        }
        try keyToggle(key, down: false, modifiers: modifiers)
    }

    public static func keyDown(_ key: String, modifiers: [String] = []) throws {
        try keyToggle(key, down: true, modifiers: modifiers)
    }

    public static func keyUp(_ key: String, modifiers: [String] = []) throws {
        try keyToggle(key, down: false, modifiers: modifiers)
    }

    public static func keyToggle(_ key: String, down: Bool, modifiers: [String] = []) throws {
        let normalized = key.lowercased()
        guard let code = keyCodes[normalized] else {
            throw RobotError.invalidArgument("Unknown key: \(key)")
        }

        let flags = flagsFromModifiers(modifiers)
        guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: code, keyDown: down) else {
            throw RobotError.operationFailed("Could not create keyboard event for \(key)")
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    public static func typeText(_ text: String, delay: TimeInterval = 0) {
        for scalar in text.unicodeScalars {
            var chars = Array(String(scalar).utf16)
            guard let eventDown = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: 0, keyDown: true),
                  let eventUp = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: 0, keyDown: false) else {
                continue
            }

            chars.withUnsafeMutableBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else {
                    return
                }
                eventDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: baseAddress)
                eventUp.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: baseAddress)
            }

            eventDown.post(tap: .cghidEventTap)
            eventUp.post(tap: .cghidEventTap)

            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
        }
    }

    public static func pasteText(_ text: String) throws {
        try RobotClipboard.write(text)
        try keyTap("v", modifiers: ["cmd"])
    }

    public static func flagsFromModifiers(_ modifiers: [String]) -> CGEventFlags {
        var flags = CGEventFlags()
        for modifier in modifiers.map({ $0.lowercased() }) {
            switch modifier {
            case "cmd", "command", "lcmd", "rcmd", "meta":
                flags.insert(.maskCommand)
            case "ctrl", "control", "lctrl", "rctrl":
                flags.insert(.maskControl)
            case "alt", "option", "lalt", "ralt":
                flags.insert(.maskAlternate)
            case "shift", "lshift", "rshift":
                flags.insert(.maskShift)
            case "fn", "function":
                flags.insert(.maskSecondaryFn)
            default:
                continue
            }
        }
        return flags
    }
}
