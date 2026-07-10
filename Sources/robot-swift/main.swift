import Foundation
import RobotSwift

struct CommandError: LocalizedError {
    let errorDescription: String?
}

let arguments = Array(CommandLine.arguments.dropFirst())

do {
    try run(arguments)
} catch {
    FileHandle.standardError.write((error.localizedDescription + "\n").data(using: .utf8)!)
    printUsage(toError: true)
    exit(1)
}

@MainActor
func run(_ arguments: [String]) throws {
    guard let command = arguments.first else {
        printUsage()
        return
    }

    let args = Array(arguments.dropFirst())
    switch command {
    case "status-icon":
        runStatusIcon()

    case "version":
        print(Robot.getVersion())

    case "permissions":
        let prompt = args.contains("--prompt")
        let accessibility = prompt ? RobotPermissions.requestAccessibilityIfNeeded() : RobotPermissions.isAccessibilityTrusted
        print("accessibility=\(accessibility)")

    case "pos", "location":
        let point = Robot.location()
        print("\(point.x) \(point.y)")

    case "move":
        let (x, y) = try twoInts(args, usage: "move X Y")
        Robot.move(x: x, y: y)

    case "move-smooth":
        let (x, y) = try twoInts(args, usage: "move-smooth X Y [duration]")
        let duration = args.count > 2 ? (Double(args[2]) ?? 0.35) : 0.35
        RobotMouse.moveSmooth(to: RobotPoint(x: x, y: y), duration: duration)

    case "click":
        let button = try mouseButton(args.first ?? "left")
        Robot.click(button, doubleClick: args.contains("--double"))

    case "drag":
        guard args.count >= 2, let x = Int(args[0]), let y = Int(args[1]) else {
            throw CommandError(errorDescription: "Usage: drag X Y [left|right|middle]")
        }
        let button = try mouseButton(args.count > 2 ? args[2] : "left")
        RobotMouse.drag(to: RobotPoint(x: x, y: y), button: button)

    case "scroll":
        let (dx, dy) = try twoInts(args, usage: "scroll DX DY")
        RobotMouse.scroll(dx: dx, dy: dy)

    case "key":
        guard let key = args.first else {
            throw CommandError(errorDescription: "Usage: key KEY [MODIFIER...]")
        }
        try Robot.keyTap(key, modifiers: Array(args.dropFirst()))

    case "type":
        guard !args.isEmpty else {
            throw CommandError(errorDescription: "Usage: type TEXT [--paste]")
        }
        let paste = args.contains("--paste")
        let text = args.filter { $0 != "--paste" }.joined(separator: " ")
        if paste {
            try RobotKeyboard.pasteText(text)
        } else {
            Robot.typeText(text)
        }

    case "copy":
        try Robot.writeClipboard(args.joined(separator: " "))

    case "paste":
        print(Robot.readClipboard())

    case "size":
        let size = Robot.screenSize()
        print("\(size.width) \(size.height)")

    case "displays":
        for (index, id) in RobotScreen.displayIDs().enumerated() {
            let rect = try RobotScreen.displayRect(index)
            let scale = RobotScreen.scale(displayIndex: index)
            print("\(index): id=\(id) x=\(rect.x) y=\(rect.y) w=\(rect.width) h=\(rect.height) scale=\(scale)")
        }

    case "rect":
        let index = args.first.flatMap(Int.init) ?? RobotScreen.mainDisplayIndex()
        let rect = try RobotScreen.displayRect(index)
        print("\(rect.x) \(rect.y) \(rect.width) \(rect.height)")

    case "windows":
        for window in RobotWindows.list() {
            let title = window.title.isEmpty ? "-" : window.title
            print("\(window.id) pid=\(window.ownerPID) \(window.ownerName) \(window.bounds.x),\(window.bounds.y),\(window.bounds.width),\(window.bounds.height) \(title)")
        }

    case "active":
        print("\(RobotWindows.activeApplicationPID() ?? -1) \(RobotWindows.activeApplicationName() ?? "")")

    case "activate":
        guard let pidString = args.first, let pid = Int32(pidString) else {
            throw CommandError(errorDescription: "Usage: activate PID")
        }
        print(try RobotWindows.activate(pid: pid))

    case "processes":
        for process in RobotProcesses.all() {
            print("\(process.pid) \(process.name) \(process.path ?? "")")
        }

    case "find":
        guard let name = args.first else {
            throw CommandError(errorDescription: "Usage: find NAME")
        }
        print(RobotProcesses.findIDs(named: name).map(String.init).joined(separator: " "))

    case "kill":
        guard let pidString = args.first, let pid = Int32(pidString) else {
            throw CommandError(errorDescription: "Usage: kill PID")
        }
        try RobotProcesses.kill(pid: pid)

    case "alert":
        guard args.count >= 2 else {
            throw CommandError(errorDescription: "Usage: alert TITLE MESSAGE")
        }
        print(RobotWindows.alert(title: args[0], message: args.dropFirst().joined(separator: " ")))

    case "help", "-h", "--help":
        printUsage()

    default:
        throw CommandError(errorDescription: "Unknown command: \(command)")
    }
}

func twoInts(_ args: [String], usage: String) throws -> (Int, Int) {
    guard args.count >= 2, let first = Int(args[0]), let second = Int(args[1]) else {
        throw CommandError(errorDescription: "Usage: \(usage)")
    }
    return (first, second)
}

func mouseButton(_ value: String) throws -> MouseButton {
    guard let button = MouseButton(rawValue: value.lowercased()) else {
        throw CommandError(errorDescription: "Unknown mouse button: \(value)")
    }
    return button
}

func printUsage(toError: Bool = false) {
    let text = """
    robot-swift: native macOS desktop automation

    Commands:
      permissions [--prompt]
      status-icon
      pos | move X Y | move-smooth X Y [duration]
      click [left|right|middle] [--double] | drag X Y [button] | scroll DX DY
      key KEY [MODIFIER...] | type TEXT [--paste]
      copy TEXT | paste
      size | displays | rect [display]
      windows | active | activate PID
      processes | find NAME | kill PID
      alert TITLE MESSAGE
      version
    """
    let data = (text + "\n").data(using: .utf8)!
    if toError {
        FileHandle.standardError.write(data)
    } else {
        FileHandle.standardOutput.write(data)
    }
}
